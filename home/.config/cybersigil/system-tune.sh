#!/usr/bin/env bash
# Ajustes de sistema (requieren root).
#   sudo bash system-tune.sh            aplica los ajustes que corresponden a ESTE equipo
#   sudo bash system-tune.sh --revert   los deshace y deja /etc como estaba
#
# Detecta el hardware: cada ajuste se aplica solo si el equipo lo necesita (procesador, gráfica,
# chip WiFi). Antes de modificar un archivo de /etc guarda el original en /var/lib/cybersigil,
# y anota lo que crea o activa, para poder revertirlo. Se puede ejecutar varias veces.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Ejecutar con sudo"; exit 1; }

STATE=/var/lib/cybersigil
ACTIONS=$STATE/actions
MARK="# cybersigil system-tune.sh"
USER_HOME=$(getent passwd "${SUDO_USER:-root}" | cut -d: -f6)
LOCAL="$USER_HOME/.config/cybersigil/local.sh"

remember() { grep -qxF "$1" "$ACTIONS" 2>/dev/null || echo "$1" >> "$ACTIONS"; }

# write_etc <archivo>: escribe stdin en el archivo; la primera vez guarda el original (o anota
# que no existía, para borrarlo al revertir)
write_etc() {
  local f=$1
  if ! grep -qxF "created $f" "$ACTIONS" 2>/dev/null && [[ ! -e $STATE/backup$f ]]; then
    if [[ -e $f ]]; then
      mkdir -p "$(dirname "$STATE/backup$f")"
      cp -a "$f" "$STATE/backup$f"
    else
      remember "created $f"
    fi
  fi
  mkdir -p "$(dirname "$f")"
  cat > "$f"
}

# instala solo los paquetes que existen en los repositorios (los nombres cambian con el tiempo)
install_pkgs() {
  local available=()
  for p in "$@"; do pacman -Si "$p" &>/dev/null && available+=("$p"); done
  ((${#available[@]})) || return 0
  pacman -S --needed --noconfirm "${available[@]}"
}

enable_unit() {  # activa un servicio y lo anota solo si lo activó este script
  systemctl is-enabled --quiet "$1" 2>/dev/null || { systemctl enable --now "$1"; remember "enabled $1"; }
}

revert() {
  [[ -d $STATE ]] || { echo "No hay ajustes de cybersigil para revertir."; exit 0; }
  echo "==> Revirtiendo"
  if [[ -f $ACTIONS ]]; then
    while read -r kind arg; do
      case $kind in
        created) rm -f "$arg" && echo "  borrado $arg" ;;
        enabled) systemctl disable --now "$arg" 2>/dev/null && echo "  desactivado $arg" || true ;;
        display-manager)
          if [[ $arg == none ]]; then
            systemctl disable gdm 2>/dev/null || true
          elif systemctl cat "$arg.service" &>/dev/null; then
            systemctl disable gdm 2>/dev/null || true
            systemctl enable "$arg" && echo "  vuelve $arg como gestor de inicio de sesión"
          else
            # se desinstaló después: sin GDM el equipo arrancaría sin pantalla de inicio de sesión
            echo "  $arg ya no está instalado: queda GDM como gestor de inicio de sesión"
          fi ;;
      esac
    done < <(tac "$ACTIONS")
  fi
  if [[ -d $STATE/backup ]]; then
    while IFS= read -r -d '' f; do
      cp -a "$STATE/backup/$f" "/$f" && echo "  restaurado /$f"
    done < <(cd "$STATE/backup" && find . -type f -printf '%P\0')
  fi
  rm -rf "$STATE"
  sysctl --system >/dev/null
  echo "Listo. Los paquetes instalados quedan; reinicia el equipo para que todo vuelva a su estado."
  exit 0
}

[[ ${1:-} == --revert ]] && revert
mkdir -p "$STATE"

