#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# mktether.sh — pack everything the Linux dev host needs to drive the M5
# over USB-C into one tarball.
#
# The M5 is the target: while m1n1 owns it, macOS (and this repo) are not
# running, so the proxyclient has to live on the other machine.
#
#   scripts/mktether.sh              -> build/tether-bundle.tar.gz
#   scp build/tether-bundle.tar.gz thinkpad:
#
# Everything in the bundle is self-contained: m1n1's proxyclient package,
# the kernel/DT/initramfs, a chainloadable m1n1, the udev rule, and two
# runner scripts.

set -euo pipefail

cd "$(dirname "$0")/.."

OUT="build/tether-bundle.tar.gz"
STAGE="build/tether"
BOARD="j714s"

die() { echo "ERROR: $*" >&2; exit 1; }

DTB="vendor/linux/arch/arm64/boot/dts/apple/t6050-$BOARD.dtb"
KERNEL="vendor/linux/arch/arm64/boot/Image.gz"

[ -d vendor/m1n1/proxyclient ] || die "vendor/m1n1 missing — run: make fetch"
[ -f "$KERNEL" ]               || die "$KERNEL missing — run: make kernel"
[ -f "$DTB" ]                  || die "$DTB missing — run: make dtbs"
[ -f build/initramfs.cpio.gz ] || die "initramfs missing — run: make initramfs"
[ -f build/m1n1-chain.bin ]    || die "build/m1n1-chain.bin missing — run: CHAINLOADING=1 scripts/build-m1n1.sh && cp vendor/m1n1/build/m1n1.bin build/m1n1-chain.bin"

echo "==> Staging $STAGE"
rm -rf "$STAGE"
mkdir -p "$STAGE/boot"

# proxyclient is pure python; ship it verbatim so the host needs no clone
cp -R vendor/m1n1/proxyclient "$STAGE/proxyclient"
find "$STAGE/proxyclient" -name '__pycache__' -type d -exec rm -rf {} + 2>/dev/null || true
cp vendor/m1n1/udev/80-m1n1.rules "$STAGE/"

