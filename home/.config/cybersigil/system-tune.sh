#!/usr/bin/env bash
# Ajustes de sistema (requieren root). Uso: sudo bash ~/.config/cybersigil/system-tune.sh
# Idempotente: se puede volver a ejecutar. Para revertir, ver el bloque REVERTIR al final.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Ejecutar con sudo"; exit 1; }

echo "==> Paquetes (tema + WiFi + mantenimiento)"
pacman -S --needed --noconfirm \
  adw-gtk-theme papirus-icon-theme ttf-jetbrains-mono-nerd starship fastfetch \
  wireless-regdb iw pacman-contrib rtkit xdg-terminal-exec python-nautilus

echo "==> WiFi: dominio regulatorio Argentina (canales y potencia correctos)"
cat > /etc/conf.d/wireless-regdom <<'EOF'
WIRELESS_REGDOM="AR"
EOF
cat > /etc/modprobe.d/cfg80211.conf <<'EOF'
options cfg80211 ieee80211_regdom=AR
EOF
iw reg set AR || true

echo "==> WiFi: sin ahorro de energía en todas las redes (evita pérdida de paquetes y picos de latencia)"
mkdir -p /etc/NetworkManager/conf.d
cat > /etc/NetworkManager/conf.d/10-wifi-powersave.conf <<'EOF'
[connection]
wifi.powersave = 2
EOF

echo "==> WiFi: MT7902 (mt7921e) sin ASPM PCIe (causa típica de cortes/latencia en este chip)"
cat > /etc/modprobe.d/mt7921e.conf <<'EOF'
options mt7921e disable_aspm=1
EOF

echo "==> Red: TCP BBR + fq (mejor rendimiento en enlaces WiFi con pérdida)"
echo "==> Memoria: ajustes recomendados para swap en zram"
cat > /etc/sysctl.d/99-cybersigil.conf <<'EOF'
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
# zram es mucho más rápido que el disco: preferir comprimir en RAM antes que descartar caché
vm.swappiness = 180
vm.page-cluster = 0
vm.watermark_boost_factor = 0
vm.watermark_scale_factor = 125
EOF
echo tcp_bbr > /etc/modules-load.d/bbr.conf
modprobe tcp_bbr
sysctl --system >/dev/null

echo "==> zram: 4G -> mitad de la RAM (8G)"
cat > /etc/systemd/zram-generator.conf <<'EOF'
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
swap-priority = 100
EOF

echo "==> Caché de pacman: conservar 2 versiones por paquete + limpieza semanal"
paccache -rk2
paccache -ruk0
systemctl enable --now paccache.timer

echo "==> thermald: control térmico Intel (menos throttling, temperaturas estables)"
pacman -S --needed --noconfirm thermald
systemctl enable --now thermald

echo "==> Pantalla de bloqueo (Super+L): GDM en lugar de SDDM"
systemctl disable sddm
systemctl enable gdm

echo
echo "Listo. REINICIA el equipo. Luego, como tu usuario:"
echo "  yay -S bibata-cursor-theme-bin papirus-folders && cybersigil-apply"

# REVERTIR:
#   rm /etc/NetworkManager/conf.d/10-wifi-powersave.conf /etc/modprobe.d/mt7921e.conf \
#      /etc/modprobe.d/cfg80211.conf /etc/modules-load.d/bbr.conf \
#      /etc/sysctl.d/99-cybersigil.conf /etc/conf.d/wireless-regdom
#   printf '[zram0]\ncompression-algorithm = zstd\n' > /etc/systemd/zram-generator.conf
#   systemctl disable gdm && systemctl enable sddm
#   systemctl disable --now thermald
