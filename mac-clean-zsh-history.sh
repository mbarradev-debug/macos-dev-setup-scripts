#!/bin/bash
# =============================================================================
#  mac-clean-zsh-history.sh — Deja tu ~/.zsh_history limpio y útil
#  Author: Miguel Barra
#
#  Qué hace, en orden:
#    1. Secretos:   borra líneas con tokens, contraseñas o claves (siempre).
#    2. Largos:     borra textos enormes pegados por error.
#    3. Triviales:  borra comandos que no vale la pena guardar (ls, clear, cd ..).
#    4. Tipeo:      borra comandos que no existen (gti status, npmm i).
#    5. Duplicados: deja una sola copia de cada comando, la más reciente.
#    6. Antiguos:   borra lo que no usas hace mucho (cada uso renueva la fecha).
#    7. Límite:     si aún sobran entradas, borra las más viejas.
#  Lo que calce con PATRONES_CONSERVAR se salta los pasos 2, 3, 4, 6 y 7.
#
#  Uso:
#    ./mac-clean-zsh-history.sh --dry-run        Simula: muestra qué borraría
#    ./mac-clean-zsh-history.sh --dry-run --todo Igual, pero lista todo
#    ./mac-clean-zsh-history.sh                  Limpia de verdad (con respaldo)
#    ./mac-clean-zsh-history.sh --restaurar      Vuelve al último respaldo
#    ./mac-clean-zsh-history.sh --instalar-zshrc Agrega a ~/.zshrc la config
#                                                que evita que se vuelva a ensuciar
#    ./mac-clean-zsh-history.sh --archivo RUTA   Usa otro archivo de historial
#
#  Seguridad:
#    - Antes de escribir guarda un respaldo en CARPETA_RESPALDOS.
#    - Usa el mismo bloqueo que zsh (~/.zsh_history.LOCK), así ninguna
#      terminal abierta escribe mientras se reescribe el archivo.
#    - Escribe en un archivo temporal y lo reemplaza de una vez: si algo
#      falla a mitad de camino, tu historial original queda intacto.
#
#  Compatible con /bin/bash 3.2 (el de macOS). La lógica va en python3, que
#  viene con las Command Line Tools de Xcode.
# =============================================================================

set -u
set -o pipefail


# =============================================================================
#  1) CONFIGURACIÓN — edita esta sección a tu gusto
# =============================================================================

ARCHIVO_HISTORIAL="${HISTFILE:-$HOME/.zsh_history}"

BORRAR_SECRETOS=true       # tokens, contraseñas, claves de API
BORRAR_TRIVIALES=true      # según PATRONES_TRIVIALES
BORRAR_ERRORES_TIPEO=true  # comandos cuyo programa no existe en tu Mac
BORRAR_DUPLICADOS=true     # conserva solo la copia más reciente

LARGO_MAXIMO=500           # caracteres; 0 = sin límite

# Borra comandos cuyo último uso fue hace más de DIAS_SIN_USO días. Como los
# duplicados se reducen a la copia más reciente, todo lo que sigues usando
# tiene fecha nueva y se queda. 0 = desactivado.
DIAS_SIN_USO=365

MAX_ENTRADAS=5000          # tope final; 0 = sin tope

CARPETA_RESPALDOS="$HOME/.local/share/zsh-history-backups"
RESPALDOS_A_CONSERVAR=5

# Comandos triviales (expresiones regulares sobre el comando completo).
PATRONES_TRIVIALES=(
  '^(ls|ll|la|l|lsa|eza|tree)( |$)'                       # listar archivos
  '^(pwd|clear|reset|exit|history|whoami|date|cal|c|q|:q|:wq)$'
  '^cd( +(\.\.(/\.\.)*|-|~|/))? *$'                       # cd, cd .., cd -, cd ~
  '^\.{2,}$'                                              # .., ... (alias de Oh My Zsh)
  '^(nvim|vim|vi|code|cursor|open|z)( +\.)?$'             # abrir el directorio actual
  '^(which|type|where|man|tldr) +[^ ]+$'                  # consultas rápidas
)

