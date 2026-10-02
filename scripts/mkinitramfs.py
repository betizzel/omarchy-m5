#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Build a minimal aarch64 initramfs for T6050 bring-up, on macOS, without root.

Sources an Alpine aarch64 minirootfs (busybox + musl + a real /bin/sh) and
repacks it straight into a newc cpio image in memory. Nothing is ever
extracted to the filesystem, so we never need mknod/chown: device nodes and
ownership are synthesized directly in the archive.

  scripts/mkinitramfs.py [--out build/initramfs.cpio.gz] [--version 3.21.3]

The generated /init mounts the pseudo-filesystems, prints the boot banner we
care about for the first milestone (console alive, single core), and execs a
shell on /dev/console so a dead kernel is distinguishable from a dead shell.
"""

import argparse
import gzip
import io
import os
import stat
import sys
import tarfile
import urllib.request

CDN = "https://dl-cdn.alpinelinux.org/alpine"

INIT = r"""#!/bin/sh
# omarchy-m5 bring-up init.
#
# echo alone proves nothing while the console is broken, so paint bands
# straight into the framebuffer through /dev/mem, the same way the kernel's
# checkpoint markers do. Rows 112..143 are ours (kernel uses 0..111, m1n1
# uses 144..159).
BB=/bin/busybox
$BB mkdir -p /proc /sys /dev /tmp /run
$BB mount -t proc     proc     /proc
$BB mount -t sysfs    sysfs    /sys
$BB mount -t devtmpfs devtmpfs /dev 2>/dev/null
$BB mount -t tmpfs    tmpfs    /tmp

FB_BASE=1149440917504      # 0x10bd3110000, from m1n1's "fb init:" line
STRIDE=12096               # 0x2f40

# 16 rows x 256 px of one 32-bit x2r10g10b10 pixel value, written at a row
# offset. STRICT_DEVMEM permits this because the framebuffer sits above the
# usable-RAM window m1n1 reports.
band() {
    row="$1"; pattern="$2"
    $BB rm -f /tmp/px
    i=0
    while [ $i -lt 256 ]; do printf "$pattern" >> /tmp/px; i=$((i + 1)); done
    y=0
    while [ $y -lt 16 ]; do
        off=$((FB_BASE + (row + y) * STRIDE))
        $BB dd if=/tmp/px of=/dev/mem bs=1 seek=$off conv=notrunc 2>/dev/null
        y=$((y + 1))
    done
}

# rows 112..127: /init is running at all
band 112 '\x00\x00\xff\x3f'

# rows 128..143: the DRM/fbdev devices the console depends on exist
if [ -e /dev/fb0 ] || [ -e /dev/dri/card0 ]; then
    band 128 '\xff\xff\xff\x3f'
fi

echo
echo "================================================"
echo " omarchy-m5: userspace is alive on T6050 (M5 Pro)"
echo "================================================"
echo "kernel:  $($BB uname -a)"
echo "cpus:    $($BB grep -c ^processor /proc/cpuinfo)"
echo "cmdline: $($BB cat /proc/cmdline)"
echo "fb:      $($BB ls /dev/fb0 /dev/dri/ 2>&1)"
echo "drm:     $($BB dmesg | $BB grep -iE 'simpledrm|simple-framebuffer|fbcon|drm' | $BB tail -10)"
echo
$BB dmesg | $BB tail -20
echo

# USB gadget network + serial console (see usb-gadget-net.sh), then root FS.
[ -x /usr/sbin/usb-gadget-net ] && /usr/sbin/usb-gadget-net
ROOT=$($BB sed -n 's/.*\bm5\.root=\([^ ]*\).*/\1/p' /proc/cmdline)
if [ -n "$ROOT" ]; then
    i=0; while [ ! -b "$ROOT" ] && [ $i -lt 100 ]; do $BB sleep 0.1; i=$((i+1)); done
    if $BB mount -t ext4 -o noatime "$ROOT" /mnt 2>/dev/null; then
        $BB umount /proc /sys /dev /tmp 2>/dev/null
        exec $BB switch_root /mnt /sbin/init
    fi
    echo "m5.root=$ROOT did not mount; staying in initramfs"
