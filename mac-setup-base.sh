#!/usr/bin/env bash
# Author: Miguel Barra <mbarra.git@gmail.com>
set -euo pipefail

echo "==========================================="
echo "  macOS Apple Silicon setup"
echo "  - Xcode Command Line Tools + license"
echo "  - Homebrew (+ PATH in .zshrc)"
echo "  - Oh My Zsh"
echo "  - Powerlevel10k"
echo "  - Fira Code Nerd Font Mono"
echo "  - zsh-autosuggestions + zsh-syntax-highlighting (via brew)"
echo "==========================================="

# --------------------------------------------------
# 0) Basic check
# --------------------------------------------------
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This script only works on macOS."
  exit 1
fi

# --------------------------------------------------
# 1) Xcode Command Line Tools
# --------------------------------------------------
echo "[+] Checking Xcode Command Line Tools..."
if ! xcode-select -p >/dev/null 2>&1; then
  echo "Not installed. Launching graphical installer..."
  xcode-select --install || true
  echo
  echo "Complete the installation from the macOS popup and then run this script again."
  exit 1
else
  echo "Xcode Command Line Tools are already installed."
fi

# --------------------------------------------------
# 1.1) Xcode license
# --------------------------------------------------
echo "[+] Checking Xcode license..."

NEEDS_LICENSE=0
if xcodebuild -license check >/dev/null 2>&1; then
  echo "The Xcode license is already accepted."
else
  echo "The Xcode license is NOT accepted."
  NEEDS_LICENSE=1
fi

echo "[+] Checking sudo access (may ask for your password)..."
if sudo -v; then
  # Keep sudo alive
  while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
else
  echo "Could not obtain sudo permissions. Aborting."
  exit 1
fi

if [[ "$NEEDS_LICENSE" -eq 1 ]]; then
  echo "[+] Attempting automatic license acceptance..."
  if sudo xcodebuild -license accept >/dev/null 2>&1; then
    echo "License accepted automatically."
  else
    echo "Could not accept automatically."
    echo "Run manually:"
    echo "    sudo xcodebuild -license"
    echo "and type: agree"
    exit 1
  fi
fi

# --------------------------------------------------
# 2) Homebrew
# --------------------------------------------------
ZSHRC="${HOME}/.zshrc"
ZSHRC_WAS_MISSING=0

if [[ ! -f "${ZSHRC}" ]]; then
  ZSHRC_WAS_MISSING=1
  touch "${ZSHRC}"
fi

if ! command -v brew >/dev/null 2>&1; then
  echo "[+] Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
  echo "[+] Homebrew is already installed."
fi

# Detect prefix
if [[ -x "/opt/homebrew/bin/brew" ]]; then
  BREW_PREFIX="/opt/homebrew"
else
  BREW_PREFIX="$(brew --prefix)"
fi

echo "[+] Loading Homebrew into the current session..."
eval "$("${BREW_PREFIX}/bin/brew" shellenv)"

# Add to .zshrc
BREW_SNIPPET='eval "$('"${BREW_PREFIX}"'/bin/brew shellenv)"'
if ! grep -Fq "${BREW_SNIPPET}" "${ZSHRC}" 2>/dev/null; then
  echo "[+] Adding Homebrew to PATH in ~/.zshrc..."
  {
    echo ""
    echo "# >>> Homebrew >>>"
    echo "${BREW_SNIPPET}"
    echo "# <<< Homebrew <<<"
  } >> "${ZSHRC}"
else
  echo "[+] Homebrew was already in the PATH in ~/.zshrc."
fi

# --------------------------------------------------
# 3) Oh My Zsh
# --------------------------------------------------
if [[ ! -d "${HOME}/.oh-my-zsh" ]]; then
  echo "[+] Installing Oh My Zsh..."
  export RUNZSH=no
  export CHSH=no
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
  echo "[+] Oh My Zsh is already installed."
fi

# Ensure basic Oh My Zsh lines are in .zshrc if we just created it
if ! grep -q 'oh-my-zsh.sh' "${ZSHRC}" 2>/dev/null; then
  echo "[+] Configuring oh-my-zsh in ~/.zshrc..."
  {
    echo ''
    echo 'export ZSH="$HOME/.oh-my-zsh"'
    echo 'ZSH_THEME="robbyrussell"'
    echo 'plugins=(git)'
    echo 'source "$ZSH/oh-my-zsh.sh"'
  } >> "${ZSHRC}"
fi

# --------------------------------------------------
# 3.1) zsh-autosuggestions + zsh-syntax-highlighting (via Homebrew)
#       (Must go after Oh My Zsh)
# --------------------------------------------------
echo "[+] Installing zsh-autosuggestions and zsh-syntax-highlighting (via brew)..."

