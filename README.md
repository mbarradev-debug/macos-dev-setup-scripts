# macOS Dev Setup Scripts

A collection of shell scripts to set up and maintain a macOS (Apple Silicon) development machine, targeting a React / Next.js / TypeScript / PostgreSQL / Vercel stack.

## Scripts

| Script | Description |
| --- | --- |
| `mac-setup-base.sh` | Base macOS setup: Xcode Command Line Tools (+ license), Homebrew, Oh My Zsh, Powerlevel10k, Fira Code Nerd Font, and zsh plugins (`zsh-autosuggestions`, `zsh-syntax-highlighting`). |
| `mac-install-cli-tools.sh` | Installs essential CLI tools: Homebrew, Git, GitHub CLI, nvm + Node.js LTS, Vercel CLI, PostgreSQL client (`psql`), Neovim, tree, tmux, ripgrep, fzf, bat, eza, jq, htop, direnv, Docker CLI, and Watchman. Also drops minimal config files for Neovim (`~/.config/nvim/init.lua`) and tmux (`~/.tmux.conf`). |
| `mac-install-gui-apps.sh` | Installs GUI applications via Homebrew Cask: editors/IDEs, database/API tools, browsers, communication apps, multimedia/gaming, and utilities. |
| `mac-setup-ssh-github.sh` | Generates a personal SSH key and configures `~/.ssh/config` for GitHub. |
| `mac-clone-repos.sh` | Clones a predefined set of work repositories into local folders. |
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
3. `mac-install-gui-apps.sh`
4. `mac-setup-ssh-github.sh`
5. `mac-clone-repos.sh`

`mac-clean.sh` is intended to be run periodically (e.g. via a scheduled `launchd`/cron job).

## Author

Miguel Barra <mbarra.git@gmail.com>
