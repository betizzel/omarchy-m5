#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Try a variant of the T6050 secondary release with breadcrumb traps at both
places a core could plausibly come up: the locked RVBAR (m1n1 vector slot 0)
and iBoot's 48 KiB WFI sled (the secondary-only CTRR_C window). Installed
stage-1 m1n1 only, watchdog armed:

    hv/wdt-arm.py 90
    hv/smp-release-try.py VARIANT cpuN

Variants (PMGR CPU_START block SB = pmgr reg[0] + 0x88000):
  plain       SB+0x4 = BIT(cpu-id); SB+0x8+4*cl = BIT(core)      (XNU/m1n1)
  stop-w1c    SB+0x0 = BIT(cpu-id) first, then plain
  stop-zero   SB+0x0 = 0 first, then plain
  start-only  SB+0x8+4*cl = BIT(core) only
  acc         64-bit 1 -> cpm-impl-reg+0x40f8 of the core's cluster (macOS
              restoreACC), then plain

Prints the CPU_START block, the core's PMGR power state and impl+0x100 status
before and after, then any crumbs (MPIDR + where it came from + CurrentEL).
"""
import sys, time, pathlib
sys.path.append(str(pathlib.Path(__file__).resolve().parents[1] / "proxyclient"))
from m1n1.setup import *
from m1n1.asm import ARMAsm

VARIANTS = ("plain", "stop-w1c", "stop-zero", "start-only", "acc")
if len(sys.argv) != 3 or sys.argv[1] not in VARIANTS:
    sys.exit(f"usage: {sys.argv[0]} {{{','.join(VARIANTS)}}} cpuN")
variant, name = sys.argv[1], sys.argv[2]

adt = u.adt
cpus = {c.name: c for c in adt["/cpus"] if c.name.startswith("cpu") and c.name != "cpus"}
c = cpus[name]
assert c.state != "running", "pick a secondary"
base = u.base
im = c.cpu_impl_reg[0]
assert (p.read64(im) & 0xffffffffff000) == base, "RVBAR is not this m1n1: use the stage-1"
pmgr = adt["/arm-io/pmgr"]
pmgr0 = pmgr.get_reg(0)[0]
sb = pmgr0 + 0x88000
dev = next(d for d in pmgr.devices if str(d.name) in (f"MCPU{c.cluster_id}_{c.cluster_core_id}",
                                                       f"PCPU_{c.cluster_core_id}")
           and (str(d.name).startswith("P") == (c.cluster_type == "P")))
lwr, upr = u.mrs((3, 0, 11, 0, 0)), u.mrs((3, 0, 11, 0, 1))
size = upr + 0x1000 - lwr
assert 0 < size <= 0x10000

buf = u.memalign(0x4000, 0x4000)
p.memset32(buf, 0, 0x4000)
p.dc_civac(buf, 0x4000)


def crumb_stub(addr, tag):
    return ARMAsm(f"""
    mov  x9, x30
    ldr  x0, crumbs
    mrs  x1, mpidr_el1
    ubfx x2, x1, #0, #8
    ubfx x3, x1, #8, #8
    ubfx x4, x1, #16, #1
    orr  x2, x2, x3, lsl #3
    orr  x2, x2, x4, lsl #5
    add  x0, x0, x2, lsl #5
    str  x1, [x0]
    str  x9, [x0, #8]
    mrs  x5, CurrentEL
    orr  x5, x5, #{tag}
    str  x5, [x0, #16]
    dsb  sy
1:  wfe
    b    1b
    .align 3
crumbs: .quad {buf:#x}
""", addr).data


def mmu_off_write(addr, data):
    flags = p.mmu_disable()
    try:
        iface.writemem(addr, data)
    finally:
        p.mmu_restore(flags)
    p.dc_civac(addr, len(data))
    p.ic_ivau(addr, len(data))


# trap 1: RVBAR (vector slot 0); tag 0x100 in the CurrentEL word
slot0 = iface.readmem(base, 0x80)
s = crumb_stub(base, 0x100)
assert len(s) <= 0x80
mmu_off_write(base, s)
# trap 2: the sled, as a bl-sled into a stub at its end; tag 0x200
sled_orig = iface.readmem(lwr, size)
stub_addr = lwr + size - 0x100
sled = bytearray()
for a in range(lwr, stub_addr, 4):
    sled += (0x94000000 | (((stub_addr - a) >> 2) & 0x3ffffff)).to_bytes(4, "little")
s = crumb_stub(stub_addr, 0x200)
sled += s + b"\0" * (0x100 - len(s))
iface.writemem(lwr, bytes(sled))
p.dc_civac(lwr, size)
p.ic_ivau(lwr, size)


def state(label):
    blk = " ".join(f"+{o:#x}={p.read32(sb + o):#x}" for o in range(0, 0x1c, 4))
    print(f"  {label:<7} {blk}")
    print(f"  {'':<7} pmgr {dev.name}={p.read32(pmgr0 + dev.offset):#x}  "
          f"status={p.read64(im + 0x100):#x}")


print(f"{variant} on {name} (cpu-id {c.cpu_id}, cluster {c.cluster_id} core {c.cluster_core_id}, "
      f"{c.cluster_type}); traps at RVBAR {base:#x} and sled [{lwr:#x}, {lwr + size:#x})")
state("before")
if variant == "stop-w1c":
    p.write32(sb + 0x0, 1 << c.cpu_id)
    state("+0 w1c")
elif variant == "stop-zero":
    p.write32(sb + 0x0, 0)
    state("+0 = 0")
elif variant == "acc":
    cpm = c.cpm_impl_reg[0]
    p.write64(cpm + 0x40f8, 1)
    print(f"  wrote 1 -> {cpm + 0x40f8:#x}")
if variant != "start-only":
    p.write32(sb + 0x4, 1 << c.cpu_id)
p.write32(sb + 0x8 + 4 * c.cluster_id, 1 << c.cluster_core_id)
time.sleep(0.05)
state("after")
time.sleep(0.3)
state("+350ms")

p.dc_ivac(buf, 0x4000)
hits = 0
for i in range(64):
    mp = p.read64(buf + 32 * i)
    if mp:
        hits += 1
        ret, el = p.read64(buf + 32 * i + 8), p.read64(buf + 32 * i + 16)
        where = "RVBAR" if el & 0x100 else f"sled+{ret - 4 - lwr:#x}"
        print(f"  CRUMB slot {i}: MPIDR {mp:#x} at {where} EL{el >> 2 & 3}")
print(f"  {hits} crumb(s)")

mmu_off_write(base, slot0)
iface.writemem(lwr, sled_orig)
p.dc_civac(lwr, size)
p.ic_ivau(lwr, size)
print("traps removed")
