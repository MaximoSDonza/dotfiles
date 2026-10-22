#!/usr/bin/env bash
# Actualiza lo que no vive como enlace: ajustes de GNOME (dconf), paquetes y extensiones.
# Ejecutar antes de cada commit: ./backup.sh && git add -A && git commit
set -euo pipefail
DOT="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"

# Rutas de dconf a respaldar (el nombre de archivo usa '+' en lugar de '/')
PATHS=(
  org/gnome/shell
  org/gnome/desktop/interface
  org/gnome/desktop/wm/preferences
  org/gnome/desktop/wm/keybindings
  org/gnome/desktop/peripherals/touchpad
  org/gnome/desktop/search-providers
  org/gnome/desktop/privacy
  org/gnome/settings-daemon/plugins/media-keys
  org/gnome/software
  org/freedesktop/tracker/miner/files
)
# Claves que no se respaldan:
#   command-history                    lo escrito en Alt+F2 (privado)
#   welcome-dialog-*, check-timestamp, last-selected-power-profile, last-version-name-installed
#                                      estado local que cambia solo
#   overridden-settings, maximize, unmaximize
#                                      Tiling Shell vacía estos atajos mientras está activa y guarda
#                                      los originales en overridden-settings; restaurarlos dejaría
#                                      Super+↑/↓ sin función si Tiling Shell no está activa
EXCLUDE='^(command-history|welcome-dialog-last-shown-version|check-timestamp|last-selected-power-profile|last-version-name-installed|overridden-settings|maximize|unmaximize)='
mkdir -p "$DOT/dconf"
rm -f "$DOT"/dconf/*.ini
for p in "${PATHS[@]}"; do
  out=$(dconf dump "/$p/" | { grep -vE "$EXCLUDE" || true; })
  # sin claves (solo cabeceras [..]) no hay nada que respaldar
  grep -qvE '^(\[.*\])?$' <<<"$out" || continue
  printf '%s\n' "$out" > "$DOT/dconf/$(tr '/' '+' <<<"$p").ini"
done

mkdir -p "$DOT/packages"
pacman -Qqen > "$DOT/packages/pacman.txt"             # instalados explícitamente, repos oficiales
pacman -Qqem > "$DOT/packages/aur.txt" || true        # AUR / externos (falla si no hay ninguno)
gnome-extensions list --user > "$DOT/packages/gnome-extensions.txt"

echo "Respaldo actualizado. Revisa con: git -C $DOT status"
