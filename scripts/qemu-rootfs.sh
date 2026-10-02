#!/bin/sh
# qemu-rootfs.sh - boot the M5's kernel + initramfs + rootfs image under
# QEMU (virt, TCG, same 16K-page config), no root needed. Checks what does
# not need M5 hardware: the m5.root= switch_root hook, systemd on our
# kernel config, x-systemd.growfs, networking, and userland on 16K pages.
#
#   scripts/qemu-rootfs.sh            # serial console; root/root; Ctrl-A x quits
#
# Needs: scripts/build-kernel.sh, mkinitramfs.py, mkrootfs-image.py done.
# QEMU comes from the distro's packages unpacked under build/qemu/root
# (pacman -Sp: URLs only, nothing installed). The kernel is a reflink copy of
# vendor/linux with CONFIG_OMARCHY_FB_MARKERS off: the markers store to the
# J714s framebuffer's physical address from head.S on, which kills a VM
# before its console exists.
set -eu
cd "$(dirname "$0")/.."
Q=build/qemu
mkdir -p $Q/pkgs $Q/root

if [ ! -x $Q/root/usr/bin/qemu-system-aarch64 ]; then
    echo "==> fetching qemu-system-aarch64 (unpacked into $Q/root, not installed)"
    for u in $(pacman -Sp qemu-system-aarch64 | grep -v edk2); do
        f=$Q/pkgs/$(basename "$u")
        [ -s "$f" ] || curl -sSfL -o "$f" "$u"
        # --force-local: epoch filenames (dtc-1:1.8.1) are not host:path
        tar --force-local --zstd -xf "$f" -C $Q/root
    done
fi

if [ ! -f $Q/Image ] || [ vendor/linux/arch/arm64/boot/Image -nt $Q/Image ]; then
    echo "==> marker-free kernel (incremental, reflink copy of vendor/linux)"
    rm -rf $Q/linux
    cp -a --reflink=auto vendor/linux $Q/linux
    (cd $Q/linux && scripts/config --disable OMARCHY_FB_MARKERS &&
        make ARCH=arm64 LLVM=1 olddefconfig >/dev/null &&
        make ARCH=arm64 LLVM=1 -j"$(nproc)" Image >/dev/null)
    cp $Q/linux/arch/arm64/boot/Image $Q/Image
fi

# Fresh sparse copy each run; 8G so growfs has something to grow.
gunzip -c build/rootfs/m5root.img.gz | cp --sparse=always /dev/stdin $Q/m5root-test.img
truncate -s 8G $Q/m5root-test.img

exec env LD_LIBRARY_PATH=$PWD/$Q/root/usr/lib $Q/root/usr/bin/qemu-system-aarch64 \
    -L $Q/root/usr/share/qemu -M virt -cpu max -accel tcg,thread=multi \
    -smp 8 -m 6G -nographic \
    -kernel $Q/Image -initrd build/initramfs.cpio.gz \
    -append "console=ttyAMA0 loglevel=4 m5.root=/dev/vda" \
    -drive file=$Q/m5root-test.img,format=raw,if=virtio \
    -netdev user,id=n0 -device virtio-net-pci,netdev=n0
