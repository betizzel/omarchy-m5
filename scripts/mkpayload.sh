#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# mkpayload.sh — assemble a self-contained m1n1 boot object:
#
#   m1n1.bin | chosen.bootargs=… | Image.gz | t6050-j714s.dtb | initramfs.cpio.gz
#
# m1n1 scans everything after its own image as a chain of payloads
# (src/payload.c: gz/xz/fdt/cpio magics, plus plain "key=value\n" variable
# lines), so a plain `cat` in the right order is the whole format.
#
# Two ways to use the result:
#   1. Tethered   — proxyclient chainload.py build/m1n1-payload.bin
#   2. Standalone — sudo scripts/finish-install.sh --m1n1 build/m1n1-payload.bin
#                   then repeat the 1TR ceremony. No second machine needed,
#                   but every kernel change costs a ceremony, so use this for
#                   milestone boots, not for iteration.
#
# Usage: scripts/mkpayload.sh [--bootargs "..."] [--board j714s] [--out PATH]
#                             [--no-initramfs]

set -euo pipefail

cd "$(dirname "$0")/.."

BOARD="j714s"
# SMP is broken on T6050 (secondaries never execute the reset vector), so the
# first milestone is deliberately single-core.
#
# Console: earlycon=efifb draws the kernel log on the panel from early
# setup_arch() on - the bring-up kernel (patch 0001) describes m1n1's
# framebuffer to it - and tty0 takes over once simpledrm/fbcon bind;
# keep_bootcon keeps the early one so a crash in between stays readable.
# No bare `earlycon`: it resolves through /chosen/stdout-path, which is
# serial0 (the s5l UART behind the debug cable).
#
# pd_ignore_unused/clk_ignore_unused: genpd powering off unclaimed PMGR
# domains SErrors on T6050 (and would freeze m1n1's framebuffer); patch 0004
# makes the sync_state path honour pd_ignore_unused too.
BOOTARGS="maxcpus=1 earlycon=efifb keep_bootcon console=tty0 loglevel=8 pd_ignore_unused clk_ignore_unused no_console_suspend"
OUT="build/m1n1-payload.bin"
M1N1="vendor/m1n1/build/m1n1.bin"
KERNEL="vendor/linux/arch/arm64/boot/Image.gz"
INITRAMFS="build/initramfs.cpio.gz"
USE_INITRAMFS=1

while [ $# -gt 0 ]; do
    case "$1" in
        --bootargs) BOOTARGS="$2"; shift 2 ;;
        --board) BOARD="$2"; shift 2 ;;
        --out) OUT="$2"; shift 2 ;;
        --m1n1) M1N1="$2"; shift 2 ;;
        --kernel) KERNEL="$2"; shift 2 ;;
        --initramfs) INITRAMFS="$2"; shift 2 ;;
        --no-initramfs) USE_INITRAMFS=0; shift ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
done

DTB="vendor/linux/arch/arm64/boot/dts/apple/t6050-$BOARD.dtb"

die() { echo "ERROR: $*" >&2; exit 1; }

[ -f "$M1N1" ]   || die "$M1N1 missing — run: CHAINLOADING=0 make m1n1"
[ -f "$KERNEL" ] || die "$KERNEL missing — run: make kernel"
[ -f "$DTB" ]    || die "$DTB missing — run: make dtbs"
if [ "$USE_INITRAMFS" = 1 ]; then
    [ -f "$INITRAMFS" ] || die "$INITRAMFS missing — run: make initramfs"
fi

# build_cfg.h describes the vendor tree's last build, so it only tells us
# anything when we're using that tree's output. A chainload payload (-m1n1
# build/m1n1-chain.bin) is *supposed* to be a CHAINLOADING=1 image.
if [ "$M1N1" = "vendor/m1n1/build/m1n1.bin" ] \
   && grep -q CHAINLOADING vendor/m1n1/build/build_cfg.h 2>/dev/null; then
    die "$M1N1 is a CHAINLOADING=1 build; an installed boot object must be CHAINLOADING=0
     rebuild with: CHAINLOADING=0 make m1n1"
fi

mkdir -p "$(dirname "$OUT")"

echo "==> Assembling $OUT"
echo "    bootargs: $BOOTARGS"
{
    cat "$M1N1"
    printf 'chosen.bootargs=%s\n' "$BOOTARGS"
    cat "$KERNEL"
    cat "$DTB"
    [ "$USE_INITRAMFS" = 1 ] && cat "$INITRAMFS"
} > "$OUT"

echo
echo "==> Verifying the payload chain the way m1n1 parses it"
M1N1_SIZE=$(stat -c %s "$M1N1" 2>/dev/null || stat -f %z "$M1N1") python3 - "$OUT" <<'EOF'
import os, sys, zlib

blob = open(sys.argv[1], "rb").read()
pos = int(os.environ["M1N1_SIZE"])
print(f"    m1n1 image: 0x{pos:x} bytes")

FDT_MAGIC = b"\xd0\x0d\xfe\xed"
found = []

def gz_end(buf, start):
    """Length of the gzip stream at `start` (m1n1 decompresses in place)."""
    d = zlib.decompressobj(16 + zlib.MAX_WBITS)
    out = d.decompress(buf[start:])
    return len(buf) - start - len(d.unused_data), out

while pos < len(blob):
    p = blob[pos:]
    if not p.strip(b"\0"):
        break
    if p[:2] == b"\x1f\x8b":
        size, out = gz_end(blob, pos)
        kind = "kernel" if out[0x38:0x3c] == b"ARM\x64" else (
               "initramfs" if out[:5] in (b"07070", b"07071") else "unknown")
        print(f"    +0x{pos:08x}  gzip stream, 0x{size:x} bytes "
              f"-> 0x{len(out):x} raw ({kind})")
        found.append(kind)
        pos += size
    elif p[:4] == FDT_MAGIC:
        size = int.from_bytes(p[4:8], "big")
        print(f"    +0x{pos:08x}  flattened devicetree, 0x{size:x} bytes")
        found.append("dtb")
        pos += size
    elif p[:5] in (b"07070", b"07071"):
        print(f"    +0x{pos:08x}  cpio initramfs (uncompressed)")
        found.append("initramfs")
        break
    elif b"=" in p[:64] and b"\n" in p[:1024]:
        line = p[: p.index(b"\n")].decode()
        print(f"    +0x{pos:08x}  variable: {line}")
        if not line.startswith(("chosen.", "chainload=", "display=",
                                "mitigations=", "tso=")):
            sys.exit(f"ERROR: m1n1 would reject unknown variable '{line}'")
        found.append("var")
        pos += len(line) + 1
    else:
        sys.exit(f"ERROR: unparseable payload at +0x{pos:x}: {p[:8].hex()}")

if "kernel" not in found:
    sys.exit("ERROR: no kernel found in the chain")
if "dtb" not in found:
    sys.exit("ERROR: no devicetree found in the chain")
print(f"\n    chain: m1n1 -> {' -> '.join(found)}")
EOF

echo
ls -lh "$OUT"
