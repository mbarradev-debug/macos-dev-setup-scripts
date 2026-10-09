#!/bin/bash

# ==========================================================
# Essential CLI tools setup for Mac
# Stack: React / Next.js / TypeScript / PostgreSQL / Vercel
#
# Author: Miguel Barra <mbarra.git@gmail.com>
# ==========================================================

set -e

echo "Starting installation of essential tools..."
echo ""

# ----------------------------------------------------------
# 1. Homebrew (base package manager for everything else)
# ----------------------------------------------------------
if ! command -v brew &> /dev/null; then
  echo "Homebrew not found. Installing..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Add Homebrew to PATH (Apple Silicon)
  if [[ $(uname -m) == "arm64" ]]; then
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
else
  echo "Homebrew is already installed."
fi

echo ""
echo "Updating Homebrew..."
brew update

# ----------------------------------------------------------
# 2. Git (version control)
# ----------------------------------------------------------
if ! command -v git &> /dev/null; then
  echo "Installing Git..."
  brew install git
else
  echo "Git is already installed."
fi

# ----------------------------------------------------------
# 3. GitHub CLI (manage repos, PRs, issues from the terminal)
# ----------------------------------------------------------
if ! command -v gh &> /dev/null; then
  echo "Installing GitHub CLI..."
  brew install gh
else
  echo "GitHub CLI is already installed."
fi

# ----------------------------------------------------------
# 4. nvm (Node.js version manager)
# ----------------------------------------------------------
export NVM_DIR="$HOME/.nvm"
if [ ! -d "$NVM_DIR" ]; then
  echo "Installing nvm..."
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
else
  echo "nvm is already installed."
fi

# Load nvm into this shell (also on re-runs, so npm is available below)
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

if ! command -v node &> /dev/null; then
  echo "Installing Node.js LTS with nvm..."
  nvm install --lts
  nvm alias default lts/*
else
  echo "Node.js is already installed ($(node --version))."
fi

# ----------------------------------------------------------
# 5. Vercel CLI (deploy your Next.js projects)
# ----------------------------------------------------------
if ! command -v npm &> /dev/null; then
  echo "npm not available (nvm/Node.js failed to load). Skipping Vercel CLI."
elif ! command -v vercel &> /dev/null; then
  echo "Installing Vercel CLI..."
  npm install -g vercel
else
  echo "Vercel CLI is already installed."
fi

# ----------------------------------------------------------
# 6. PostgreSQL client (psql)
# ----------------------------------------------------------
if ! command -v psql &> /dev/null; then
  echo "Installing PostgreSQL client (libpq)..."
  brew install libpq
  brew link --force libpq
else
  echo "PostgreSQL client is already installed."
fi

# ----------------------------------------------------------
# 7. Neovim (terminal text editor)
# ----------------------------------------------------------
if ! command -v nvim &> /dev/null; then
  echo "Installing Neovim..."
  brew install neovim
else
  echo "Neovim is already installed."
fi

if [ ! -f "$HOME/.config/nvim/init.lua" ]; then
  echo "Creating minimal Neovim config at ~/.config/nvim..."
  mkdir -p "$HOME/.config/nvim"
  cat > "$HOME/.config/nvim/init.lua" <<'EOF'
-- Minimal initial configuration
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.mouse = "a"
vim.opt.clipboard = "unnamedplus"
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.g.mapleader = " "
EOF
else
  echo "A Neovim config already exists at ~/.config/nvim."
fi

# ----------------------------------------------------------
# 8. tree (visualize directory structure)
# ----------------------------------------------------------
if ! command -v tree &> /dev/null; then
  echo "Installing tree..."
  brew install tree
else
  echo "tree is already installed."
fi

# ----------------------------------------------------------
# 9. tmux (terminal multiplexer)
# ----------------------------------------------------------
if ! command -v tmux &> /dev/null; then
  echo "Installing tmux..."
  brew install tmux
else
  echo "tmux is already installed."
fi

if [ ! -f "$HOME/.tmux.conf" ]; then
  echo "Creating minimal tmux config at ~/.tmux.conf..."
  cat > "$HOME/.tmux.conf" <<'EOF'
# Minimal initial configuration
set -g mouse on
set -g base-index 1
setw -g pane-base-index 1
set -g history-limit 10000

# More comfortable prefix: Ctrl-a instead of Ctrl-b
unbind C-b
set -g prefix C-a
bind C-a send-prefix

# Reload config with prefix + r
bind r source-file ~/.tmux.conf \; display "Config reloaded"
EOF
else
  echo "A tmux config already exists at ~/.tmux.conf."
fi

# ----------------------------------------------------------
# 10. Search and productivity: ripgrep, fzf, bat, eza
# ----------------------------------------------------------
if ! command -v rg &> /dev/null; then
  echo "Installing ripgrep..."
  brew install ripgrep
else
  echo "ripgrep is already installed."
fi

if ! command -v fzf &> /dev/null; then
  echo "Installing fzf..."
  brew install fzf
  "$(brew --prefix)/opt/fzf/install" --key-bindings --completion --no-update-rc
else
  echo "fzf is already installed."
fi

if ! command -v bat &> /dev/null; then
  echo "Installing bat..."
  brew install bat
else
  echo "bat is already installed."
fi

if ! command -v eza &> /dev/null; then
  echo "Installing eza..."
  brew install eza
else
  echo "eza is already installed."
fi

# ----------------------------------------------------------
# 11. Utilities: jq, htop, direnv
# ----------------------------------------------------------
if ! command -v jq &> /dev/null; then
  echo "Installing jq..."
  brew install jq
else
  echo "jq is already installed."
fi

if ! command -v htop &> /dev/null; then
  echo "Installing htop..."
  brew install htop
else
  echo "htop is already installed."
fi

if ! command -v direnv &> /dev/null; then
  echo "Installing direnv..."
  brew install direnv
  if ! grep -q "direnv hook zsh" "$HOME/.zshrc" 2>/dev/null; then
    echo 'eval "$(direnv hook zsh)"' >> "$HOME/.zshrc"
  fi
else
  echo "direnv is already installed."
fi

# ----------------------------------------------------------
# 12. Docker CLI + Watchman
# ----------------------------------------------------------
if ! command -v docker &> /dev/null; then
  echo "Installing Docker CLI..."
  brew install docker
  echo "Note: only the Docker CLI was installed. You need a daemon (Docker Desktop, colima, etc.) to run containers."
else
  echo "Docker CLI is already installed."
fi

if ! command -v watchman &> /dev/null; then
  echo "Installing Watchman..."
  brew install watchman
else
  echo "Watchman is already installed."
fi

echo ""
echo "Done! Installed tools:"
echo "   - Homebrew"
echo "   - Git"
echo "   - GitHub CLI (gh)"
echo "   - nvm + Node.js LTS"
echo "   - Vercel CLI"
echo "   - psql (PostgreSQL client)"
echo "   - Neovim (+ minimal config at ~/.config/nvim)"
echo "   - tree"
echo "   - tmux (+ minimal config at ~/.tmux.conf, prefix Ctrl-a)"
echo "   - ripgrep, fzf, bat, eza"
echo "   - jq, htop, direnv"
echo "   - Docker CLI, Watchman"
echo ""
echo "Close and reopen your terminal (or run 'source ~/.zprofile' and 'source ~/.zshrc') for everything to take effect."