# Live-hardware probes (guarded sysreg/MMIO from the m1n1 proxy) and the
# PMGR tree they check; they find proxyclient/ as their sibling.
mkdir -p "$STAGE/hv"
cp scripts/probes/*.py dt/t6050-pmgr.dtsi "$STAGE/hv/"

cp "$KERNEL"                 "$STAGE/boot/Image.gz"
cp "$DTB"                    "$STAGE/boot/t6050-$BOARD.dtb"
cp build/initramfs.cpio.gz   "$STAGE/boot/"
cp build/m1n1-chain.bin      "$STAGE/boot/"
[ -f build/m1n1-chain-payload.bin ] && cp build/m1n1-chain-payload.bin "$STAGE/boot/"

# earlycon=efifb: kernel log on the panel from setup_arch() on (patch 0001);
# pd_ignore_unused: T6050 SErrors when genpd powers off unclaimed domains
# (patch 0004 makes sync_state honour it). See mkpayload.sh for the rest.
# m5.root: switch_root to Arch on disk0s5 (scripts/provision-rootfs.sh); /init
# stays in the initramfs shell if it does not mount.
BOOTARGS="maxcpus=1 earlycon=efifb keep_bootcon console=tty0 loglevel=8 pd_ignore_unused clk_ignore_unused no_console_suspend nvme_apple.flush_interval=0 m5.root=/dev/nvme0n1p5"

cat > "$STAGE/boot-linux.sh" <<EOF
#!/bin/sh
# Boot the M5's kernel over the m1n1 proxy. Iterations are memory-only:
# nothing on the M5's disk is touched, and a failed boot just needs a
# power-cycle back into m1n1.
set -e
cd "\${0%/*}"
: "\${M1N1DEVICE:=/dev/m1n1}"
export M1N1DEVICE
if [ ! -e "\$M1N1DEVICE" ]; then
    echo "\$M1N1DEVICE is gone: the Mac is not sitting in the m1n1 proxy." >&2
    echo "This must run BEFORE ./boot-linux.sh - once Linux is entered the" >&2
    echo "USB gadget disappears. Power-cycle into m1n1, ./chainload.sh, then" >&2
    echo "re-run this." >&2
    exit 1
fi
exec ./proxyclient/tools/linux.py \\
    boot/Image.gz \\
    boot/t6050-$BOARD.dtb \\
    "\${INITRAMFS:-boot/initramfs.cpio.gz}" \\
    -b "\${BOOTARGS:-$BOOTARGS}" "\$@"
EOF

cat > "$STAGE/chainload.sh" <<'EOF'
#!/bin/sh
# Load a new m1n1 into RAM and jump to it (for iterating on m1n1 itself).
# Default target is the CHAINLOADING=1 build shipped in this bundle.
set -e
cd "${0%/*}"
: "${M1N1DEVICE:=/dev/m1n1}"
export M1N1DEVICE
if [ ! -e "$M1N1DEVICE" ]; then
    echo "$M1N1DEVICE is gone: the Mac is not sitting in the m1n1 proxy." >&2
    echo "Power-cycle into m1n1 (power-hold -> picker -> Omarchy), run" >&2
    echo "./chainload.sh, then re-run this before booting Linux." >&2
    exit 1
fi
exec ./proxyclient/tools/chainload.py -r "${1:-boot/m1n1-chain.bin}"
EOF

cat > "$STAGE/dump-adt.sh" <<'EOF'
#!/bin/sh
# Dump the *runtime* ADT that iBoot handed m1n1.
#
# This is not the same tree as the on-disk devicetree.img4: iBoot patches
# it before handing it over (different size, different properties), so
# offline analysis of the firmware file can be actively misleading.
# Send adt-runtime.bin back to the build host.
set -e
cd "${0%/*}"
: "${M1N1DEVICE:=/dev/m1n1}"
export M1N1DEVICE
if [ ! -e "$M1N1DEVICE" ]; then
    echo "$M1N1DEVICE is gone: the Mac is not sitting in the m1n1 proxy." >&2
    echo "Power-cycle into m1n1 (power-hold -> picker -> Omarchy), run" >&2
    echo "./chainload.sh, then re-run this before booting Linux." >&2
    exit 1
fi
exec ./proxyclient/tools/dump_adt.py "${1:-adt-runtime.bin}"
EOF

cat > "$STAGE/proxyclient/tools/dump_adt.py" <<'EOF'
#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
import sys, pathlib
sys.path.append(str(pathlib.Path(__file__).resolve().parents[1]))

out = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "adt-runtime.bin")

from m1n1.setup import *

data = u.get_adt()
out.write_bytes(data)
print(f"Wrote {len(data)} bytes to {out}")
EOF
chmod +x "$STAGE/proxyclient/tools/dump_adt.py" "$STAGE/dump-adt.sh"

cat > "$STAGE/dump-fdt.sh" <<EOF
#!/bin/sh
# Dump the *final, patched* FDT m1n1 hands to Linux.
#
# Not the input DTB and not the Apple ADT: this is the tree after every
# m1n1 fixup (CPU pruning, framebuffer node, initrd, bootargs, memory
# map). It does everything boot-linux.sh does EXCEPT the jump, so the
# machine stays in the proxy afterwards.
set -e
cd "\${0%/*}"
: "\${M1N1DEVICE:=/dev/m1n1}"
export M1N1DEVICE
if [ ! -e "\$M1N1DEVICE" ]; then
    echo "\$M1N1DEVICE is gone: the Mac is not sitting in the m1n1 proxy." >&2
    echo "This must run BEFORE ./boot-linux.sh - once Linux is entered the" >&2
    echo "USB gadget disappears. Power-cycle into m1n1, ./chainload.sh, then" >&2
    echo "re-run this." >&2
    exit 1
fi
exec ./proxyclient/tools/dump_fdt.py \\
    boot/t6050-$BOARD.dtb boot/initramfs.cpio.gz \\
    "\${BOOTARGS:-$BOOTARGS}" "\${1:-fdt-final.dtb}"
EOF

cat > "$STAGE/proxyclient/tools/dump_fdt.py" <<'EOF'
#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Dump the FDT m1n1 prepares for Linux, without booting it."""
import sys, pathlib, struct
sys.path.append(str(pathlib.Path(__file__).resolve().parents[1]))

dtb_path = pathlib.Path(sys.argv[1])
initramfs_path = pathlib.Path(sys.argv[2])
bootargs = sys.argv[3]
out = pathlib.Path(sys.argv[4] if len(sys.argv) > 4 else "fdt-final.dtb")

from m1n1.setup import *

dtb = dtb_path.read_bytes()
initramfs = initramfs_path.read_bytes()

# Mirror linux.py's setup so the fixups match a real boot exactly.
print(f'Setting boot args: "{bootargs}"')
p.kboot_set_chosen("bootargs", bootargs)

dtb_addr = u.malloc(len(dtb))
print(f"Loading DTB to 0x{dtb_addr:x}...")
iface.writemem(dtb_addr, dtb)

initramfs_base = u.memalign(65536, len(initramfs))
print(f"Loading {len(initramfs)} initramfs bytes to 0x{initramfs_base:x}...")
iface.writemem(initramfs_base, initramfs, True)
p.kboot_set_initrd(initramfs_base, len(initramfs))

if p.kboot_prepare_dt(dtb_addr):
    print("DT prepare failed")
    sys.exit(1)

fdt_addr = p.kboot_get_dt()
header = iface.readmem(fdt_addr, 8)
magic, totalsize = struct.unpack(">II", header)
if magic != 0xD00DFEED:
    sys.exit(f"Bad FDT magic 0x{magic:08x} at 0x{fdt_addr:x}")

data = iface.readmem(fdt_addr, totalsize)
out.write_bytes(data)
print(f"Wrote {totalsize} bytes of prepared FDT from 0x{fdt_addr:x} to {out}")
print("The machine is still in the proxy; nothing was booted.")
EOF
chmod +x "$STAGE/proxyclient/tools/dump_fdt.py" "$STAGE/dump-fdt.sh"

# Linux as a guest of the m1n1 hypervisor: the kernel console comes back
# over USB (/dev/m1n1-sec) and survives into userspace, and the host keeps
# a debugger. The guest is m1n1 + payloads, booted --raw at 0x800. Needs
# the patched m1n1 running (./chainload.sh): stock m1n1's hypervisor dies
# on T6050's locked VM_TMR_FIQ_ENA_EL2 (patches/m1n1/0002).
HV_BOOTARGS="maxcpus=1 earlycon console=tty0 console=ttySAC0 loglevel=8 pd_ignore_unused clk_ignore_unused no_console_suspend"
cat > "$STAGE/boot-hv.sh" <<EOF
#!/bin/sh
# Boot Linux under the m1n1 hypervisor. Run ./chainload.sh first, and keep a
# reader on the guest console: hv/vuart-log.py (logs to hv/vuart.log) or
# picocom /dev/m1n1-sec. Ctrl+C here drops into the hypervisor shell.
set -e
cd "\${0%/*}"
: "\${M1N1DEVICE:=/dev/m1n1}"
export M1N1DEVICE
if [ ! -e "\$M1N1DEVICE" ]; then
    echo "\$M1N1DEVICE is gone: the Mac is not sitting in the m1n1 proxy." >&2
    exit 1
fi
{
    cat boot/m1n1-chain.bin
    printf 'chosen.bootargs=%s\n' "\${BOOTARGS:-$HV_BOOTARGS}"
    cat boot/Image.gz boot/t6050-$BOARD.dtb boot/initramfs.cpio.gz
} > hv/guest-payload.bin
exec ./proxyclient/tools/run_guest.py -l hv/hv.log --raw hv/guest-payload.bin "\$@"
EOF

chmod +x "$STAGE/boot-linux.sh" "$STAGE/chainload.sh" "$STAGE/boot-hv.sh"

cat > "$STAGE/README.md" <<EOF
# omarchy-m5 tether bundle

Drives a MacBook Pro M5 Pro (J714s / T6050) sitting in m1n1 proxy mode
from this Linux host over USB-C.

## Host setup (Arch)

    sudo pacman -S --needed python python-pyserial python-construct
    sudo cp 80-m1n1.rules /etc/udev/rules.d/
    sudo udevadm control --reload

The rule matches m1n1's USB gadget (1209:316d) and creates:

  * \`/dev/m1n1\`     — proxy channel (what the tools talk to)
  * \`/dev/m1n1-sec\` — m1n1's own console output

Your user needs read/write on those: \`sudo usermod -aG uucp \$USER\`,
then re-login. Without the udev rule, pass \`M1N1DEVICE=/dev/ttyACM0\`.

## Boot Linux (the normal loop)

    ./boot-linux.sh

Override the cmdline without repacking:

    BOOTARGS="... initcall_debug" ./boot-linux.sh   # start from the default in boot-linux.sh

The kernel log is drawn on the M5's own panel below the marker bands by
\`earlycon=efifb\` from early setup_arch() on, and by fbcon once simpledrm
binds - no cable needed. \`keep_bootcon\` keeps both, so a crash before
fbcon is still readable. m1n1's messages land on \`/dev/m1n1-sec\`
(\`picocom -b 1500000 /dev/m1n1-sec\`).

## Boot Linux under the hypervisor (console over USB)

    ./chainload.sh                 # the patched m1n1 hosts the hypervisor
    hv/vuart-log.py /dev/m1n1-sec hv/vuart.log &   # or: picocom /dev/m1n1-sec
    ./boot-hv.sh

The guest's \`console=ttySAC0\` is the hypervisor's virtual UART, so the
kernel log and the \`/init\` shell are on \`/dev/m1n1-sec\` - interactive,
and still there after Linux takes over. Ctrl+C in \`boot-hv.sh\` gives the
hypervisor shell (registers, memory, MMIO tracing). The guest runs at EL1,
single core.

## Iterate on m1n1 itself

    ./chainload.sh                     # the bundled CHAINLOADING=1 build
    ./chainload.sh boot/m1n1-chain-payload.bin   # m1n1 + kernel + dt + initramfs

After \`chainload.sh\` the new m1n1 re-enumerates its USB gadget and drops
back into proxy mode, so run \`./boot-linux.sh\` again afterwards.

## Where we are: the kernel boots

The previous build answered the big question: **red, green, blue and white
all appeared.** Linux entered, enabled the MMU, parsed our devicetree,
finished \`paging_init()\` and reached \`console_init()\` — so AIC, the
timers, memblock and the DT are all working. This is not a boot failure
any more; it is purely a console problem.

So this build extends the bands along the console chain itself. Each band
is 16 rows of 256 px down the left edge:

| rows | colour | meaning |
|------|--------|---------|
| 0-15    | RED     | kernel entry (\`head.S\`, MMU **off**) — *confirmed* |
| 16-31   | GREEN   | C running, MMU on, before the DT is parsed — *confirmed* |
| 32-47   | BLUE    | \`paging_init()\` returned — *confirmed* |
| 48-63   | WHITE   | reached \`console_init()\` — *confirmed* |
| 64-79   | CYAN    | **simpledrm probed the framebuffer successfully** |
| 80-95   | MAGENTA | **fbcon took over the console** |
| 96-111  | ORANGE  | \`kernel_init\` is about to exec \`/init\` |
| 112-127 | BLUE    | **/init is running** (painted from userspace via /dev/mem) |
| 128-143 | WHITE   | /dev/fb0 or /dev/dri/card0 exists |
| 144-159 | YELLOW  | painted by m1n1 before the jump (control) |

