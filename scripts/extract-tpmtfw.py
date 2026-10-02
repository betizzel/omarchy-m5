#!/usr/bin/env python3
"""Extract the MTP trackpad firmware (apple/tpmtfw-<board>.bin) for one board
from a macOS restore bundle / IPSW, using the Asahi installer's own converter.

UNTESTED against Apple data: written from asahi-installer's
src/stub.py:collect_firmware() (FUD part) and asahi_firmware/multitouch.py. The
plumbing (BuildManifest lookup -> fud_firmware/<board>/Multitouch.im4p ->
MultitouchFWCollection -> apple/tpmtfw-<board>.bin with a valid "HIDF" header)
was exercised with a synthetic IM4P/BuildManifest only; no real Multitouch.im4p
was available on the machine this was written on. Run it on the M5's macOS (or
any Mac) where the restore bundle is readable:

  git clone https://github.com/AsahiLinux/asahi-installer /tmp/asahi-installer
  scripts/extract-tpmtfw.py \\
      --installer /tmp/asahi-installer \\
      --bundle /System/Volumes/Preboot/<macOS VGID>/restore \\
      --device-class j714sap --out build/firmware

Result: build/firmware/apple/tpmtfw-j714s.bin   ("HIDF" header + CBOR blob,
the format dockchannel-hid.c's dchid_get_firmware() validates: magic
0x46444948, version 1). Put it at /lib/firmware/apple/ in the initramfs.

--bundle is any directory that contains BuildManifest.plist and the paths it
references (the Preboot "restore" dir the stub already carries, or an unzipped
IPSW). --ipsw instead reads just the manifest and the needed members out of a
restore IPSW - a local file or an https URL, fetched with HTTP range requests
(~30 MB of a ~20 GB image). Pick the IPSW whose macOS matches the system iBoot
boots (the preloaded MTP image and tpmtfw must be a pair); e.g. for 26.5:

  scripts/extract-tpmtfw.py --installer build/asahi-installer \\
      --ipsw https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-58869/DFB1CEEF-5619-4591-9924-E20DB2C8FED0/UniversalMac_26.5_25F71_Restore.ipsw \\
      --out build/firmware

(URLs per device: https://api.ipsw.me/v4/device/Mac17,9?type=ipsw)

Only entries flagged IsFUDFirmware and NOT IsLoadedByiBoot are taken:
the MTP RTKit image itself is IsLoadedByiBoot (iBoot preloads it, the ADT says
pre-loaded = 1) and must never be needed from Linux.
"""
import argparse, io, os, plistlib, shutil, sys, tempfile, pathlib, urllib.request, zipfile


class HTTPRangeFile(io.RawIOBase):
    """Seekable read-only view of a remote file, one Range request per read."""

    def __init__(self, url):
        self.url, self.pos = url, 0
        head = urllib.request.urlopen(urllib.request.Request(url, method="HEAD"), timeout=30)
        self.size = int(head.headers["Content-Length"])

    def seekable(self):
        return True

    def readable(self):
        return True

    def tell(self):
        return self.pos

    def seek(self, off, whence=0):
        self.pos = {0: off, 1: self.pos + off, 2: self.size + off}[whence]
        return self.pos

    def readinto(self, b):
        if self.pos >= self.size:
            return 0
        end = min(self.pos + len(b), self.size) - 1
        req = urllib.request.Request(self.url, headers={"Range": f"bytes={self.pos}-{end}"})
        data = urllib.request.urlopen(req, timeout=60).read()
        b[:len(data)] = data
        self.pos += len(data)
        return len(data)


def open_source(a):
    """Return (BuildManifest dict, read(path) -> bytes or None)."""
    if a.bundle:
        bundle = pathlib.Path(a.bundle)

        def read(path):
            p = bundle / path
            return p.read_bytes() if p.exists() else None

        return plistlib.loads(read("BuildManifest.plist")), read

    raw = HTTPRangeFile(a.ipsw) if a.ipsw.startswith(("http://", "https://")) else open(a.ipsw, "rb")
    z = zipfile.ZipFile(io.BufferedReader(raw, buffer_size=1 << 20) if isinstance(raw, HTTPRangeFile) else raw)
    names = set(z.namelist())

    def read(path):
        return z.read(path) if path in names else None

    return plistlib.loads(z.read("BuildManifest.plist")), read


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--installer", required=True, help="asahi-installer checkout (provides asahi_firmware/)")
    src = ap.add_mutually_exclusive_group(required=True)
    src.add_argument("--bundle", help="directory with BuildManifest.plist (restore bundle / unzipped IPSW)")
    src.add_argument("--ipsw", help="restore IPSW: local path or https URL (range requests)")
    ap.add_argument("--device-class", default="j714sap")
    ap.add_argument("--variant", default="macOS Customer")
    ap.add_argument("--behavior", default="Erase")
    ap.add_argument("--out", required=True)
    a = ap.parse_args()

    sys.path.insert(0, a.installer)
    from asahi_firmware.multitouch import MultitouchFWCollection

    manifest, read = open_source(a)

    ident = None
    for i in manifest["BuildIdentities"]:
        info = i["Info"]
        if (info["DeviceClass"] == a.device_class and info["RestoreBehavior"] == a.behavior
                and info["Variant"] == a.variant):
            ident = i
            break
    if ident is None:
        sys.exit(f"no build identity for {a.device_class} / {a.behavior} / {a.variant}")

    board = a.device_class[:-2]  # j714sap -> j714s
    with tempfile.TemporaryDirectory() as tmp:
        fud = pathlib.Path(tmp) / "fud_firmware"
        dev_dir = fud / board
        dev_dir.mkdir(parents=True)
        found = []
        for key, val in ident["Manifest"].items():
            info = val["Info"]
            path = info["Path"]
            if (not info.get("IsFUDFirmware", False) or info.get("IsLoadedByiBoot", False)
                    or info.get("IsLoadedByiBootStage1", False) or not path.endswith(".im4p")):
                continue
            # Only the trackpad blob matters here; skip fetching the rest of
            # the FUD set (several MB each over HTTP).
            if key != "Multitouch":
                continue
            data = read(path)
            if data is None:
                print(f"warning: {key}: {path} missing", file=sys.stderr)
                continue
            (dev_dir / f"{key}.im4p").write_bytes(data)
            found.append(key)
        print("FUD firmware for", board, ":", ", ".join(found) or "(none)")
        if "Multitouch" not in found:
            sys.exit("Multitouch.im4p not in this source (OTA-only bundle? use the full IPSW)")

        col = MultitouchFWCollection(str(fud))
        out = pathlib.Path(a.out)
        n = 0
        for name, fw in col.files():
            dst = out / name
            dst.parent.mkdir(parents=True, exist_ok=True)
            dst.write_bytes(fw.data)
            print("wrote", dst, len(fw.data), "bytes")
            n += 1
        if not n:
            sys.exit("MultitouchFWCollection produced nothing (no C1FD* key in the mtfw plist?)")


if __name__ == "__main__":
    main()
