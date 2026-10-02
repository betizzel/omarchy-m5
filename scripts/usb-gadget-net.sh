#!/bin/sh
# usb-gadget-net - initramfs side. Turn every DWC3 UDC into a composite
# gadget: CDC-NCM Ethernet + CDC-ACM serial (root shell on ttyGS<n>).
#
# Nothing here touches PHY / PMGR / DART state beyond what the dwc3 driver
# does: m1n1 (usb_phy_bringup) left the eUSB2 PHY running and the PIPE mux on
# the dummy PHY, and the cable is still plugged into the ThinkPad. That is
# exactly the state m1n1's own gadget runs in.
#
# Port numbering follows the DT: dwc3_0 = ADT usb-drd0 (port-number 1,
# hpm0 left-back), dwc3_1 = drd1 (port 2, left-front), dwc3_2 = drd2 (port 3,
# right). Subnet per UDC index: 10.55.<n>.0/24, host .1, M5 .2.
BB=/bin/busybox
CFG=/sys/kernel/config
G=$CFG/usb_gadget

$BB mountpoint -q $CFG || $BB mount -t configfs none $CFG || exit 1

i=0
while [ ! -d /sys/class/udc ] || [ -z "$($BB ls /sys/class/udc 2>/dev/null)" ]; do
    i=$((i + 1)); [ $i -gt 100 ] && { echo "usb-gadget-net: no UDC (dwc3 probe failed?)"; exit 1; }
    $BB sleep 0.1
done

n=0
for udc in $($BB ls /sys/class/udc); do
    g=$G/m5_$n
    $BB mkdir -p $g
    echo 0x1d6b > $g/idVendor        # Linux Foundation
    echo 0x0104 > $g/idProduct       # Multifunction Composite Gadget
    echo 0x0200 > $g/bcdUSB
    $BB mkdir -p $g/strings/0x409
    echo "omarchy-m5"      > $g/strings/0x409/manufacturer
    echo "MBP14 M5 Pro j714s udc$n" > $g/strings/0x409/product
    echo "m5pro-$n"        > $g/strings/0x409/serialnumber
    $BB mkdir -p $g/configs/c.1/strings/0x409
    echo "ncm+acm"         > $g/configs/c.1/strings/0x409/configuration
    echo 250               > $g/configs/c.1/MaxPower

    $BB mkdir -p $g/functions/ncm.usb0
    echo "02:4d:35:00:0$n:01" > $g/functions/ncm.usb0/host_addr
    echo "02:4d:35:00:0$n:02" > $g/functions/ncm.usb0/dev_addr
    $BB mkdir -p $g/functions/acm.GS0

    $BB ln -s $g/functions/ncm.usb0 $g/configs/c.1/ncm.usb0
    $BB ln -s $g/functions/acm.GS0  $g/configs/c.1/acm.GS0

    if echo "$udc" > $g/UDC; then
        IF=$(cat $g/functions/ncm.usb0/ifname)
        echo "usb-gadget-net: udc=$udc gadget=m5_$n netdev=$IF host=10.55.$n.1 me=10.55.$n.2"
        $BB ip link set "$IF" up
        $BB ip addr add 10.55.$n.2/24 dev "$IF"
        # ttyGS<n> console: a root shell for the ThinkPad (also covers "no
        # keyboard": type on the ThinkPad, /dev/ttyACM<k> there).
        ( while :; do
              $BB setsid $BB cttyhack $BB sh </dev/ttyGS$n >/dev/ttyGS$n 2>&1
              $BB sleep 1
          done ) &
    else
        echo "usb-gadget-net: binding $udc failed"
        $BB rmdir $g/configs/c.1/strings/0x409 $g/configs/c.1 2>/dev/null
    fi
    n=$((n + 1))
done

# Default route on whichever UDC the host actually configures (state ==
# configured). The host script NATs 10.55.0.0/16. Backgrounded so /init (and
# a switch_root to the SSD rootfs, whose networkd has its own static config)
# is not held up.
(
    t=0
    while [ $t -lt 300 ]; do
        n=0
        for udc in $($BB ls /sys/class/udc); do
            if [ "$(cat /sys/class/udc/$udc/state)" = configured ]; then
                $BB ip route replace default via 10.55.$n.1
                echo "nameserver 1.1.1.1" > /etc/resolv.conf
                echo "usb-gadget-net: host on $udc (10.55.$n.1), default route set"
                exit 0
            fi
            n=$((n + 1))
        done
        t=$((t + 1)); $BB sleep 0.1
    done
    echo "usb-gadget-net: no host enumerated us within 30 s; check cable/port"
) &
