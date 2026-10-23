#!/usr/bin/env bash
# Arranque con la paleta: menú de GRUB ("Bootmenu"), animación de Plymouth y el logo que muestra
# cada imagen unificada del kernel (UKI) al arrancar. Requiere root.
#   sudo bash boot-theme.sh            instala o actualiza (después de cambiar la paleta: cybersigil-apply y esto)
#   sudo bash boot-theme.sh --revert   vuelve al arranque de antes
#
# Los temas los arma cybersigil-apply (como tu usuario) en ~/.config/cybersigil/generated/boot.
# La primera vez guarda /etc/default/grub, grub.cfg, el tema de Plymouth y los presets de mkinitcpio
# en /var/lib/cybersigil-boot.
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
PRESETS_DIR=/etc/mkinitcpio.d
SPLASH=/usr/local/share/cybersigil/uki-splash.bmp

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
# presets de mkinitcpio que arman imágenes unificadas (UKI) con logo (--splash o *_splash=)
presets_con_logo() {
  local f
  for f in "$PRESETS_DIR"/*.preset; do
    [[ -f $f ]] && grep -qE '^\s*[A-Za-z_]+_uki=' "$f" && grep -qE -- '--splash|^\s*[A-Za-z_]+_splash=' "$f" && echo "$f"
  done
  return 0
}
# Cómo arranca Linux un grub.cfg: "linux" (kernel + initramfs; las opciones del kernel salen de
# /etc/default/grub) o "uki" (imágenes unificadas con el comando uki; las opciones van dentro de cada
# imagen, desde /etc/kernel/cmdline). Vacío si no se reconoce
modo_arranque() {
  if grep -qE '^\s*linux\s' "$1"; then echo linux
  elif grep -qE '^\s*uki(\s|$)' "$1"; then echo uki
  fi
}
# arma grub.cfg aparte y lo pone en su lugar solo si es válido y tiene todo lo pedido (una expresión
# regular por argumento). Si no, lo deja en $STATE/grub.cfg.rechazado para revisarlo
regenerar_grub() {
  local nuevo="$GRUB_CFG.cybersigil-nuevo" requisito
  rm -f "$STATE/grub.cfg.rechazado"
  if ! grub-mkconfig -o "$nuevo"; then
    echo "  falló grub-mkconfig" >&2
  elif ! grub-script-check "$nuevo"; then
    echo "  el grub.cfg nuevo tiene errores de sintaxis" >&2
  else
    for requisito in "$@"; do
      if ! grep -qE "$requisito" "$nuevo"; then
        echo "  al grub.cfg nuevo le falta: $requisito" >&2
        mv "$nuevo" "$STATE/grub.cfg.rechazado"
        return 1
      fi
    done
    mv "$nuevo" "$GRUB_CFG"
    return 0
  fi
  [[ -f $nuevo ]] && mv "$nuevo" "$STATE/grub.cfg.rechazado"
  return 1
}

if [[ ${1:-} == --revert ]]; then
  [[ -d $STATE ]] || { echo "No hay un arranque de Cybersigil para revertir."; exit 0; }
  rehacer=0
  if [[ -d $STATE/presets ]]; then
    echo "==> Logo de las UKI: vuelve el de antes"
    cp -a "$STATE/presets/." "$PRESETS_DIR/"
    rm -f "$SPLASH"
    rmdir "$(dirname "$SPLASH")" 2>/dev/null || true
    rehacer=1
  fi
  if [[ -f $STATE/plymouth-tema ]]; then
    prev=$(cat "$STATE/plymouth-tema")
    echo "==> Plymouth: vuelve el tema '$prev'"
    plymouth-set-default-theme "$prev"
    rm -rf "$PLY_DIR"
    rehacer=1
  fi
  if (( rehacer )); then
    echo "==> Rehaciendo las imágenes del kernel (1 o 2 minutos)"
    mkinitcpio -P
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
rehacer=0   # el tema de Plymouth y el logo viajan dentro de cada imagen del kernel: se rehacen si cambian

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
  if (( cambio )); then rehacer=1; else echo "  sin cambios"; fi
  PLY_OK=1
else
  echo "  Plymouth no está instalado o no está en el initramfs: se omite. Para usarlo:"
  echo "    sudo pacman -S plymouth, agrega 'plymouth' a HOOKS en /etc/mkinitcpio.conf (después de udev o systemd)"
  echo "    y vuelve a ejecutar esto."
fi

echo "==> Logo al arrancar cada imagen del kernel (UKI)"
# Reemplaza el de la distribución (en Arch, el azul) por el mismo recoloreado de GDM. Una imagen
# rota no impide arrancar: systemd-stub la ignora y sigue
mapfile -t con_logo < <(presets_con_logo)
if [[ ! -f $SRC/uki-splash.bmp ]]; then
  echo "  No hay logo generado (la distribución no tiene un logo SVG): se omite."
elif (( ! ${#con_logo[@]} )); then
  echo "  Los kernels no arrancan como imágenes unificadas con logo: se omite."
elif [[ $(head -c2 "$SRC/uki-splash.bmp") != BM ]]; then
  echo "  $SRC/uki-splash.bmp no es un BMP: se omite." >&2
else
  logo_cambio=0
  if ! cmp -s "$SRC/uki-splash.bmp" "$SPLASH"; then
    install -Dm644 "$SRC/uki-splash.bmp" "$SPLASH"
    logo_cambio=1
  fi
  mkdir -p "$STATE/presets"
  for f in "${con_logo[@]}"; do
    [[ -f $STATE/presets/$(basename "$f") ]] || cp -a "$f" "$STATE/presets/"
    nuevo=$(sed -E -e "s#(--splash[= ]+)[^\" ]+#\1$SPLASH#g" -e "s#^(\s*[A-Za-z_]+_splash=).*#\1\"$SPLASH\"#" "$f")
    if [[ $nuevo != "$(cat "$f")" ]]; then
      printf '%s\n' "$nuevo" > "$f"
      echo "  $(basename "$f"): logo de Cybersigil"
      logo_cambio=1
    fi
  done
  if (( logo_cambio )); then rehacer=1; else echo "  sin cambios"; fi
fi

if (( rehacer )); then
  echo "==> Rehaciendo las imágenes del kernel (1 o 2 minutos)"
  mkinitcpio -P
fi

echo "==> GRUB"
if [[ ! -d $SRC/grub ]]; then
  echo "  No hay tema de GRUB generado (falta grub-mkfont): se omite."
elif ! grub_usable; then
  echo "  Este sistema no arranca con GRUB (o no está en $GRUB_CFG): se omite."
elif modo=$(modo_arranque "$GRUB_CFG"); [[ -z $modo ]]; then
  echo "  No reconozco cómo arranca Linux en $GRUB_CFG (no tiene líneas linux ni uki): se omite."
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

  if [[ $modo == linux ]]; then
    # Opciones con las que arrancó este sistema que /etc/default/grub no tiene (las que alguien puso
    # a mano en grub.cfg, por ejemplo): sin esto, grub-mkconfig las perdería
    L=$(get_var GRUB_CMDLINE_LINUX)
    D=$(get_var GRUB_CMDLINE_LINUX_DEFAULT)
    read -ra opciones < /proc/cmdline
    (( PLY_OK )) && opciones+=(splash)
    for o in "${opciones[@]}"; do
      case $o in BOOT_IMAGE=*|root=*|initrd=*|ro|rw) continue ;; esac
      [[ " $L $D " == *" $o "* ]] && continue
      case $o in
        *\"*|*\'*) echo "  aviso: no se copia la opción $o (lleva comillas); revísala en $GRUB_DEFAULT" >&2; continue ;;
        quiet|splash|loglevel=*) D="${D:+$D }$o" ;;
        *) L="${L:+$L }$o" ;;
      esac
      echo "  se conserva la opción del kernel: $o"
    done
    set_var GRUB_CMDLINE_LINUX "$L"
    set_var GRUB_CMDLINE_LINUX_DEFAULT "$D"
  else
    # UKI: GRUB no le pasa opciones, cada imagen trae las suyas (/etc/kernel/cmdline al armarla)
    echo "  arranque con imágenes unificadas (UKI): las opciones del kernel quedan en /etc/kernel/cmdline"
    opciones_uki=$(cat /etc/kernel/cmdline /etc/cmdline.d/*.conf 2>/dev/null || true)   # cmdline.d puede no existir
    if (( PLY_OK )) && ! grep -qw splash <<< "$opciones_uki"; then
      echo "  aviso: falta 'splash' en /etc/kernel/cmdline, sin eso no se ve Plymouth (agrégalo y: sudo mkinitcpio -P)" >&2
    fi
  fi

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

  # el grub.cfg nuevo tiene que arrancar Linux igual que el actual, y con el tema
  requisitos=("theme=.*cybersigil/theme.txt")
  if [[ $modo == linux ]]; then
    requisitos+=('^\s*linux\s')
    (( PLY_OK )) && requisitos+=('^\s*linux\s.*\bsplash\b')
  else
    requisitos+=('^\s*uki(\s|$)')
  fi
  if regenerar_grub "${requisitos[@]}"; then
    rm -f "$antes"
    [[ $modo == linux ]] &&
      echo "  kernel: $(grep -m1 -oE '^\s*linux\s.*' "$GRUB_CFG" | sed -E 's/^\s*//; s/root=[^ ]+/root=…/')"
  else
    cp "$antes" "$GRUB_DEFAULT"
    rm -f "$antes"
    if (( tema_nuevo )); then
      rm -rf "$GRUB_THEME_DIR"
      rmdir "$(dirname "$GRUB_THEME_DIR")" 2>/dev/null || true
    fi
    echo "  No se pudo armar un grub.cfg válido: se dejó todo como estaba." >&2
    [[ -f $STATE/grub.cfg.rechazado ]] && echo "  (el que se descartó quedó en $STATE/grub.cfg.rechazado)" >&2
    exit 1
  fi
fi

echo "Listo. Se ve al reiniciar. Para deshacer: sudo bash $0 --revert"
