#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Do released T6050 secondaries come up inside iBoot's WFI sled instead of at
their locked RVBAR? M5 in the installed stage-1 m1n1, watchdog armed:

    hv/wdt-arm.py 90
    hv/smp-sled-crumb.py [cpu1 ...] [--ipi]

The secondary-only CTRR_C window ([CTRR_C_LWR_EL1, CTRR_C_UPR_EL1 + 4K), 48 KiB
ending at top_of_kernel_data) holds nothing but `wfi`. Secondaries cannot
write it; the boot core can. This turns it into a branch sled: every word
becomes `bl stub`, and the stub (in the last 0x100 bytes) stores the core's
MPIDR, its return address (= where in the window it was) and CurrentEL into a
DRAM buffer, then parks in WFE. Then it releases the listed cores (XNU's PMGR
sequence) and, with --ipi, also sends each one a fast IPI (a pending
interrupt wakes WFI even when masked). Afterwards the window gets its original
contents back.

Crumbs from a released core mean the hidden reset vector points into the
sled: m1n1 could then plant a branch to its own vectors there.
"""
import sys, time, pathlib
sys.path.append(str(pathlib.Path(__file__).resolve().parents[1] / "proxyclient"))
from m1n1.setup import *
from m1n1.asm import ARMAsm

IPI = "--ipi" in sys.argv
names = [a for a in sys.argv[1:] if not a.startswith("--")] or ["cpu1"]

adt = u.adt
cpus = {c.name: c for c in adt["/cpus"] if c.name.startswith("cpu") and c.name != "cpus"}
lwr, upr = u.mrs((3, 0, 11, 0, 0)), u.mrs((3, 0, 11, 0, 1))
top = u.ba.top_of_kernel_data
size = upr + 0x1000 - lwr
print(f"CTRR_C window [{lwr:#x}, {lwr + size:#x}) = {size:#x} bytes; top_of_kernel_data {top:#x}")
if not (0 < size <= 0x10000 and lwr % 0x1000 == 0):
    sys.exit("unexpected CTRR_C window; refusing to write")

orig = iface.readmem(lwr, size)
nwfi = sum(1 for i in range(0, size, 4) if orig[i:i + 4] == b"\x7f\x20\x03\xd5")
print(f"window holds {nwfi} wfi of {size // 4} words")

buf = u.memalign(0x4000, 0x4000)
p.memset32(buf, 0, 0x4000)
p.dc_civac(buf, 0x4000)

stub_addr = lwr + size - 0x100
stub = ARMAsm(f"""
    mov  x9, x30               // bl from the sled: return address = slot + 4
    ldr  x0, crumbs
    mrs  x1, mpidr_el1
    ubfx x2, x1, #0, #8
    ubfx x3, x1, #8, #8
    ubfx x4, x1, #16, #1
    orr  x2, x2, x3, lsl #3
    orr  x2, x2, x4, lsl #5
    add  x0, x0, x2, lsl #5    // 32 bytes per core
    str  x1, [x0]
    str  x9, [x0, #8]
    mrs  x5, CurrentEL
    str  x5, [x0, #16]
    dsb  sy
1:  wfe
    b    1b
    .align 3
crumbs: .quad {buf:#x}
""", stub_addr)
assert len(stub.data) <= 0x100

sled = bytearray()
for a in range(lwr, stub_addr, 4):
    imm26 = ((stub_addr - a) >> 2) & 0x3ffffff
    sled += (0x94000000 | imm26).to_bytes(4, "little")          # bl stub
sled += stub.data + b"\x00" * (0x100 - len(stub.data))
assert len(sled) == size

iface.writemem(lwr, bytes(sled))
p.dc_civac(lwr, size)
p.ic_ivau(lwr, size)
assert iface.readmem(lwr, 16) == bytes(sled[:16])
print(f"window is now a bl-sled into the stub at {stub_addr:#x}; crumbs at {buf:#x}")

sb = adt["/arm-io/pmgr"].get_reg(0)[0] + 0x88000
for n in names:
    c = cpus[n]
    im = c.cpu_impl_reg[0]
    before = p.read64(im + 0x100)
    p.write32(sb + 4, 1 << c.cpu_id)
    p.write32(sb + 8 + 4 * c.cluster_id, 1 << c.cluster_core_id)
    time.sleep(0.02)
    print(f"released {n:<6} (type {c.cluster_type}): status {before:#x} -> {p.read64(im + 0x100):#x}")

if IPI:
    boot = next(c for c in cpus.values() if c.state == "running")
    for n in names:
        c = cpus[n]
        if c.cluster_id == boot.cluster_id:   # IPI_RR_LOCAL_EL1: core in this cluster
            u.msr((3, 5, 15, 0, 0), c.cluster_core_id)
        else:                                  # IPI_RR_GLOBAL_EL1: cluster << 16 | core
            u.msr((3, 5, 15, 0, 1), (c.cluster_id << 16) | c.cluster_core_id)
        print(f"fast IPI -> {n}")

time.sleep(0.3)
p.dc_ivac(buf, 0x4000)
hits = []
for i in range(64):
    mp, ret, el = p.read64(buf + 32 * i), p.read64(buf + 32 * i + 8), p.read64(buf + 32 * i + 16)
    if mp:
        hits.append(i)
        print(f"  crumb {i:2d}: MPIDR {mp:#x}  came from window+{ret - 4 - lwr:#x}  "
              f"CurrentEL {el >> 2 & 3}")
if not hits:
    print("  no crumbs: nothing executed in the window")

iface.writemem(lwr, orig)
p.dc_civac(lwr, size)
p.ic_ivau(lwr, size)
print("window restored")
