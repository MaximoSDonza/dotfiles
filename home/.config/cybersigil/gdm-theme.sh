#!/usr/bin/env bash
# Colores de la paleta en la pantalla de inicio de sesión (GDM). Requiere root.
#   sudo bash gdm-theme.sh            instala o actualiza (después de cambiar la paleta: cybersigil-apply y esto)
#   sudo bash gdm-theme.sh --revert   vuelve a la pantalla de GNOME por defecto
#
# No modifica los archivos de GNOME (las actualizaciones los pisarían): instala una extensión del
# sistema que solo corre en la pantalla de inicio (session-modes ["gdm"]) y la activa en la
# configuración de GDM, junto con el logo de la distribución recoloreado. Se ve al cerrar sesión o al reiniciar.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Ejecutar con sudo"; exit 1; }

UUID=cybersigil-gdm@donza
DEST=/usr/share/gnome-shell/extensions/$UUID
PROFILE=/etc/dconf/profile/gdm          # tiene prioridad sobre /usr/share/dconf/profile/gdm
DB_DIR=/etc/dconf/db/gdm.d
DB_FILE=$DB_DIR/90-cybersigil
MARK="# cybersigil gdm-theme.sh"
DOT="$(cd "$(dirname "$(readlink -f "$0")")/../../.." && pwd)"
USER_HOME=$(getent passwd "${SUDO_USER:-root}" | cut -d: -f6)
CSS="$USER_HOME/.config/cybersigil/generated/gdm.css"

if [[ ${1:-} == --revert ]]; then
  rm -rf "$DEST" "$DB_FILE"
  rmdir "$DB_DIR" "$(dirname "$DEST")" 2>/dev/null || true   # solo si quedaron vacías
  # el perfil solo se borra si lo creó este script
  if grep -qxF "$MARK" "$PROFILE" 2>/dev/null; then
    rm -f "$PROFILE" /etc/dconf/db/gdm
  fi
  dconf update
  echo "Listo: la pantalla de inicio vuelve a la de GNOME (se ve al cerrar sesión)."
  exit 0
fi

[[ -f $CSS ]] || { echo "Falta $CSS: ejecuta cybersigil-apply como tu usuario primero"; exit 1; }

echo "==> Extensión $UUID"
mkdir -p "$DEST"
install -m 644 "$DOT/gdm/$UUID/metadata.json" "$DOT/gdm/$UUID/extension.js" "$DEST/"
install -m 644 "$CSS" "$DEST/stylesheet.css"
# logo de abajo: el de la distribución en los colores de la paleta; si no se pudo recolorear, ninguno
LOGO=""
if [[ -f $(dirname "$CSS")/gdm-logo.svg ]]; then
  install -m 644 "$(dirname "$CSS")/gdm-logo.svg" "$DEST/logo.svg"
  LOGO="$DEST/logo.svg"
else
  rm -f "$DEST/logo.svg"
fi

echo "==> Configuración de GDM"
if [[ ! -f $PROFILE ]]; then
  # el perfil de GDM, más una base de datos del sistema para activar la extensión
  { echo "$MARK"; echo "user-db:user"; echo "system-db:gdm"; grep -v '^user-db:' /usr/share/dconf/profile/gdm; } > "$PROFILE"
elif ! grep -qx "system-db:gdm" "$PROFILE"; then
  echo "  $PROFILE ya existe y no usa system-db:gdm: agrega esa línea a mano y vuelve a ejecutar" >&2
  exit 1
fi
mkdir -p "$DB_DIR"
cat > "$DB_FILE" <<EOF
$MARK
[org/gnome/shell]
enabled-extensions=['$UUID']

[org/gnome/login-screen]
logo='$LOGO'
EOF
dconf update

echo "Listo. Se ve al cerrar sesión o al reiniciar. Para deshacer: sudo bash $0 --revert"
