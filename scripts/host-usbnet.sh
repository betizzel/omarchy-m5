#!/bin/bash
# host-usbnet.sh - ThinkPad side of the M5's USB network (CDC EEM gadget,
# see scripts/usb-gadget-net.sh). Run once per ThinkPad boot:
#   sudo ./host-usbnet.sh
#   ssh bay@10.55.<n>.2               # n = the M5's UDC index (port), 0 here
#
# Installs, persistently:
#   - NetworkManager: leave cdc_eem interfaces alone. Otherwise NM tries DHCP,
#     fails after 45 s and strips every address, link-local included.
#   - udev: give each M5 gadget netdev 10.55.<n>.1/24 whenever it appears,
#     so an M5 reboot needs no re-run.
#   - ufw (Omarchy enables it): route-allow 10.55.0.0/16. Its routed policy
#     is deny but ICMP is let through, so ping works while TCP/UDP (DNS,
#     pacman) silently do not - unless docker's FORWARD jump got there first.
# Per ThinkPad boot (not persistent): forwarding, NAT on whatever interface
# the traffic leaves by (Wi-Fi, Ethernet, or a VPN such as proton0, whose
# policy routing applies to forwarded packets too), and docker's FORWARD.
set -eu

cat > /etc/NetworkManager/conf.d/90-m5-gadget.conf <<'CONF'
# omarchy-m5: the M5's USB gadget (scripts/host-usbnet.sh configures it)
[keyfile]
unmanaged-devices=driver:cdc_eem
CONF
command -v nmcli >/dev/null && nmcli general reload conf 2>/dev/null || true

# Match by USB device (1d6b:0104, serial m5pro-<n>), not MAC: EEM carries none.
rules=/etc/udev/rules.d/81-m5-gadget.rules
: > $rules
for n in 0 1 2; do
    echo "ACTION==\"add\", SUBSYSTEM==\"net\", ATTRS{idVendor}==\"1d6b\", ATTRS{idProduct}==\"0104\", ATTRS{serial}==\"m5pro-$n\", RUN+=\"/usr/bin/ip addr replace 10.55.$n.1/24 dev \$name\", RUN+=\"/usr/bin/ip link set \$name up\"" >> $rules
done
udevadm control --reload

# Interfaces that are already up (the udev rule only fires on the next add).
found=0
for d in /sys/class/net/*; do
    u=$(readlink -f "$d/device/.." 2>/dev/null) || continue   # lo, bridges: no device
    [ "$(cat "$u/idVendor" 2>/dev/null):$(cat "$u/idProduct" 2>/dev/null)" = 1d6b:0104 ] || continue
    s=$(cat "$u/serial" 2>/dev/null)
    case "$s" in m5pro-[0-9]) n=${s#m5pro-} ;; *) continue ;; esac
    IF=$(basename "$d"); found=1
    echo "port udc$n -> $IF"
    command -v nmcli >/dev/null && nmcli dev set "$IF" managed no || true
    ip addr replace 10.55.$n.1/24 dev "$IF"
    ip link set "$IF" up
done
[ $found = 1 ] || echo "no M5 gadget netdev yet; udev will configure it when it appears"

sysctl -qw net.ipv4.ip_forward=1
# Recreated on every run, so an older rule (it used to be tied to one egress
# interface) never lingers.
nft delete table ip m5nat 2>/dev/null || true
nft add table ip m5nat
nft 'add chain ip m5nat post { type nat hook postrouting priority 100; }'
nft add rule ip m5nat post ip saddr 10.55.0.0/16 ip daddr != 10.55.0.0/16 masquerade
# This ThinkPad runs docker (docker0/br-*): its FORWARD policy is DROP and an
# accept in another base chain cannot override it, so go through DOCKER-USER.
if iptables -nL DOCKER-USER >/dev/null 2>&1; then
    iptables -C DOCKER-USER -s 10.55.0.0/16 -j ACCEPT 2>/dev/null ||
        iptables -I DOCKER-USER -s 10.55.0.0/16 -j ACCEPT
    iptables -C DOCKER-USER -d 10.55.0.0/16 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>/dev/null ||
        iptables -I DOCKER-USER -d 10.55.0.0/16 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
fi
if command -v ufw >/dev/null && ufw status | grep -q '^Status: active'; then
    ufw route allow from 10.55.0.0/16 >/dev/null
fi
echo "done. ssh bay@10.55.<n>.2 (n = the M5 port: 0 left-back, 1 left-front, 2 right)"
