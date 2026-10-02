#!/bin/sh
# provision-rootfs.sh - run on the M5 (initramfs shell, USB link up).
# Formats ONLY disk0s5 (= nvme0n1p5) and unpacks an aarch64 rootfs tarball
# that the ThinkPad serves (python3 -m http.server 8000 -d <dir>).
#
#   EXPECT_START4K=<first LBA> EXPECT_COUNT4K=<LBA count> \
#   TARBALL_URL=http://10.55.0.1:8000/ArchLinuxARM-aarch64-latest.tar.gz \
#   KEY_URL=http://10.55.0.1:8000/authorized_keys  sh provision-rootfs.sh
#
# EXPECT_* come from `nvme-proxy-probe.py` (m1n1 view) or macOS
# (`sudo gpt -r show /dev/disk0`; macOS LBAs are 4096-byte on this disk).
# Both must match Linux's view of nvme0n1p5 or nothing is written.
set -eu
DEV=${DEV:-/dev/nvme0n1}
PART=${PART:-${DEV}p5}
N=${NET:-0}                       # which 10.55.N.0/24 link the host is on
: "${EXPECT_START4K:?}" "${EXPECT_COUNT4K:?}" "${TARBALL_URL:?}"
b=$(basename "$PART")

[ -b "$PART" ] || { echo "no $PART (NVMe not up?)"; exit 1; }
bs=$(cat /sys/block/$(basename $DEV)/queue/logical_block_size)
start512=$(cat /sys/class/block/$b/start); size512=$(cat /sys/class/block/$b/size)
[ "$bs" = 4096 ] || { echo "logical block size $bs != 4096"; exit 1; }
[ "$start512" = $((EXPECT_START4K * 8)) ] && [ "$size512" = $((EXPECT_COUNT4K * 8)) ] ||
    { echo "REFUSING: $b is start=$start512 size=$size512 (512B units), expected $((EXPECT_START4K*8))/$((EXPECT_COUNT4K*8))"; exit 1; }
if blkid "$PART" >/dev/null 2>&1 && [ "${FORCE:-0}" != 1 ]; then
    echo "REFUSING: $PART already has a filesystem ($(blkid $PART)); FORCE=1 to overwrite"; exit 1
fi
echo "partition ok: $PART $((size512/2/1024/1024)) GiB, start LBA(4K)=$EXPECT_START4K"

# time: no RTC driver yet; TLS (apk, pacman, git, claude) needs a sane clock.
[ -n "${EPOCH:-}" ] && date -s "@$EPOCH"

command -v mkfs.ext4 >/dev/null || {
    # plain http repos are fine: apk verifies signatures on the index
    sed -i 's#^https://#http://#' /etc/apk/repositories
    apk add --no-cache e2fsprogs tar
}
# 4 KiB ext4 blocks on a 16 KiB-page kernel are fine; keep it simple.
# -E nodiscard: ANS discard support unverified.
mkfs.ext4 -F -L m5root -b 4096 -E nodiscard "$PART"
mkdir -p /mnt/root && mount -t ext4 -o noatime "$PART" /mnt/root

echo "unpacking $TARBALL_URL ..."
wget -qO- "$TARBALL_URL" | tar -xz -C /mnt/root

# --- minimal bring-up config so the first boot from SSD is reachable ----
R=/mnt/root
echo m5pro > $R/etc/hostname
echo "LABEL=m5root / ext4 noatime 0 1" > $R/etc/fstab
mkdir -p $R/etc/systemd/network $R/root/.ssh
cat > $R/etc/systemd/network/10-usb-gadget.network <<NET
[Match]
Name=usb* enx*
[Network]
Address=10.55.$N.2/24
Gateway=10.55.$N.1
DNS=1.1.1.1
NET
rm -f $R/etc/resolv.conf; echo "nameserver 1.1.1.1" > $R/etc/resolv.conf
[ -n "${KEY_URL:-}" ] && wget -qO $R/root/.ssh/authorized_keys "$KEY_URL" && chmod 700 $R/root/.ssh && chmod 600 $R/root/.ssh/authorized_keys
mkdir -p $R/etc/systemd/system/multi-user.target.wants $R/etc/systemd/system/sockets.target.wants
mkdir -p $R/etc/systemd/system/getty.target.wants
ln -sf /usr/lib/systemd/system/serial-getty@.service $R/etc/systemd/system/getty.target.wants/serial-getty@ttyGS0.service
ln -sf /usr/lib/systemd/system/sshd.service $R/etc/systemd/system/multi-user.target.wants/sshd.service
ln -sf /usr/lib/systemd/system/systemd-networkd.service $R/etc/systemd/system/multi-user.target.wants/systemd-networkd.service
sync; umount $R
echo "done. Next boot: add  m5.root=$PART  to the kernel cmdline (initramfs switch_root hook)."
