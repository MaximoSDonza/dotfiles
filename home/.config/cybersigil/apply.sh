#!/usr/bin/env bash
# Aplica el tema Cybersigil desde palette.sh + templates/. Seguro de re-ejecutar.
set -euo pipefail
DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
set -a; . "$DIR/palette.sh"
# ajustes privados de esta máquina (ciudad, etc.); no está en el repo
[[ -f $HOME/.config/cybersigil/local.sh ]] && . "$HOME/.config/cybersigil/local.sh"
set +a
EXT="$HOME/.local/share/gnome-shell/extensions"

# Un archivo propio del usuario (no generado acá: sin la marca "Cybersigil") se guarda antes de
# reemplazarlo; uninstall.sh lo restaura
BACKUP="$HOME/.dotfiles-backup/$(date +%F_%H%M%S)"
protect() {
  [[ $1 == "$HOME/.config/cybersigil/generated/"* ]] && return 0   # carpeta propia del tema
  [[ -f $1 && ! -L $1 ]] && ! grep -q "Cybersigil" "$1" || return 0
  mkdir -p "$(dirname "$BACKUP/${1#"$HOME"/}")"
  cp -a "$1" "$BACKUP/${1#"$HOME"/}"
  echo "  tu ${1/#"$HOME"/\~} anterior quedó en ${BACKUP/#"$HOME"/\~}"
}

# put <destino>: escribe stdin en el archivo solo si cambió. GTK, GNOME (el fondo) y otras apps vigilan
# estos archivos y los recargan cada vez que se tocan, aunque el contenido sea el mismo
put() {
  mkdir -p "$(dirname "$1")"
  protect "$1"
  local tmp
  tmp=$(mktemp)
  cat > "$tmp"
  cmp -s "$tmp" "$1" || cat "$tmp" > "$1"
  rm -f "$tmp"
}
render() { subst "$1" | put "$2"; }  # render <plantilla> <destino>
# Tokens de las plantillas. Cada color existe en tres formatos:
#   @@X@@ → #8b0a14 · @@X_RGB@@ → 139, 10, 20 (rgba() en CSS) · @@X_ANSI@@ → 139;10;20 (terminal)
#   @@X_HEX@@ → 8b0a14 (IntelliJ)
# GLASS_* van primero porque en palette.sh pueden contener tokens de color (ej. @@CHROME_RGB@@)
SED_ARGS=()
for v in GLASS GLASS_CARD GLASS_HOVER FONT_SIGIL WIDGET_ALPHA; do SED_ARGS+=(-e "s/@@$v@@/${!v}/g"); done
for v in BG BG_ALT SURFACE SURFACE_HI TEXT CHROME CHROME_DIM CHROME_HI ACCENT ACCENT_HI \
         ACCENT_SOFT SYN_STRING SYN_NUMBER SYN_TYPE SYN_PROPERTY SYN_COMMENT; do
  hex=${!v}
  [[ $hex =~ ^#[0-9a-fA-F]{6}$ ]] || { echo "palette.sh: $v='$hex' no es un color #rrggbb" >&2; exit 1; }
  r=$((16#${hex:1:2})) g=$((16#${hex:3:2})) b=$((16#${hex:5:2}))
  SED_ARGS+=(-e "s/@@$v@@/$hex/g" -e "s/@@${v}_RGB@@/$r, $g, $b/g" -e "s/@@${v}_ANSI@@/$r;$g;$b/g" \
            -e "s/@@${v}_HEX@@/${hex:1}/g")
done
subst() {  # subst <plantilla>: reemplaza los tokens y escribe en stdout
  sed "${SED_ARGS[@]}" "$DIR/templates/$1"
}
has_icons() { [[ -d /usr/share/icons/$1 || -d $HOME/.local/share/icons/$1 || -d $HOME/.icons/$1 ]]; }

# Archivos
render gnome-shell.css "$HOME/.themes/Cybersigil/gnome-shell/gnome-shell.css"
render gtk.css "$HOME/.config/gtk-3.0/gtk.css"
# GTK4 además usa variables CSS (:root), que GTK3 no entiende
{ subst gtk.css; subst gtk4-vars.css; } | put "$HOME/.config/gtk-4.0/gtk.css"
# Imagen de fondo de kitty e IntelliJ (APPS_BG_IMAGE): pegada a la derecha sobre el negro, tenue y
# desvanecida hacia la izquierda, donde está el texto. Se arma solo si cambió la imagen o la opacidad
FONDO="$HOME/.config/cybersigil/generated/fondo-apps"
if [[ -n $APPS_BG_IMAGE && -r $APPS_BG_IMAGE ]]; then
  origen=$({ sha1sum < "$APPS_BG_IMAGE"; echo "$APPS_BG_ALPHA $BG"; } | sha1sum | cut -d' ' -f1)
  if [[ $origen != "$(cat "$FONDO.origen" 2>/dev/null)" ]]; then
    mkdir -p "$(dirname "$FONDO")"
    python3 -I - "$APPS_BG_IMAGE" "$FONDO" "$APPS_BG_ALPHA" "$BG" <<'EOF' && echo "$origen" > "$FONDO.origen"
# FONDO.png: opaco, para kitty · FONDO-transparente.png: solo la imagen tenue, para IntelliJ
import io, sys
import cairo, gi
gi.require_version("GdkPixbuf", "2.0")
from gi.repository import GdkPixbuf
imagen, salida, alfa, bg = sys.argv[1], sys.argv[2], float(sys.argv[3]), sys.argv[4]
W, H = 2560, 1440
pb = GdkPixbuf.Pixbuf.new_from_file(imagen)
pb = pb.scale_simple(round(pb.get_width() * H / pb.get_height()), H, GdkPixbuf.InterpType.HYPER)
img = cairo.ImageSurface.create_from_png(io.BytesIO(pb.save_to_bufferv("png", [], [])[1]))
x = W - img.get_width()
for opaco in (True, False):
    s = cairo.ImageSurface(cairo.FORMAT_ARGB32, W, H)
    cr = cairo.Context(s)
    if opaco:
        cr.set_source_rgb(*(int(bg[i:i + 2], 16) / 255 for i in (1, 3, 5)))
        cr.paint()
    desvanecido = cairo.LinearGradient(x, 0, x + img.get_width() * 0.45, 0)
    desvanecido.add_color_stop_rgba(0, 0, 0, 0, 0)
    desvanecido.add_color_stop_rgba(1, 0, 0, 0, alfa)
    cr.set_source_surface(img, x, 0)
    cr.mask(desvanecido)
    s.write_to_png(salida + (".png" if opaco else "-transparente.png"))
EOF
  fi
fi
{
  subst kitty-theme.conf
  echo "background_opacity $APPS_OPACITY"
  if [[ -n $APPS_BG_IMAGE && -f $FONDO.png ]]; then
    printf 'background_image %s\nbackground_image_layout cscaled\nbackground_image_linear yes\n' "$FONDO.png"
  fi
} | put "$HOME/.config/kitty/cybersigil.conf"
render nvim-colors.lua "$HOME/.config/nvim/colors/cybersigil.lua"
render starship.toml "$HOME/.config/starship.toml"
render fastfetch.jsonc "$HOME/.config/fastfetch/config.jsonc"
# Widgets de escritorio: estilos y configuración de la extensión
CSW="$HOME/.local/share/gnome-shell/extensions/cybersigil-widgets@donza"
if [[ -d $CSW ]]; then
  render widgets.css "$CSW/stylesheet.css"
  mkdir -p "$HOME/.config/cybersigil/generated"
  python3 -I - <<'EOF' | put "$HOME/.config/cybersigil/generated/widgets.json"
import json, os, sys
e = os.environ
widgets = e["WIDGETS"].split()
json.dump({
    "widgets": widgets,
    "anchors": {w: e.get(f"WIDGET_{w.upper()}_ANCHOR", "top-left") for w in widgets},
    "city": e["WEATHER_CITY"], "region": e["WEATHER_REGION"],
    "latitude": float(e["WEATHER_LAT"]), "longitude": float(e["WEATHER_LON"]),
    "margin": int(e["WIDGET_MARGIN"]), "gap": int(e["WIDGET_GAP"]), "blur": int(e["WIDGET_BLUR"]),
}, sys.stdout, ensure_ascii=False, indent=2)
EOF
fi

# Apps con la paleta: Brave, VS Code, IntelliJ y la pantalla de inicio de sesión (GDM)
G="$HOME/.config/cybersigil/generated"
mkdir -p "$G/brave-theme" "$G/vscode/extension/themes" "$G/intellij/META-INF" "$G/intellij/themes"
render brave-theme.json "$G/brave-theme/manifest.json"      # Brave: brave://extensions → Cargar descomprimida
render darkreader.txt "$G/brave-darkreader.txt"             # colores para la extensión Dark Reader
render gdm.css "$G/gdm.css"                                 # lo instala: sudo bash gdm-theme.sh
subst vscode-package.json > "$G/vscode/extension/package.json"
subst vscode-theme.json > "$G/vscode/extension/themes/cybersigil-color-theme.json"
subst intellij-plugin.xml > "$G/intellij/META-INF/plugin.xml"
subst intellij-theme.json > "$G/intellij/themes/cybersigil.theme.json"
subst intellij-scheme.xml > "$G/intellij/themes/cybersigil.xml"
python3 -I - "$G" <<'EOF'
# Empaqueta los temas: .vsix para VS Code (zip con su manifiesto) y .jar (plugin) para JetBrains
import os, sys, zipfile
g = sys.argv[1]
def pack(src, dest, extra):
    with zipfile.ZipFile(dest, "w", zipfile.ZIP_DEFLATED) as z:
        for name, content in extra.items():
            z.writestr(zipfile.ZipInfo(name, date_time=(2026, 1, 1, 0, 0, 0)), content)
        for root, _, files in sorted(os.walk(src)):
            for f in sorted(files):
                if not f.startswith(".") and not f.endswith((".vsix", ".jar")):
                    full = os.path.join(root, f)
                    # fecha fija: mismo contenido → mismo archivo (no se reinstala si no cambió)
                    info = zipfile.ZipInfo(os.path.relpath(full, src), date_time=(2026, 1, 1, 0, 0, 0))
                    info.compress_type = zipfile.ZIP_DEFLATED
                    with open(full, "rb") as fh:
                        z.writestr(info, fh.read())
pack(f"{g}/vscode", f"{g}/vscode/cybersigil.vsix", {
    "[Content_Types].xml": '<?xml version="1.0" encoding="utf-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
                           '<Default Extension=".json" ContentType="application/json"/><Default Extension=".vsixmanifest" ContentType="text/xml"/></Types>',
    "extension.vsixmanifest": '<?xml version="1.0" encoding="utf-8"?>\n<PackageManifest Version="2.0.0" xmlns="http://schemas.microsoft.com/developer/vsx-schema/2011">'
        '<Metadata><Identity Language="en-US" Id="cybersigil-theme" Version="1.0.0" Publisher="cybersigil"/><DisplayName>Cybersigil</DisplayName>'
        '<Description xml:space="preserve">Tema generado desde palette.sh</Description><Categories>Themes</Categories>'
        '<Properties><Property Id="Microsoft.VisualStudio.Code.Engine" Value="^1.70.0"/></Properties></Metadata>'
        '<Installation><InstallationTarget Id="Microsoft.VisualStudio.Code"/></Installation><Dependencies/>'
        '<Assets><Asset Type="Microsoft.VisualStudio.Code.Manifest" Path="extension/package.json" Addressable="true"/></Assets></PackageManifest>',
})
pack(f"{g}/intellij", f"{g}/intellij/cybersigil-theme.jar", {})
EOF
# VS Code: se instala solo si el tema cambió o no está (code --install-extension tarda unos segundos)
if command -v code >/dev/null; then
  sum=$(cat "$G/vscode/extension/package.json" "$G/vscode/extension/themes/"*.json | sha1sum | cut -d' ' -f1)
  if [[ $sum != "$(cat "$G/vscode/.instalado" 2>/dev/null)" || $(code --list-extensions 2>/dev/null) != *cybersigil.cybersigil-theme* ]]; then
    code --install-extension "$G/vscode/cybersigil.vsix" --force >/dev/null 2>&1 &&
      echo "$sum" > "$G/vscode/.instalado" && echo "  VS Code: tema Cybersigil instalado"
  fi
fi
# IDEs de JetBrains: el plugin va a la carpeta de plugins de cada IDE configurado (~/.config/JetBrains/<IDE>)
for cfg in "$HOME"/.config/JetBrains/*/; do
  [[ -d $cfg ]] || continue
  plugins="$HOME/.local/share/JetBrains/$(basename "$cfg")"
  mkdir -p "$plugins"
  cmp -s "$G/intellij/cybersigil-theme.jar" "$plugins/cybersigil-theme.jar" 2>/dev/null ||
    { cp "$G/intellij/cybersigil-theme.jar" "$plugins/" && echo "  $(basename "$cfg"): tema Cybersigil (Ajustes → Apariencia → Tema)"; }
  # imagen de fondo del editor y de la ventana (la misma de kitty, ya tenue). Con el IDE abierto no se
  # toca: al cerrarse guarda su configuración y pisaría el cambio
  if [[ -f $cfg/options/other.xml ]] && ! pgrep -u "$USER" -f 'com.intellij.idea.Main' >/dev/null; then
    imagen=""
    [[ -n $APPS_BG_IMAGE && -f $FONDO-transparente.png ]] && imagen="$FONDO-transparente.png,100,scale,center"
    python3 -I - "$cfg/options/other.xml" "$imagen" <<'EOF'
import json, os, re, sys
ruta, valor = sys.argv[1], sys.argv[2]
xml = open(ruta).read()
m = re.search(r'(<component name="PropertyService"><!\[CDATA\[)(.*?)(\]\]></component>)', xml, re.S)
datos = json.loads(m.group(2)) if m else {}
props = datos.setdefault("keyToString", {})
antes = dict(props)
for clave in ("idea.background.editor", "idea.background.frame"):
    if valor:
        props[clave] = valor
    elif "fondo-apps" in props.get(clave, ""):   # solo quita la imagen si la puso cybersigil-apply
        del props[clave]
if props != antes:
    bloque = json.dumps(datos, indent=2, ensure_ascii=False)
    if m:
        xml = xml[:m.start(2)] + bloque + xml[m.end(2):]
    else:
        xml = xml.replace("</application>", f'  <component name="PropertyService"><![CDATA[{bloque}]]></component>\n</application>')
    open(ruta, "w").write(xml)
    print(f"  {os.path.normpath(ruta).split('/')[-3]}: imagen de fondo {'puesta' if valor else 'quitada'}")
EOF
  fi
done
# Logo de la pantalla de inicio: el de la distribución con sus colores pasados a la paleta (blanco y
# grises quedan, el resto pasa a rojo). Si no es un SVG no se genera y gdm-theme.sh lo quita
logo=$(gsettings get org.gnome.login-screen logo 2>/dev/null | tr -d "'" || true)   # sin GDM no existe esa clave
if [[ $logo != *.svg || ! -r $logo ]]; then
  rm -f "$G/gdm-logo.svg"
else
  python3 -I - "$logo" "$ACCENT_HI" <<'EOF' | put "$G/gdm-logo.svg"
import colorsys, re, sys
def color(m):
    h = m.group(2) if len(m.group(2)) == 6 else "".join(c * 2 for c in m.group(2))
    saturacion = colorsys.rgb_to_hls(*(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)))[2]
    return m.group(1) + (sys.argv[2] if saturacion > 0.25 else "#" + m.group(2))
svg = open(sys.argv[1]).read()
print(re.sub(r"""((?:fill|stroke|stop-color)\s*[=:]\s*["']?)#([0-9a-fA-F]{6}|[0-9a-fA-F]{3})\b""", color, svg), end="")
EOF
fi
# Arranque (menú de GRUB y Plymouth): lo instala sudo bash boot-theme.sh. Se rehace solo si cambió
# la paleta, el generador o las fuentes que encuentra (tarda un par de segundos)
if python3 -c 'import cairo, gi' 2>/dev/null; then
  origen=$({ cat "$DIR/palette.sh" "$DIR"/templates/{boot,wallpaper}.py; command -v grub-mkfont
             cat "$G/gdm-logo.svg" 2>/dev/null || true   # el logo de la UKI sale del de GDM
             for f in UnifrakturMaguntia 'Space Grotesk' 'JetBrainsMono Nerd Font'; do fc-match -f '%{file}\n' "$f"; done
           } | sha1sum | cut -d' ' -f1)
  if [[ $origen != "$(cat "$G/boot/.origen" 2>/dev/null)" ]]; then
    rm -rf "$G/boot"
    python3 -I "$DIR/templates/boot.py" "$G/boot" "$G/gdm-logo.svg" && echo "$origen" > "$G/boot/.origen" &&
      echo "  arranque: tema nuevo (instalar: sudo bash ~/.config/cybersigil/boot-theme.sh)"
  fi
fi

WP="$HOME/.local/share/backgrounds/cybersigil.svg"
python3 -I "$DIR/templates/wallpaper.py" 3072 1728 | put "$WP"

# GNOME
gs() { gsettings set "$@"; }
gs org.gnome.desktop.interface color-scheme prefer-dark
gs org.gnome.desktop.interface accent-color slate
gs org.gnome.desktop.interface font-name "$FONT_UI"
gs org.gnome.desktop.interface document-font-name "$FONT_UI"
gs org.gnome.desktop.wm.preferences titlebar-font "Space Grotesk Bold 11"
fc-list -q "${FONT_MONO% *}" && gs org.gnome.desktop.interface monospace-font-name "$FONT_MONO"
[[ -d /usr/share/themes/adw-gtk3-dark ]] && gs org.gnome.desktop.interface gtk-theme adw-gtk3-dark
has_icons Papirus-Dark && gs org.gnome.desktop.interface icon-theme Papirus-Dark
has_icons Bibata-Modern-Classic && gs org.gnome.desktop.interface cursor-theme Bibata-Modern-Classic
for k in picture-uri picture-uri-dark; do gs org.gnome.desktop.background $k "file://$WP"; done
gs org.gnome.desktop.background picture-options zoom
gs org.gnome.desktop.background primary-color "$BG"
gs org.gnome.desktop.screensaver picture-uri "file://$WP"

# Extensiones: cada bloque solo si la extensión está instalada (puede no haber versión para
# la GNOME de otro equipo)
UT="$EXT/user-theme@gnome-shell-extensions.gcampax.github.com"
[[ -d $UT ]] && gsettings --schemadir "$UT/schemas" set org.gnome.shell.extensions.user-theme name Cybersigil
B="gsettings --schemadir $EXT/blur-my-shell@aunetx/schemas set org.gnome.shell.extensions.blur-my-shell"
if [[ -d $EXT/blur-my-shell@aunetx ]]; then
  $B.panel blur false          # panel negro puro
  $B.overview blur true
  $B.lockscreen blur true
  $B.applications blur false   # sin blur en ventanas (rendimiento)
  # Menús/calendario/ajustes rápidos: blur dinámico detrás del cristal del tema
  $B.popup blur true
  $B.popup static-blur false
  $B.popup override-background false   # el color del cristal lo pone nuestro CSS (GLASS)
  $B.popup preserve-shell-theme true
  $B.popup sigma "$BLUR_SIGMA"
  $B.popup brightness "$BLUR_BRIGHTNESS"
  $B.popup rounded-corners 3           # esquinas rectas, como el tema
  for k in corner-radius menu-corner-radius submenu-corner-radius calendar-corner-radius \
           quick-settings-corner-radius notification-corner-radius dialog-corner-radius \
           osd-corner-radius osd-window-corner-radius resize-popup-corner-radius candidate-corner-radius; do
    $B.popup "$k" 0
  done
fi

# Tiling Shell: mosaico
T="gsettings --schemadir $EXT/tilingshell@ferrarodomenico.com/schemas set org.gnome.shell.extensions.tilingshell"
if [[ -d $EXT/tilingshell@ferrarodomenico.com ]]; then
  $T inner-gaps 8
  $T outer-gaps 6
  # Sin borde de foco: no coincide con el contorno real de ventanas con sombras/esquinas propias (GTK4, Brave)
  $T enable-window-border false
  $T enable-blur-snap-assistant true
  $T enable-blur-selected-tilepreview true
  $T focus-window-left  "['<Super><Control>Left']"
  $T focus-window-right "['<Super><Control>Right']"
  $T focus-window-up    "['<Super><Control>Up']"
  $T focus-window-down  "['<Super><Control>Down']"
fi

# Nautilus: "Abrir en terminal" con kitty (extensión nautilus-open-any-terminal, AUR)
NOAT=com.github.stunkymonkey.nautilus-open-any-terminal
if gsettings list-keys $NOAT >/dev/null 2>&1; then
  gs $NOAT terminal kitty
  gs $NOAT new-tab false
fi

# btop: tema generado desde la paleta
render btop.theme "$HOME/.config/btop/themes/cybersigil.theme"
render fzf.sh "$HOME/.config/cybersigil/generated/fzf.sh"

# Papirus: carpetas negras. Solo si hace falta, porque papirus-folders -C pide sudo
if command -v papirus-folders >/dev/null && has_icons Papirus-Dark &&
   [[ $(papirus-folders -l --theme Papirus-Dark 2>/dev/null) != *"> black"* ]]; then
  papirus-folders -C black --theme Papirus-Dark || true
fi

echo "Cybersigil aplicado. Si el tema de la shell no cambia, cierra sesión y vuelve a entrar."
