# Phase 1 bring-up guide — m1n1 → kernel → TTY on M5 Pro

The dev loop is tethered: an installed stage-1 m1n1 chainloads test builds
over USB, so kernel/DT iterations never touch boot policy. Partitioning and
`kmutil` happen once, up front; everything after is memory-only.

## Host setup (this Mac)

```sh
make setup    # brew llvm/lld/dtc/bc/bison/flex/openssl + rust aarch64 target
make fetch    # clone vendor/m1n1 (main) + vendor/linux (asahi-wip-7.2)
make m1n1     # CHAINLOADING=1 build -> vendor/m1n1/build/m1n1.bin
make dtbs     # overlay dt/ into the kernel tree, build t6050 DTBs only
make kernel   # full kernel (defconfig; KCONFIG=asahi_defconfig to override)
```

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

## Filling the DT TODOs

`dt/t6050.dtsi` / `t6050-pmgr.dtsi` carry `TODO(adt)` markers for every
value not yet verified. On the device, via m1n1 proxyclient:

```sh
vendor/m1n1/proxyclient/tools/dump_pmgr.py      # PMGR device table
vendor/m1n1/proxyclient/tools/pmgr_adt2dt.py    # emits pmgr dtsi nodes
# ADT interrupt numbers, GPIO pin counts, AIC event region: read the ADT
# directly (proxyclient `adt` object) or ioreg -lw0 on macOS.
```

Known-verified values already in the DTs (from J716c ioreg dump +
m1n1 source): uart0 0x505200000, AIC 0x280400000/0x1cc000, PMGR
0x280600000/0x1fc000, wdt 0x28836c000, dockchannel 0x288e28000,
i2c0-2 0x50501{0,4,8}000, spi2/spi4 0x5051{08,10}0000,
pinctrls 0x2881e4000/0x290824000/0x29c000000, CPU MPIDRs and PMGR
CPU/cluster power-state offsets.

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