fi
exec $BB sh
"""


class CpioWriter:
    """newc (SVR4, no CRC) cpio writer."""

    MAGIC = b"070701"

    def __init__(self, fp):
        self.fp = fp
        self.ino = 1
        self.seen = set()

    def _pad(self, n):
        if n % 4:
            self.fp.write(b"\0" * (4 - n % 4))

    def entry(self, name, mode, data=b"", *, uid=0, gid=0, nlink=1,
              rdev=(0, 0), mtime=0):
        name = name.lstrip("/")
        if not name or name in self.seen:
            return
        self.seen.add(name)
        raw = name.encode() + b"\0"
        fields = (self.ino, mode, uid, gid, nlink, mtime, len(data),
                  0, 0, rdev[0], rdev[1], len(raw), 0)
        self.ino += 1
        header = self.MAGIC + b"".join(b"%08X" % f for f in fields)
        self.fp.write(header)
        self.fp.write(raw)
        self._pad(len(header) + len(raw))
        if data:
            self.fp.write(data)
            self._pad(len(data))

    def parents(self, name):
        parts = name.lstrip("/").split("/")[:-1]
        for i in range(len(parts)):
            self.entry("/".join(parts[: i + 1]), stat.S_IFDIR | 0o755, nlink=2)

    def close(self):
        self.entry("TRAILER!!!", 0, nlink=1)
        # cpio images are padded to a 512-byte boundary so a concatenated
        # payload after us still starts on something sane.
        pos = self.fp.tell()
        if pos % 512:
            self.fp.write(b"\0" * (512 - pos % 512))


def fetch(url, cache_dir):
    os.makedirs(cache_dir, exist_ok=True)
    path = os.path.join(cache_dir, os.path.basename(url))
    if os.path.exists(path) and os.path.getsize(path) > 0:
        print(f"    cached {path}")
        return path
    print(f"    fetching {url}")
    with urllib.request.urlopen(url) as r, open(path, "wb") as out:
        out.write(r.read())
    return path


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--version", default="3.21.3", help="Alpine release")
    ap.add_argument("--out", default="build/initramfs.cpio.gz")
    ap.add_argument("--cache", default="build/cache")
    ap.add_argument("--firmware", default="build/firmware",
                    help="tree packed under lib/firmware/ if it exists "
                         "(apple/tpmtfw-j714s.bin: scripts/extract-tpmtfw.py)")
    ap.add_argument("--rootfs-image", metavar="IMG",
                    help="ship IMG (scripts/mkrootfs-image.py output) as /m5root.img.gz "
                         "for provision-rootfs, in a second, uncompressed cpio segment "
                         "(the kernel unpacks concatenated archives; IMG is already gzip)")
    args = ap.parse_args()

    branch = "v" + ".".join(args.version.split(".")[:2])
    url = (f"{CDN}/{branch}/releases/aarch64/"
           f"alpine-minirootfs-{args.version}-aarch64.tar.gz")

    print("==> Sourcing userspace")
    tar_path = fetch(url, args.cache)

    print("==> Repacking as newc cpio")
    buf = io.BytesIO()
    cpio = CpioWriter(buf)

    # Directories the kernel and our /init need before anything else.
    for d in ("dev", "proc", "sys", "tmp", "run"):
        cpio.entry(d, stat.S_IFDIR | 0o755, nlink=2)
    # devtmpfs is mounted by /init, but the kernel opens /dev/console for
    # stdio *before* that, so it has to exist in the archive itself.
    cpio.entry("dev/console", stat.S_IFCHR | 0o600, rdev=(5, 1))
    cpio.entry("dev/null", stat.S_IFCHR | 0o666, rdev=(1, 3))
    cpio.entry("dev/tty", stat.S_IFCHR | 0o666, rdev=(5, 0))

    counts = {"file": 0, "dir": 0, "link": 0, "skipped": 0}
    with tarfile.open(tar_path, "r:gz") as tf:
        for m in tf:
            name = m.name.lstrip("./").lstrip("/")
            if not name or name in (".", ".."):
                continue
            cpio.parents(name)
            if m.isdir():
                cpio.entry(name, stat.S_IFDIR | (m.mode & 0o7777), nlink=2)
                counts["dir"] += 1
            elif m.issym():
                cpio.entry(name, stat.S_IFLNK | 0o777,
                           m.linkname.encode())
                counts["link"] += 1
            elif m.isfile():
                f = tf.extractfile(m)
                cpio.entry(name, stat.S_IFREG | (m.mode & 0o7777), f.read())
                counts["file"] += 1
            else:
                # char/block/fifo from the rootfs: we synthesize our own
                counts["skipped"] += 1

    if os.path.isdir(args.firmware):
        for root, _, files in sorted(os.walk(args.firmware)):
            for fn in sorted(files):
                src = os.path.join(root, fn)
                name = "lib/firmware/" + os.path.relpath(src, args.firmware)
                cpio.parents(name)
                cpio.entry(name, stat.S_IFREG | 0o644, open(src, "rb").read())
                print(f"    firmware: /{name}")

    here = os.path.dirname(__file__)
    cpio.entry("init", stat.S_IFREG | 0o755, INIT.encode())
    cpio.entry("usr/sbin/usb-gadget-net", stat.S_IFREG | 0o755,
               open(os.path.join(here, "usb-gadget-net.sh"), "rb").read())
    cpio.entry("usr/sbin/provision-rootfs", stat.S_IFREG | 0o755,
               open(os.path.join(here, "provision-rootfs.sh"), "rb").read())
    cpio.close()

    raw = buf.getvalue()
    os.makedirs(os.path.dirname(args.out) or ".", exist_ok=True)
    with open(args.out, "wb") as out:
        # mtime=0 so the image is reproducible
        with gzip.GzipFile(fileobj=out, mode="wb", compresslevel=9, mtime=0) as gz:
            gz.write(raw)
        if args.rootfs_image:
            # init/initramfs.c skips zero padding between archives but only
            # starts a new uncompressed one on a 4-byte boundary.
            out.write(b"\0" * (-out.tell() % 4))
            seg = CpioWriter(out)
            seg.entry("m5root.img.gz", stat.S_IFREG | 0o644,
                      open(args.rootfs_image, "rb").read())
            seg.close()
            print(f"    + /m5root.img.gz ({os.path.getsize(args.rootfs_image) / 1e6:.0f} MB, "
                  "uncompressed cpio segment)")

    print(f"    files={counts['file']} dirs={counts['dir']} "
          f"symlinks={counts['link']} device-nodes-synthesized=3 "
          f"(skipped {counts['skipped']} nodes from the rootfs)")
    print(f"\n==> {args.out}  "
          f"({os.path.getsize(args.out) / 1024:.0f} KiB, "
          f"{len(raw) / 1024 / 1024:.1f} MiB raw base archive)")


if __name__ == "__main__":
    sys.exit(main())
