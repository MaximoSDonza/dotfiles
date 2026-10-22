#!/usr/bin/env bash
# Arranque con la paleta: menú de GRUB ("Bootmenu") y animación de Plymouth. Requiere root.
#   sudo bash boot-theme.sh            instala o actualiza (después de cambiar la paleta: cybersigil-apply y esto)
#   sudo bash boot-theme.sh --revert   vuelve al arranque de antes
#
# Los temas los arma cybersigil-apply (como tu usuario) en ~/.config/cybersigil/generated/boot.
# La primera vez guarda /etc/default/grub, grub.cfg y el tema de Plymouth en /var/lib/cybersigil-boot.
# grub.cfg se arma aparte y solo reemplaza al actual si pasa las comprobaciones.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Ejecutar con sudo"; exit 1; }

USER_HOME=$(getent passwd "${SUDO_USER:-root}" | cut -d: -f6)
SRC="$USER_HOME/.config/cybersigil/generated/boot"
STATE=/var/lib/cybersigil-boot        # aparte de /var/lib/cybersigil (system-tune.sh --revert lo borra entero)
GRUB_DEFAULT=/etc/default/grub
GRUB_CFG=/boot/grub/grub.cfg
GRUB_THEME_DIR=/boot/grub/themes/cybersigil
PLY_DIR=/usr/share/plymouth/themes/cybersigil
LOADER_INFO=/sys/firmware/efi/efivars/LoaderInfo-4a67b082-0a4c-41cf-b6c7-440b29bb8c4f

