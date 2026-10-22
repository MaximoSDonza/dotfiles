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
  [[ -f $1 && ! -L $1 ]] && ! grep -q "Cybersigil" "$1" || return 0
  mkdir -p "$(dirname "$BACKUP/${1#"$HOME"/}")"
  cp -a "$1" "$BACKUP/${1#"$HOME"/}"
  echo "  tu ${1/#"$HOME"/\~} anterior quedó en ${BACKUP/#"$HOME"/\~}"
}

render() {  # render <plantilla> <destino>
  mkdir -p "$(dirname "$2")"
  protect "$2"
  subst "$1" > "$2"
}
# Tokens de las plantillas. Cada color existe en tres formatos:
#   @@X@@ → #8b0a14 · @@X_RGB@@ → 139, 10, 20 (rgba() en CSS) · @@X_ANSI@@ → 139;10;20 (terminal)
# GLASS_* van primero porque en palette.sh pueden contener tokens de color (ej. @@CHROME_RGB@@)
SED_ARGS=()
for v in GLASS GLASS_CARD GLASS_HOVER FONT_SIGIL WIDGET_ALPHA; do SED_ARGS+=(-e "s/@@$v@@/${!v}/g"); done
for v in BG BG_ALT SURFACE SURFACE_HI TEXT CHROME CHROME_DIM CHROME_HI ACCENT ACCENT_HI; do
  hex=${!v}
  [[ $hex =~ ^#[0-9a-fA-F]{6}$ ]] || { echo "palette.sh: $v='$hex' no es un color #rrggbb" >&2; exit 1; }
  r=$((16#${hex:1:2})) g=$((16#${hex:3:2})) b=$((16#${hex:5:2}))
  SED_ARGS+=(-e "s/@@$v@@/$hex/g" -e "s/@@${v}_RGB@@/$r, $g, $b/g" -e "s/@@${v}_ANSI@@/$r;$g;$b/g")
done
subst() {  # subst <plantilla>: reemplaza los tokens y escribe en stdout
  sed "${SED_ARGS[@]}" "$DIR/templates/$1"
}
has_icons() { [[ -d /usr/share/icons/$1 || -d $HOME/.local/share/icons/$1 || -d $HOME/.icons/$1 ]]; }

# Archivos
render gnome-shell.css "$HOME/.themes/Cybersigil/gnome-shell/gnome-shell.css"
render gtk.css "$HOME/.config/gtk-3.0/gtk.css"
# GTK4 además usa variables CSS (:root), que GTK3 no entiende
mkdir -p "$HOME/.config/gtk-4.0"
protect "$HOME/.config/gtk-4.0/gtk.css"
{ subst gtk.css; subst gtk4-vars.css; } > "$HOME/.config/gtk-4.0/gtk.css"
render kitty-theme.conf "$HOME/.config/kitty/cybersigil.conf"
render starship.toml "$HOME/.config/starship.toml"
render fastfetch.jsonc "$HOME/.config/fastfetch/config.jsonc"
# Widgets de escritorio: estilos y configuración de la extensión
CSW="$HOME/.local/share/gnome-shell/extensions/cybersigil-widgets@donza"
if [[ -d $CSW ]]; then
  render widgets.css "$CSW/stylesheet.css"
  mkdir -p "$HOME/.config/cybersigil/generated"
  python3 -I - "$HOME/.config/cybersigil/generated/widgets.json" <<'EOF'
import json, os, sys
e = os.environ
widgets = e["WIDGETS"].split()
json.dump({
    "widgets": widgets,
    "anchors": {w: e.get(f"WIDGET_{w.upper()}_ANCHOR", "top-left") for w in widgets},
    "city": e["WEATHER_CITY"], "region": e["WEATHER_REGION"],
    "latitude": float(e["WEATHER_LAT"]), "longitude": float(e["WEATHER_LON"]),
    "margin": int(e["WIDGET_MARGIN"]), "gap": int(e["WIDGET_GAP"]), "blur": int(e["WIDGET_BLUR"]),
}, open(sys.argv[1], "w"), ensure_ascii=False, indent=2)
EOF
fi

WP="$HOME/.local/share/backgrounds/cybersigil.svg"
mkdir -p "$(dirname "$WP")"
protect "$WP"
python3 "$DIR/templates/wallpaper.py" 3072 1728 > "$WP"

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