Reading the new bands:

- no cyan            -> simpledrm never bound the \`/chosen/framebuffer\`
  node; the DRM device does not exist, so nothing can draw
- cyan, no magenta   -> the framebuffer exists but fbcon never took the
  console, so \`console=tty0\` stayed on dummycon
- cyan + magenta, still no text -> the console is bound and drawing
  somewhere we cannot see (wrong base/stride/format in the handed-over
  framebuffer node)
- orange + blue(112) -> userspace is alive; the kernel booted end to end
  and only the console path is broken
- blue(112) + white(128) -> even the device nodes are present

If userspace comes up, \`/init\` also prints \`dmesg | grep drm\` and the
contents of /dev/dri — worth photographing if any text ever appears.

One caveat, stated up front so it is not mistaken for evidence: the red
band is written with the MMU off, which is uncached — *unless* m1n1 enters
the kernel with the MMU and caches still on, in which case that store can
sit in a dirty cache line and never reach the panel. So "green but no red"
means the entry store was absorbed, **not** that entry was skipped. Every
other marker uses a Device-nGnRE mapping and has no such ambiguity.

    ./chainload.sh && ./boot-linux.sh

Then photograph the left edge of the panel and report which bands appear.

## Dumping the final FDT

    ./dump-fdt.sh          # -> fdt-final.dtb, send it to the build host

This is the tree **after** every m1n1 fixup (CPU pruning, framebuffer node,
initrd, bootargs, memory map) — not the input DTB and not the ADT. It does
everything \`boot-linux.sh\` does except the jump, so the machine stays in
the proxy and you can run it back to back with a boot attempt.

## Dumping the runtime ADT

    ./dump-adt.sh          # -> adt-runtime.bin, send it to the build host

The runtime tree is **not** the on-disk \`devicetree.img4\`: iBoot patches
it first (737280 bytes at runtime vs 835984 on disk), and the two disagree
about this very DART. Analyze only the runtime dump.

## Expected noise on first boot

m1n1 prints \`Starting CPU n …  Failed!\` for every secondary. SMP is known
broken on T6050 — secondaries never execute the reset vector. It is
bounded (100 ms per core, ~1.4 s total) and not fatal; that is why the
kernel cmdline pins \`maxcpus=1\`.

Success looks like the initramfs banner
("omarchy-m5: userspace is alive on T6050") on the M5's panel.
EOF

echo "==> Packing $OUT"
tar -czf "$OUT" -C build tether
rm -rf "$STAGE"

ls -lh "$OUT"
echo
echo "Copy to the ThinkPad:"
echo "  scp $OUT <host>:"
echo "  ssh <host> 'tar xzf tether-bundle.tar.gz && cat tether/README.md'"