# Comandos que siempre se conservan aunque sean viejos o poco usados:
# justamente los "esenciales" que corres de vez en cuando y cuesta recordar.
PATRONES_CONSERVAR=(
  '^ssh '
  '^(scp|rsync) '
  '^git (clone|remote|config) '
  '^docker (run|compose|build) '
  '^brew (install|uninstall) '
  '^(npx|pnpm dlx|pnpm create|npm create) '
  '^(psql|supabase|vercel) '
  '^launchctl '
)


# =============================================================================
#  2) OPCIONES DE LÍNEA DE COMANDOS
# =============================================================================

uso() { sed -n '17,23p' "$0" | sed 's/^#  *//'; }

MODO="limpiar"
MOSTRAR_TODO=false

while [ $# -gt 0 ]; do
  case "$1" in
    -n|--dry-run)     MODO="simular" ;;
    --todo)           MOSTRAR_TODO=true ;;
    --restaurar)      MODO="restaurar" ;;
    --instalar-zshrc) MODO="zshrc" ;;
    --archivo)        shift; ARCHIVO_HISTORIAL="${1:-}" ;;
    -h|--help)        uso; exit 0 ;;
    *) echo "Opción desconocida: $1"; uso; exit 2 ;;
  esac
  shift
done


# =============================================================================
#  3) MODO --instalar-zshrc: prevenir en vez de limpiar
# =============================================================================

if [ "$MODO" = "zshrc" ]; then
  ZSHRC="${ZDOTDIR:-$HOME}/.zshrc"
  MARCA_INICIO="# >>> zsh-history-clean >>>"
  if grep -qF "$MARCA_INICIO" "$ZSHRC" 2>/dev/null; then
    echo "La configuración ya está en $ZSHRC. No se cambió nada."
    exit 0
  fi
  if [ -f "$ZSHRC" ]; then
    cp -p "$ZSHRC" "$ZSHRC.bak-$(date +%Y%m%d-%H%M%S)"
  fi
  cat >> "$ZSHRC" <<'EOF'

# >>> zsh-history-clean >>>
# Mantiene ~/.zsh_history limpio solo. Va al final para pisar lo que define
# Oh My Zsh. Lo agregó mac-clean-zsh-history.sh --instalar-zshrc.
HISTSIZE=50000                 # comandos en memoria por sesión
SAVEHIST=10000                 # comandos guardados en el archivo
setopt HIST_IGNORE_ALL_DUPS    # al repetir un comando, se borra la copia vieja
setopt HIST_SAVE_NO_DUPS       # nunca escribe duplicados al archivo
setopt HIST_IGNORE_SPACE       # " comando" (con espacio delante) no se guarda
setopt HIST_REDUCE_BLANKS      # quita espacios sobrantes antes de guardar
setopt HIST_NO_STORE           # no guarda los "history" / "fc -l"
setopt HIST_FIND_NO_DUPS       # al buscar con flecha arriba no repite resultados
HISTORY_IGNORE='(ls|ll|la|l|pwd|clear|reset|exit|history|cd|cd ..|cd -|cd ~|..|...)'
# <<< zsh-history-clean <<<
EOF
  echo "Listo: configuración agregada al final de $ZSHRC (respaldo creado)."
  echo "Aplícala con:  exec zsh"
  exit 0
fi


# =============================================================================
#  4) MODO --restaurar
# =============================================================================

if [ "$MODO" = "restaurar" ]; then
  ULTIMO="$(ls -1 "$CARPETA_RESPALDOS"/zsh_history-* 2>/dev/null | tail -n 1)"
  if [ -z "$ULTIMO" ]; then
    echo "No hay respaldos en $CARPETA_RESPALDOS."
    exit 1
  fi
  [ -f "$ARCHIVO_HISTORIAL" ] && cp -p "$ARCHIVO_HISTORIAL" "$ARCHIVO_HISTORIAL.antes-de-restaurar"
  cp -p "$ULTIMO" "$ARCHIVO_HISTORIAL"
  echo "Restaurado desde: $ULTIMO"
  echo "(El historial que había quedó en $ARCHIVO_HISTORIAL.antes-de-restaurar)"
  echo "Abre una terminal nueva o ejecuta: exec zsh"
  exit 0
