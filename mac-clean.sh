#!/bin/bash
# Author: Miguel Barra <mbarra.git@gmail.com>
set -uo pipefail

LOG_DIR="$HOME/Library/Logs/NightlyCleanup"
LOG_FILE="$LOG_DIR/cleanup_$(date +%Y-%m-%d_%H-%M-%S).log"
mkdir -p "$LOG_DIR"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

safe_clear_dir_contents() {
  local target="$1"
  local exclude_pattern="${2:-}"
  if [ -d "$target" ]; then
    find "$target" -mindepth 1 -maxdepth 1 2>/dev/null | while read -r item; do
      base_lower=$(basename "$item" | tr '[:upper:]' '[:lower:]')
      if [ -n "$exclude_pattern" ] && [[ "$base_lower" == *"$exclude_pattern"* ]]; then
        continue
      fi
      rm -rf "$item" 2>/dev/null
    done
  fi
}

log "Starting safe nightly system cleanup"

BEFORE_FREE=$(df -h / | awk 'NR==2{print $4}')
log "Free space before: $BEFORE_FREE"

log "Cleaning user caches (excluding Photos-related items)"
if [ -d "$HOME/Library/Caches" ]; then
  find "$HOME/Library/Caches" -mindepth 1 -maxdepth 1 2>/dev/null | while read -r item; do
    base_lower=$(basename "$item" | tr '[:upper:]' '[:lower:]')
    if [[ "$base_lower" == *"photo"* ]]; then
      continue
    fi
    rm -rf "$item" 2>/dev/null
  done
fi

log "Cleaning user logs"
safe_clear_dir_contents "$HOME/Library/Logs" "nightlycleanup"

log "Cleaning crash reports"
safe_clear_dir_contents "$HOME/Library/Application Support/CrashReporter"

log "Cleaning user temporary files"
if [ -n "${TMPDIR:-}" ] && [ -d "$TMPDIR" ]; then
  find "$TMPDIR" -mindepth 1 -maxdepth 1 2>/dev/null -exec rm -rf {} + 2>/dev/null
fi

log "Cleaning QuickLook cache"
qlmanage -r cache >/dev/null 2>&1

log "Restarting QuickLook service"
qlmanage -r >/dev/null 2>&1

if command -v brew >/dev/null 2>&1; then
  log "Cleaning Homebrew cache"
  brew cleanup -s --prune=all >>"$LOG_FILE" 2>&1
  rm -rf "$(brew --cache)" 2>/dev/null
fi

if command -v npm >/dev/null 2>&1; then
  log "Cleaning npm cache"
  npm cache clean --force >>"$LOG_FILE" 2>&1
fi

if command -v yarn >/dev/null 2>&1; then
  log "Cleaning yarn cache"
  yarn cache clean >>"$LOG_FILE" 2>&1
fi

if command -v pip3 >/dev/null 2>&1; then
  log "Cleaning pip cache"
  pip3 cache purge >>"$LOG_FILE" 2>&1
fi

if command -v docker >/dev/null 2>&1; then
  if docker info >/dev/null 2>&1; then
    log "Cleaning unused Docker resources"
    docker system prune -f >>"$LOG_FILE" 2>&1
  fi
fi

AFTER_FREE=$(df -h / | awk 'NR==2{print $4}')
log "Free space after: $AFTER_FREE"
log "Nightly cleanup completed"

exit 0
