#!/bin/sh
# usb-gadget-net - initramfs side. Turn every DWC3 UDC into a CDC-EEM
# Ethernet gadget: two bulk endpoints, no interrupt endpoint.
#
# Why EEM and not NCM/ECM/ACM: with NCM+ACM the host's SET_CONFIGURATION
# never completed. The dwc3 trace showed the status stage armed ("ep0in
# Start Transfer: Successful") right after NCM queued its first notification
# on its interrupt IN endpoint, then no further controller events at all, not
# even for the host's retry; GSTS showed no bus error. m1n1's working gadget
# never transmits on an interrupt endpoint, and Apple's ADT marks the NCM
# interrupt endpoint disabled on this port (usb-drd0:
# ncm-interrupt-ep-disabled = 1). EEM needs only bulk endpoints, like m1n1.
# The ThinkPad binds cdc_eem by class; EEM carries no MAC, so
# scripts/host-usbnet.sh finds the netdev by USB serial (m5pro-<n>).
#
# Nothing here touches PHY / PMGR / DART state beyond what the dwc3 driver
# does: m1n1 (usb_phy_bringup) left the eUSB2 PHY running and the PIPE mux on
# the dummy PHY, and the cable is still plugged into the ThinkPad. That is
# exactly the state m1n1's own gadget runs in.
#
# Port numbering follows the DT: dwc3_0 = ADT usb-drd0 (port-number 1,
# hpm0 left-back), dwc3_1 = drd1 (port 2, left-front), dwc3_2 = drd2 (port 3,
# right). Netdev usb<n>, subnet 10.55.<n>.0/24, host .1, M5 .2.
BB=/bin/busybox
CFG=/sys/kernel/config
# m5.root=: /init switch_roots to the SSD right after us; its systemd-networkd
# owns usb0, so only set up the gadget.
case " $(cat /proc/cmdline) " in *" m5.root="*) SSDROOT=1 ;; *) SSDROOT=0 ;; esac
G=$CFG/usb_gadget

$BB mountpoint -q $CFG || $BB mount -t configfs none $CFG || exit 1

# dwc3 tracepoints (setup packets, endpoint commands + completion status,
# controller events) from before the first bind, so a link that never comes
# up leaves a record in /sys/kernel/tracing/trace. Needs CONFIG_FTRACE.
T=/sys/kernel/tracing
$BB mountpoint -q $T || $BB mount -t tracefs none $T 2>/dev/null
$BB mountpoint -q /sys/kernel/debug || $BB mount -t debugfs none /sys/kernel/debug 2>/dev/null
if [ -d $T/events/dwc3 ]; then
    echo 8192 > $T/buffer_size_kb
    echo 1 > $T/events/dwc3/enable
fi

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
    echo "eem"             > $g/configs/c.1/strings/0x409/configuration
    echo 250               > $g/configs/c.1/MaxPower

    $BB mkdir -p $g/functions/eem.usb0
    echo "02:4d:35:00:0$n:02" > $g/functions/eem.usb0/dev_addr
    $BB ln -s $g/functions/eem.usb0 $g/configs/c.1/eem.usb0

    if echo "$udc" > $g/UDC; then
        IF=$(cat $g/functions/eem.usb0/ifname)
        echo "usb-gadget-net: udc=$udc gadget=m5_$n netdev=$IF host=10.55.$n.1 me=10.55.$n.2"
        $BB ip link set "$IF" up
        $BB ip addr add 10.55.$n.2/24 dev "$IF"
    else
        echo "usb-gadget-net: binding $udc failed"
        $BB rmdir $g/configs/c.1/strings/0x409 $g/configs/c.1 2>/dev/null
    fi
    n=$((n + 1))
done

[ $SSDROOT = 1 ] && exit 0

# Default route on whichever UDC the host configures. The host script NATs
# 10.55.0.0/16. Backgrounded so /init is not held up.
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
    echo "usb-gadget-net: no host configured us within 30 s; dwc3 trace: /sys/kernel/tracing/trace"
) &