fi


# =============================================================================
#  5) LIMPIEZA (la hace python3)
# =============================================================================

if [ -z "$ARCHIVO_HISTORIAL" ] || [ ! -f "$ARCHIVO_HISTORIAL" ]; then
  echo "No encontré el historial: ${ARCHIVO_HISTORIAL:-(vacío)}"
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "Falta python3. Instálalo con: xcode-select --install"
  exit 1
fi

# Une un array en un texto con una línea por elemento (para pasarlo a python).
unir() { local IFS=$'\n'; echo "$*"; }

export ZHC_ARCHIVO="$ARCHIVO_HISTORIAL"
export ZHC_MODO="$MODO"
export ZHC_MOSTRAR_TODO="$MOSTRAR_TODO"
export ZHC_SECRETOS="$BORRAR_SECRETOS"
export ZHC_TRIVIALES_ON="$BORRAR_TRIVIALES"
export ZHC_TIPEO="$BORRAR_ERRORES_TIPEO"
export ZHC_DUPLICADOS="$BORRAR_DUPLICADOS"
export ZHC_LARGO_MAXIMO="$LARGO_MAXIMO"
export ZHC_DIAS_SIN_USO="$DIAS_SIN_USO"
export ZHC_MAX_ENTRADAS="$MAX_ENTRADAS"
export ZHC_RESPALDOS="$CARPETA_RESPALDOS"
export ZHC_RESPALDOS_N="$RESPALDOS_A_CONSERVAR"
export ZHC_TRIVIALES="$(unir ${PATRONES_TRIVIALES[@]+"${PATRONES_TRIVIALES[@]}"})"
export ZHC_CONSERVAR="$(unir ${PATRONES_CONSERVAR[@]+"${PATRONES_CONSERVAR[@]}"})"

exec python3 - <<'PY'
import os, re, sys, time, stat, shutil, fcntl, subprocess, datetime
from collections import Counter

env = os.environ
def si(n):     return env.get(n, "true") == "true"
def num(n):    return int(env.get(n, "0") or 0)
def lista(n):  return [p for p in env.get(n, "").split("\n") if p.strip()]

ARCHIVO      = env["ZHC_ARCHIVO"]
SIMULAR      = env["ZHC_MODO"] == "simular"
MOSTRAR_TODO = si("ZHC_MOSTRAR_TODO")
LARGO_MAXIMO = num("ZHC_LARGO_MAXIMO")
DIAS_SIN_USO = num("ZHC_DIAS_SIN_USO")
MAX_ENTRADAS = num("ZHC_MAX_ENTRADAS")

def compilar(nombre):
    salida = []
    for p in lista(nombre):
        try:
            salida.append(re.compile(p))
        except re.error as e:
            print(f"Patrón inválido en {nombre}: {p!r} ({e}); se ignora.")
    return salida

TRIVIALES = compilar("ZHC_TRIVIALES")
CONSERVAR = compilar("ZHC_CONSERVAR")

# Patrones de secretos. (?i) = sin distinguir mayúsculas.
SECRETOS = [re.compile(p) for p in [
    r'(?i)(password|passwd|secret|token|api[_-]?key|access[_-]?key|private[_-]?key)\w*["\']?\s*(=|:\s*["\'])\s*[^\s"\'$]\S*',
    r'(?i)--(password|pass|token|secret|api-?key)[= ]+[^\s$-]\S*',
    r'\b(ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{20,}',
    r'\bgithub_pat_\w{20,}',
    r'\bsk-(ant-|proj-)?[A-Za-z0-9_-]{20,}',
    r'\bAKIA[0-9A-Z]{16}\b',
    r'\bxox[abprs]-[A-Za-z0-9-]{10,}',
    r'\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.',       # JWT (Supabase, etc.)
    r'(?i)authorization:\s*(bearer|basic)\s+[^\s"\']+',
    r'(?i)\b[a-z][a-z0-9+.-]*://[^/\s:@]+:[^@\s/]+@',       # usuario:clave@ en URLs
    r'\b(mysql|sshpass)\b.*\s-p\S+',
]]