# Las versiones anteriores de este script no guardaban registro: se adoptan sus archivos para
# poder revertirlos (solo la primera vez)
if [[ ! -f $ACTIONS ]]; then
  touch "$ACTIONS"
  for f in /etc/NetworkManager/conf.d/10-wifi-powersave.conf /etc/modprobe.d/mt7921e.conf \
           /etc/modprobe.d/cfg80211.conf /etc/modules-load.d/bbr.conf /etc/sysctl.d/99-cybersigil.conf; do
    [[ -e $f ]] && remember "created $f"
  done
  zf=/etc/systemd/zram-generator.conf  # la versión vieja lo modificó: el original era el de Arch
  if grep -qs "zram-size = ram / 2" "$zf" && [[ ! -e $STATE/backup$zf ]]; then
    mkdir -p "$(dirname "$STATE/backup$zf")"
    printf '[zram0]\ncompression-algorithm = zstd\n' > "$STATE/backup$zf"
  fi
fi

# ---------------------------------------------------------------------------------------------
echo "==> Detectando el hardware"
CPU=$(awk -F': ' '/^vendor_id/{print $2; exit}' /proc/cpuinfo)
GPUS=""
for d in /sys/bus/pci/devices/*; do
  [[ $(cat "$d/class") == 0x03* ]] || continue  # 0x03xxxx = controlador de video
  case $(cat "$d/vendor") in
    0x8086) GPUS+=" intel" ;; 0x1002) GPUS+=" amd" ;; 0x10de) GPUS+=" nvidia" ;;
  esac
done
WIFI_DRIVERS=""
for n in /sys/class/net/*; do
  [[ -d $n/wireless ]] && WIFI_DRIVERS+=" $(basename "$(readlink -f "$n/device/driver")")"
done
REGDOM=$(grep -oP '^WIFI_REGDOM="?\K[A-Z]{2}(?="?\s*(#.*)?$)' "$LOCAL" 2>/dev/null || true)
echo "  procesador: ${CPU:-?} · gráfica:${GPUS:- ?} · WiFi:${WIFI_DRIVERS:- ninguno} · región WiFi: ${REGDOM:-sin definir}"

echo "==> Paquetes que usan estos ajustes"
install_pkgs pacman-contrib rtkit zram-generator
[[ -n $WIFI_DRIVERS ]] && install_pkgs wireless-regdb iw

echo "==> Procesador"
case $CPU in
  GenuineIntel)
    install_pkgs intel-ucode thermald
    echo "  thermald: control térmico de Intel (menos bajadas de frecuencia por temperatura)"
    enable_unit thermald ;;
  AuthenticAMD)
    install_pkgs amd-ucode ;;
esac

echo "==> Gráfica (aceleración de video y Vulkan)"
[[ $GPUS == *intel* ]] && install_pkgs intel-media-driver vulkan-intel
[[ $GPUS == *amd* ]] && install_pkgs vulkan-radeon  # VA-API de AMD ya viene en mesa
[[ $GPUS == *nvidia* ]] && echo "  NVIDIA detectada: elige e instala el driver a mano (nvidia-open, nvidia, nouveau)"

echo "==> WiFi"
if [[ -n $REGDOM ]]; then
  echo "  región $REGDOM (canales y potencia legales del país)"
  write_etc /etc/modprobe.d/cfg80211.conf <<EOF
$MARK
options cfg80211 ieee80211_regdom=$REGDOM
EOF
  iw reg set "$REGDOM" 2>/dev/null || true
elif [[ -n $WIFI_DRIVERS ]]; then
  echo "  región sin definir: agrega WIFI_REGDOM=\"XX\" (código de país) a $LOCAL"
fi
# Los chips MediaTek mt7921/mt7922/mt7902 (driver mt7921e) y mt7925 pierden paquetes con el
# ahorro de energía del WiFi y del bus PCIe (ASPM)
for drv in mt7921e mt7925e; do
  [[ $WIFI_DRIVERS == *$drv* ]] || continue
  echo "  MediaTek ($drv): sin ahorro de energía del WiFi ni ASPM"
  write_etc /etc/NetworkManager/conf.d/10-wifi-powersave.conf <<EOF
$MARK
[connection]
wifi.powersave = 2
EOF
  if grep -q '^disable_aspm:' <<< "$(modinfo -p "$drv" 2>/dev/null)"; then
    write_etc "/etc/modprobe.d/$drv.conf" <<EOF
$MARK
options $drv disable_aspm=1
EOF
  fi
done

BT_CONF=/etc/bluetooth/main.conf
if [[ -f $BT_CONF ]]; then
  echo "==> Bluetooth: arranca apagado (se prende desde el menú de arriba cuando hace falta)"
  # BlueZ enciende solo los adaptadores que encuentra (AutoEnable=true por defecto). Si al arrancar
  # el Bluetooth no quedó bloqueado (en notebooks ASUS el firmware guarda su propio estado aparte del
  # que restaura systemd), arrancaba encendido aunque se hubiera apagado antes de cerrar.
  # GNOME lo sigue prendiendo bien: su botón desbloquea el adaptador y lo enciende
  if ! grep -qE '^\s*AutoEnable\s*=\s*false\s*$' "$BT_CONF"; then
    # (sin comentario en la misma línea: BlueZ lo tomaría como parte del valor)
    if grep -qE '^\s*#?\s*AutoEnable\s*=' "$BT_CONF"; then
      nuevo=$(sed -E "0,/^\s*#?\s*AutoEnable\s*=.*/s||$MARK\nAutoEnable=false|" "$BT_CONF")
    elif grep -q '^\[Policy\]' "$BT_CONF"; then
      nuevo=$(sed "/^\[Policy\]/a $MARK\nAutoEnable=false" "$BT_CONF")
    else
      nuevo=$(cat "$BT_CONF"; printf '\n[Policy]\n%s\nAutoEnable=false\n' "$MARK")
    fi
    # se arma aparte: write_etc vacía el archivo antes de escribir
    printf '%s\n' "$nuevo" | write_etc "$BT_CONF"
  fi
