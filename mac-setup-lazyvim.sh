#!/bin/bash

# ==========================================================
# LazyVim setup — thin wrapper around the dedicated config repo
# https://github.com/mbarradev-debug/lazyvim-config
#
# That repo IS ~/.config/nvim (pinned plugin versions, extras,
# and the LazyVim-Atajos.md cheat sheet). This script just clones
# it into place and runs its own install.sh.
#
# Safe to re-run (idempotent). Existing ~/.config/nvim that isn't
# already this repo is backed up, never deleted.
#
# Author: Miguel Barra <mbarra.git@gmail.com>
# ==========================================================

set -e

NVIM_CONFIG="$HOME/.config/nvim"
REPO_URL="git@github.com:mbarradev-debug/lazyvim-config.git"

echo "Setting up LazyVim (from $REPO_URL)..."
echo ""

# ----------------------------------------------------------
# 1. Back up any pre-existing ~/.config/nvim that isn't this repo
# ----------------------------------------------------------
if [ -d "$NVIM_CONFIG" ]; then
  if [ -d "$NVIM_CONFIG/.git" ] && git -C "$NVIM_CONFIG" remote get-url origin 2>/dev/null | grep -q "lazyvim-config"; then
    echo "~/.config/nvim is already this repo. Pulling latest..."
    git -C "$NVIM_CONFIG" pull --ff-only
  else
    BACKUP="$HOME/.config/nvim.bak.$(date +%Y%m%d%H%M%S)"
    echo "Existing ~/.config/nvim found (not this repo)."
    echo "Backing it up to: $BACKUP"
    mv "$NVIM_CONFIG" "$BACKUP"
  fi
fi

# ----------------------------------------------------------
# 2. Clone the config repo if it's not there yet
# ----------------------------------------------------------
if [ ! -d "$NVIM_CONFIG" ]; then
  echo "Cloning $REPO_URL..."
  git clone "$REPO_URL" "$NVIM_CONFIG"
fi

# ----------------------------------------------------------
# 3. Delegate to the repo's own bootstrap script (installs
#    Neovim if needed, syncs plugins, symlinks the cheat sheet)
# ----------------------------------------------------------
"$NVIM_CONFIG/install.sh"