get_var() { ( set +u; . "$GRUB_DEFAULT"; printf '%s' "${!1:-}" ); }
set_var() {  # set_var NOMBRE VALOR: deja NOMBRE="VALOR" en /etc/default/grub (reemplaza o descomenta)
  local linea esc
  linea="$1=\"$2\""
  esc=$(printf '%s' "$linea" | sed 's/[&|\\]/\\&/g')
  if grep -qE "^$1=" "$GRUB_DEFAULT"; then
    sed -i -E "s|^$1=.*|$esc|" "$GRUB_DEFAULT"
  elif grep -qE "^#\s*$1=" "$GRUB_DEFAULT"; then
    sed -i -E "0,/^#\s*$1=.*/s||$esc|" "$GRUB_DEFAULT"
  else
    echo "$linea" >> "$GRUB_DEFAULT"
  fi
}
grub_usable() {
  [[ -f $GRUB_DEFAULT && -f $GRUB_CFG ]] && command -v grub-mkconfig >/dev/null || return 1
  # en UEFI, el gestor que arrancó este sistema lo anota en LoaderInfo (GRUB 2.12+, systemd-boot…)
  local loader
  loader=$(tail -c +5 "$LOADER_INFO" 2>/dev/null | tr -d '\0') || true
  [[ -z $loader || $loader == GRUB* ]]
}
plymouth_usable() {
  command -v plymouth-set-default-theme >/dev/null || return 1
  local hooks   # (mkinitcpio.conf.d puede no existir: que eso no cuente como error)
  hooks=$(grep -hsE '^\s*HOOKS=' /etc/mkinitcpio.conf /etc/mkinitcpio.conf.d/*.conf || true)
  grep -qwE 'plymouth|sd-plymouth' <<< "$hooks"
}
# arma grub.cfg aparte y lo pone en su lugar solo si es válido; si no, deja todo como estaba
regenerar_grub() {
  local nuevo="$GRUB_CFG.cybersigil-nuevo" requisito
  if grub-mkconfig -o "$nuevo" && grub-script-check "$nuevo" && grep -qE '^\s*linux\s' "$nuevo"; then
    for requisito in "$@"; do
      grep -qE "$requisito" "$nuevo" || { echo "  falta '$requisito' en el grub.cfg nuevo" >&2; rm -f "$nuevo"; return 1; }
    done
    mv "$nuevo" "$GRUB_CFG"
  else
    rm -f "$nuevo"
    return 1
  fi
}

if [[ ${1:-} == --revert ]]; then
  [[ -d $STATE ]] || { echo "No hay un arranque de Cybersigil para revertir."; exit 0; }
  if [[ -f $STATE/plymouth-tema ]]; then
    prev=$(cat "$STATE/plymouth-tema")
    echo "==> Plymouth: vuelve el tema '$prev' (rehace el initramfs)"
    plymouth-set-default-theme -R "$prev"
    rm -rf "$PLY_DIR"
  fi
  if [[ -f $STATE/grub.default ]]; then
    echo "==> GRUB: vuelve la configuración anterior"
    # las opciones del kernel quedan como están ahora, para que un grub-mkconfig futuro no las pierda
    L=$(get_var GRUB_CMDLINE_LINUX)
    D=$(get_var GRUB_CMDLINE_LINUX_DEFAULT)
    cp "$STATE/grub.default" "$GRUB_DEFAULT"
    set_var GRUB_CMDLINE_LINUX "$L"
    set_var GRUB_CMDLINE_LINUX_DEFAULT "$D"
    cp "$STATE/grub.cfg" "$GRUB_CFG"
    rm -rf "$GRUB_THEME_DIR"
    rmdir "$(dirname "$GRUB_THEME_DIR")" 2>/dev/null || true
  fi
  rm -rf "$STATE"
  echo "Listo: se ve al reiniciar."
  exit 0
fi

[[ -d $SRC/plymouth ]] || { echo "Falta $SRC: ejecuta cybersigil-apply como tu usuario primero"; exit 1; }
mkdir -p "$STATE"
PLY_OK=0

echo "==> Plymouth"
if plymouth_usable; then
  actual=$(plymouth-set-default-theme)
  [[ -f $STATE/plymouth-tema ]] || echo "$actual" > "$STATE/plymouth-tema"
  cambio=0
  if ! diff -rq "$SRC/plymouth" "$PLY_DIR" >/dev/null 2>&1; then
    rm -rf "$PLY_DIR"
    cp -r "$SRC/plymouth" "$PLY_DIR"
    chmod -R u=rwX,go=rX "$PLY_DIR"
    cambio=1
  fi
  if [[ $actual != cybersigil ]]; then
    plymouth-set-default-theme cybersigil
    cambio=1
  fi
  # el tema viaja dentro del initramfs: hay que rehacerlo si cambió (los kernels instalados, 1 o 2 minutos)
  if (( cambio )); then mkinitcpio -P; else echo "  sin cambios"; fi
  PLY_OK=1
else
  echo "  Plymouth no está instalado o no está en el initramfs: se omite. Para usarlo:"
  echo "    sudo pacman -S plymouth, agrega 'plymouth' a HOOKS en /etc/mkinitcpio.conf (después de udev o systemd)"
  echo "    y vuelve a ejecutar esto."
fi

echo "==> GRUB"
if [[ ! -d $SRC/grub ]]; then
  echo "  No hay tema de GRUB generado (falta grub-mkfont): se omite."
elif ! grub_usable; then
  echo "  Este sistema no arranca con GRUB (o no está en $GRUB_CFG): se omite."
else
  [[ -f $STATE/grub.default ]] || cp "$GRUB_DEFAULT" "$STATE/grub.default"
  [[ -f $STATE/grub.cfg ]] || cp "$GRUB_CFG" "$STATE/grub.cfg"
  antes=$(mktemp)
  cp "$GRUB_DEFAULT" "$antes"
  tema_nuevo=0
  [[ -d $GRUB_THEME_DIR ]] || tema_nuevo=1

  if ! diff -rq "$SRC/grub" "$GRUB_THEME_DIR" >/dev/null 2>&1; then
    rm -rf "$GRUB_THEME_DIR"
    mkdir -p "$(dirname "$GRUB_THEME_DIR")"
    cp -r "$SRC/grub" "$GRUB_THEME_DIR"
  fi

  # Opciones con las que arrancó este sistema que /etc/default/grub no tiene (por ejemplo, las que
  # puso el instalador directo en grub.cfg): sin esto, grub-mkconfig las perdería
  L=$(get_var GRUB_CMDLINE_LINUX)
  D=$(get_var GRUB_CMDLINE_LINUX_DEFAULT)
  read -ra opciones < /proc/cmdline
  (( PLY_OK )) && opciones+=(splash)
  for o in "${opciones[@]}"; do
    case $o in BOOT_IMAGE=*|root=*|initrd=*|ro|rw) continue ;; esac
    [[ " $L $D " == *" $o "* ]] && continue
    case $o in quiet|splash|loglevel=*) D="${D:+$D }$o" ;; *) L="${L:+$L }$o" ;; esac
    echo "  se conserva la opción del kernel: $o"
  done
  set_var GRUB_CMDLINE_LINUX "$L"
  set_var GRUB_CMDLINE_LINUX_DEFAULT "$D"

  # resolución nativa de la pantalla (la de la notebook si hay), con auto como respaldo
  nativa=""
  for c in /sys/class/drm/card*-*; do
    [[ $(cat "$c/status" 2>/dev/null) == connected ]] || continue
    nativa=$(head -1 "$c/modes" 2>/dev/null)
    [[ $c == *eDP* ]] && break
  done
  [[ $nativa =~ ^[0-9]+x[0-9]+$ ]] && set_var GRUB_GFXMODE "$nativa,auto"
  set_var GRUB_THEME "$GRUB_THEME_DIR/theme.txt"
  if [[ $(get_var GRUB_TERMINAL_OUTPUT) == console ]]; then
    echo "  aviso: GRUB_TERMINAL_OUTPUT=console en $GRUB_DEFAULT no deja dibujar el tema; coméntalo" >&2
  fi

  requisitos=("theme=.*cybersigil/theme.txt")
  (( PLY_OK )) && requisitos+=("^\s*linux\s.*\bsplash\b")
  if regenerar_grub "${requisitos[@]}"; then
    rm -f "$antes"
    echo "  kernel: $(grep -m1 -oE '^\s*linux\s.*' "$GRUB_CFG" | sed -E 's/^\s*//; s/root=[^ ]+/root=…/')"
  else
    cp "$antes" "$GRUB_DEFAULT"
    rm -f "$antes"
    if (( tema_nuevo )); then
      rm -rf "$GRUB_THEME_DIR"
      rmdir "$(dirname "$GRUB_THEME_DIR")" 2>/dev/null || true
    fi
    echo "  No se pudo armar un grub.cfg válido: se dejó todo como estaba." >&2
    exit 1
  fi
fi

echo "Listo. Se ve al reiniciar. Para deshacer: sudo bash $0 --revert"
