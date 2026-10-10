#!/usr/bin/env python3
"""T6050 SMP read-only probe. Run from the tether bundle with the M5 sitting in
m1n1 proxy mode (same place as hv/probe-pmgr.py), BEFORE starting any secondary:

    python3 hv/t6050-smp-probe.py            # P0: tables only, nothing is written
    python3 hv/t6050-smp-probe.py --dbg      # + external-debug regs of the BOOT core only
    python3 hv/t6050-smp-probe.py --dbg-all  # + same for the offline cores (may hang the bus!)

Every MMIO read goes through u.exec() behind m1n1's exception guard with a
dsb/isb, exactly like probe-pmgr.py, so an SError is reported, not fatal.
(A *store* to an auto-gated block hangs the machine; this script never stores.)

What it answers (findings: docs/HANDOFF.md "SMP"; raw output in docs/research/probe-logs/):
  1. is RVBAR identical, locked and == m1n1's _vectors_start page for all 15 cores?
  2. what does impl+0x100 (per-core status) look like for every core at rest?
  3. what do the PMGR CPU_START words (+0x88000) and MCPU/PCPU/MCPM power states say?
  4. where is the CTRR "SMP-RO" window (s3_0_c11_c0_{0,1}, c1_4) relative to m1n1's image,
     and what is in it (candidate home of the firmware's per-core boot data)?
  5. expected MPIDR per core (Aff2 = type bit, Aff1 = cluster, Aff0 = core) for the DT.
"""
import sys, json, re, pathlib
sys.path.append(str(pathlib.Path(__file__).resolve().parents[1] / "proxyclient"))
from m1n1.setup import *
from m1n1.proxy import ProxyError

DBG = "--dbg" in sys.argv or "--dbg-all" in sys.argv
DBG_ALL = "--dbg-all" in sys.argv

LD64 = "ldr x0, [x0]\n dsb sy\n isb"
LD32 = "ldr w0, [x0]\n dsb sy\n isb"


def rd64(addr):
    try:
        return u.exec(LD64, addr, silent=True)
    except ProxyError:
        return None


def rd32(addr):
    try:
        return u.exec(LD32, addr, silent=True) & 0xffffffff
    except ProxyError:
        return None


def mrs(reg):
    try:
        return u.mrs(reg, silent=True)
    except ProxyError:
        return None


def h(v, w=0):
    return "SERROR" if v is None else f"{v:#0{w}x}" if w else f"{v:#x}"


adt = u.adt
chip = adt["/chosen"].chip_id
mpidr = u.mrs(MPIDR_EL1)
print(f"chip-id {chip:#x}  boot MPIDR_EL1 = {mpidr:#x}  (Aff2={mpidr >> 16 & 0xff:#x} Aff1={mpidr >> 8 & 0xff} Aff0={mpidr & 0xff})")
print(f"m1n1 base u.base = {u.base:#x}  (RVBAR page of a chainloaded raw image == u.base)")

TYPE_BIT = {"E": 0x0, "P": 0x1, "M": 0x4}

# ---------------------------------------------------------------- 1/2/5: per-core table
print("\n== cores (ADT /cpus)  RVBAR=impl+0x0, status=impl+0x100")
print(f"{'cpu':<6}{'state':<9}{'reg':>7} {'exp.MPIDR[23:0]':>16}  {'RVBAR raw':>20} {'==u.base?':>9}  {'status @+0x100':>20}  impl")
rows = []
for cpu in adt["/cpus"]:
    if not cpu.name.startswith("cpu") or cpu.name == "cpus":
        continue
    impl = cpu.cpu_impl_reg[0]
    exp = (TYPE_BIT.get(cpu.cluster_type, 0) << 16) | (cpu.cluster_id << 8) | cpu.cluster_core_id
    rv = rd64(impl)
    st = rd64(impl + 0x100)
    same = "-" if rv is None else ("yes" if (rv & 0xffffffff000) == (u.base & ~0xfff) else "NO")
    print(f"{cpu.name:<6}{cpu.state:<9}{cpu.reg:>#7x} {exp:>#16x}  {h(rv, 18):>20} {same:>9}  {h(st, 18):>20}  {impl:#x}")
    rows.append(dict(name=cpu.name, cpu_id=cpu.cpu_id, state=cpu.state, reg=cpu.reg, exp_mpidr=exp, rvbar=rv, status=st))
locked = {r["rvbar"] for r in rows if r["rvbar"] is not None}
print("distinct RVBAR values:", [hex(x) for x in sorted(locked)])
print("bit0 (LOCK) set on all:", all(r["rvbar"] is not None and r["rvbar"] & 1 for r in rows))

