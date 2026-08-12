#!/bin/bash

# ==========================================================
# LazyVim setup — personal config snapshot
# Reproduces the exact LazyVim state (extras + pinned plugin
# versions) verified working on this machine, on a fresh Mac.
# Target hardware: MacBook Air M4, LATAM keyboard.
#
# Safe to re-run (idempotent). Existing ~/.config/nvim that
# wasn't created by this script is backed up, never deleted.
#
# Author: Miguel Barra <mbarra.git@gmail.com>
# ==========================================================

set -e

NVIM_CONFIG="$HOME/.config/nvim"
MARKER="$NVIM_CONFIG/.lazyvim-snapshot-marker"

echo "Setting up LazyVim..."
echo ""

# ----------------------------------------------------------
# 1. Homebrew (in case this script runs standalone)
# ----------------------------------------------------------
if ! command -v brew &> /dev/null; then
  echo "Homebrew not found. Installing..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [[ $(uname -m) == "arm64" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
else
  echo "Homebrew is already installed."
fi

# ----------------------------------------------------------
# 2. Neovim
# ----------------------------------------------------------
if ! command -v nvim &> /dev/null; then
  echo "Installing Neovim..."
  brew install neovim
else
  echo "Neovim is already installed ($(nvim --version | head -1))."
fi

# ----------------------------------------------------------
# 3. Back up any pre-existing nvim config/state that isn't ours
# ----------------------------------------------------------
if [ -d "$NVIM_CONFIG" ] && [ ! -f "$MARKER" ]; then
  BACKUP="$HOME/.config/nvim.bak.$(date +%Y%m%d%H%M%S)"
  echo "Existing ~/.config/nvim found (not managed by this script)."
  echo "Backing it up to: $BACKUP"
  mv "$NVIM_CONFIG" "$BACKUP"
fi

if [ ! -f "$MARKER" ]; then
  # Fresh install or re-install: clear plugin/state dirs so lazy-lock.json
  # below is applied cleanly instead of merging with stale state.
  rm -rf "$HOME/.local/share/nvim" "$HOME/.local/state/nvim" "$HOME/.cache/nvim"
fi

# ----------------------------------------------------------
# 4. Clone the official LazyVim starter (init.lua, config/*, etc.)
# ----------------------------------------------------------
if [ ! -d "$NVIM_CONFIG" ]; then
  echo "Cloning LazyVim starter..."
  git clone --depth 1 https://github.com/LazyVim/starter "$NVIM_CONFIG"
  rm -rf "$NVIM_CONFIG/.git"
fi

touch "$MARKER"

# ----------------------------------------------------------
# 5. Apply the personal snapshot: extras enabled + exact plugin
#    versions pinned, so the new Mac installs precisely what was
#    tested — not whatever is newest upstream that day.
# ----------------------------------------------------------
echo "Writing lazyvim.json (extras: snacks_picker, snacks_explorer)..."
cat > "$NVIM_CONFIG/lazyvim.json" <<'EOF'
{
  "extras": [
    "lazyvim.plugins.extras.editor.snacks_picker",
    "lazyvim.plugins.extras.editor.snacks_explorer"
  ],
  "install_version": 8,
  "news": {
    "NEWS.md": "11866"
  },
  "version": 8
}
EOF

