#!/usr/bin/env python3
"""Build the M5's root filesystem image on the host, no root needed.

Arch Linux ARM's generic aarch64 tarball, minus what our kernel never uses
(linux-aarch64: /boot, modules; linux-firmware*: ~1 GB), plus the bring-up
config, written as a tar and turned into ext4 by `mke2fs -d <tarball>`
(e2fsprogs >= 1.47.1 reads tarballs through libarchive, taking uid/gid/mode/
xattrs from the headers, so the result is right without fakeroot/sudo).

  scripts/mkrootfs-image.py                       # -> build/rootfs/m5root.img.gz

The image is small (2 GiB, mostly empty); fstab's x-systemd.growfs grows the
filesystem to the whole partition on the first boot. Flash it with
provision-rootfs.sh on the M5 (guarded: only nvme0n1p5 with the expected
geometry).
"""
import argparse, glob, gzip, io, os, pathlib, shutil, subprocess, sys, tarfile, time

ALARM_URL = "http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz"
DROP_PKGS = ("linux-aarch64-", "linux-firmware")   # pacman local db dir prefixes
DROP_TREES = ("boot/", "usr/lib/firmware/", "usr/lib/modules/")
NET = 0                                            # usb-gadget-net subnet 10.55.<NET>.0/24

FILES = {
    "etc/hostname": "m5pro\n",
    # growfs: the image is 2 GiB; the first boot grows it to the partition.
    "etc/fstab": "LABEL=m5root / ext4 noatime,x-systemd.growfs 0 1\n",
    # usb-gadget-net.sh (initramfs) creates the EEM function as usb0; the
    # ThinkPad side is scripts/host-usbnet.sh (10.55.<n>.1, NAT).
    "etc/systemd/network/10-usb-gadget.network": f"""[Match]
Name=usb0

[Network]
Address=10.55.{NET}.2/24
Gateway=10.55.{NET}.1
DNS=1.1.1.1
""",
}
SYMLINKS = {}


def is_pkg_db(path):
    p = path.split("/")
    return (len(p) >= 4 and p[:3] == ["var", "lib", "pacman"] and p[3] == "local"
            and len(p) >= 5 and p[4].startswith(DROP_PKGS) and not p[4].startswith("linux-api-headers"))


def dropped_files(src):
    """Paths owned by the dropped packages, from their pacman db 'files'."""
    owned = set()
    with tarfile.open(src) as tf:
        for m in tf:
            name = m.name.removeprefix("./")
            if is_pkg_db(name) and name.endswith("/files"):
                sect = None
                for line in tf.extractfile(m).read().decode().splitlines():
                    if line.startswith("%"):
                        sect = line
                    elif sect == "%FILES%" and line and not line.endswith("/"):
                        owned.add(line)
    return owned


def info(name, data=None, mode=0o644, link=None):
    ti = tarfile.TarInfo(name)
    ti.uid = ti.gid = 0
    ti.uname = ti.gname = "root"
    ti.mtime = int(time.time())
    if link is not None:
        ti.type, ti.linkname, ti.mode = tarfile.SYMTYPE, link, 0o777
    else:
        ti.mode, ti.size = mode, len(data)
    return ti


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--tarball", default="build/cache/ArchLinuxARM-aarch64-latest.tar.gz")
    ap.add_argument("--keys", default=None, help="authorized_keys for root (default: ~/.ssh/*.pub)")
    ap.add_argument("--firmware", default="build/firmware",
                    help="tree installed as /usr/lib/firmware (apple/tpmtfw-j714s.bin: the "
                         "trackpad driver loads it on every open, i.e. after switch_root too)")
    ap.add_argument("--size", default="2G", help="image size (grown on first boot)")
    ap.add_argument("--out", default="build/rootfs/m5root.img.gz")
    a = ap.parse_args()

    src = pathlib.Path(a.tarball)
    if not src.exists():
        sys.exit(f"{src} missing: curl -L -o {src} {ALARM_URL}  (check the .md5 next to it)")
    keys = (pathlib.Path(a.keys).read_bytes() if a.keys else
            b"".join(pathlib.Path(k).read_bytes() for k in sorted(glob.glob(os.path.expanduser("~/.ssh/*.pub")))))
    if not keys:
        sys.exit("no SSH public key (~/.ssh/*.pub or --keys)")

    out = pathlib.Path(a.out)
    work = out.parent
    work.mkdir(parents=True, exist_ok=True)
    tar_path, img_path = work / "m5root.tar", work / "m5root.img"

    print("==> scanning pacman db for", ", ".join(DROP_PKGS))
    owned = dropped_files(src)
    replaced = set(FILES) | set(SYMLINKS) | {"root/.ssh/authorized_keys"}
    kept = dropped = 0
    gone = set()
    print(f"==> repacking {src.name} (dropping {len(owned)} owned files + {', '.join(DROP_TREES)})")
    with tarfile.open(src) as tf, tarfile.open(tar_path, "w", format=tarfile.PAX_FORMAT) as tw:
        for m in tf:
            name = m.name.removeprefix("./").rstrip("/")
            if not name:
                continue
            drop = (is_pkg_db(name) or name in replaced
                    or (not m.isdir() and name in owned)
                    or any(name.startswith(t) for t in DROP_TREES)
                    or (m.islnk() and m.linkname.removeprefix("./") in gone))
            if drop:
                gone.add(name)
                dropped += 1
                continue
            m.name = name
            tw.addfile(m, tf.extractfile(m) if m.isreg() else None)
            kept += 1
        for name, text in FILES.items():
            data = text.encode()
            tw.addfile(info(name, data), io.BytesIO(data))
        for name, target in SYMLINKS.items():
            tw.addfile(info(name, link=target))
        tw.addfile(info("root/.ssh/authorized_keys", keys, 0o600), io.BytesIO(keys))
        fw = pathlib.Path(a.firmware)
        for f in sorted(fw.rglob("*")) if fw.is_dir() else []:
            rel = "usr/lib/firmware/" + str(f.relative_to(fw))
            if f.is_dir():
                d = info(rel, b"", 0o755); d.type = tarfile.DIRTYPE; d.size = 0
                tw.addfile(d)
            else:
                data = f.read_bytes()
                tw.addfile(info(rel, data), io.BytesIO(data))
                print(f"    firmware: /{rel}")
    print(f"    kept {kept}, dropped {dropped}, tar {tar_path.stat().st_size / 1e6:.0f} MB")

    print(f"==> mke2fs -d -> {img_path} ({a.size})")
    img_path.unlink(missing_ok=True)
    subprocess.run(["mke2fs", "-q", "-F", "-t", "ext4", "-b", "4096", "-L", "m5root",
                    "-d", str(tar_path), str(img_path), a.size], check=True)
    subprocess.run(["e2fsck", "-fn", str(img_path)], check=True, stdout=subprocess.DEVNULL)

    print(f"==> gzip -> {out}")
    with open(img_path, "rb") as f, open(out, "wb") as raw, \
            gzip.GzipFile(fileobj=raw, mode="wb", compresslevel=6, mtime=0) as g:
        shutil.copyfileobj(f, g, 16 << 20)
    tar_path.unlink()       # m5root.img stays (sparse) for debugfs inspection
    print(f"    {out} {out.stat().st_size / 1e6:.0f} MB")


if __name__ == "__main__":
    main()
