#!/bin/bash
# =============================================================================
#  mac-clean.sh — Limpieza nocturna segura para macOS (Apple Silicon)
#  Author: Miguel Barra <mbarra.git@gmail.com>
#
#  Borra cachés, temporales, logs antiguos e historial de Claude Code, dejando
#  intactos tus datos personales, tus apps y sus configuraciones.
#
#  Uso:
#    ./mac-clean.sh --dry-run     Simula: muestra qué borraría y cuánto liberaría
#    ./mac-clean.sh --inventario  Muestra qué hay en ~/.claude y qué haría con cada cosa
#    ./mac-clean.sh               Ejecuta la limpieza de verdad
#
#  Reglas de seguridad (no negociables):
#    - Nunca usa sudo, chmod, chown ni chflags.
#    - Solo borra dentro de tu carpeta de usuario (~).
#    - Antes de borrar algo verifica: ruta no vacía, dentro de ~, no protegida,
#      que sea tuya y que tengas permiso de escritura. Si algo falla, lo
#      registra como "omitido" y sigue con lo demás.
#
#  Compatible con /bin/bash 3.2 (el que trae macOS), por eso no usa arrays
#  asociativos ni otras funciones de bash 4+.
# =============================================================================

# -u: error si se usa una variable no definida (protege contra rutas vacías).
# No usamos -e a propósito: si un borrado falla queremos registrarlo y seguir.
set -u
set -o pipefail


# =============================================================================
#  1) CONFIGURACIÓN — edita esta sección a tu gusto
# =============================================================================

# --- Navegadores -------------------------------------------------------------
# true  = además de la caché, borra historial, cookies y sesiones iniciadas
#         (tendrás que volver a iniciar sesión en los sitios web).
# false = solo caché y temporales (recomendado).
BORRAR_HISTORIAL_Y_SESIONES=false

# Si un navegador está abierto: true = pedirle que se cierre (como Cmd+Q);
# false = no tocar ese navegador esa noche.
CERRAR_NAVEGADORES=true

# Cuando corre programado (launchd) y detecta que estás usando el Mac
# (actividad de teclado/ratón en los últimos N minutos), NO cierra navegadores
# ni toca Claude Code. Evita que te cierre Chrome si el Mac despierta por la
# mañana y la limpieza pendiente se ejecuta mientras trabajas.
MINUTOS_INACTIVIDAD_MINIMA=15

# --- Claude Code -------------------------------------------------------------
LIMPIAR_CLAUDE_CODE=true
# 0 = borrar todo el historial. 3 = conservar sesiones de los últimos 3 días
# (útil si quieres poder hacer "claude --resume" de algo reciente).
DIAS_CONSERVAR_CLAUDE=0

# --- Sistema -----------------------------------------------------------------
LIMPIAR_CACHES_USUARIO=true
LIMPIAR_LOGS=true
DIAS_LOGS=7                    # borra logs de usuario con más de N días
LIMPIAR_INFORMES_FALLOS=true   # ~/Library/Logs/DiagnosticReports
VACIAR_PAPELERA=true

# --- Cachés de desarrollo (opcionales, apagadas por defecto) -----------------
LIMPIAR_NPM=false              # ~/.npm/_cacache, _logs, _npx
LIMPIAR_PNPM=false             # pnpm store prune (solo paquetes sin usar)
LIMPIAR_YARN=false             # ~/Library/Caches/Yarn y ~/.yarn/berry/cache
LIMPIAR_HOMEBREW=false         # caché de descargas de Homebrew (dentro de ~)
# Esto ejecuta "brew cleanup --prune=all", que además borra versiones viejas
# de paquetes en /opt/homebrew. Es la ÚNICA acción fuera de ~ y la hace el
# propio Homebrew con tu usuario (sin sudo). Por eso va aparte.
LIMPIAR_HOMEBREW_VERSIONES_ANTIGUAS=false
LIMPIAR_NEXT_CACHE=false       # carpetas .next/cache de tus proyectos
LIMPIAR_XCODE_DERIVEDDATA=false

# Dónde buscar proyectos Next.js (nunca pongas Documents, Desktop ni Downloads:
# están protegidas y el script las rechazaría igual).
DIRECTORIOS_PROYECTOS=( "$HOME/workspace" )

# --- Varios ------------------------------------------------------------------
NOTIFICAR_AL_TERMINAR=true
ARCHIVO_LOG="$HOME/Library/Logs/limpieza-nocturna.log"
TAMANO_MAX_LOG_KB=5120         # al pasar 5 MB, el log se rota a .log.1


