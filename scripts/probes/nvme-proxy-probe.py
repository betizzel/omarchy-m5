#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Read-only SSD sanity check over the m1n1 proxy (no kernel involved).

Uses m1n1's own T8132-style ANS driver (src/nvme.c, nvme-secure-bar path):
boots ANS RTKit, sets up SARTv4 + NVMMU, reads the GPT. Writes nothing to the
disk. Run from the tether bundle with the Mac sitting in the m1n1 proxy,
BEFORE boot-linux.sh:

    hv/nvme-proxy-probe.py

NB: nvme_shutdown() ends with pmgr_reset("ANS"), i.e. a following Linux boot
finds ANS cold (the M1-style reset path in apple_nvme_reset_work), not warm.
Skip this script when you want to test the warm-adoption path.
"""
import sys, struct, uuid, pathlib

LINUX_FS = uuid.UUID("0fc63daf-8483-4772-8e79-3d69d8477de4")   # GPT "Linux filesystem"
sys.path.append(str(pathlib.Path(__file__).resolve().parents[1] / "proxyclient"))
from m1n1.setup import *

if not p.nvme_init():
    sys.exit("nvme_init failed - read m1n1's log (/dev/m1n1-sec or panel)")

buf = u.memalign(0x4000, 0x4000)

def rd(lba):
    if not p.nvme_read(1, lba, buf):
        sys.exit(f"nvme_read(lba {lba}) failed")
    return iface.readmem(buf, 4096)

try:
    hdr = rd(1)                       # LBA size is 4096 on Apple ANS
    print("GPT signature :", hdr[:8])
    if hdr[:8] != b"EFI PART":
        sys.exit("no GPT at LBA 1 (4K LBAs)")
    (rev, hsz, crc, _, my, alt, first, last) = struct.unpack_from("<IIIIQQQQ", hdr, 8)
    guid = uuid.UUID(bytes_le=hdr[56:72])
    ent_lba, n_ent, ent_sz = struct.unpack_from("<QII", hdr, 72)
    print(f"disk guid {guid} usable LBA {first}..{last} ({(last-first+1)*4096/1e9:.1f} GB)")
    per = 4096 // ent_sz
    idx = 0
    linux = []
    for blk in range((n_ent + per - 1) // per):
        data = rd(ent_lba + blk)
        for k in range(per):
            e = data[k*ent_sz:(k+1)*ent_sz]
            idx += 1
            if not any(e[:16]):
                continue
            t = uuid.UUID(bytes_le=e[0:16]); g = uuid.UUID(bytes_le=e[16:32])
            s, l = struct.unpack_from("<QQ", e, 32)
            name = e[56:128].decode("utf-16le").rstrip("\0")
            print(f"  p{idx}: {t}  uuid={g}  LBA {s}..{l}  ({(l-s+1)*4096/1e9:.1f} GB) '{name}'")
            if t == LINUX_FS:
                linux.append((idx, s, l - s + 1))
    # Linux numbers nvme0n1pN by GPT entry, like the pN above. The tether's
    # m5.root= and provision-rootfs both default to p5.
    for n, start, count in linux:
        part = "" if n == 5 else f"PART=/dev/nvme0n1p{n} "
        print(f"rootfs p{n}: on the M5 run  {part}provision-rootfs {start} {count}")
        if n != 5:
            print(f"  NB: boot with m5.root=/dev/nvme0n1p{n} (BOOTARGS), not p5")
    if not linux:
        print("no Linux filesystem partition (prep-stub.sh --linux-size N makes one)")
finally:
    p.nvme_shutdown()