fi

echo "==> Red: TCP BBR + fq (mejor rendimiento en enlaces con pérdida, como el WiFi)"
echo "==> Memoria: parámetros recomendados para swap en zram"
write_etc /etc/sysctl.d/99-cybersigil.conf <<EOF
$MARK
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
# zram es mucho más rápido que el disco: preferir comprimir en RAM antes que descartar caché
vm.swappiness = 180
vm.page-cluster = 0
vm.watermark_boost_factor = 0
vm.watermark_scale_factor = 125
EOF
write_etc /etc/modules-load.d/bbr.conf <<EOF
$MARK
tcp_bbr
EOF
modprobe tcp_bbr
sysctl --system >/dev/null

echo "==> zram: swap comprimido en RAM, del tamaño de la mitad de la memoria"
write_etc /etc/systemd/zram-generator.conf <<EOF
$MARK
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
swap-priority = 100
EOF

echo "==> Caché de pacman: conservar 2 versiones por paquete + limpieza semanal"
paccache -rk2 && paccache -ruk0
enable_unit paccache.timer

echo "==> GDM como gestor de inicio de sesión (necesario para bloquear con Super+L)"
install_pkgs gdm
current_dm=$(basename "$(readlink -f /etc/systemd/system/display-manager.service 2>/dev/null)" .service)
if [[ $current_dm != gdm ]]; then
  if [[ -n $current_dm && $current_dm != display-manager ]]; then
    systemctl disable "$current_dm"
    remember "display-manager $current_dm"
  else
    remember "display-manager none"
  fi
  systemctl enable gdm
fi

echo
echo "Listo. REINICIA el equipo. Para deshacer: sudo bash $0 --revert"