# =============================================================================
#  2) LISTA BLANCA — rutas que el script NUNCA borra
#     Protege la ruta, todo lo que está dentro y también impide borrar
#     cualquier carpeta que la contenga.
# =============================================================================
RUTAS_PROTEGIDAS=(
  # Carpetas personales
  "$HOME/Documents"
  "$HOME/Desktop"
  "$HOME/Downloads"
  "$HOME/Pictures"
  "$HOME/Music"
  "$HOME/Movies"
  "$HOME/scripts"
  # iCloud Drive y apps de Apple con tus datos
  "$HOME/Library/Mobile Documents"
  "$HOME/Library/CloudStorage"
  "$HOME/Library/Mail"
  "$HOME/Library/Messages"
  "$HOME/Library/Photos"
  "$HOME/Library/Calendars"
  "$HOME/Library/Application Support/AddressBook"
  "$HOME/Library/Group Containers/group.com.apple.notes"
  "$HOME/Library/Keychains"
  "$HOME/Library/Preferences"
  # Credenciales
  "$HOME/.ssh"
  "$HOME/.gnupg"
  # Claude Desktop (no se toca nada)
  "$HOME/Library/Application Support/Claude"
  "$HOME/Library/Logs/Claude"
  # Claude Code: configuración y personalizaciones
  "$HOME/.claude.json"
  "$HOME/.claude/settings.json"
  "$HOME/.claude/settings.local.json"
  "$HOME/.claude/CLAUDE.md"
  "$HOME/.claude/skills"
  "$HOME/.claude/agents"
  "$HOME/.claude/commands"
  "$HOME/.claude/plugins"
  "$HOME/.claude/hooks"
  "$HOME/.claude/output-styles"
  "$HOME/.claude/keybindings.json"
  "$HOME/.claude/.credentials.json"
  "$HOME/.local/share/claude"      # binarios de Claude Code
  "$HOME/.local/bin"
)

# Nombres de carpetas dentro de ~/Library/Caches que la limpieza general NO
# toca (acepta comodines *). Algunas se limpian en su propia sección.
CACHES_EXCLUIDAS=(
  "com.apple.*"           # cachés de Apple: guardan estado de iCloud, Fotos, etc.
  "com.anthropic.*"       # Claude Desktop
  "Claude*"               # Claude Desktop
  "claude-cli-nodejs"     # Claude Code (se limpia en su sección)
  "Google"                # Chrome (se limpia en su sección)
  "com.google.Chrome*"
  "Firefox"               # Firefox (se limpia en su sección)
  "org.mozilla.*"
  "Homebrew"              # se limpia solo si LIMPIAR_HOMEBREW=true
  "Yarn"                  # se limpia solo si LIMPIAR_YARN=true
  "pnpm"
  "ms-playwright"         # navegadores de Playwright (pesan y se re-descargan)
  "Cypress"
  "com.spotify.client"    # contiene tu música descargada para escuchar offline
)


# =============================================================================
#  3) VARIABLES INTERNAS Y COMPROBACIONES INICIALES
# =============================================================================
MODO_SIMULACION=0
MODO_INVENTARIO=0
for arg in "$@"; do
  case "$arg" in
    --dry-run|--simulacion) MODO_SIMULACION=1 ;;
    --inventario)           MODO_INVENTARIO=1 ;;
    -h|--help)
      sed -n '2,14p' "$0"; exit 0 ;;
    *) echo "Opción desconocida: $arg (usa --help)"; exit 2 ;;
  esac
done

MI_UID="$(id -u)"
TOTAL_KB=0
TOTAL_ELEMENTOS=0
OMITIDOS=()
INICIO="$(date '+%Y-%m-%d %H:%M:%S')"

# Nunca correr como root: si alguien lo lanza con sudo, se detiene.
if [ "$MI_UID" -eq 0 ]; then
  echo "Este script NO debe ejecutarse con sudo ni como root. Abortando."
  exit 1
fi

# $HOME debe existir, no estar vacío, no ser "/" y estar en /Users.
case "${HOME:-}" in
  /Users/?*) ;;
  *) echo "HOME inválido ('${HOME:-}'). Abortando por seguridad."; exit 1 ;;
esac
[ -d "$HOME" ] || { echo "HOME no existe. Abortando."; exit 1; }
cd "$HOME" || exit 1

# PATH explícito: launchd arranca con un PATH mínimo.
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$HOME/Library/pnpm"
if [ -d "$HOME/.nvm/versions/node" ]; then
  # Agrega la versión de Node más reciente instalada con nvm (para pnpm/yarn).
  ULTIMO_NODE="$(ls -1d "$HOME/.nvm/versions/node"/*/bin 2>/dev/null | sort -V | tail -n 1)"
  [ -n "$ULTIMO_NODE" ] && export PATH="$ULTIMO_NODE:$PATH"
fi
export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1


# =============================================================================
#  4) FUNCIONES DE APOYO: log, tamaños, permisos y el borrado seguro
# =============================================================================

# Escribe en pantalla y en el archivo de log.
log() {
  printf '%s\n' "$*"
  [ "$MODO_INVENTARIO" -eq 1 ] || printf '%s\n' "$*" >> "$ARCHIVO_LOG"
}

