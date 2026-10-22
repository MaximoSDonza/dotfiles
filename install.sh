#!/usr/bin/env bash
# Instala estos dotfiles: enlaza home/ dentro de $HOME, restaura GNOME y aplica el tema.
# Uso: ./install.sh              tema completo (enlaces, extensiones, ajustes del tema, servicios)
#      ./install.sh --personal   además mis preferencias de GNOME (favoritos, touchpad, atajos...)
#      ./install.sh --links      solo los enlaces simbólicos
# Lo que ya existe en $HOME y no es un enlace se mueve a ~/.dotfiles-backup/<fecha>/
set -euo pipefail
DOT="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
BACKUP="$HOME/.dotfiles-backup/$(date +%F_%H%M%S)"
LINKS_ONLY=0 PERSONAL=0
for arg in "$@"; do
  case $arg in
    --links) LINKS_ONLY=1 ;;
    --personal) PERSONAL=1 ;;
    *) echo "Opción desconocida: $arg (ver el encabezado de install.sh)" >&2; exit 1 ;;
  esac
done

link() {  # link <origen en repo> <destino>
  local src=$1 dst=$2
  # ya enlazado (se comparan rutas resueltas: el origen puede ser otro enlace)
  [[ -L $dst && $(readlink -f "$dst") == "$(readlink -f "$src")" ]] && return
  if [[ -e $dst || -L $dst ]]; then
    mkdir -p "$BACKUP/$(dirname "${dst#$HOME/}")"
    mv "$dst" "$BACKUP/${dst#$HOME/}"
  fi
  mkdir -p "$(dirname "$dst")"
  ln -s "$src" "$dst"
  echo "  ↳ ${dst/#$HOME/\~}"
}

echo "==> Enlaces"
while IFS= read -r -d '' f; do
  link "$f" "$HOME/${f#$DOT/home/}"
done < <(find "$DOT/home" -type f -print0)
link "$HOME/.config/cybersigil/apply.sh" "$HOME/.local/bin/cybersigil-apply"
ff=0
for p in "$HOME"/.config/mozilla/firefox/*.default-release "$HOME"/.mozilla/firefox/*.default-release; do
  [[ -d $p ]] && { link "$DOT/firefox/user.js" "$p/user.js"; ff=1; }
done
# el perfil se crea la primera vez que se abre Firefox
(( ff )) || echo "  ! Firefox sin perfil todavía: ábrelo una vez y ejecuta ./install.sh --links"
# control de secretos antes de cada commit (ver .githooks/pre-commit)
git -C "$DOT" config core.hooksPath .githooks 2>/dev/null || true
(( LINKS_ONLY )) && exit 0

echo "==> Plantillas de Nautilus (clic derecho → Nuevo documento)"
# copias, no enlaces: un documento nuevo no debe quedar enlazado al repo
TPL=$(xdg-user-dir TEMPLATES 2>/dev/null || echo "$HOME/Templates")
mkdir -p "$TPL" && cp --update=none "$DOT"/plantillas/* "$TPL"/

echo "==> Fuentes"
mkdir -p "$HOME/.local/share/fonts/cybersigil"
cp -n "$DOT"/fonts/*.ttf "$HOME/.local/share/fonts/cybersigil/" && fc-cache -f >/dev/null

echo "==> Extensiones de GNOME (extensions.gnome.org)"
SHELL_VER=$(gnome-shell --version | grep -oE '[0-9]+' | head -1)
TMP=$(mktemp -d)
while read -r uuid; do
  [[ -z $uuid || $uuid == \#* ]] && continue
  if [[ -d $HOME/.local/share/gnome-shell/extensions/$uuid ]]; then echo "  ✓ $uuid"; continue; fi
  url=$(curl -sf "https://extensions.gnome.org/extension-info/?uuid=$uuid&shell_version=$SHELL_VER" \
        | python3 -c 'import sys,json; print(json.load(sys.stdin)["download_url"])') || { echo "  ✗ $uuid (sin versión para GNOME $SHELL_VER)"; continue; }
  curl -sfL -o "$TMP/$uuid.zip" "https://extensions.gnome.org$url" && gnome-extensions install --force "$TMP/$uuid.zip" && echo "  + $uuid"
done < "$DOT/packages/gnome-extensions.txt"
rm -rf "$TMP"

echo "==> Ajustes de GNOME del tema"
python3 -I "$DOT/lib/dconf_sync.py" restore "$DOT/dconf/tema.ini"
if (( PERSONAL )); then
  echo "==> Ajustes personales de GNOME (favoritos, touchpad, atajos...)"
  python3 -I "$DOT/lib/dconf_sync.py" restore "$DOT/dconf/personal.ini"
fi

echo "==> Servicios de usuario"
# GNOME Software no arranca con la sesión; se abre a demanda (ver home/.local/share/dbus-1/services)
systemctl --user mask gnome-software.service
# servicios de GNOME para hardware que esta laptop no tiene (lector de smartcard, módem 3G/4G)
# y protección USB, que sin el paquete usbguard no hace nada. Revertir: systemctl --user unmask ...
systemctl --user mask org.gnome.SettingsDaemon.Smartcard.service org.gnome.SettingsDaemon.Wwan.service \
  org.gnome.SettingsDaemon.UsbProtection.service
# JetBrains Toolbox no arranca con la sesión; este temporizador avisa de versiones nuevas de los IDEs
[[ -x /opt/jetbrains-toolbox/jetbrains-toolbox ]] && systemctl --user enable jetbrains-update-check.timer

echo "==> Tema Cybersigil"
"$HOME/.local/bin/cybersigil-apply"

cat <<EOF

Listo. Si todavía no los ejecutaste (ver README):
  sudo pacman -S --needed - < $DOT/packages/base.txt
  yay -S --needed - < $DOT/packages/aur-base.txt
  sudo bash ~/.config/cybersigil/system-tune.sh     # detecta el hardware; deshacer: --revert
Luego cierra sesión y vuelve a entrar. Para desinstalar: $DOT/uninstall.sh
EOF
