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

# Paquetes. base.txt y aur-base.txt se mantienen a mano: lo que necesita el tema.
# apps.txt y aur-apps.txt se generan: lo instalado a mano que no está en base, ni en el grupo
# "gnome", ni en exclude.txt (sistema, hardware, restos de KDE y Hyprland)
mkdir -p "$DOT/packages"
skip=$(mktemp)
{ cat "$DOT/packages/base.txt" "$DOT/packages/aur-base.txt"; pacman -Sgq gnome 2>/dev/null || true; } > "$skip"
apps() { grep -vxFf "$skip" | grep -vEf <(grep -vE '^(#|$)' "$DOT/packages/exclude.txt") || true; }
pacman -Qqen | apps > "$DOT/packages/apps.txt"        # repos oficiales
pacman -Qqem | apps > "$DOT/packages/aur-apps.txt"    # AUR
rm -f "$skip" "$DOT/packages/pacman.txt" "$DOT/packages/aur.txt"  # listas viejas, sin clasificar
gnome-extensions list --user > "$DOT/packages/gnome-extensions.txt"

echo "Respaldo actualizado. Revisa con: git -C $DOT status"
