#!/bin/sh
# provision-rootfs - run on the M5 (initramfs shell, as /usr/sbin/provision-rootfs).
# Writes the ext4 image from scripts/mkrootfs-image.py to disk0s5
# (= nvme0n1p5) and nothing else, then reads it back to verify.
#
#   provision-rootfs START4K COUNT4K [IMAGE]
#
# START4K/COUNT4K: the partition's first LBA and LBA count (4096-byte LBAs),
#   from hv/nvme-proxy-probe.py, which prints this exact command line for
#   the Linux partition (m1n1's view of the GPT), or macOS
#   `sudo gpt -r show /dev/disk0`. Both must match Linux's view of
#   nvme0n1p5 or nothing is written.
# IMAGE: gzip'd ext4 image. Default /m5root.img.gz, shipped by a provisioning
#   initramfs (mkinitramfs.py --rootfs-image); or an http:// URL once the USB
#   link is up (ThinkPad: python3 -m http.server -d build/rootfs 8000).
#
# FORCE=1 overwrites an existing filesystem on the partition.
set -eu
set -o pipefail
BB=/bin/busybox
DEV=${DEV:-/dev/nvme0n1}
PART=${PART:-${DEV}p5}
[ $# -ge 2 ] || { $BB sed -n '2,16s/^# \{0,1\}//p' "$0"; exit 2; }
EXPECT_START4K=$1 EXPECT_COUNT4K=$2 IMAGE=${3:-/m5root.img.gz}
b=$($BB basename "$PART")

[ -b "$PART" ] || { echo "no $PART (NVMe not up?)"; exit 1; }
bs=$(cat /sys/block/$($BB basename $DEV)/queue/logical_block_size)
start512=$(cat /sys/class/block/$b/start); size512=$(cat /sys/class/block/$b/size)
[ "$bs" = 4096 ] || { echo "logical block size $bs != 4096"; exit 1; }
[ "$start512" = $((EXPECT_START4K * 8)) ] && [ "$size512" = $((EXPECT_COUNT4K * 8)) ] ||
    { echo "REFUSING: $b is start=$start512 size=$size512 (512B units), expected $((EXPECT_START4K*8))/$((EXPECT_COUNT4K*8))"; exit 1; }
if $BB blkid "$PART" | $BB grep -q TYPE= && [ "${FORCE:-0}" != 1 ]; then
    echo "REFUSING: $PART already has a filesystem ($($BB blkid $PART)); FORCE=1 to overwrite"; exit 1
fi
echo "partition ok: $PART $((size512 / 2 / 1024 / 1024)) GiB, start LBA(4K)=$EXPECT_START4K"

case "$IMAGE" in
http://*)
    echo "fetching $IMAGE ..."
    $BB wget -qO /tmp/m5root.img.gz "$IMAGE"
    IMAGE=/tmp/m5root.img.gz ;;
esac
[ -r "$IMAGE" ] || { echo "no image $IMAGE"; exit 1; }
n=$($BB zcat "$IMAGE" | $BB wc -c)
[ $((n / 512)) -le "$size512" ] || { echo "image ($n bytes) larger than $PART"; exit 1; }

echo "writing $((n / 1024 / 1024)) MiB to $PART ..."
$BB zcat "$IMAGE" | $BB dd of="$PART" bs=4M conv=fsync 2>&1 | $BB tail -1
$BB sync

# Read back from the device, not the page cache: the NVMe/SART path is new.
echo 3 > /proc/sys/vm/drop_caches
want=$($BB zcat "$IMAGE" | $BB md5sum | $BB cut -d' ' -f1)
got=$($BB head -c "$n" "$PART" | $BB md5sum | $BB cut -d' ' -f1)
[ "$want" = "$got" ] || { echo "READBACK MISMATCH: image $want, $PART $got"; exit 1; }
echo "readback ok ($got): $($BB blkid $PART)"
echo "done. Next boot: add  m5.root=$PART  to the kernel cmdline (initramfs switch_root hook);"
echo "the first boot grows the filesystem to the whole partition (x-systemd.growfs)."
