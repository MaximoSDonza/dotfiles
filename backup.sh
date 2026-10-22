#!/usr/bin/env bash
# Actualiza lo que no vive como enlace: ajustes de GNOME (dconf), paquetes y extensiones.
# Ejecutar antes de cada commit: ./backup.sh && git add -A && git commit
set -euo pipefail
DOT="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"

# Ajustes de GNOME en dos grupos: dconf/tema.ini (siempre) y dconf/personal.ini (con --personal).
# Qué va en cada uno, y qué no se guarda nunca, está en lib/dconf_sync.py
rm -f "$DOT"/dconf/*.ini
python3 -I "$DOT/lib/dconf_sync.py" backup "$DOT"

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