# Convierte KB a un texto legible (ej. 1536 -> "1.5 MB").
humano() {
  awk -v kb="${1:-0}" 'BEGIN {
    if (kb >= 1048576) printf "%.2f GB", kb/1048576;
    else if (kb >= 1024) printf "%.1f MB", kb/1024;
    else printf "%d KB", kb }'
}

# Tamaño en KB de un archivo o carpeta (0 si no se puede leer).
tamano_kb() {
  local kb
  kb="$(du -sk "$1" 2>/dev/null | awk '{print $1}' | tail -n 1)"
  echo "${kb:-0}"
}

# UID del dueño de una ruta, sin seguir enlaces simbólicos (stat de macOS).
uid_de() { stat -f %u "$1" 2>/dev/null; }

registrar_omitido() {
  OMITIDOS+=("$1  →  $2")
  log "  [omitido] $1 ($2)"
}

# ¿La ruta está protegida por la lista blanca?
# Protegida si: es una ruta protegida, está dentro de una, o contiene una.
esta_protegido() {
  local p="$1" r
  for r in "${RUTAS_PROTEGIDAS[@]}"; do
    case "$p" in "$r"|"$r"/*) return 0 ;; esac
    case "$r" in "$p"/*)       return 0 ;; esac
  done
  return 1
}

# ¿El nombre de una carpeta de ~/Library/Caches está en la lista de excluidas?
cache_excluida() {
  local nombre="$1" patron
  for patron in "${CACHES_EXCLUIDAS[@]}"; do
    # Sin comillas en $patron a propósito: así funcionan los comodines *.
    # shellcheck disable=SC2254
    case "$nombre" in $patron) return 0 ;; esac
  done
  return 1
}

# ---------------------------------------------------------------------------
# borrar RUTA
# El único lugar del script que ejecuta rm. Hace todas las verificaciones
# antes de borrar y nunca detiene el script si algo falla.
# ---------------------------------------------------------------------------
borrar() {
  local p="${1:-}" padre kb kb_resto ajeno err relativo

  # 1. Nunca operar sobre una ruta vacía.
  if [ -z "$p" ]; then log "  [error interno] ruta vacía ignorada"; return 0; fi

  # 2. Si no existe, no hay nada que hacer (no es un error).
  [ -e "$p" ] || [ -L "$p" ] || return 0

  # 3. Debe estar dentro de ~ y al menos 2 niveles abajo (~/algo/otra-cosa).
  case "$p" in
    "$HOME"/*) ;;
    *) registrar_omitido "$p" "fuera de la carpeta de usuario"; return 0 ;;
  esac
  case "$p" in
    */../*|*/..|*/./*|*/.) registrar_omitido "$p" "ruta con . o .."; return 0 ;;
  esac
  relativo="${p#"$HOME"/}"
  case "$relativo" in
    */*) ;;
    *) registrar_omitido "$p" "demasiado cerca de ~, no se borra"; return 0 ;;
  esac

  # 4. Lista blanca.
  if esta_protegido "$p"; then return 0; fi

  # 5. Debe pertenecer a tu usuario.
  if [ "$(uid_de "$p")" != "$MI_UID" ]; then
    registrar_omitido "$p" "pertenece a otro usuario o no se puede leer"
    return 0
  fi

  # 6. Necesitas permiso de escritura en la carpeta que lo contiene
  #    (y en la propia carpeta, si es una carpeta).
  padre="$(dirname "$p")"
  if [ ! -w "$padre" ]; then
    registrar_omitido "$p" "sin permiso de escritura en $padre"; return 0
  fi
  if [ -d "$p" ] && [ ! -L "$p" ] && [ ! -w "$p" ]; then
    registrar_omitido "$p" "sin permiso de escritura"; return 0
  fi

  # 7. Si es carpeta, no puede contener nada de otro usuario.
  if [ -d "$p" ] && [ ! -L "$p" ]; then
    ajeno="$(find "$p" ! -user "$MI_UID" -print -quit 2>/dev/null)"
    if [ -n "$ajeno" ]; then
      registrar_omitido "$p" "contiene archivos de otro usuario (ej. $ajeno)"
      return 0
    fi
  fi

  kb="$(tamano_kb "$p")"

  # Modo simulación: solo cuenta y muestra.
  if [ "$MODO_SIMULACION" -eq 1 ]; then
    log "  [simulación] $p ($(humano "$kb"))"
    TOTAL_KB=$((TOTAL_KB + kb)); TOTAL_ELEMENTOS=$((TOTAL_ELEMENTOS + 1))
    return 0
  fi

  # Borrado real. "--" evita que un nombre que empiece con "-" sea opción.
  err="$(rm -rf -- "$p" 2>&1)"
  if [ -e "$p" ] || [ -L "$p" ]; then
    # Quedó algo (en uso, bloqueado o protegido por macOS): cuenta lo liberado.
    kb_resto="$(tamano_kb "$p")"
    TOTAL_KB=$((TOTAL_KB + kb - kb_resto))
    registrar_omitido "$p" "no se pudo borrar completo: $(printf '%s' "$err" | head -n 1)"
  else
    TOTAL_KB=$((TOTAL_KB + kb)); TOTAL_ELEMENTOS=$((TOTAL_ELEMENTOS + 1))
  fi
}

# Borra el CONTENIDO de una carpeta (la carpeta queda, vacía).
# Segundo parámetro opcional: solo elementos con más de N días sin modificar.
vaciar() {
  local dir="${1:-}" dias="${2:-0}" item
  [ -n "$dir" ] && [ -d "$dir" ] || return 0
  if ! ls "$dir" >/dev/null 2>&1; then
    registrar_omitido "$dir" "macOS no permite leerla (¿falta Acceso total al disco?)"
    return 0
  fi
  while IFS= read -r -d '' item; do
    borrar "$item"
  done < <(
    if [ "$dias" -gt 0 ]; then
      find "$dir" -mindepth 1 -maxdepth 1 -mtime +"$dias" -print0 2>/dev/null
    else
      find "$dir" -mindepth 1 -maxdepth 1 -print0 2>/dev/null
    fi
  )
}

# Segundos desde la última vez que tocaste teclado o ratón.
segundos_inactivo() {
  ioreg -c IOHIDSystem 2>/dev/null \
    | awk '/HIDIdleTime/ {print int($NF/1000000000); exit}'
}

# ¿Estás usando el Mac ahora mismo? Solo se evalúa en ejecuciones
# programadas; si lo corres tú a mano desde Terminal, se asume que decides tú.
usuario_activo() {
  [ -t 0 ] && return 1
  local s; s="$(segundos_inactivo)"
  [ -n "$s" ] && [ "$s" -lt $((MINUTOS_INACTIVIDAD_MINIMA * 60)) ]
}

# Cierra una app de forma segura (como Cmd+Q). Devuelve 0 si quedó cerrada.
# $1 = nombre de la app, $2 = nombre del proceso
cerrar_app() {
  local app="$1" proceso="$2" osa
  pgrep -x "$proceso" >/dev/null 2>&1 || return 0

  if [ "$MODO_SIMULACION" -eq 1 ]; then
    log "  [simulación] $app está abierto: se le pediría cerrarse"
    return 0
  fi
  if [ "$CERRAR_NAVEGADORES" != true ]; then
    registrar_omitido "$app" "está abierto y CERRAR_NAVEGADORES=false"; return 1
  fi
  if usuario_activo; then
    registrar_omitido "$app" "estás usando el Mac; no se cierra"; return 1
  fi

  log "  Cerrando $app..."
  osascript -e "tell application \"$app\" to quit" >/dev/null 2>&1 &
  osa=$!
  for _ in $(seq 1 30); do
    sleep 1
    if ! pgrep -x "$proceso" >/dev/null 2>&1; then
      kill "$osa" 2>/dev/null; sleep 2; return 0
    fi
  done
  kill "$osa" 2>/dev/null
  registrar_omitido "$app" "no se cerró en 30 s (¿diálogo abierto o falta permiso de Automatización?)"
  return 1
}


# =============================================================================
#  5) MODO INVENTARIO — revisa ~/.claude sin borrar nada
# =============================================================================

# Lo que se borra dentro de ~/.claude (todo lo demás se conserva).
CLAUDE_CARPETAS_BORRAR=( todos shell-snapshots statsig debug file-history session-env paste-cache telemetry plans )
CLAUDE_ARCHIVOS_BORRAR=( history.jsonl )

clasificar_claude() {
  local n="$1" x
  for x in "${CLAUDE_CARPETAS_BORRAR[@]}" "${CLAUDE_ARCHIVOS_BORRAR[@]}"; do
    [ "$n" = "$x" ] && { echo "BORRAR"; return; }
  done
  [ "$n" = "projects" ] && { echo "BORRAR (excepto memory/)"; return; }
  echo "CONSERVAR"
}

describir_claude() {
  case "$1" in
    projects)        echo "Conversaciones de cada sesión (.jsonl) por proyecto; memory/ guarda la memoria automática" ;;
    todos)           echo "Listas de tareas internas de cada sesión" ;;
    shell-snapshots) echo "Fotos de tu entorno de terminal usadas al ejecutar comandos" ;;
    statsig)         echo "Caché de configuración remota y métricas" ;;
    debug)           echo "Logs de depuración de sesiones" ;;
    file-history)    echo "Copias de archivos para deshacer cambios (checkpoints / Esc Esc)" ;;
    session-env)     echo "Variables de entorno de sesiones pasadas" ;;
    paste-cache)     echo "Textos e imágenes grandes que pegaste en sesiones" ;;
    telemetry)       echo "Eventos de uso pendientes de enviar" ;;
    plans)           echo "Planes generados en modo plan" ;;
    history.jsonl)   echo "Historial de prompts (flecha arriba en Claude Code)" ;;
    settings.json|settings.local.json) echo "Tu configuración" ;;
    CLAUDE.md)       echo "Tus instrucciones globales" ;;
    skills|agents|commands|plugins|hooks|output-styles) echo "Tus personalizaciones" ;;
    .credentials.json) echo "Credenciales (en macOS suelen estar en el Llavero)" ;;
    *)               echo "Desconocido: se conserva por seguridad" ;;
  esac
}

if [ "$MODO_INVENTARIO" -eq 1 ]; then
  echo "Inventario de Claude Code (no se borra nada)"
  echo "============================================="
  if [ ! -d "$HOME/.claude" ]; then
    echo "No existe ~/.claude"
  else
    while IFS= read -r -d '' item; do
      n="$(basename "$item")"
      printf '%-24s %10s  %-26s %s\n' "$n" "$(humano "$(tamano_kb "$item")")" \
        "$(clasificar_claude "$n")" "$(describir_claude "$n")"
    done < <(find "$HOME/.claude" -mindepth 1 -maxdepth 1 -print0 2>/dev/null | sort -z)
  fi
  echo
  echo "Fuera de ~/.claude:"
  for item in "$HOME/.claude.json" "$HOME/Library/Caches/claude-cli-nodejs" "$HOME/.local/share/claude"; do
    [ -e "$item" ] || continue
    case "$item" in
      *claude-cli-nodejs) d="BORRAR contenido  Logs de servidores MCP de Claude Code" ;;
      *) d="CONSERVAR         Configuración / binarios de Claude Code" ;;
    esac
    printf '%-45s %10s  %s\n' "${item#"$HOME"/}" "$(humano "$(tamano_kb "$item")")" "$d"
  done
  echo
  echo "Claude Desktop (nunca se toca):"
  for item in "$HOME/Library/Application Support/Claude" "$HOME/Library/Logs/Claude"; do
    [ -e "$item" ] && echo "  ${item#"$HOME"/}  →  CONSERVAR"
  done
  ls -d "$HOME"/Library/Caches/com.anthropic.* 2>/dev/null | sed "s|$HOME/|  |; s|$|  →  CONSERVAR|"
  exit 0
fi


# =============================================================================
#  6) INICIO: bloqueo, rotación del log y encabezado
# =============================================================================

# Evita que dos limpiezas corran a la vez.
BLOQUEO="$HOME/.limpieza-nocturna.lock"
if ! mkdir "$BLOQUEO" 2>/dev/null; then
  PID_ANTERIOR="$(cat "$BLOQUEO/pid" 2>/dev/null || true)"
  if [ -n "$PID_ANTERIOR" ] && kill -0 "$PID_ANTERIOR" 2>/dev/null; then
    echo "Ya hay una limpieza en curso (PID $PID_ANTERIOR). Saliendo."; exit 0
  fi
  rm -f "$BLOQUEO/pid"; rmdir "$BLOQUEO" 2>/dev/null; mkdir "$BLOQUEO" || exit 1
fi
echo $$ > "$BLOQUEO/pid"
trap 'rm -f "$BLOQUEO/pid"; rmdir "$BLOQUEO" 2>/dev/null' EXIT

# Evita que el Mac se duerma mientras dura la limpieza.
caffeinate -i -w $$ >/dev/null 2>&1 &

# Rotación del log para que no crezca sin límite.
mkdir -p "$(dirname "$ARCHIVO_LOG")"
if [ -f "$ARCHIVO_LOG" ] && [ "$(tamano_kb "$ARCHIVO_LOG")" -gt "$TAMANO_MAX_LOG_KB" ]; then
  mv -f "$ARCHIVO_LOG" "$ARCHIVO_LOG.1"
fi

LIBRE_ANTES_KB="$(df -k "$HOME" | awk 'NR==2 {print $4}')"
log ""
log "=================================================================="
if [ "$MODO_SIMULACION" -eq 1 ]; then
  log " Limpieza nocturna — $INICIO — MODO SIMULACIÓN (no se borra nada)"
else
  log " Limpieza nocturna — $INICIO"
fi
log "=================================================================="


# =============================================================================
#  7) CLAUDE CODE — historial de sesiones (no la configuración)
# =============================================================================
if [ "$LIMPIAR_CLAUDE_CODE" = true ]; then
  log ""
  log "[Claude Code]"
  CLAUDE_DIR="$HOME/.claude"

  # Si Claude Code está corriendo, borrar su sesión activa la rompería.
  if pgrep -x claude >/dev/null 2>&1 || pgrep -f "@anthropic-ai/claude-code" >/dev/null 2>&1; then
    registrar_omitido "$CLAUDE_DIR" "Claude Code está abierto; se limpia la próxima vez"
  elif usuario_activo; then
    registrar_omitido "$CLAUDE_DIR" "estás usando el Mac; se limpia la próxima vez"
  elif [ -d "$CLAUDE_DIR" ]; then
    # Carpetas de historial: se vacían (la carpeta queda).
    for c in "${CLAUDE_CARPETAS_BORRAR[@]}"; do
      vaciar "$CLAUDE_DIR/$c" "$DIAS_CONSERVAR_CLAUDE"
    done
    # Archivos sueltos de historial.
    for a in "${CLAUDE_ARCHIVOS_BORRAR[@]}"; do
      if [ "$DIAS_CONSERVAR_CLAUDE" -eq 0 ] || \
         [ -n "$(find "$CLAUDE_DIR/$a" -mtime +"$DIAS_CONSERVAR_CLAUDE" 2>/dev/null)" ]; then
        borrar "$CLAUDE_DIR/$a"
      fi
    done
    # projects/<proyecto>/: borra conversaciones pero conserva memory/.
    if [ -d "$CLAUDE_DIR/projects" ]; then
      while IFS= read -r -d '' proyecto; do
        while IFS= read -r -d '' item; do
          [ "$(basename "$item")" = "memory" ] && continue
          borrar "$item"
        done < <(
          if [ "$DIAS_CONSERVAR_CLAUDE" -gt 0 ]; then
            find "$proyecto" -mindepth 1 -maxdepth 1 -mtime +"$DIAS_CONSERVAR_CLAUDE" -print0 2>/dev/null
          else
            find "$proyecto" -mindepth 1 -maxdepth 1 -print0 2>/dev/null
          fi
        )
      done < <(find "$CLAUDE_DIR/projects" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
    fi
    # Logs de servidores MCP de Claude Code.
    vaciar "$HOME/Library/Caches/claude-cli-nodejs" "$DIAS_CONSERVAR_CLAUDE"
  else
    log "  No existe ~/.claude, nada que limpiar."
  fi
fi


# =============================================================================
#  8) NAVEGADORES — caché siempre; historial y sesiones solo si lo activas
# =============================================================================
log ""
log "[Navegadores]  borrar historial y sesiones: $BORRAR_HISTORIAL_Y_SESIONES"

# ---- Safari ----------------------------------------------------------------
SAFARI_CONT="$HOME/Library/Containers/com.apple.Safari/Data/Library"
if [ -d "$HOME/Library/Safari" ] || [ -d "$SAFARI_CONT" ]; then
  log " Safari"
  if cerrar_app "Safari" "Safari"; then
    vaciar "$HOME/Library/Caches/com.apple.Safari"
    vaciar "$SAFARI_CONT/Caches"
    # Caché de service workers (CacheStorage) dentro de los datos de sitios web.
    while IFS= read -r -d '' d; do borrar "$d"; done < <(
      find "$SAFARI_CONT/WebKit/WebsiteData" "$HOME/Library/WebKit/com.apple.Safari" \
        -type d -name CacheStorage -prune -print0 2>/dev/null)

    if [ "$BORRAR_HISTORIAL_Y_SESIONES" = true ]; then
      for f in History.db History.db-shm History.db-wal History.db-lock \
               LastSession.plist RecentlyClosedTabs.plist; do
        borrar "$HOME/Library/Safari/$f"
      done
      vaciar "$SAFARI_CONT/Cookies"
      vaciar "$HOME/Library/HTTPStorages/com.apple.Safari"
      vaciar "$SAFARI_CONT/WebKit/WebsiteData"   # localStorage, IndexedDB, sesiones
      vaciar "$HOME/Library/Safari/LocalStorage"
      vaciar "$HOME/Library/Safari/Databases"
    fi
  fi
fi

# ---- Google Chrome ---------------------------------------------------------
CHROME_DIR="$HOME/Library/Application Support/Google/Chrome"
if [ -d "$CHROME_DIR" ]; then
  log " Google Chrome"
  if cerrar_app "Google Chrome" "Google Chrome"; then
    vaciar "$HOME/Library/Caches/Google/Chrome"
    # Cachés globales de GPU / shaders.
    for c in ShaderCache GrShaderCache GraphiteDawnCache; do borrar "$CHROME_DIR/$c"; done
    vaciar "$CHROME_DIR/Crashpad/completed"   # informes de fallos ya enviados
    # Cada perfil (Default, Profile 1, ...) se reconoce por su archivo Preferences.
    while IFS= read -r -d '' pref; do
      perfil="$(dirname "$pref")"
      for c in "Cache" "Code Cache" "GPUCache" "DawnGraphiteCache" "DawnWebGPUCache" \
               "Service Worker/CacheStorage" "Service Worker/ScriptCache"; do
        borrar "$perfil/$c"
      done
      if [ "$BORRAR_HISTORIAL_Y_SESIONES" = true ]; then
        for c in "History" "History-journal" "Visited Links" "Top Sites" "Top Sites-journal" \
                 "Shortcuts" "Shortcuts-journal" "Cookies" "Cookies-journal" \
                 "Network/Cookies" "Network/Cookies-journal" "Sessions" "Session Storage"; do
          borrar "$perfil/$c"
        done
        # IndexedDB de sitios web, pero NO el de las extensiones.
        while IFS= read -r -d '' idb; do
          case "$(basename "$idb")" in chrome-extension_*) continue ;; esac
          borrar "$idb"
        done < <(find "$perfil/IndexedDB" -mindepth 1 -maxdepth 1 -print0 2>/dev/null)
      fi
    done < <(find "$CHROME_DIR" -mindepth 2 -maxdepth 2 -name Preferences -type f -print0 2>/dev/null)
  fi
fi

# ---- Firefox ---------------------------------------------------------------
FF_PERFILES="$HOME/Library/Application Support/Firefox/Profiles"
if [ -d "$FF_PERFILES" ]; then
  log " Firefox"
  if cerrar_app "Firefox" "firefox"; then
    # Caché de disco de cada perfil (cache2, startupCache, miniaturas...).
    while IFS= read -r -d '' p; do vaciar "$p"; done < <(
      find "$HOME/Library/Caches/Firefox/Profiles" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)

    while IFS= read -r -d '' perfil; do
      borrar "$perfil/shader-cache"
      vaciar "$perfil/crashes/submitted"
      vaciar "$perfil/minidumps"
      # Caché de service workers de cada sitio (no de extensiones moz-extension).
      while IFS= read -r -d '' origen; do
        case "$(basename "$origen")" in moz-extension*) continue ;; esac
        borrar "$origen/cache"
      done < <(find "$perfil/storage/default" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)

      if [ "$BORRAR_HISTORIAL_Y_SESIONES" = true ]; then
        # places.sqlite guarda historial Y marcadores juntos: no se borra el
        # archivo; solo se eliminan las visitas con sqlite3.
        if [ -f "$perfil/places.sqlite" ] && [ "$(uid_de "$perfil/places.sqlite")" = "$MI_UID" ]; then
          if [ "$MODO_SIMULACION" -eq 1 ]; then
            n="$(sqlite3 -readonly "$perfil/places.sqlite" 'SELECT count(*) FROM moz_historyvisits;' 2>/dev/null || echo '?')"
            log "  [simulación] se borrarían $n visitas del historial de $(basename "$perfil")"
          elif ! sqlite3 "$perfil/places.sqlite" \
              'DELETE FROM moz_historyvisits; DELETE FROM moz_inputhistory;
               UPDATE moz_places SET visit_count = 0, last_visit_date = NULL;' 2>/dev/null; then
            registrar_omitido "$perfil/places.sqlite" "no se pudo limpiar el historial"
          fi
        fi
        for f in formhistory.sqlite cookies.sqlite cookies.sqlite-wal cookies.sqlite-shm \
                 sessionstore.jsonlz4 sessionstore-backups webappsstore.sqlite; do
          borrar "$perfil/$f"
        done
        # Datos de sitios (localStorage, IndexedDB), excepto extensiones.
        while IFS= read -r -d '' origen; do
          case "$(basename "$origen")" in moz-extension*) continue ;; esac
          borrar "$origen"
        done < <(find "$perfil/storage/default" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
      fi
    done < <(find "$FF_PERFILES" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
  fi
fi


# =============================================================================
#  9) SISTEMA — cachés de usuario, logs, informes de fallos y Papelera
# =============================================================================
log ""
log "[Sistema]"

if [ "$LIMPIAR_CACHES_USUARIO" = true ]; then
  log " Cachés de usuario (~/Library/Caches)"
  while IFS= read -r -d '' item; do
    nombre="$(basename "$item")"
    if cache_excluida "$nombre"; then continue; fi
    # En cada carpeta de app se borra el contenido y se deja la carpeta,
    # porque algunas apps fallan si su carpeta de caché desaparece.
    if [ -d "$item" ] && [ ! -L "$item" ]; then vaciar "$item"; else borrar "$item"; fi
  done < <(find "$HOME/Library/Caches" -mindepth 1 -maxdepth 1 -print0 2>/dev/null)
fi

if [ "$LIMPIAR_LOGS" = true ]; then
  log " Logs de usuario con más de $DIAS_LOGS días"
  while IFS= read -r -d '' f; do
    case "$(basename "$f")" in limpieza-nocturna*) continue ;; esac
    borrar "$f"
  done < <(find "$HOME/Library/Logs" -path "$HOME/Library/Logs/DiagnosticReports" -prune \
             -o -type f -mtime +"$DIAS_LOGS" -print0 2>/dev/null)
fi

if [ "$LIMPIAR_INFORMES_FALLOS" = true ]; then
  log " Informes de fallos (DiagnosticReports)"
  vaciar "$HOME/Library/Logs/DiagnosticReports"
fi

if [ "$VACIAR_PAPELERA" = true ]; then
  log " Papelera"
  vaciar "$HOME/.Trash"
fi


# =============================================================================
#  10) CACHÉS DE DESARROLLO (opcionales)
# =============================================================================
log ""
log "[Desarrollo]"

if [ "$LIMPIAR_NPM" = true ]; then
  log " npm"
  vaciar "$HOME/.npm/_cacache"; vaciar "$HOME/.npm/_logs"; vaciar "$HOME/.npm/_npx"
fi

if [ "$LIMPIAR_YARN" = true ]; then
  log " yarn"
  vaciar "$HOME/Library/Caches/Yarn"; vaciar "$HOME/.yarn/berry/cache"
fi

if [ "$LIMPIAR_PNPM" = true ]; then
  log " pnpm"
  if command -v pnpm >/dev/null 2>&1; then
    STORE="$(pnpm store path 2>/dev/null || true)"
    if [ "$MODO_SIMULACION" -eq 1 ]; then
      log "  [simulación] pnpm store prune sobre $STORE ($(humano "$(tamano_kb "$STORE")") en total; solo borra lo no usado)"
    else
      ANTES="$(tamano_kb "$STORE")"
      pnpm store prune >/dev/null 2>&1 || registrar_omitido "pnpm store" "pnpm store prune falló"
      TOTAL_KB=$((TOTAL_KB + ANTES - $(tamano_kb "$STORE")))
    fi
  else
    log "  pnpm no está instalado o no está en el PATH; se omite."
  fi
fi

if [ "$LIMPIAR_HOMEBREW" = true ]; then
  log " Homebrew (caché de descargas)"
  vaciar "$HOME/Library/Caches/Homebrew"
fi

if [ "$LIMPIAR_HOMEBREW_VERSIONES_ANTIGUAS" = true ] && command -v brew >/dev/null 2>&1; then
  log " Homebrew (brew cleanup --prune=all)"
  if [ "$MODO_SIMULACION" -eq 1 ]; then
    brew cleanup --prune=all -n 2>&1 | tail -n 5 | sed 's/^/  [simulación] /' | while IFS= read -r l; do log "$l"; done
  else
    brew cleanup --prune=all 2>&1 | tail -n 3 | sed 's/^/  /' | while IFS= read -r l; do log "$l"; done
  fi
fi

if [ "$LIMPIAR_NEXT_CACHE" = true ]; then
  log " .next/cache"
  for raiz in ${DIRECTORIOS_PROYECTOS[@]+"${DIRECTORIOS_PROYECTOS[@]}"}; do
    [ -d "$raiz" ] || continue
    if esta_protegido "$raiz"; then registrar_omitido "$raiz" "carpeta protegida"; continue; fi
    while IFS= read -r -d '' d; do borrar "$d"; done < <(
      find "$raiz" -maxdepth 6 \( -name node_modules -o -name .git \) -prune \
        -o -type d -path '*/.next/cache' -print0 -prune 2>/dev/null)
  done