# ---------------------------------------------------------------------------
# Lectura del formato de zsh
#   Con EXTENDED_HISTORY (Oh My Zsh lo activa) cada entrada es
#   ": <inicio>:<duración>;<comando>". Un comando de varias líneas se guarda
#   con "\" al final de cada línea. zsh además "metafica" los bytes no ASCII
#   (byte 0x83 + byte^0x20): para analizar se decodifica, pero al escribir se
#   copia el texto original intacto, byte por byte.
# ---------------------------------------------------------------------------
EXTENDIDO = re.compile(rb'^: *(\d+):(\d+);(.*)\Z', re.S)

def desmetaficar(b):
    out, i = bytearray(), 0
    while i < len(b):
        if b[i] == 0x83 and i + 1 < len(b):
            out.append(b[i + 1] ^ 0x20); i += 2
        else:
            out.append(b[i]); i += 1
    return out.decode("utf-8", "replace")

class Entrada:
    __slots__ = ("crudo", "ts", "texto", "protegido")
    def __init__(self, crudo):
        self.crudo = crudo
        m = EXTENDIDO.match(crudo)
        cmd = m.group(3) if m else crudo
        self.ts = int(m.group(1)) if m else None
        self.texto = desmetaficar(cmd).replace("\\\n", "\n").strip()
        self.protegido = False

def leer(data):
    lineas = data.split(b"\n")
    if lineas and lineas[-1] == b"":
        lineas.pop()
    entradas, buf = [], []
    for ln in lineas:
        buf.append(ln)
        if ln.endswith(b"\\") and not ln.endswith(b"\\\\"):
            continue                      # el comando sigue en la línea siguiente
        entradas.append(Entrada(b"\n".join(buf)))
        buf = []
    if buf:
        entradas.append(Entrada(b"\n".join(buf)))
    return entradas

# ---------------------------------------------------------------------------
# Comandos que existen: le pregunta a tu propio zsh (con tu .zshrc cargado)
# por programas del PATH, alias, funciones y builtins.
# ---------------------------------------------------------------------------
def comandos_conocidos():
    prueba = env.get("ZHC_COMANDOS_ARCHIVO")          # solo para pruebas
    if prueba:
        return set(open(prueba).read().split())
    zsh = shutil.which("zsh") or "/bin/zsh"
    script = ('print -r -- __ZHC__; print -rl -- ${(k)commands} ${(k)aliases} '
              '${(k)functions} ${(k)builtins} ${(k)reswords}')
    try:
        r = subprocess.run([zsh, "-i", "-c", script], stdin=subprocess.DEVNULL,
                           capture_output=True, timeout=30,
                           env={**env, "POWERLEVEL9K_INSTANT_PROMPT": "off",
                                "DISABLE_AUTO_UPDATE": "true"})
        salida = r.stdout.decode("utf-8", "replace")
        if "__ZHC__" not in salida:
            return None
        nombres = set(salida.split("__ZHC__", 1)[1].split())
        return nombres if len(nombres) >= 100 else None
    except Exception:
        return None

ASIGNACION = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=")
ESPECIALES = set("/$`~({['\"=!;|&<>*")

def es_tipeo(texto, conocidos):
    for palabra in texto.split():
        if ASIGNACION.match(palabra):
            continue                      # VAR=valor comando
        palabra = palabra.lstrip("\\")
        if not palabra or any(c in ESPECIALES for c in palabra):
            return False                  # rutas, variables, subshells: no se juzgan
        return palabra not in conocidos
    return False

def es_secreto(texto):
    return any(p.search(texto) for p in SECRETOS)