echo "Writing lazy-lock.json (pinned plugin versions)..."
cat > "$NVIM_CONFIG/lazy-lock.json" <<'EOF'
{
  "LazyVim": { "branch": "main", "commit": "c10948c50b18fae7f256433afdef09e432410480" },
  "blink.cmp": { "branch": "main", "commit": "78336bc89ee5365633bcf754d93df01678b5c08f" },
  "bufferline.nvim": { "branch": "main", "commit": "655133c3b4c3e5e05ec549b9f8cc2894ac6f51b3" },
  "catppuccin": { "branch": "main", "commit": "edefef779ab08ce1a4a404713e3012b0d202bd35" },
  "conform.nvim": { "branch": "master", "commit": "016802de402556da54c36bd7359b441266b01cdd" },
  "flash.nvim": { "branch": "main", "commit": "b6346946d10d07998efee029fb0f7a593806d0cd" },
  "friendly-snippets": { "branch": "main", "commit": "6cd7280adead7f586db6fccbd15d2cac7e2188b9" },
  "gitsigns.nvim": { "branch": "main", "commit": "5be654f2232c10ddcad19c1607a67b6b4b78fc29" },
  "grug-far.nvim": { "branch": "main", "commit": "6e05398cf6cad05b3fb46569db96b1ccfcbbd402" },
  "lazy.nvim": { "branch": "main", "commit": "85c7ff3711b730b4030d03144f6db6375044ae82" },
  "lazydev.nvim": { "branch": "main", "commit": "ff2cbcba459b637ec3fd165a2be59b7bbaeedf0d" },
  "lualine.nvim": { "branch": "master", "commit": "221ce6b2d999187044529f49da6554a92f740a96" },
  "mason-lspconfig.nvim": { "branch": "main", "commit": "67029ccdac1ef8941e13b826417bc0ffac24cc86" },
  "mason.nvim": { "branch": "main", "commit": "2a6940af80375532e5e9e7c1f2fc6319a1b7a69d" },
  "mini.ai": { "branch": "main", "commit": "25248c6aa002391936a6200f12d1466015987133" },
  "mini.icons": { "branch": "main", "commit": "98faae31e9be1cc054ae63485e58ceb185efcad0" },
  "mini.pairs": { "branch": "main", "commit": "b1c5a726921b7a8c9321e9a7a208aa0571de5810" },
  "noice.nvim": { "branch": "main", "commit": "7bfd942445fb63089b59f97ca487d605e715f155" },
  "nui.nvim": { "branch": "main", "commit": "de740991c12411b663994b2860f1a4fd0937c130" },
  "nvim-lint": { "branch": "master", "commit": "a219b2c9e5b4765e5c845aba119dad55806fcaf1" },
  "nvim-lspconfig": { "branch": "master", "commit": "d2011e1dd0c27569c551f16b688d86029ae015c9" },
  "nvim-treesitter": { "branch": "main", "commit": "c9f9ed6c1892f629ea399f4ee7905f2686fa13f2" },
  "nvim-treesitter-textobjects": { "branch": "main", "commit": "898ee307df58f854d11cd7edd06472574d48014e" },
  "nvim-ts-autotag": { "branch": "main", "commit": "88c1453db4ba7dd24131086fe51fdf74e587d275" },
  "persistence.nvim": { "branch": "main", "commit": "b20b2a7887bd39c1a356980b45e03250f3dce49c" },
  "plenary.nvim": { "branch": "master", "commit": "74b06c6c75e4eeb3108ec01852001636d85a932b" },
  "snacks.nvim": { "branch": "main", "commit": "882c996cf28183f4d63640de0b4c02ec886d01f2" },
  "todo-comments.nvim": { "branch": "main", "commit": "31e3c38ce9b29781e4422fc0322eb0a21f4e8668" },
  "tokyonight.nvim": { "branch": "main", "commit": "cdc07ac78467a233fd62c493de29a17e0cf2b2b6" },
  "trouble.nvim": { "branch": "main", "commit": "bd67efe408d4816e25e8491cc5ad4088e708a69a" },
  "ts-comments.nvim": { "branch": "main", "commit": "a59d6092213447450191122c9346f309161504cb" },
  "which-key.nvim": { "branch": "main", "commit": "3aab2147e74890957785941f0c1ad87d0a44c15a" }
}
EOF

# ----------------------------------------------------------
# 6. Install/sync plugins headlessly (no need to open nvim by hand)
# ----------------------------------------------------------
echo "Installing plugins (headless sync, this can take a minute)..."
nvim --headless "+Lazy! sync" +qa

# ----------------------------------------------------------
# 7. Personal keybindings cheat sheet
# ----------------------------------------------------------
if [ -f "$HOME/LazyVim-Atajos.md" ]; then
  echo "~/LazyVim-Atajos.md already exists, leaving it as is."
else
  echo "Restoring ~/LazyVim-Atajos.md (LazyVim keybindings reference)..."
  cat > "$HOME/LazyVim-Atajos.md" <<'ATAJOS_EOF'
# Atajos de LazyVim (guía personal)

Generado a partir de tu instalación real en `~/.config/nvim` (LazyVim `v16.0.0`, Neovim `0.12.4`).
Tecla líder (`<leader>`) = **barra espaciadora**. Adaptado para **MacBook Air M4, teclado LATAM**.

