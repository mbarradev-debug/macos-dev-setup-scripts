#!/usr/bin/env bash
# Author: Miguel Barra <mbarra.git@gmail.com>
set -euo pipefail

echo "==========================================="
echo "  iTerm2 privacy & security permissions"
echo "  - Touch ID for sudo (+ pam-reattach for tmux)"
echo "  - Developer Tools pane for terminals"
echo "  - Guided manual grants (one panel at a time):"
echo "    Accessibility, App Management,"
echo "    Developer Tools, Full Disk Access"
echo "  - Final verification summary"
echo "==========================================="

usage() {
  echo "Usage: $(basename "$0") [--check]"
  echo "  (no option)  Automate what can be automated and guide the manual grants"
  echo "  --check      Only verify and print the summary (changes nothing)"
}

MODE="setup"
case "${1:-}" in
  "")        ;;
  --check)   MODE="check" ;;
  -h|--help) usage; exit 0 ;;
  *)         usage; exit 1 ;;
esac

ITERM_APP="/Applications/iTerm.app"
ITERM_BUNDLE_ID="com.googlecode.iterm2"
SUDO_LOCAL="/etc/pam.d/sudo_local"
PAM_TID_MODULE="/usr/lib/pam/pam_tid.so.2"
PAM_TID_LINE="auth       sufficient     pam_tid.so"
SYSTEM_TCC_DB="/Library/Application Support/com.apple.TCC/TCC.db"
USER_TCC_DB="${HOME}/Library/Application Support/com.apple.TCC/TCC.db"
SETTINGS_URL="x-apple.systempreferences:com.apple.preference.security"

# Permissions granted by hand, in the order they are opened.
# Full Disk Access goes last: macOS offers "Quit & Reopen" for iTerm,
# which would kill this script if accepted.
PERM_NAMES=("Accessibility" "App Management" "Developer Tools" "Full Disk Access")
PERM_SERVICES=("kTCCServiceAccessibility" "kTCCServiceSystemPolicyAppBundles" "kTCCServiceDeveloperTool" "kTCCServiceSystemPolicyAllFiles")
PERM_ANCHORS=("Privacy_Accessibility" "Privacy_AppBundles" "Privacy_DevTools" "Privacy_AllFiles")
PERM_PATHS=(
  "Privacy & Security > Accessibility"
  "Privacy & Security > App Management"
  "Privacy & Security > Developer Tools"
  "Privacy & Security > Full Disk Access"
)

# --------------------------------------------------
# 0) Basic checks
# --------------------------------------------------
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This script only works on macOS."
  exit 1
fi

if [[ ! -d "${ITERM_APP}" ]]; then
  echo "iTerm2 is not installed at ${ITERM_APP}."
  echo "Run ./mac-install-gui-apps.sh first (brew install --cask iterm2)."
  exit 1
fi

if [[ "${TERM_PROGRAM:-}" != "iTerm.app" ]]; then
  echo "[!] You are not running this from iTerm2 (TERM_PROGRAM=${TERM_PROGRAM:-unknown})."
  echo "    It still works, but run it from iTerm2 for the most accurate checks."
fi

# --------------------------------------------------
# Helpers: read-only permission checks
# --------------------------------------------------
# The TCC database is only readable by an app that already has Full Disk
# Access. We only READ it (sqlite3 -readonly); we never write to it.
tcc_db_readable() {
  head -c 16 "${SYSTEM_TCC_DB}" >/dev/null 2>&1
}

# Prints: granted | missing | unknown
perm_status() {
  local service="$1" db value found_db=0
  if tcc_db_readable; then
    for db in "${SYSTEM_TCC_DB}" "${USER_TCC_DB}"; do
      [[ -f "${db}" ]] || continue
      if value="$(sqlite3 -readonly "${db}" \
          "SELECT auth_value FROM access WHERE service='${service}' AND client='${ITERM_BUNDLE_ID}' LIMIT 1;" 2>/dev/null)"; then
        found_db=1
        if [[ "${value}" == "2" ]]; then
          echo "granted"
          return
        fi
      fi
    done
    if [[ "${found_db}" -eq 1 ]]; then
      echo "missing"
      return
    fi
  fi

  # Without database access, Accessibility can still be asked live,
  # but only when we are running inside iTerm2.
  if [[ "${service}" == "kTCCServiceAccessibility" && "${TERM_PROGRAM:-}" == "iTerm.app" ]]; then
    case "$(osascript -l JavaScript -e 'ObjC.import("ApplicationServices"); $.AXIsProcessTrusted()' 2>/dev/null || true)" in
      true)  echo "granted"; return ;;
      false) echo "missing"; return ;;
    esac
  fi
  echo "unknown"
}

touch_id_status() {
  if [[ -f "${SUDO_LOCAL}" ]] && grep -Eq '^[[:space:]]*auth[[:space:]]+sufficient[[:space:]]+pam_tid\.so' "${SUDO_LOCAL}"; then
    echo "granted"
  else
    echo "missing"
  fi
}

