#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Does a released T6050 secondary execute *anything* at its locked RVBAR?
Run on the installed stage-1 m1n1 (not after a chainload), M5 in the proxy:

    hv/wdt-arm.py 60
    hv/smp-reset-crumb.py [cpu1 cpu2 ...] [--wdt]

RVBAR (cpu-impl-reg+0, locked by iBoot) points at m1n1's base, i.e. vector
slot 0 of _vectors_start, which only ever runs on reset ("b cpu_reset"; m1n1
itself takes exceptions on SPx, slots 0x200+). This script swaps slot 0 for a
stack-free, MMU-off-safe stub that stores the core's MPIDR into a DRAM
buffer (cleaned+invalidated beforehand, invalidated again before reading),
then parks in WFE. With --wdt the stub also arms the watchdog for a 3 s reset:
an M5 that resets ~3 s after the release proves execution even if the DRAM
store were invisible.

The release is XNU's configMiscCores sequence on PMGR reg[0]+0x88000:
+0x4 = BIT(cpu-id), then +0x8+4*cluster = BIT(core-in-cluster). One-shot per
core per boot. Slot 0 is restored afterwards.
"""
import sys, time, pathlib
sys.path.append(str(pathlib.Path(__file__).resolve().parents[1] / "proxyclient"))
from m1n1.setup import *
from m1n1.asm import ARMAsm

WDT = "--wdt" in sys.argv
names = [a for a in sys.argv[1:] if not a.startswith("--")] or ["cpu1", "cpu2", "cpu3", "cpu4"]

adt = u.adt
cpus = {c.name: c for c in adt["/cpus"] if c.name.startswith("cpu") and c.name != "cpus"}
for n in names:
    if cpus[n].state == "running":
        sys.exit(f"{n} is the boot core")

base = u.base
rv = {n: p.read64(cpus[n].cpu_impl_reg[0]) for n in names}
for n, v in rv.items():
    if (v & 0xffffffffff000) != base:
        sys.exit(f"{n}: RVBAR {v:#x} does not point at this m1n1 ({base:#x}); "
                 "run this on the installed stage-1, not after a chainload")

buf = u.memalign(0x4000, 0x4000)
p.memset32(buf, 0, 0x4000)
p.dc_civac(buf, 0x4000)

wdt_base = adt["/arm-io/wdt"].get_reg(0)[0]
stub = ARMAsm(f"""
    ldr  x0, crumbs
    mrs  x1, mpidr_el1
    ubfx x2, x1, #0, #8        // Aff0: core in cluster
    ubfx x3, x1, #8, #8        // Aff1: cluster
    ubfx x4, x1, #16, #1       // Aff2 bit0: P (1) vs M (4) type
    orr  x2, x2, x3, lsl #3
    orr  x2, x2, x4, lsl #5
    str  x1, [x0, x2, lsl #3]
    dsb  sy
    ldr  w5, arm_wdt
    cbz  w5, 1f
    ldr  x0, wdt
    ldr  w1, alarm
    str  w1, [x0, #0x14]
    str  wzr, [x0, #0x10]
    mov  w1, #4
    str  w1, [x0, #0x1c]
    dsb  sy
1:  wfe
    b    1b
    .align 3
crumbs:  .quad {buf:#x}
wdt:     .quad {wdt_base:#x}
alarm:   .word {3 * 24_000_000}
arm_wdt: .word {1 if WDT else 0}
""", base)
assert len(stub.data) <= 0x80, f"stub is {len(stub.data)} bytes, slot 0 holds 0x80"

def write_slot0(data):
    # m1n1 maps its own text read-only (a cached write data-aborts), so write
    # the vector page with the MMU off: straight to DRAM, which is also where
    # an MMU-off secondary fetches it from. Then drop any clean cached copy.
    flags = p.mmu_disable()
    try:
        iface.writemem(base, data)
    finally:
        p.mmu_restore(flags)
    p.dc_civac(base, 0x80)
    p.ic_ivau(base, 0x80)


orig = iface.readmem(base, 0x80)
write_slot0(stub.data)
assert iface.readmem(base, len(stub.data)) == stub.data, "slot 0 write did not stick"
print(f"m1n1 base {base:#x}: slot 0 now holds the {len(stub.data)}-byte crumb stub; "
      f"crumbs at {buf:#x}{'; stub arms a 3 s watchdog reset' if WDT else ''}")

sb = adt["/arm-io/pmgr"].get_reg(0)[0] + 0x88000
for n in names:
    c = cpus[n]
    im = c.cpu_impl_reg[0]
    before = p.read64(im + 0x100)
    p.write32(sb + 4, 1 << c.cpu_id)
    p.write32(sb + 8 + 4 * c.cluster_id, 1 << c.cluster_core_id)
    time.sleep(0.02)
    print(f"released {n:<6} (type {c.cluster_type}, cpu-id {c.cpu_id}, cluster {c.cluster_id} "
          f"core {c.cluster_core_id}): status {before:#x} -> {p.read64(im + 0x100):#x}")

time.sleep(0.2)
p.dc_ivac(buf, 0x4000)
hits = [(i, v) for i in range(64) if (v := p.read64(buf + 8 * i))]
print("\ncrumbs (MPIDR written by a core that ran our reset code):")
for i, v in hits:
    print(f"  slot {i:2d}: MPIDR {v:#x}")
if not hits:
    print("  none: no released core executed the instruction at its RVBAR")

write_slot0(orig)
print("slot 0 restored")