# Make sure brew is available
if ! command -v brew >/dev/null 2>&1; then
  echo "brew not available — make sure Homebrew is installed and in PATH."
  exit 1
fi

# Install the packages if not already installed
if ! brew list zsh-autosuggestions >/dev/null 2>&1; then
  echo "[+] Installing zsh-autosuggestions..."
  brew install zsh-autosuggestions
else
  echo "[+] zsh-autosuggestions already installed."
fi

if ! brew list zsh-syntax-highlighting >/dev/null 2>&1; then
  echo "[+] Installing zsh-syntax-highlighting..."
  brew install zsh-syntax-highlighting
else
  echo "[+] zsh-syntax-highlighting already installed."
fi

# Paths to the scripts installed by Homebrew
ZSH_AUTOSUGGESTIONS_SCRIPT="${BREW_PREFIX}/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
ZSH_SYNTAX_HIGHTLIGHT_SCRIPT="${BREW_PREFIX}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

# Add to ~/.zshrc (zsh-syntax-highlighting must be last)
if ! grep -Fq "${ZSH_AUTOSUGGESTIONS_SCRIPT}" "${ZSHRC}" 2>/dev/null; then
  echo "[+] Adding zsh-autosuggestions source to ~/.zshrc..."
  {
    echo ''
    echo '# >>> zsh-autosuggestions (via Homebrew) >>>'
    echo "if [ -f \"${ZSH_AUTOSUGGESTIONS_SCRIPT}\" ]; then"
    echo "  source \"${ZSH_AUTOSUGGESTIONS_SCRIPT}\""
    echo "fi"
    echo '# <<< zsh-autosuggestions <<<'
  } >> "${ZSHRC}"
else
  echo "[+] ~/.zshrc already loads zsh-autosuggestions."
fi

# Make sure zsh-syntax-highlighting is at the end of .zshrc
# (recommended by the project)
if ! grep -Fq "${ZSH_SYNTAX_HIGHTLIGHT_SCRIPT}" "${ZSHRC}" 2>/dev/null; then
  echo "[+] Adding zsh-syntax-highlighting source to the end of ~/.zshrc..."
  {
    echo ''
    echo '# >>> zsh-syntax-highlighting (via Homebrew) >>>'
    echo "if [ -f \"${ZSH_SYNTAX_HIGHTLIGHT_SCRIPT}\" ]; then"
    echo "  source \"${ZSH_SYNTAX_HIGHTLIGHT_SCRIPT}\""
    echo "fi"
    echo '# <<< zsh-syntax-highlighting <<<'
  } >> "${ZSHRC}"
else
  echo "[+] ~/.zshrc already loads zsh-syntax-highlighting."
fi

# --------------------------------------------------
# 4) Powerlevel10k
# --------------------------------------------------
P10K_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"

if [[ ! -d "${P10K_DIR}" ]]; then
  echo "[+] Installing Powerlevel10k..."
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${P10K_DIR}"
else
  echo "[+] Powerlevel10k is already installed."
fi

# ZSH_THEME -> powerlevel10k
if grep -q '^ZSH_THEME=' "${ZSHRC}" 2>/dev/null; then
  echo "[+] Setting ZSH_THEME=powerlevel10k in ~/.zshrc..."
  sed -i.bak 's/^ZSH_THEME=.*/ZSH_THEME="powerlevel10k\/powerlevel10k"/' "${ZSHRC}"
else
  echo '[+] Adding ZSH_THEME="powerlevel10k/powerlevel10k" to ~/.zshrc...'
  echo 'ZSH_THEME="powerlevel10k/powerlevel10k"' >> "${ZSHRC}"
fi

# Autoload .p10k.zsh
if ! grep -q '\.p10k.zsh' "${ZSHRC}" 2>/dev/null; then
  echo "[+] Adding automatic load of ~/.p10k.zsh..."
  {
    echo ''
    echo '# Load Powerlevel10k configuration if it exists'
    echo '[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh'
  } >> "${ZSHRC}"
fi

# --------------------------------------------------
# 5) Fira Code Nerd Font (no extra tap)
# --------------------------------------------------
echo "[+] Installing Fira Code Nerd Font Mono..."
brew install --cask font-fira-code-nerd-font

# --------------------------------------------------
# END
# --------------------------------------------------
echo "==========================================="
echo "Setup completed successfully."
echo
echo "1) Close and reopen the terminal, or run:"
echo "     source ~/.zshrc"
echo "2) The first time you open Powerlevel10k, the wizard will launch."
echo "3) In your terminal (iTerm2/Terminal), choose the font:"
echo "     FiraCode Nerd Font Mono"
echo "==========================================="
