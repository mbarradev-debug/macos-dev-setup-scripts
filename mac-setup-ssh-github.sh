#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# mac-setup-ssh-github.sh
#
# Author: Miguel Barra <mbarra.git@gmail.com>
#
# Sets up a personal SSH key for GitHub:
# - Creates the key if it doesn't exist.
# - Adds it to the ssh-agent.
# - Writes ~/.ssh/config using that key for github.com.
# - Shows the public key at the end so you can copy it to GitHub.
#
# Optional variables (env):
#   PERSONAL_EMAIL   (default: mbarra.dev@icloud.com)
#   KEY_TYPE         (default: ed25519, can be rsa)
#   CLEAN_AGENT      (default: false; if true runs ssh-add -D first)
###############################################################################

# ---------- logging helpers ----------
info()  { printf "\033[32m[INFO]\033[0m %s\n" "$*"; }
warn()  { printf "\033[33m[WARN]\033[0m %s\n" "$*"; }
error() { printf "\033[31m[ERROR]\033[0m %s\n" "$*\n" >&2; exit 1; }

# ---------- variables ----------
PERSONAL_EMAIL="${PERSONAL_EMAIL:-mbarra.dev@icloud.com}"
KEY_TYPE="${KEY_TYPE:-ed25519}"

if [[ "${KEY_TYPE}" == "ed25519" ]]; then
  PERSONAL_KEY="${PERSONAL_KEY:-${HOME}/.ssh/id_ed25519_github_personal}"
else
  PERSONAL_KEY="${PERSONAL_KEY:-${HOME}/.ssh/id_rsa_github_personal}"
fi

CLEAN_AGENT="${CLEAN_AGENT:-false}"

info "Configuration:"
info "  Personal key   : ${PERSONAL_KEY} (${PERSONAL_EMAIL})"
info "  Key type       : ${KEY_TYPE}"

# ---------- main functions ----------

ensure_ssh_dir() {
  if [[ ! -d "${HOME}/.ssh" ]]; then
    info "Creating ~/.ssh directory..."
    mkdir -p "${HOME}/.ssh"
    chmod 700 "${HOME}/.ssh"
  fi
}

generate_key_if_missing() {
  local key_path="$1"
  local email="$2"

  if [[ -f "${key_path}" ]]; then
    info "Key already exists: ${key_path}"
    return
  fi

  info "Creating SSH key: ${key_path}"
  if [[ "${KEY_TYPE}" == "ed25519" ]]; then
    ssh-keygen -t ed25519 -C "${email}" -f "${key_path}" -N ""
  else
    ssh-keygen -t rsa -b 4096 -C "${email}" -f "${key_path}" -N ""
  fi
}

start_ssh_agent_if_needed() {
  # ssh-add -l exits 0 (has keys) or 1 (no keys) when it can reach an agent,
  # and 2 when it can't. On macOS, launchd provides the agent in Terminal.
  local rc=0
  ssh-add -l >/dev/null 2>&1 || rc=$?
  if [[ "${rc}" -eq 2 ]]; then
    info "No reachable ssh-agent (SSH_AUTH_SOCK unset or stale). Starting one for this run..."
    eval "$(ssh-agent -s)" >/dev/null
    # Only lives for this run; ~/.ssh/config points ssh at the key anyway
    trap 'ssh-agent -k >/dev/null 2>&1' EXIT
  fi
}

add_key_to_agent() {
  local key_path="$1"
  local fingerprint
  fingerprint="$(ssh-keygen -lf "${key_path}.pub" | awk '{print $2}')"

  if ! ssh-add -l 2>/dev/null | grep -qF "${fingerprint}"; then
    info "Adding key to ssh-agent: ${key_path}"
    ssh-add "${key_path}"
  else
    info "Key is already in the ssh-agent: ${key_path}"
  fi
}

clean_agent_if_requested() {
  if [[ "${CLEAN_AGENT}" == "true" ]]; then
    warn "Clearing current identities from the ssh-agent (ssh-add -D)..."
    ssh-add -D || true
  fi
}

write_ssh_config() {
  local cfg="${HOME}/.ssh/config"

  info "Updating ~/.ssh/config..."

  # Backup if it exists
  if [[ -f "${cfg}" && ! -f "${cfg}.bak" ]]; then
    cp "${cfg}" "${cfg}.bak"
    info "Backup created: ${cfg}.bak"
  fi

  # Remove previous github.com block
  local tmp
  tmp="$(mktemp)"
  if [[ -f "${cfg}" ]]; then
    awk '
      BEGIN { skip=0 }
      /^Host[[:space:]]+github\.com$/ { skip=1; next }
      /^Host[[:space:]]+/ && skip==1 { skip=0 }
      skip==0 { print }
    ' "${cfg}" > "${tmp}"
  fi

  cat >> "${tmp}" <<EOF

Host github.com
  HostName github.com
  User git
  IdentityFile ${PERSONAL_KEY}
  IdentitiesOnly yes
EOF

  mv "${tmp}" "${cfg}"
  chmod 600 "${cfg}"
  info "~/.ssh/config updated."
}

show_public_key() {
  echo
  info "================ PUBLIC KEY FOR GITHUB ================"
  if [[ -f "${PERSONAL_KEY}.pub" ]]; then
    echo
    echo ">>> PERSONAL key (${PERSONAL_KEY}.pub):"
    cat "${PERSONAL_KEY}.pub"
    echo
  else
    warn "Could not find ${PERSONAL_KEY}.pub"
  fi

  cat <<EOT

Paste this key into GitHub:

  Settings -> SSH and GPG keys -> New SSH key
  Suggested title: "Personal laptop"

EOT
}

# ---------- main ----------

ensure_ssh_dir
generate_key_if_missing "${PERSONAL_KEY}" "${PERSONAL_EMAIL}"

start_ssh_agent_if_needed
clean_agent_if_requested
add_key_to_agent "${PERSONAL_KEY}"

write_ssh_config
show_public_key
