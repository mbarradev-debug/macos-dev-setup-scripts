# macOS Dev Setup Scripts

A collection of shell scripts to set up and maintain a macOS (Apple Silicon) development machine, targeting a React / Next.js / TypeScript / PostgreSQL / Vercel stack.

## Scripts

| Script | Description |
| --- | --- |
| `mac-setup-base.sh` | Base macOS setup: Xcode Command Line Tools (+ license), Homebrew, Oh My Zsh, Powerlevel10k, Fira Code Nerd Font, and zsh plugins (`zsh-autosuggestions`, `zsh-syntax-highlighting`). Works with just the Command Line Tools (no Xcode.app needed), and registers the font with macOS right away (fresh macOS 27 installs otherwise ignore new fonts until the next login). |
| `mac-install-cli-tools.sh` | Installs essential CLI tools: Homebrew, Git, GitHub CLI, nvm + Node.js LTS, Vercel CLI, PostgreSQL client (`psql`), Neovim, tree, tmux, ripgrep, fzf, bat, eza, jq, htop, direnv, Docker CLI, Watchman, uv, xcodegen, glslang, exiftool, imagemagick, mpv, whisper.cpp, macmon, mactop, NestJS CLI, and Claude Code. Also drops minimal config files for Neovim (`~/.config/nvim/init.lua`) and tmux (`~/.tmux.conf`). |
| `mac-setup-lazyvim.sh` | Clones [`lazyvim-config`](https://github.com/mbarradev-debug/lazyvim-config) into `~/.config/nvim` over HTTPS (push stays on SSH), installs the `tree-sitter` CLI, and runs its `install.sh` (Neovim, pinned plugin versions, `snacks_picker`/`snacks_explorer` extras, and the `LazyVim-Atajos.md` keybindings cheat sheet symlinked into `$HOME`). Idempotent; backs up any pre-existing `~/.config/nvim` that isn't already that repo. |
| `mac-install-gui-apps.sh` | Installs GUI applications via Homebrew Cask: editors/IDEs, database/API tools, browsers, communication apps, multimedia/gaming, and utilities. |
| `mac-setup-iterm-permissions.sh` | Gets iTerm2 ready with the privacy permissions a dev terminal needs. Automates what macOS allows (Touch ID for `sudo` via `/etc/pam.d/sudo_local` plus `pam-reattach` for tmux, and the Developer Tools pane via `spctl developer-mode enable-terminal`), then opens Accessibility, App Management, Developer Tools and Full Disk Access one at a time and waits for you to turn iTerm on. Ends with a read-only verification summary; `--check` only verifies. Never edits the TCC database or touches SIP. Run it from iTerm2. |
| `mac-setup-ssh-github.sh` | Generates a personal SSH key and configures `~/.ssh/config` for GitHub. |
| `mac-clone-repos.sh` | Clones a predefined set of work repositories into local folders. Requires a `github-work` host alias (with your work key) in `~/.ssh/config`; skips repos already cloned and exits non-zero if any clone fails. |
| `mac-clean.sh` | Safe nightly cleanup, run as your normal user (never sudo) and only inside `~`: Claude Code session history (keeps settings, `CLAUDE.md`, skills, agents, plugins and MCP config; never touches Claude Desktop), Safari/Chrome/Firefox caches (history, cookies and sessions optional), user caches, old logs, crash reports and the Trash, plus opt-in dev caches (npm, pnpm, yarn, Homebrew, `.next/cache`, Xcode DerivedData). Editable allowlist of protected paths, `--dry-run` and `--inventario` modes, logs to `~/Library/Logs/limpieza-nocturna.log`. Schedule it with `launchd/com.mbarra.limpieza-nocturna.plist`. |
| `mac-clean-zsh-history.sh` | Keeps `~/.zsh_history` small and useful: drops lines with secrets (tokens, passwords, API keys), huge pasted blobs, trivial commands (`ls`, `clear`, `cd ..`), typos (commands that don't exist on your Mac), duplicates (keeps the most recent) and commands unused for a year, while always keeping the rare-but-essential ones (`ssh`, `git clone`, `docker run`...). Backs up before writing, uses zsh's own lock, `--dry-run` and `--restaurar` modes, and `--instalar-zshrc` adds zsh options that stop the history from filling up again. |

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
5. `mac-setup-iterm-permissions.sh` (run it from iTerm2; then restart iTerm2 and run it again with `--check`)
6. `mac-setup-ssh-github.sh`
7. `mac-clone-repos.sh`

`mac-clean.sh` is intended to run nightly via `launchd`. Try it first with `./mac-clean.sh --dry-run`, then copy `launchd/com.mbarra.limpieza-nocturna.plist` to `~/Library/LaunchAgents/` and load it with `launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.mbarra.limpieza-nocturna.plist`.

## Nightly cleanup (`mac-clean.sh`)

Runs as your normal user (never `sudo`) and only deletes inside `~`. Before removing anything it checks that the path is not empty, is inside your home folder, is not on the protected list, belongs to you and is writable. Anything it cannot remove is logged as skipped and the run continues.

### 1. Configure

Edit the variables at the top of the script:

| Variable | Default | What it does |
| --- | --- | --- |
| `BORRAR_HISTORIAL_Y_SESIONES` | `false` | Also delete browser history, cookies and signed-in sessions (passwords, bookmarks and extensions are always kept) |
| `CERRAR_NAVEGADORES` | `true` | Ask open browsers to quit (like Cmd+Q) before cleaning them |
| `MINUTOS_INACTIVIDAD_MINIMA` | `15` | On scheduled runs, skip browsers and Claude Code if the Mac was used in the last N minutes |
| `DIAS_CONSERVAR_CLAUDE` | `0` | Keep Claude Code sessions newer than N days |
| `DIAS_LOGS` | `7` | Delete user logs older than N days |
| `LIMPIAR_NPM`, `LIMPIAR_PNPM`, `LIMPIAR_YARN`, `LIMPIAR_HOMEBREW`, `LIMPIAR_NEXT_CACHE`, `LIMPIAR_XCODE_DERIVEDDATA` | `false` | Opt-in dev caches |
| `LIMPIAR_HOMEBREW_VERSIONES_ANTIGUAS` | `false` | Runs `brew cleanup --prune=all` (the only action outside `~`, done by Homebrew itself) |
| `DIRECTORIOS_PROYECTOS` | `~/workspace` | Where to look for `.next/cache` folders |

`RUTAS_PROTEGIDAS` (paths never deleted) and `CACHES_EXCLUIDAS` (folders in `~/Library/Caches` that are skipped) are plain lists, one entry per line.

### 2. Test without deleting anything

```bash
cd ~/scripts
./mac-clean.sh --inventario   # what is inside ~/.claude and what would happen to each item
./mac-clean.sh --dry-run      # list everything that would be deleted and the space it would free
tail -n 40 ~/Library/Logs/limpieza-nocturna.log
```

Run it for real once by hand with `./mac-clean.sh`.

### 3. Grant permissions

In **System Settings → Privacy & Security**:

- **Full Disk Access**: add your terminal app (Terminal or iTerm) for manual runs, and `/bin/bash` for scheduled runs (click **+**, press Cmd+Shift+G, type `/bin/bash`). Restart the terminal app afterwards. Without it, the Safari cache and the Trash are skipped; everything else still works. Note that granting it to `/bin/bash` applies to every bash script.
- **Automation**: the first time the script quits a browser, macOS asks whether `bash` may control it. If that happens during the night, approve it in the morning.

### 4. Schedule it (every night at 03:30)

```bash
cp ~/scripts/launchd/com.mbarra.limpieza-nocturna.plist ~/Library/LaunchAgents/
plutil -lint ~/Library/LaunchAgents/com.mbarra.limpieza-nocturna.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.mbarra.limpieza-nocturna.plist
launchctl print gui/$(id -u)/com.mbarra.limpieza-nocturna | grep -E "state|path"
```

If the Mac is asleep at 03:30, the job runs once when it wakes up; if it is shut down, that night is skipped. Changes to the script apply on the next run; changes to the `.plist` need the job to be reloaded (step 5, then step 4).

### 5. Disable it

```bash
launchctl bootout gui/$(id -u)/com.mbarra.limpieza-nocturna
```

### Logs

- `~/Library/Logs/limpieza-nocturna.log`: every run, the space freed and the list of skipped items (rotated at 5 MB).
- `~/Library/Logs/limpieza-nocturna.launchd.log`: unexpected errors from `launchd` itself.

## Shell history cleanup (`mac-clean-zsh-history.sh`)

Run it whenever the history feels noisy, and install the zsh options once so it stays clean on its own:

```bash
./mac-clean-zsh-history.sh --dry-run          # see what would be removed, per rule
./mac-clean-zsh-history.sh                    # clean it (backup in ~/.local/share/zsh-history-backups)
./mac-clean-zsh-history.sh --instalar-zshrc   # one-time: prevent noise from coming back
./mac-clean-zsh-history.sh --restaurar        # undo: restore the latest backup
```

Rules run in this order: secrets → too long → trivial → typos → duplicates → unused for `DIAS_SIN_USO` days → `MAX_ENTRADAS` cap. Anything matching `PATRONES_CONSERVAR` skips every rule except secrets and duplicates. All rules, limits and pattern lists are variables at the top of the script.

After cleaning, close other open terminals (or run `exec zsh` in them) so they don't write their old in-memory history back. Removing a secret from the history does not revoke it: rotate it if it was real.

## Author

Miguel Barra <mbarra.git@gmail.com>