# ---------------------------------------------------------------- 3: PMGR start block + power states
pmgr = adt["/arm-io/pmgr"]
pmgr0 = pmgr.get_reg(0)[0]
off = 0x88000 if chip in (0x6031, 0x6032, 0x6034, 0x6040, 0x6041, 0x6050, 0x6051) else None
print(f"\n== PMGR CPU_START block  (pmgr reg0 = {pmgr0:#x}, +{off:#x} on this chip)")
if off is not None:
    base = pmgr0 + off
    labels = {0x0: "stop", 0x4: "core-alive (W1C? 18 bits)", 0x8: "start cluster0", 0xC: "start cluster1", 0x10: "start cluster2", 0x14: "?", 0x18: "?"}
    for o, lab in labels.items():
        print(f"  +{o:#04x} {lab:<28} = {h(rd32(base + o), 10)}")

print("\n== PMGR power states of the CPU devices (target<<0, actual<<4; 0x1f0 = on)")
for d in pmgr.devices:
    n = str(d.name)
    if re.fullmatch(r"[MP]CPU\d*_\d+|MCPM\d|PCPM", n):
        print(f"  {n:<9} @ {pmgr0 + d.offset:#x} = {h(rd32(pmgr0 + d.offset), 10)}")

# ---------------------------------------------------------------- 4: CTRR / SMP-RO window
print("\n== CTRR 'SMP-RO' window (M4+: enabled on secondaries only; kboot.c reserves it)")
# The CTRR sysreg naming moved around upstream: PR #657 first used s3_0_c11_c0_{0,1}, then
# s3_0_c11_c1_{0,1} (the vendor tree), current main calls s3_0_c11_c0_{0,1} "CTRR_C_{LWR,UPR}".
# Read the whole s3_0_c11_c{0,1}_{0..5} grid and use the first pair that looks like a DRAM range.
grid = {(c, e): mrs((3, 0, 11, c, e)) for c in (0, 1, 2) for e in range(6)}
for (c, e), v in grid.items():
    if v:
        print(f"  s3_0_c11_c{c}_{e} = {h(v)}")
lwr = upr = ctl = None
for c in (0, 1):
    a, b = grid[(c, 0)], grid[(c, 1)]
    if a and b and 0x10000000000 <= a < b < 0x20000000000 and b - a < 0x100000:
        lwr, upr = a, b
        print(f"  using s3_0_c11_c{c}_{{0,1}} as the SMP-RO window")
        break
ctl = grid[(1, 4)]
print(f"  CTL s3_0_c11_c1_4 = {h(ctl)}")
img_lo = u.base
img_hi = u.base + 0x1000000  # m1n1 image + heap are well under 16 MiB
if lwr is not None and upr is not None:
    print(f"  window = [{lwr:#x}, {upr + 1:#x})  size {upr + 1 - lwr:#x}")
    print(f"  overlaps m1n1 image/heap [{img_lo:#x}, {img_hi:#x})?  {'YES  <-- secondaries cannot write m1n1 .data/.bss' if lwr < img_hi and upr >= img_lo else 'no'}")
    n = min(upr + 1 - lwr, 0x200)
    data = u.iface.readmem(lwr, n)
    out = pathlib.Path(__file__).with_name("smp-ro-window.bin")
    out.write_bytes(u.iface.readmem(lwr, min(upr + 1 - lwr, 0x10000)))
    print(f"  first {n:#x} bytes (full dump -> {out}):")
    chexdump(data, lwr)
    nz = sum(1 for b in data if b)
    print(f"  non-zero bytes in first {n:#x}: {nz}")

# ---------------------------------------------------------------- optional: external debug
if DBG:
    print("\n== external debug interface (reg-private / coresight-reg), ARMv8 Debug memory map guesses")
    OFFS = {"EDSCR": 0x88, "EDPCSRlo": 0xA0, "EDPCSRhi": 0xAC, "EDPRSR": 0x314, "EDLSR": 0xFB4, "EDDEVID": 0xFC8}
    for cpu in adt["/cpus"]:
        if not cpu.name.startswith("cpu") or cpu.name == "cpus":
            continue
        if cpu.state != "running" and not DBG_ALL:
            continue
        b = cpu.reg_private if hasattr(cpu, "reg_private") else cpu.coresight_reg[0]
        vals = {k: rd32(b + o) for k, o in OFFS.items()}
        print(f"  {cpu.name:<6} base {b:#x}: " + "  ".join(f"{k}={h(v)}" for k, v in vals.items()))

json.dump(rows, open(pathlib.Path(__file__).with_name("smp-probe.json"), "w"), indent=1, default=str)
print("\nwrote smp-probe.json")
