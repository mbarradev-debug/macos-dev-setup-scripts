#!/usr/bin/env bash
# Author: Miguel Barra <mbarra.git@gmail.com>
set -euo pipefail

echo "==========================================="
echo "  Installing GUI apps via Homebrew"
echo "  - Editors / IDE / Terminal"
echo "  - DB / APIs / Docker"
echo "  - Browsers"
echo "  - Communication"
echo "  - Notes / Productivity"
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
# oahd only runs on demand, so check that x86_64 binaries actually execute
if /usr/bin/arch -x86_64 /usr/bin/true >/dev/null 2>&1; then
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
# 5) Notes / Productivity
# --------------------------------------------------
echo "[+] Installing notes and productivity apps..."

brew install --cask \
  notion \
  obsidian || true

# --------------------------------------------------
# 6) Multimedia / Gaming
# --------------------------------------------------
echo "[+] Installing multimedia and gaming apps..."

# openemu is disabled in Homebrew (fails Gatekeeper); install it manually from openemu.org
brew install --cask \
  vlc \
  cog \
  spotify || true

# --------------------------------------------------
# 7) Additional utilities
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