fi

if [ "$LIMPIAR_XCODE_DERIVEDDATA" = true ]; then
  log " Xcode DerivedData"
  vaciar "$HOME/Library/Developer/Xcode/DerivedData"
fi


# =============================================================================
#  11) RESUMEN FINAL
# =============================================================================
LIBRE_DESPUES_KB="$(df -k "$HOME" | awk 'NR==2 {print $4}')"
log ""
log "------------------------------------------------------------------"
if [ "$MODO_SIMULACION" -eq 1 ]; then
  log " SIMULACIÓN: se borrarían $TOTAL_ELEMENTOS elementos y se liberarían ~$(humano "$TOTAL_KB")"
else
  log " Elementos borrados: $TOTAL_ELEMENTOS"
  log " Espacio liberado:   $(humano "$TOTAL_KB")"
  log " Libre en disco:     $(humano "$LIBRE_ANTES_KB") → $(humano "$LIBRE_DESPUES_KB")"
fi

if [ "${#OMITIDOS[@]}" -gt 0 ]; then
  log ""
  log " Omitidos (${#OMITIDOS[@]}) — revísalos a mano si quieres:"
  for o in "${OMITIDOS[@]}"; do log "   - $o"; done
else
  log " Omitidos: ninguno"
fi
log " Terminó: $(date '+%Y-%m-%d %H:%M:%S')"
log "------------------------------------------------------------------"

if [ "$NOTIFICAR_AL_TERMINAR" = true ] && [ "$MODO_SIMULACION" -eq 0 ]; then
  osascript -e "display notification \"Liberado: $(humano "$TOTAL_KB") · Omitidos: ${#OMITIDOS[@]}\" with title \"Limpieza nocturna\"" >/dev/null 2>&1 || true
fi

exit 0