def ocultar(texto):
    for p in SECRETOS:
        texto = p.sub("[OCULTO]", texto)
    return texto

def corto(texto, n=90):
    texto = texto.replace("\n", " ⏎ ")
    return texto if len(texto) <= n else texto[: n - 1] + "…"

# ---------------------------------------------------------------------------
# Filtro
# ---------------------------------------------------------------------------
CATEGORIAS = [
    ("secretos",   "Con posibles secretos (tokens, contraseñas, claves)"),
    ("largos",     f"Demasiado largos (más de {LARGO_MAXIMO} caracteres)"),
    ("triviales",  "Triviales (ls, clear, cd .., etc.)"),
    ("tipeo",      "Errores de tipeo (el comando no existe)"),
    ("duplicados", "Duplicados (se dejó solo el más reciente)"),
    ("antiguos",   f"Sin usar hace más de {DIAS_SIN_USO} días"),
    ("exceso",     f"Sobre el límite de {MAX_ENTRADAS} entradas (las más viejas)"),
    ("vacias",     "Vacías"),
]

def limpiar(entradas, conocidos):
    borrados = {c: [] for c, _ in CATEGORIAS}
    paso = []
    for e in entradas:
        t = e.texto
        if not t:
            borrados["vacias"].append(""); continue
        if si("ZHC_SECRETOS") and es_secreto(t):
            borrados["secretos"].append(ocultar(t)); continue
        e.protegido = any(p.search(t) for p in CONSERVAR)
        if not e.protegido:
            if LARGO_MAXIMO and len(t) > LARGO_MAXIMO:
                borrados["largos"].append(t); continue
            if si("ZHC_TRIVIALES_ON") and any(p.search(t) for p in TRIVIALES):
                borrados["triviales"].append(t); continue
            if conocidos and es_tipeo(t, conocidos):
                borrados["tipeo"].append(t); continue
        paso.append(e)

    if si("ZHC_DUPLICADOS"):
        ultimo = {}
        for i, e in enumerate(paso):
            ultimo[e.texto] = i
        unicos = []
        for i, e in enumerate(paso):
            if ultimo[e.texto] == i:
                unicos.append(e)
            else:
                borrados["duplicados"].append(e.texto)
        paso = unicos

    if DIAS_SIN_USO > 0:
        limite = time.time() - DIAS_SIN_USO * 86400
        quedan = []
        for e in paso:
            if not e.protegido and e.ts is not None and e.ts < limite:
                borrados["antiguos"].append(e.texto)
            else:
                quedan.append(e)
        paso = quedan

    if MAX_ENTRADAS > 0 and len(paso) > MAX_ENTRADAS:
        sobran = len(paso) - MAX_ENTRADAS
        quedan = []
        for e in paso:                    # el archivo va de más viejo a más nuevo
            if sobran > 0 and not e.protegido:
                borrados["exceso"].append(e.texto); sobran -= 1
            else:
                quedan.append(e)
        paso = quedan
    return paso, borrados

def serializar(entradas):
    return b"".join(e.crudo + b"\n" for e in entradas)

def humano(n):
    for u in ("B", "KB", "MB"):
        if n < 1024: return f"{n:.0f} {u}"
        n /= 1024
    return f"{n:.1f} GB"

def informe(total, final, borrados, antes, despues):
    print(f"\nHistorial: {ARCHIVO}")
    print(f"Entradas:  {total}  →  {len(final)}   ({humano(antes)} → {humano(despues)})\n")
    limite = None if MOSTRAR_TODO else 8
    for clave, titulo in CATEGORIAS:
        items = borrados[clave]
        if not items: continue
        print(f"■ {titulo}: {len(items)}")
        if clave == "vacias": continue
        conteo = Counter(items).most_common(limite)
        for texto, n in conteo:
            veces = f"x{n:<4}" if n > 1 else "     "
            print(f"    {veces} {corto(texto)}")
        resto = len(set(items)) - len(conteo)
        if resto > 0:
            print(f"    … y {resto} más (usa --todo para verlos todos)")
        print()

