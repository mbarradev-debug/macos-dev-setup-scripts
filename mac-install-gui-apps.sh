#!/usr/bin/env bash
# Author: Miguel Barra <mbarra.git@gmail.com>
set -euo pipefail

echo "==========================================="
echo "  Installing GUI apps via Homebrew"
echo "  - Editors / IDE / Terminal"
echo "  - DB / APIs / Docker"
echo "  - Browsers"
echo "  - Communication"
echo "  - Multimedia / Gaming"
echo "  - Utilities (Keka, iStat Menus)"
echo "==========================================="

# --------------------------------------------------
# 0) Basic checks
# --------------------------------------------------
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This script is intended for macOS."
  exit 1
fi

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew is not installed or not in PATH."
  echo "Install Homebrew first and then run this script again."
  exit 1
fi

# --------------------------------------------------
# 0.1) Install Rosetta 2
# --------------------------------------------------
echo "[+] Checking Rosetta 2..."
if /usr/bin/pgrep oahd >/dev/null 2>&1; then
  echo "Rosetta is already installed."
else
  echo "[+] Rosetta is not installed. Installing..."
  sudo /usr/sbin/softwareupdate --install-rosetta --agree-to-license
  echo "Rosetta installed successfully."
fi

# --------------------------------------------------
# 1) Editors, IDE and terminal
# --------------------------------------------------
echo "[+] Installing editors and terminal..."

brew install --cask \
  visual-studio-code \
  cursor \
  iterm2 \
  jetbrains-toolbox \
  claude \
  figma \
  linear || true

# --------------------------------------------------
# 2) Databases, APIs and Docker
# --------------------------------------------------
echo "[+] Installing graphical development tools..."

brew install --cask \
  dbeaver-community \
  docker \
  postman || true

# --------------------------------------------------
# 3) Browsers
# --------------------------------------------------
echo "[+] Installing browsers..."

brew install --cask \
  google-chrome \
  firefox || true

# --------------------------------------------------
# 4) Communication
# --------------------------------------------------
echo "[+] Installing communication apps..."

brew install --cask \
  zoom || true

# --------------------------------------------------
# 5) Multimedia / Gaming
# --------------------------------------------------
echo "[+] Installing multimedia and gaming apps..."

brew install --cask \
  openemu \
  vlc || true

# --------------------------------------------------
# 6) Additional utilities
# --------------------------------------------------
echo "[+] Installing utilities..."

brew install --cask \
  keka \
  istat-menus \
  keyboardcleantool || true

# --------------------------------------------------
# END
# --------------------------------------------------
echo "==========================================="
echo "GUI apps installation completed."
echo "You can open them from Launchpad or Spotlight."
echo "==========================================="