> **Estado de tu config:** era 100% stock, sin ningún keymap propio. No tenía buscador de archivos ni file tree
> habilitados (los "extras" estaban vacíos). Para que esta guía sea útil, habilité los extras oficiales
> `snacks_picker` y `snacks_explorer` en `lazyvim.json` — son la opción recomendada actual de LazyVim, no instalan
> plugins nuevos (ya tenías `snacks.nvim`) y ya quedaron sincronizados. Si abrís nvim y algo no coincide con esta
> guía, corré `:Lazy sync` una vez.

---

## 0. Fundamentos de Vim (si nunca usaste un editor modal)

Vim tiene **modos**. VS Code solo tiene uno (edición libre); Vim separa "moverme/comandar" de "escribir texto".

| Modo | Cómo entrar | Para qué sirve |
|---|---|---|
| **Normal** | `Esc` (modo por defecto al abrir un archivo) | Moverte, borrar, copiar, ejecutar comandos |
| **Insert** | `i` (insertar antes del cursor), `a` (después), `o` (línea nueva abajo), `O` (línea nueva arriba) | Escribir texto, como en VS Code |
| **Visual** | `v` (carácter), `V` (línea), `Ctrl+v` (bloque) | Seleccionar texto |
| **Comando** | `:` desde Normal | Comandos tipo `:w`, `:q`, `:%s/...` |

| Atajo | Acción | Equivalente VS Code |
|---|---|---|
| `Esc` | Volver a modo Normal | — |
| `:w` / `Ctrl+s` | Guardar | `Cmd+S` |
| `:q` | Cerrar ventana/buffer actual | `Cmd+W` |
| `:wq` o `ZZ` | Guardar y cerrar | — |
| `:qa` / `<leader>qq` | Salir de nvim (todo) | Cerrar la app |
| `u` | Deshacer | `Cmd+Z` |
| `Ctrl+r` | Rehacer | `Cmd+Shift+Z` |
| `yy` | Copiar (yank) línea | `Cmd+C` |
| `dd` | Cortar línea | `Cmd+X` |
| `p` / `P` | Pegar después / antes del cursor | `Cmd+V` |
| `x` | Borrar carácter bajo el cursor | `Delete` |
| `.` | Repetir el último cambio | — |
| `hjkl` | Izquierda/abajo/arriba/derecha | Flechas |
| `w` / `b` | Palabra siguiente / anterior | `Opt+→` / `Opt+←` |
| `0` / `$` | Inicio / fin de línea | `Cmd+←` / `Cmd+→` |
| `gg` / `G` | Inicio / fin del archivo | `Cmd+↑` / `Cmd+↓` |
| `/texto` + Enter | Buscar en el archivo, `n`/`N` siguiente/anterior | `Cmd+F` |

---

## 1. Which-Key (tu "menú de comandos" visual)

| Atajo | Acción |
|---|---|
| `<leader>` (Space, solo) | Muestra el menú de atajos disponibles (which-key) |
| `<leader>?` | Atajos disponibles en el buffer actual |
| `<leader>:` | Historial de comandos `:` |
| `<leader>sk` | Buscar cualquier keymap (útil si olvidás uno) |
| `<leader>sC` | Buscar comandos `:` disponibles |

Tip: si no te acordás un atajo, apretá `<leader>` y esperá un segundo — which-key te muestra todas las opciones.

---

## 2. Buscar y abrir archivos rápido (≈ `Cmd+P` de VS Code)

| Atajo | Acción | Equivalente VS Code |
|---|---|---|
| `<leader><space>` | **Buscar archivo por nombre** (raíz del proyecto) | `Cmd+P` |
| `<leader>ff` | Igual que arriba (find files, root) | `Cmd+P` |
| `<leader>fF` | Buscar archivo (desde el directorio actual, no la raíz) | — |
| `<leader>fr` | Archivos recientes | `Cmd+P` + historial |
| `<leader>fR` | Archivos recientes (solo del directorio actual) | — |
| `<leader>fg` | Buscar solo archivos trackeados por git | — |
| `<leader>fb` | Buscar entre buffers abiertos | `Cmd+P` (lista de tabs) |
| `<leader>fc` | Buscar en tus archivos de config de nvim | — |
| `<leader>fp` | Buscar entre proyectos conocidos | — |
| `<leader>,` | Lista rápida de buffers abiertos | `Cmd+K Cmd+W` (lista de tabs) |

**Dentro del buscador** (mientras escribís):

