#!/usr/bin/env bash
# Desinstala estos dotfiles de tu usuario y deja GNOME como estaba:
#   - quita los enlaces a este repo y restaura los archivos que había antes (~/.dotfiles-backup)
#   - borra lo que generó cybersigil-apply (tema, fondo, estilos) solo si lleva su marca
#   - desactiva las extensiones y vuelve a los valores por defecto los ajustes que cambió el tema
#   - reactiva los servicios que se habían desactivado
# No toca los paquetes instalados ni los ajustes de sistema; esos se revierten con:
#   sudo bash <repo>/home/.config/cybersigil/system-tune.sh --revert
#
# Uso: ./uninstall.sh [--yes]
set -euo pipefail
DOT="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
BACKUPS="$HOME/.dotfiles-backup"
EXT="$HOME/.local/share/gnome-shell/extensions"
EXTENSIONS=(cybersigil-widgets@donza tilingshell@ferrarodomenico.com blur-my-shell@aunetx
            just-perfection-desktop@just-perfection user-theme@gnome-shell-extensions.gcampax.github.com)
say() { echo "  ${1/#"$HOME"/\~}"; }

if [[ ${1:-} != --yes ]]; then
  read -rp "¿Desinstalar los dotfiles de Cybersigil de $USER? [s/N] " answer
  [[ $answer == [sSyY]* ]] || exit 0
fi

echo "==> Copia de seguridad de los ajustes actuales de GNOME"
SAFETY="$BACKUPS/antes-de-desinstalar-$(date +%F_%H%M%S)"
mkdir -p "$SAFETY"
dconf dump / > "$SAFETY/dconf.ini"
say "$SAFETY/dconf.ini (para recuperarlos: dconf load / < ese archivo)"

echo "==> Servicios"
systemctl --user disable --now jetbrains-update-check.timer 2>/dev/null || true
systemctl --user unmask gnome-software.service org.gnome.SettingsDaemon.Smartcard.service \
  org.gnome.SettingsDaemon.Wwan.service org.gnome.SettingsDaemon.UsbProtection.service 2>/dev/null || true

echo "==> Enlaces a este repo"
while IFS= read -r -d '' f; do
  t="$HOME/${f#"$DOT"/home/}"
  if [[ -L $t && $(readlink -f "$t") == "$(readlink -f "$f")" ]]; then
    rm "$t" && say "$t"
  fi
