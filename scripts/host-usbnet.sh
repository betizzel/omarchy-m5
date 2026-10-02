#!/bin/bash
# host-usbnet.sh - ThinkPad side. Run as root after the M5 has booted Linux
# (m1n1's /dev/m1n1 disappears and a new "MBP14 M5 Pro" gadget shows up).
#   sudo ./host-usbnet.sh            # configure + NAT
#   ssh root@10.55.<n>.2             # once dropbear/sshd runs on the M5
set -eu
WAN=${WAN:-$(ip -4 route show default | awk '{print $5; exit}')}
found=0
for n in 0 1 2; do
    for d in /sys/class/net/*; do
        [ "$(cat $d/address 2>/dev/null)" = "02:4d:35:00:0$n:01" ] || continue
        IF=$(basename "$d"); found=1
        echo "port udc$n -> $IF (WAN=$WAN)"
        command -v nmcli >/dev/null && nmcli dev set "$IF" managed no || true
        ip addr flush dev "$IF"
        ip addr add 10.55.$n.1/24 dev "$IF"
        ip link set "$IF" up
    done
done
[ $found = 1 ] || { echo "no 02:4d:35:00:0n:01 interface; lsusb | grep 1d6b:0104"; exit 1; }

sysctl -qw net.ipv4.ip_forward=1
nft list table ip m5nat >/dev/null 2>&1 || {
    nft add table ip m5nat
    nft 'add chain ip m5nat post { type nat hook postrouting priority 100; }'
    nft add rule ip m5nat post ip saddr 10.55.0.0/16 oifname "$WAN" masquerade
}
# This ThinkPad runs docker (docker0/br-*): its FORWARD policy is DROP and an
# accept in another base chain cannot override it, so go through DOCKER-USER.
if iptables -nL DOCKER-USER >/dev/null 2>&1; then
    iptables -C DOCKER-USER -s 10.55.0.0/16 -j ACCEPT 2>/dev/null ||
        iptables -I DOCKER-USER -s 10.55.0.0/16 -j ACCEPT
    iptables -C DOCKER-USER -d 10.55.0.0/16 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>/dev/null ||
        iptables -I DOCKER-USER -d 10.55.0.0/16 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
fi
# Keep ModemManager away from the gadget's ttyACM (it would send AT commands
# into the M5's root shell).
cat > /etc/udev/rules.d/81-m5-gadget.rules <<'RULE'
ATTRS{idVendor}=="1d6b", ATTRS{idProduct}=="0104", ENV{ID_MM_DEVICE_IGNORE}="1"
RULE
udevadm control --reload
echo "done. serial shell: ls /dev/ttyACM*  (picocom /dev/ttyACM0); ssh: root@10.55.<n>.2"