| Atajo | Acción |
|---|---|
| `Enter` | Abrir en la ventana actual |
| `Ctrl+v` | Abrir en split vertical |
| `Ctrl+s` | Abrir en split horizontal |
| `Ctrl+t` | Abrir en una pestaña (tab) nueva |
| `Tab` | Marcar/seleccionar varios resultados |
| `Ctrl+j` / `Ctrl+k` | Moverse por la lista (también `↓`/`↑`) |
| `Esc` | Cancelar |
| `Alt+h` | Mostrar/ocultar archivos ocultos |
| `Alt+p` | Mostrar/ocultar panel de preview |

---

## 3. File tree / explorador (≈ panel lateral de VS Code)

| Atajo | Acción | Equivalente VS Code |
|---|---|---|
| `<leader>e` | **Abrir/cerrar** el explorador (raíz del proyecto) | `Cmd+Shift+E` (toggle sidebar) |
| `<leader>E` | Abrir/cerrar explorador (directorio actual) | — |
| `<leader>fe` | Igual que `<leader>e` | — |
| `<leader>fE` | Igual que `<leader>E` | — |

**Navegando dentro del explorador** (cursor sobre un archivo/carpeta):

| Atajo | Acción |
|---|---|
| `j` / `k` | Moverse abajo / arriba |
| `l` o `Enter` | Abrir archivo / entrar a la carpeta |
| `h` | Cerrar carpeta / subir un nivel |
| `Backspace` | Subir al directorio padre |
| `a` | Crear archivo o carpeta nueva |
| `d` | Borrar |
| `r` | Renombrar |
| `c` | Copiar |
| `m` | Mover |
| `y` | Yank (copiar al "portapapeles" del explorador) |
| `p` | Pegar |
| `o` | Abrir con la app del sistema |
| `H` | Mostrar/ocultar archivos ocultos |
| `.` | Enfocar el explorador en la carpeta del cursor |
| `q` / `Esc` | Cerrar |

---

## 4. Buffers = tus "pestañas" de archivo (≈ tabs de VS Code)

**Importante:** en Vim, lo que VS Code llama "pestaña" (cada archivo abierto) se llama **buffer**. Las "tabs" reales
de Vim son otra cosa (más parecidas a "ventanas separadas" o distintos layouts) — casi no las vas a necesitar día a
día.