done < <(find "$DOT/home" -type f -print0)
# enlaces que no salen de home/: el comando cybersigil-apply y el user.js de Firefox
for t in "$HOME/.local/bin/cybersigil-apply" "$HOME"/.config/mozilla/firefox/*/user.js "$HOME"/.mozilla/firefox/*/user.js; do
  [[ -L $t && ( ! -e $t || $(readlink -f "$t") == "$DOT"/* ) ]] && rm "$t" && say "$t"
done

echo "==> Archivos generados por cybersigil-apply"
for f in "$HOME/.config/gtk-3.0/gtk.css" "$HOME/.config/gtk-4.0/gtk.css" "$HOME/.config/kitty/cybersigil.conf" \
         "$HOME/.config/starship.toml" "$HOME/.config/fastfetch/config.jsonc" \
         "$HOME/.config/btop/themes/cybersigil.theme" "$HOME/.local/share/backgrounds/cybersigil.svg" \
         "$EXT/cybersigil-widgets@donza/stylesheet.css"; do
  [[ -f $f ]] && grep -q "Cybersigil" "$f" && rm "$f" && say "$f"
done
for d in "$HOME/.themes/Cybersigil" "$HOME/.config/cybersigil/generated"; do
  [[ -d $d ]] && rm -r "$d" && say "$d"
done

echo "==> Archivos que había antes de instalar"
# del respaldo más viejo al más nuevo: el primero que aparece es el original
for b in $(find "$BACKUPS" -mindepth 1 -maxdepth 1 -type d ! -name 'antes-de-desinstalar-*' 2>/dev/null | sort); do
  while IFS= read -r -d '' rel; do
    t="$HOME/$rel"
    [[ -e $t || -L $t ]] && continue
    mkdir -p "$(dirname "$t")"
    cp -a "$b/$rel" "$t" && say "$t"
  done < <(cd "$b" && find . \( -type f -o -type l \) -printf '%P\0')
done

echo "==> Plantillas, fuentes y carpetas vacías"
for f in "$DOT"/plantillas/*; do
  t="$(xdg-user-dir TEMPLATES 2>/dev/null || echo "$HOME/Templates")/$(basename "$f")"
  [[ -f $t ]] && cmp -s "$f" "$t" && rm "$t" && say "$t"
done
if [[ -d $HOME/.local/share/fonts/cybersigil ]]; then
  rm -r "$HOME/.local/share/fonts/cybersigil" && fc-cache -f >/dev/null && say "$HOME/.local/share/fonts/cybersigil"
fi
for d in "$HOME/.config/cybersigil/templates" "$HOME/.config/cybersigil" "$EXT/cybersigil-widgets@donza" \
         "$HOME/.config/fastfetch" "$HOME/.config/btop/themes" "$HOME/.config/fontconfig/conf.d" "$HOME/.config/environment.d"; do
  [[ -d $d ]] && rmdir "$d" 2>/dev/null && say "$d" || true
done

echo "==> GNOME"
# 1) desactivar las extensiones: al hacerlo Tiling Shell devuelve los atajos de teclado que tomó
current=$(gsettings get org.gnome.shell enabled-extensions)
python3 -I - "$current" "${EXTENSIONS[@]}" <<'EOF' | xargs -0 gsettings set org.gnome.shell enabled-extensions
import ast, sys
current = ast.literal_eval(sys.argv[1].removeprefix("@as "))
print(str([e for e in current if e not in sys.argv[2:]]), end="\0")
EOF
sleep 2
# 2) por si alguna extensión no alcanzó a devolverlos, los atajos y ajustes que toca Tiling Shell
gsettings reset org.gnome.desktop.wm.keybindings maximize
gsettings reset org.gnome.desktop.wm.keybindings unmaximize
gsettings reset org.gnome.mutter.keybindings toggle-tiled-left
gsettings reset org.gnome.mutter.keybindings toggle-tiled-right
gsettings reset org.gnome.mutter edge-tiling
# 3) ajustes de las extensiones y los que cambia cybersigil-apply
for e in blur-my-shell just-perfection tilingshell user-theme; do
  dconf reset -f "/org/gnome/shell/extensions/$e/"
done
for k in gtk-theme icon-theme cursor-theme font-name document-font-name monospace-font-name accent-color color-scheme; do
  gsettings reset org.gnome.desktop.interface "$k"
done
gsettings reset org.gnome.desktop.wm.preferences titlebar-font
for k in picture-uri picture-uri-dark picture-options primary-color; do
  gsettings reset org.gnome.desktop.background "$k"
done
gsettings reset org.gnome.desktop.screensaver picture-uri
gsettings reset org.freedesktop.Tracker3.Miner.Files index-on-battery 2>/dev/null || true
# GNOME Software vuelve a abrirse con el servicio normal: que D-Bus relea sus archivos
busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus ReloadConfig 2>/dev/null || true
systemctl --user daemon-reload 2>/dev/null || true

cat <<EOF

Listo. Cierra sesión y vuelve a entrar para que GNOME cargue sin las extensiones ni el tema.
Quedan sin tocar:
  - los paquetes instalados (lista en $DOT/packages/)
  - las extensiones descargadas (desactivadas) en ${EXT/#"$HOME"/\~}
  - los ajustes de sistema: sudo bash $DOT/home/.config/cybersigil/system-tune.sh --revert
  - tus respaldos en ${BACKUPS/#"$HOME"/\~}
EOF