# --------------------------------------------------
# 1) Touch ID for sudo (automatic)
# --------------------------------------------------
setup_touch_id_sudo() {
  echo "[+] Checking Touch ID for sudo..."
  if [[ ! -f "${PAM_TID_MODULE}" ]]; then
    echo "[!] ${PAM_TID_MODULE} not found; skipping Touch ID for sudo."
    return
  fi

  # pam-reattach lets Touch ID work inside tmux and restored iTerm sessions
  local reattach_line=""
  if command -v brew >/dev/null 2>&1; then
    local brew_prefix
    brew_prefix="$(brew --prefix)"
    if [[ ! -f "${brew_prefix}/lib/pam/pam_reattach.so" ]]; then
      echo "[+] Installing pam-reattach (Touch ID inside tmux)..."
      brew install pam-reattach || echo "[!] Could not install pam-reattach; continuing without it."
    fi
    if [[ -f "${brew_prefix}/lib/pam/pam_reattach.so" ]]; then
      reattach_line="auth       optional       ${brew_prefix}/lib/pam/pam_reattach.so ignore_ssh"
    fi
  else
    echo "[!] Homebrew not found; skipping pam-reattach (Touch ID won't work inside tmux)."
  fi

  # Keep whatever else is in the file, drop our lines, add them back in order
  local existing="" rest desired
  [[ -f "${SUDO_LOCAL}" ]] && existing="$(cat "${SUDO_LOCAL}")"
  rest="$(printf '%s\n' "${existing}" | grep -Ev '^[[:space:]]*$|pam_tid\.so|pam_reattach\.so' || true)"
  desired="$(
    [[ -n "${rest}" ]] && printf '%s\n' "${rest}"
    [[ -n "${reattach_line}" ]] && printf '%s\n' "${reattach_line}"
    printf '%s\n' "${PAM_TID_LINE}"
  )"

  if [[ "${desired}" == "${existing}" ]]; then
    echo "Touch ID for sudo is already configured."
    return
  fi

  echo "[+] Writing ${SUDO_LOCAL} (asks for your password once)..."
  if [[ -f "${SUDO_LOCAL}" ]]; then
    sudo cp "${SUDO_LOCAL}" "${SUDO_LOCAL}.bak.$(date +%Y%m%d%H%M%S)"
  fi
  printf '%s\n' "${desired}" | sudo tee "${SUDO_LOCAL}" >/dev/null
  sudo chown root:wheel "${SUDO_LOCAL}"
  sudo chmod 444 "${SUDO_LOCAL}"
  echo "Touch ID for sudo configured. Test it later with: sudo -k && sudo true"
}

# --------------------------------------------------
# 2) Developer Tools pane (automatic)
# --------------------------------------------------
setup_developer_tools_pane() {
  echo "[+] Making the Developer Tools pane visible in System Settings..."
  if spctl developer-mode enable-terminal >/dev/null 2>&1; then
    echo "Developer Tools pane is available."
  else
    echo "[!] spctl could not enable it; the pane may already be visible."
  fi
}

# --------------------------------------------------
# 3) Manual grants, one panel at a time
# --------------------------------------------------
guide_manual_grants() {
  local i status answer
  for i in "${!PERM_NAMES[@]}"; do
    status="$(perm_status "${PERM_SERVICES[$i]}")"
    if [[ "${status}" == "granted" ]]; then
      echo "[+] ${PERM_NAMES[$i]}: already granted to iTerm2."
      continue
    fi

    echo
    echo "[+] ${PERM_NAMES[$i]} (${PERM_PATHS[$i]})"
    echo "    1. Turn on the switch next to iTerm."
    echo "    2. If iTerm is not in the list, click +, choose Applications > iTerm and turn it on."
    if [[ "${PERM_SERVICES[$i]}" == "kTCCServiceSystemPolicyAllFiles" ]]; then
      echo "    3. If macOS offers 'Quit & Reopen', choose 'Later' so this script keeps running."
    fi
    open "${SETTINGS_URL}?${PERM_ANCHORS[$i]}" || echo "[!] Could not open the panel; go there by hand."
    answer=""
    read -r -p "    Press Enter when done (or type s + Enter to skip)... " answer </dev/tty || true
    if [[ "${answer}" == "s" ]]; then
      echo "    Skipped."
    fi
  done
}

# --------------------------------------------------
# 4) Summary
# --------------------------------------------------
print_summary() {
  local i status label ready=0 missing=0 unknown=0

  print_row() {
    case "$2" in
      granted) label="[OK]     "; ready=$((ready + 1)) ;;
      missing) label="[MISSING]"; missing=$((missing + 1)) ;;
      *)       label="[RECHECK]"; unknown=$((unknown + 1)) ;;
    esac
    echo "  ${label} $1"
  }

  echo
  echo "==========================================="
  echo "  Summary for iTerm2"
  echo "==========================================="
  print_row "Touch ID for sudo" "$(touch_id_status)"
  for i in "${!PERM_NAMES[@]}"; do
    status="$(perm_status "${PERM_SERVICES[$i]}")"
    print_row "${PERM_NAMES[$i]}" "${status}"
  done
  echo "-------------------------------------------"
  echo "  Ready: ${ready}  Missing: ${missing}  To recheck: ${unknown}"
  echo "==========================================="

  if [[ "${unknown}" -gt 0 ]]; then
    echo "Some permissions can only be verified once iTerm2 has Full Disk Access"
    echo "and has been restarted. Quit iTerm2 (Cmd+Q), open it again and run:"
    echo "    ./$(basename "$0") --check"
  fi
  if [[ "${missing}" -gt 0 ]]; then
    echo "Run ./$(basename "$0") again to be guided through the missing ones."
  fi
  if [[ "${missing}" -eq 0 && "${unknown}" -eq 0 ]]; then
    echo "All set. Restart iTerm2 once if you just granted something."
  fi
}

# --------------------------------------------------
# Run
# --------------------------------------------------
if [[ "${MODE}" == "setup" ]]; then
  setup_touch_id_sudo
  setup_developer_tools_pane
  guide_manual_grants
fi
print_summary