| Atajo | Acción | Equivalente VS Code |
|---|---|---|
| `<S-h>` (Shift+h) | Buffer anterior | `Cmd+Shift+[` |
| `<S-l>` (Shift+l) | Buffer siguiente | `Cmd+Shift+]` |
| `[b` / `]b` | Buffer anterior / siguiente | igual que arriba |
| `<leader>bb` o `` <leader>` `` | Saltar al buffer anterior (alternar entre 2) | `Cmd+Tab` entre 2 archivos |
| `<leader>,` | Lista de buffers para elegir | `Cmd+P` |
| `<leader>bd` | Cerrar buffer actual | `Cmd+W` |
| `<leader>bo` | Cerrar todos los buffers **menos** el actual | "Close Others" |
| `<leader>bD` | Cerrar buffer y su ventana | — |
| `<leader>bp` | Fijar (pin) buffer en la barra | Pin tab |
| `<leader>br` | Cerrar buffers a la derecha | — |
| `<leader>bl` | Cerrar buffers a la izquierda | — |
| `<leader>bj` | Elegir buffer visualmente en la barra (bufferline pick) | — |

---

## 5. Splits / ventanas (≈ split editor de VS Code)

| Atajo | Acción | Equivalente VS Code |
|---|---|---|
| `<leader>-` | Split horizontal (uno arriba, otro abajo) | `Cmd+\` (variante horizontal) |
| `<leader>\|` | Split vertical (uno al lado del otro) | `Cmd+\` |
| `Ctrl+h/j/k/l` | Moverte al split izquierda/abajo/arriba/derecha | `Cmd+K` luego flecha |
| `Ctrl+↑/↓` | Aumentar/reducir alto del split | Arrastrar borde |
| `Ctrl+←/→` | Reducir/aumentar ancho del split | Arrastrar borde |
| `<leader>wd` | Cerrar el split actual | `Cmd+W` |
| `<leader>wm` | Maximizar/restaurar el split actual (zoom) | Maximize editor group |
| `Ctrl+w` + `Space` | Modo "hydra": moverte entre splits sin repetir `Ctrl+w` | — |

*(Splits reales de Vim: `:vsplit` / `:split` también funcionan si preferís escribirlos.)*

### Tabs reales de Vim (opcional, uso ocasional)

| Atajo | Acción |
|---|---|
| `<leader><tab><tab>` | Nueva tab |
| `<leader><tab>]` / `[` | Tab siguiente / anterior |
| `<leader><tab>d` | Cerrar tab |
| `<leader><tab>o` | Cerrar las demás tabs |

---

## 6. Buscar en el proyecto (≈ `Cmd+Shift+F`)

| Atajo | Acción | Equivalente VS Code |
|---|---|---|
| `<leader>/` | Buscar texto (grep) en todo el proyecto | `Cmd+Shift+F` |
| `<leader>sg` | Igual (grep, raíz del proyecto) | `Cmd+Shift+F` |
| `<leader>sG` | Grep desde el directorio actual | — |
| `<leader>sw` | Buscar la palabra bajo el cursor (o la selección) | `Cmd+Shift+F` con palabra ya cargada |
| `<leader>sb` | Buscar dentro del buffer actual (todas las líneas) | `Cmd+F` |
| `<leader>sB` | Buscar en todos los buffers abiertos | — |
| `<leader>sr` | **Buscar y reemplazar** en múltiples archivos (grug-far) | `Cmd+Shift+H` |

---

## 7. Código / LSP (≈ IntelliSense de VS Code)

| Atajo | Acción | Equivalente VS Code |
|---|---|---|
| `gd` | Ir a la definición | `F12` |
| `gD` | Ir a la declaración | — |
| `gr` | Ver referencias | `Shift+F12` |
| `gI` | Ir a la implementación | `Cmd+F12` |
| `gy` | Ir a la definición de tipo | — |
| `K` | Ver documentación (hover) | `Cmd` + hover |
| `gK` | Ver ayuda de firma de función | Firma al escribir `(` |
| `<leader>ca` | Code action | `Cmd+.` |
| `<leader>cr` | Rename símbolo | `F2` |
| `<leader>cR` | Renombrar archivo (y actualizar imports) | Rename file |
| `<leader>cf` | Formatear archivo | `Shift+Opt+F` |
| `<leader>cd` | Ver diagnóstico de la línea actual | Hover sobre el error |
| `]d` / `[d` | Diagnóstico siguiente / anterior | `F8` / `Shift+F8` |
| `]e` / `[e` | Error siguiente / anterior | — |
| `]w` / `[w` | Warning siguiente / anterior | — |
| `<leader>ss` | Símbolos del archivo (outline) | `Cmd+Shift+O` |
| `<leader>sS` | Símbolos de todo el workspace | `Cmd+T` |
| `<leader>xx` | Panel de diagnósticos (Trouble) | Panel "Problems" (`Cmd+Shift+M`) |
| `<leader>cs` | Panel de símbolos (Trouble) | — |
| `gcc` | Comentar/descomentar línea | `Cmd+/` |
| `gc` (en visual) | Comentar/descomentar selección | `Cmd+/` |
| `<leader>cm` | Abrir Mason (gestor de LSP/linters/formatters) | Extensiones |

---

## 8. Git (≈ panel de Source Control)

| Atajo | Acción | Equivalente VS Code |
|---|---|---|
| `<leader>gg` | Abrir **Lazygit** (interfaz completa de git) | Panel de Source Control |
| `<leader>gb` | Ver blame de la línea actual | GitLens inline blame |
| `<leader>gf` | Historial del archivo actual | — |
| `<leader>gs` | Estado de git (picker) | Panel de Source Control |
| `<leader>gd` | Ver diffs por hunk | Vista de diff |
| `]h` / `[h` | Ir al siguiente / anterior cambio (hunk) | Flechas del gutter |
| `<leader>ghs` | Stage del hunk actual | Botón "+" en el gutter |
| `<leader>ghr` | Descartar (reset) el hunk actual | Botón de revert |
| `<leader>ghp` | Preview del hunk actual | Click en el indicador del gutter |

---

## 9. Terminal integrada

| Atajo | Acción | Equivalente VS Code |
|---|---|---|
| `Ctrl+/` | Abrir/cerrar terminal flotante (raíz del proyecto) | `` Ctrl+` `` |
| `<leader>ft` | Terminal (raíz del proyecto) | `` Ctrl+` `` |
| `<leader>fT` | Terminal (directorio actual) | — |
| `Ctrl+h/j/k/l` (dentro de la terminal) | Moverte a otro split desde la terminal | — |

---

## 10. Sesiones (recuperar dónde quedaste)

| Atajo | Acción |
|---|---|
| `<leader>qs` | Restaurar sesión guardada |
| `<leader>qS` | Elegir entre varias sesiones |
| `<leader>ql` | Restaurar la última sesión |

---

## 11. Otros esenciales

| Atajo | Acción |
|---|---|
| `<leader>l` | Abrir Lazy (gestor de plugins) |
| `<leader>uw` | Alternar word wrap |
| `<leader>ul` | Alternar números de línea |
| `<leader>uL` | Alternar números de línea relativos |
| `<leader>us` | Alternar corrector ortográfico |
| `<leader>uz` | Modo Zen (sin distracciones) |
| `<leader>uC` | Elegir colorscheme |
| `s` + 2 letras | **Flash**: saltar al instante a cualquier punto visible del código |

---

## 12. Notas sobre tu teclado LATAM (Mac)

La mayoría de los atajos de arriba usan letras y `<leader>` (Space), así que no dependen del layout. Pero algunos
símbolos que Vim usa mucho para navegación (`[` `]` `{` `}`) están en teclas especiales en un teclado LATAM. Esto lo
verifiqué directamente contra la distribución **"Latin American"** activa en tu Mac (no es una tabla genérica):

| Símbolo | Cómo se escribe en tu teclado | Dónde se usa en LazyVim |
|---|---|---|
| `{` | Tecla a la derecha de la `Ñ`, **sin** modificador | Poco usado directamente, más común en código |
| `[` | **Shift** + esa misma tecla (a la derecha de la Ñ) | `[b` `[d` `[e` `[w` `[h` `[q` `[t` `[g` (todo lo que sea "anterior") |
| `}` | Tecla inmediatamente a la derecha de la anterior, **sin** modificador | Poco usado directamente |
| `]` | **Shift** + esa tecla | `]b` `]d` `]e` `]w` `]h` `]q` `]t` `]g` (todo lo que sea "siguiente") |
| `<` `>` | Tecla arriba de `Tab`, esquina superior izquierda (sin / con Shift) | Indentar en modo visual |
| `\|` (pipe) | Tecla junto al Shift izquierdo, **sin** modificador | `<leader>\|` (split vertical) |
| `$` `%` | Igual que en un teclado US: `Shift+4`, `Shift+5` | Motions `$` (fin de línea), `%` (bracket matching) |
| `^` | `Shift+Option` + la tecla de `{`/`[` (a la derecha de la Ñ) | Motion `^` (primer carácter no vacío de la línea) |
| `` ` `` (backtick) | `Shift+Option` + la tecla junto al Shift izquierdo | Marcas: `` `a `` para saltar a la marca `a` |

Como `[` y `]` son los que más vas a usar (toda la familia de atajos "anterior/siguiente" de LazyVim los usa), vale
la pena que verifiques esa combinación una vez con el **Visor de Teclado** de macOS (`Ajustes del Sistema → Teclado →
Métodos de entrada → Mostrar Visor de Teclado`, o el ícono de entrada en la barra de menú) y la practiques hasta que
salga sola.

---

## Flujo típico de un día de trabajo

1. `<leader><space>` → buscar y abrir el archivo en el que vas a trabajar.
2. `<leader>e` → si necesitás ver la estructura de carpetas, abrís el explorador; `<leader>e` de nuevo (o `q`) lo cierra.
3. Editás con los motions normales de Vim (`i`, `dd`, `yy`, `p`, `.`, etc.).
4. `gd` / `K` / `<leader>ca` → navegar y actuar sobre el código con LSP.
5. `<leader>/` → buscar algo en todo el proyecto.
6. `<S-h>` / `<S-l>` o `<leader>,` → moverte entre los archivos que ya tenés abiertos.
7. `<leader>gg` → Lazygit para revisar/commitear cambios.
8. `Ctrl+/` → terminal rápida si necesitás correr algo.
9. `:w` (o `Ctrl+s`) para guardar, `<leader>qq` para salir de todo.
ATAJOS_EOF
fi

echo ""
echo "Done. LazyVim is installed with your personal snapshot:"
echo "   - Extras: snacks_picker, snacks_explorer"
echo "   - Plugin versions pinned to the ones tested on the original machine"
echo "   - ~/LazyVim-Atajos.md restored"
echo ""
echo "Open nvim and run :Lazy to confirm plugin status, and :checkhealth to check for issues."