# ---------------------------------------------------------------------------
# Bloqueo compatible con zsh
#   zsh crea ~/.zsh_history.LOCK mientras escribe y considera abandonado un
#   bloqueo de más de 10 segundos. Por eso todo lo lento (consultar a zsh por
#   los comandos) se hace ANTES de bloquear; adentro solo se lee y escribe.
# ---------------------------------------------------------------------------
def bloquear(ruta_lock):
    for _ in range(100):                  # hasta ~10 segundos
        try:
            fd = os.open(ruta_lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
            os.write(fd, f"{os.getpid()} mac-clean-zsh-history\n".encode())
            os.close(fd)
            return True
        except FileExistsError:
            time.sleep(0.1)
    return False

def respaldar():
    carpeta = env["ZHC_RESPALDOS"]
    os.makedirs(carpeta, mode=0o700, exist_ok=True)
    os.chmod(carpeta, 0o700)
    base = os.path.join(carpeta, "zsh_history-" +
                        datetime.datetime.now().strftime("%Y%m%d-%H%M%S"))
    destino, n = base, 1
    while os.path.exists(destino):        # dos limpiezas en el mismo segundo
        destino = f"{base}-{n}"; n += 1
    shutil.copy2(ARCHIVO, destino)
    os.chmod(destino, 0o600)
    viejos = sorted(f for f in os.listdir(carpeta) if f.startswith("zsh_history-"))
    for f in viejos[: max(0, len(viejos) - num("ZHC_RESPALDOS_N"))]:
        os.remove(os.path.join(carpeta, f))
    return destino

def main():
    conocidos = None
    if si("ZHC_TIPEO"):
        conocidos = comandos_conocidos()
        if conocidos is None:
            print("Aviso: no pude obtener la lista de comandos desde zsh; "
                  "se omite el filtro de errores de tipeo.")

    if SIMULAR:
        data = open(ARCHIVO, "rb").read()
        entradas = leer(data)
        final, borrados = limpiar(entradas, conocidos)
        informe(len(entradas), final, borrados, len(data), len(serializar(final)))
        print("Simulación: no se cambió nada. Ejecuta sin --dry-run para limpiar.")
        return 0

    ruta_lock = ARCHIVO + ".LOCK"
    if not bloquear(ruta_lock):
        print("Otra terminal está escribiendo el historial. Intenta de nuevo en un rato.")
        return 1
    try:
        with open(ARCHIVO, "rb") as f:
            fcntl.lockf(f, fcntl.LOCK_SH)  # por si usas HIST_FCNTL_LOCK
            data = f.read()
        entradas = leer(data)
        final, borrados = limpiar(entradas, conocidos)
        nuevo = serializar(final)
        if len(final) == len(entradas):
            print("Tu historial ya está limpio. No se cambió nada.")
            return 0
        respaldo = respaldar()
        temporal = ARCHIVO + ".zhc-tmp"
        with open(temporal, "wb") as f:
            f.write(nuevo); f.flush(); os.fsync(f.fileno())
        os.chmod(temporal, stat.S_IMODE(os.stat(ARCHIVO).st_mode))
        os.replace(temporal, ARCHIVO)
    finally:
        try: os.remove(ruta_lock)
        except FileNotFoundError: pass

    informe(len(entradas), final, borrados, len(data), len(nuevo))
    print(f"Respaldo: {respaldo}")
    if borrados["secretos"]:
        print("\nOjo: se borraron líneas con posibles secretos. Borrarlas del historial no")
        print("las invalida: si eran reales, rota esos tokens o contraseñas. Los respaldos")
        print(f"aún las contienen; puedes borrarlos con: rm {env['ZHC_RESPALDOS']}/zsh_history-*")
    print("\nCierra las otras terminales abiertas (o ejecuta 'exec zsh' en cada una)")
    print("para que no vuelvan a escribir el historial viejo que tienen en memoria.")
    return 0

sys.exit(main())
PY
