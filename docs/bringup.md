# Phase 1 bring-up guide — m1n1 → kernel → TTY on M5 Pro

The dev loop is tethered: an installed stage-1 m1n1 chainloads test builds
over USB, so kernel/DT iterations never touch boot policy. Partitioning and
`kmutil` happen once, up front; everything after is memory-only.

```sh
make setup    # brew llvm/lld/dtc/bc/bison/flex/openssl/make/gnu-sed
              # + rust aarch64-unknown-none-softfloat target
make fetch    # clone vendor/m1n1 (main) + vendor/linux (asahi-wip-7.2)
make m1n1     # CHAINLOADING=1 build -> vendor/m1n1/build/m1n1.bin
make dtbs     # overlay dt/ into the kernel tree, build t6050 DTBs only
make kernel   # full kernel (defconfig; KCONFIG=asahi_defconfig to override)
```

macOS quirks handled by the scripts: GNU Make/sed over the BSD versions
(kernel scripts use GNU sed syntax BSD sed silently passes through), and
`scripts/host-shim/` supplies the glibc headers macOS lacks (`elf.h` —
vendored musl copy — `byteswap.h`, `copy_file_range`, `O_LARGEFILE`).

## One-time on-device step (the risky part — do it once, carefully)

Per `docs/research/dualboot-partitioning.md` §7, the manual path:

1. `diskutil apfs resizeContainer disk0s2 <newsize>` — shrink macOS.
2. `diskutil addPartition disk0s2 apfs Omarchy 2.5GB` — stub container.
3. Populate the stub (System/Data/Preboot/Recovery volumes, copy
   `AdminUserRecoveryInfo.plist` from macOS Preboot).
4. Boot the stub's **paired** recoveryOS via 1TR (hold power button).
5. `bputil -nc -v <vgid>` — Permissive Security + custom kernel.
6. `kmutil configure-boot -c m1n1.bin --raw --entry-point 2048
   --lowest-virtual-address 0 -v <stub system volume>`
   (build with `CHAINLOADING=0` for this installed image).

After this, the machine boots iBoot → m1n1 stage1 → proxy mode on the
USB-C DFU/debug port. **Never** re-run kmutil for iterations — chainload.

## Dev loop (every iteration)

```sh
# terminal 1: m1n1 proxy console over USB-C
vendor/m1n1/proxyclient/tools/chainload.py build/m1n1-test.bin   # in vendor/m1n1
# or boot a kernel directly:
vendor/m1n1/proxyclient/tools/linux.py \
    --kernel vendor/linux/arch/arm64/boot/Image \
    --dtb    vendor/linux/arch/arm64/boot/dts/apple/t6050-j714s.dtb \
    --initramfs <initramfs> \
    --bootargs "maxcpus=1 earlycon console=ttyS0"
```

Kernel cmdline for first boots: `maxcpus=1` (SMP is broken — secondaries
never execute the reset vector), plus the M4+ WFI workaround (`idle=` param
from linux-next, or m1n1 PR #672's auto-disable).

Console: dockchannel-UART (m1n1 secondary channel) and/or simplefb on the
panel. Serial0 (0x505200000) is the Samsung UART — needs the debug cable.

## DT state (populated from the real J714s ADT)

`dt/t6050-pmgr.dtsi` is generated, not hand-written:

1. Extract the ADT: `devicetree.img4` lives in the booted OS's Preboot at
   `usr/standalone/firmware/devicetree.img4`. Strip the IM4P header and
   LZFSE-decompress the `bvx2` payload (macOS `libcompression` handles it).
2. `scripts/adt2pmgr.py adt.bin > dt/t6050-pmgr.dtsi` — a fixed fork of
   m1n1's `pmgr_adt2dt.py` (upstream crashes on T6050's die-level parent
   IDs 219/325/609, which have no device entry).

Verified on J714s (macOS 26.5): 405 power domains across 6 PMGR blocks;
real IRQs/npins for uart/i2c/spi/gpio/wdt/dockchannel; CPU topology
15 cores (5+5+5, binned — cpu5/cpu11/cpu17 disabled in the board DTS).
Remaining TODO(adt) markers: AIC event region, PMU FIQ affinities,
pinmux tables, which SPI bus carries keyboard/trackpad.

Note: ADT `reg` values sit 0x2_0000_0000 below the MMIO address on this
SoC (uart0 ADT 0x305200000 → MMIO 0x505200000, matching m1n1's
EARLY_UART_BASE). Apply the same offset when converting new nodes.

## Success metric

Reproducible boot to getty: single core, on-device display (simplefb) or
dockchannel console, NVMe rootfs optional for the first milestone.

## References

- `docs/PLAN.md` — phase plan
- `docs/research/kernel-boot-m5.md` — blockers (SMP, WFI, NVMe fwabi)
- `docs/research/dualboot-partitioning.md` — stub/1TR/kmutil mechanics
- qspqww/m1n1 `t6050-j716c-bringup` — real-hardware M5 Pro/Max notes
  (findings.md, bringup/t6050-j716c/LINUX_PC_BRINGUP_GUIDE.md)
- ImAtomiskk/asahim5 — t8142 (base M5) DT + ADT dump, closest public
  reference for what a hand-authored M5-gen DT looks like
