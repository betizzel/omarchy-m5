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
# m5.root=: /init switch_roots to the SSD right after us; its systemd owns
# ttyGS0 (serial-getty) and usb0 (networkd), so only set up the gadget.
case " $(cat /proc/cmdline) " in *" m5.root="*) SSDROOT=1 ;; *) SSDROOT=0 ;; esac
G=$CFG/usb_gadget

$BB mountpoint -q $CFG || $BB mount -t configfs none $CFG || exit 1

# dwc3 tracepoints (setup packets, endpoint commands + completion status,
# controller events) from before the first bind, so a host that never
# configures us leaves a record; see usb_diag below. Needs CONFIG_FTRACE.
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
        [ $SSDROOT = 1 ] || ( while :; do
              $BB setsid $BB cttyhack $BB sh </dev/ttyGS$n >/dev/ttyGS$n 2>&1
              $BB sleep 1
          done ) &
    else
        echo "usb-gadget-net: binding $udc failed"
        $BB rmdir $g/configs/c.1/strings/0x409 $g/configs/c.1 2>/dev/null
    fi
    n=$((n + 1))
done

# One panel screen for a photo: from the first SET_CONFIGURATION the
# controller saw (or the last events, if it never saw one), plus the
# controller registers and link state. The full trace stays in
# /tmp/dwc3-trace.txt.
usb_diag() {
    printf '\033[2J\033[H'
    echo "=== usb-gadget-net: no host configured us; dwc3 diagnostics ==="
    for udc in $($BB ls /sys/class/udc); do
        d=/sys/kernel/debug/usb/$udc
        echo "$udc state=$(cat /sys/class/udc/$udc/state) link=$(cat $d/link_state 2>/dev/null)"
    done
    udc=$($BB ls /sys/class/udc | $BB head -1)
    $BB grep -E '^(GCTL|GSTS|GUSB2PHYCFG\(0\)|GUSB3PIPECTL\(0\)|GEVNTCOUNT\(0\)|DCFG|DCTL|DEVTEN|DSTS|DALEPENA) ' \
        /sys/kernel/debug/usb/$udc/regdump 2>/dev/null | $BB tr -s ' \n' ' ' ; echo
    [ -r $T/trace ] || { echo "(no tracefs: kernel built without CONFIG_FTRACE)"; return; }
    $BB sed -E 's/^.*\] [^ ]+ +([0-9]+\.[0-9]+): dwc3_/\1 /' $T/trace |
        $BB grep -v '^#' > /tmp/dwc3-trace.txt
    echo "--- dwc3 trace ($($BB wc -l < /tmp/dwc3-trace.txt) events, full: /tmp/dwc3-trace.txt) ---"
    if $BB grep -q 'Set Configuration' /tmp/dwc3-trace.txt; then
        $BB sed -n '/Set Configuration/,$p' /tmp/dwc3-trace.txt | $BB head -30
    else
        echo "(no SET_CONFIGURATION seen; last events)"
        $BB tail -30 /tmp/dwc3-trace.txt
    fi | $BB cut -c1-175
}

# Bring-up experiment, only reached when the host never configured the
# NCM+ACM composite: rebind the cabled gadget with one function at a time and
# keep the first one the host configures (ACM first: that alone gives the
# ThinkPad a root shell on /dev/ttyACM*). Apple's ADT marks the NCM interrupt
# endpoint disabled on this port (usb-drd0: ncm-interrupt-ep-disabled = 1).
usb_variants() {
    for udc in $($BB ls /sys/class/udc); do
        [ "$(cat /sys/class/udc/$udc/state)" = "not attached" ] && continue
        g=$($BB grep -l "^$udc\$" $G/*/UDC | $BB head -1); g=${g%/UDC}
        [ -n "$g" ] || continue
        for f in acm.GS0 ncm.usb0; do
            echo "" > $g/UDC
            $BB rm -f $g/configs/c.1/acm.GS0 $g/configs/c.1/ncm.usb0
            $BB ln -s $g/functions/$f $g/configs/c.1/$f
            echo "$udc" > $g/UDC
            t=0
            while [ $t -lt 150 ] && [ "$(cat /sys/class/udc/$udc/state)" != configured ]; do
                t=$((t + 1)); $BB sleep 0.1
            done
            echo "usb-gadget-net: $udc with only $f: $(cat /sys/class/udc/$udc/state)"
            if [ "$(cat /sys/class/udc/$udc/state)" = configured ]; then
                [ $f = ncm.usb0 ] && $BB ip route replace default via 10.55.${g##*_}.1 &&
                    echo "nameserver 1.1.1.1" > /etc/resolv.conf
                return 0
            fi
        done
    done
}

[ $SSDROOT = 1 ] && exit 0

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
    usb_diag
    usb_variants
) &
