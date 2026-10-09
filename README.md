# macOS Dev Setup Scripts

A collection of shell scripts to set up and maintain a macOS (Apple Silicon) development machine, targeting a React / Next.js / TypeScript / PostgreSQL / Vercel stack.

## Scripts

| Script | Description |
| --- | --- |
| `mac-setup-base.sh` | Base macOS setup: Xcode Command Line Tools (+ license), Homebrew, Oh My Zsh, Powerlevel10k, Fira Code Nerd Font, and zsh plugins (`zsh-autosuggestions`, `zsh-syntax-highlighting`). Works with just the Command Line Tools (no Xcode.app needed), and registers the font with macOS right away (fresh macOS 27 installs otherwise ignore new fonts until the next login). |
| `mac-install-cli-tools.sh` | Installs essential CLI tools: Homebrew, Git, GitHub CLI, nvm + Node.js LTS, Vercel CLI, PostgreSQL client (`psql`), Neovim, tree, tmux, ripgrep, fzf, bat, eza, jq, htop, direnv, Docker CLI, and Watchman. Also drops minimal config files for Neovim (`~/.config/nvim/init.lua`) and tmux (`~/.tmux.conf`). |
| `mac-setup-lazyvim.sh` | Clones [`lazyvim-config`](https://github.com/mbarradev-debug/lazyvim-config) into `~/.config/nvim` over HTTPS (push stays on SSH), installs the `tree-sitter` CLI, and runs its `install.sh` (Neovim, pinned plugin versions, `snacks_picker`/`snacks_explorer` extras, and the `LazyVim-Atajos.md` keybindings cheat sheet symlinked into `$HOME`). Idempotent; backs up any pre-existing `~/.config/nvim` that isn't already that repo. |
| `mac-install-gui-apps.sh` | Installs GUI applications via Homebrew Cask: editors/IDEs, database/API tools, browsers, communication apps, multimedia/gaming, and utilities. |
| `mac-setup-ssh-github.sh` | Generates a personal SSH key and configures `~/.ssh/config` for GitHub. |
| `mac-clone-repos.sh` | Clones a predefined set of work repositories into local folders. Requires a `github-work` host alias (with your work key) in `~/.ssh/config`; skips repos already cloned and exits non-zero if any clone fails. |
| `mac-clean.sh` | Safe nightly cleanup of caches, logs, crash reports, temp files, and package manager caches (Homebrew, npm, yarn, pip, Docker). Logs to `~/Library/Logs/NightlyCleanup`. |

## Usage

Each script is standalone and can be run directly:

```bash
chmod +x mac-setup-base.sh
./mac-setup-base.sh
```

Recommended order for a fresh machine:

1. `mac-setup-base.sh`
2. `mac-install-cli-tools.sh`
3. `mac-setup-lazyvim.sh`
4. `mac-install-gui-apps.sh`
5. `mac-setup-ssh-github.sh`
6. `mac-clone-repos.sh`

`mac-clean.sh` is intended to be run periodically (e.g. via a scheduled `launchd`/cron job).

## Author

Miguel Barra <mbarra.git@gmail.com>
