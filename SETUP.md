# Fresh Mac Setup Guide

Step-by-step order for running the scripts in this repo on a freshly installed macOS (Apple Silicon). Each step lists what it needs, what it does and how to know it worked. Every script is safe to run again: if a step fails halfway, fix the cause and rerun the same script.

## Overview

| # | Script | Run from | Needs | Restart afterwards? |
| --- | --- | --- | --- | --- |
| 0 | Get this repo | Terminal | Internet | No |
| 1 | `mac-setup-base.sh` | Terminal | Admin password | Yes, reopen Terminal |
| 2 | `mac-install-cli-tools.sh` | Terminal | Step 1 (Homebrew) | Yes, reopen Terminal |
| 3 | `mac-install-gui-apps.sh` | Terminal | Step 1 (Homebrew) | No |
| 4 | `mac-setup-iterm-permissions.sh` | Any terminal; `--check` in **iTerm2** | Step 3 (iTerm2), step 1 (Homebrew) | Yes, quit and reopen iTerm2, then `--check` |
| 5 | `mac-setup-lazyvim.sh` | iTerm2 | Step 2 (Neovim, Node) | No |
| 6 | `mac-setup-ssh-github.sh` | iTerm2 | Step 2 (Git) | No, but add the key to GitHub |
| 7 | `mac-clone-repos.sh` | iTerm2 | Step 6 + work SSH key | No |
| 8 | `mac-clean.sh` + `launchd` | iTerm2 | Step 4 (Full Disk Access) | No |
| 9 | `mac-clean-zsh-history.sh --instalar-zshrc` | iTerm2 | Step 1 (zsh config) | Reopen terminals |

Step 4 can run from any terminal; only its final `--check` must run in iTerm2. From step 5 on, work in iTerm2: it is the terminal that ends up with the right permissions.

## Step 0: Get this repo

A fresh Mac has no Git yet. The first time you type `git`, macOS offers to install the Xcode Command Line Tools; accept and wait for it to finish.

```bash
git clone https://github.com/mbarradev-debug/macos-dev-setup-scripts.git ~/scripts
cd ~/scripts
chmod +x *.sh
```

HTTPS is used on purpose: there is no SSH key yet (that comes in step 6).

## Step 1: Base system (`mac-setup-base.sh`)

```bash
./mac-setup-base.sh
```

- Installs Xcode Command Line Tools (if missing), Homebrew, Oh My Zsh, Powerlevel10k, Fira Code Nerd Font and the zsh plugins.
- Asks for your password once (`sudo`).
- If the Command Line Tools were missing, it opens the installer and exits. Finish the installation and **run the script again**.

Done when it prints `Setup completed successfully.` Then close and reopen Terminal so Homebrew and zsh load.

## Step 2: CLI tools (`mac-install-cli-tools.sh`)

```bash
./mac-install-cli-tools.sh
```

- Installs Git, GitHub CLI, nvm + Node.js LTS, Vercel CLI, psql, Neovim, tmux, Docker CLI, Claude Code and the rest of the CLI tools.

Done when it prints `Done! Installed tools:`. Reopen Terminal so `nvm` and `node` are on the PATH.

## Step 3: GUI apps (`mac-install-gui-apps.sh`)

```bash
./mac-install-gui-apps.sh
```

- Installs Rosetta 2 and the apps via Homebrew Cask, including **iTerm2**, VS Code, Docker Desktop, Chrome and Notion.

Done when it prints `GUI apps installation completed.`

## Step 4: iTerm2 permissions (`mac-setup-iterm-permissions.sh`)

Run it from any terminal (Terminal or iTerm2). The permissions are granted to iTerm2 either way, because in each panel you turn on iTerm, not the terminal running the script:

```bash
cd ~/scripts
./mac-setup-iterm-permissions.sh
```

- Sets up Touch ID for `sudo` (plus `pam-reattach` so it also works inside tmux).
- Opens Accessibility, App Management, Developer Tools and Full Disk Access one by one; turn iTerm on in each panel and press Enter.
- When granting Full Disk Access, if macOS offers **Quit & Reopen** and you are running the script from iTerm2, choose **Later** so the script keeps running. From Terminal it doesn't matter.
- The summary at the end may show `[RECHECK]` rows: verifying needs to read the permissions database, which only a terminal with Full Disk Access can do. That is expected; the real check is the next one.

Then quit iTerm2 (Cmd+Q) if it was open, open it again and, **from iTerm2**, verify:

```bash
./mac-setup-iterm-permissions.sh --check
```

Done when every row shows `[OK]`. Optional: in iTerm2 settings, pick `FiraCode Nerd Font Mono` as the font (installed in step 1).

## Step 5: LazyVim (`mac-setup-lazyvim.sh`)

```bash
./mac-setup-lazyvim.sh
```

- Clones the `lazyvim-config` repo into `~/.config/nvim` over HTTPS and runs its installer. Any existing config is backed up, not deleted.

Done when `nvim` opens with LazyVim and its plugins installed.

## Step 6: SSH key for GitHub (`mac-setup-ssh-github.sh`)

```bash
./mac-setup-ssh-github.sh
```

- Creates your personal SSH key, adds it to the ssh-agent and writes `~/.ssh/config` for `github.com`.
- Prints the public key at the end. **Add it to GitHub** (Settings → SSH and GPG keys → New SSH key), or with the GitHub CLI:

```bash
gh auth login
gh ssh-key add ~/.ssh/id_ed25519_github_personal.pub --title "MacBook Air M4"
```

Done when this greets you by username:

```bash
ssh -T git@github.com
```

Optional: point this repo's remote back to SSH so you can push:

```bash
git -C ~/scripts remote set-url origin git@github.com:mbarradev-debug/macos-dev-setup-scripts.git
```

## Step 7: Work repos (`mac-clone-repos.sh`)

Before running it, add your work key and a `github-work` block to `~/.ssh/config` (this step is manual on purpose; the key is not stored in this repo):

```
Host github-work
  HostName github.com
  User git
  IdentityFile ~/.ssh/<your-work-key>
  IdentitiesOnly yes
```

```bash
./mac-clone-repos.sh
```

- Clones the work repositories, skipping any that already exist. If the `github-work` alias is missing it stops and tells you what to add.

## Step 8: Nightly cleanup (`mac-clean.sh`)

Needs Full Disk Access for iTerm2 (step 4) to clean the Safari cache and the Trash. Try it first without deleting anything, then schedule it:

```bash
./mac-clean.sh --dry-run
cp ~/scripts/launchd/com.mbarra.limpieza-nocturna.plist ~/Library/LaunchAgents/
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.mbarra.limpieza-nocturna.plist
```

Scheduled runs use `/bin/bash`, so also add `/bin/bash` to Full Disk Access if you want those runs to clean the Safari cache and the Trash. Full details are in the [README](README.md#nightly-cleanup-mac-cleansh).

## Step 9: Shell history (`mac-clean-zsh-history.sh`)

One-time setup so the zsh history stays clean on its own:

```bash
./mac-clean-zsh-history.sh --instalar-zshrc
```

Close and reopen your terminals afterwards.

## If something fails

- **`brew: command not found`**: reopen the terminal (or run `eval "$(/opt/homebrew/bin/brew shellenv)"`) and rerun the script.
- **`Operation not permitted`**: iTerm2 is missing a permission. Run `./mac-setup-iterm-permissions.sh --check` to see which one.
- **`Permission denied (publickey)`**: the SSH key isn't on GitHub yet (step 6).
- Any other error: fix the cause and run the same script again; all of them skip what is already done.
