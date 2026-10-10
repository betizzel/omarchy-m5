#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Where does a T6050 secondary core go after its PMGR start? Run from the
tether bundle (hv/ next to proxyclient/) with the M5 sitting in m1n1:

    hv/wdt-arm.py 60                 # a bus hang then resets into m1n1
    hv/smp-start-trace.py            # read-only: boot core (control) + cpu1
    hv/smp-start-trace.py cpu6 --start

Per core, the ADT gives coresight-reg (base B), cpu-uttdbg-reg (U) and
cpu-impl-reg (I). Same layout as M1 (asahilinux.org/docs/hw/cpu/debug-registers):
the external debug block is B+0x20000 (lock access 0xfb0/0xfb4, EDSCR 0x088,
EDPCSR 0x0a0/0x0ac, EDPRSR 0x314) and U+0x90 is Apple's PC sample. The boot
core is the control: its PC sample must land inside m1n1.

--start releases the target exactly as XNU's configMiscCores and m1n1 do:
PMGR reg[0]+0x88004 gets BIT(cpu-id) (one bit per ADT cpu-id on T6050), then
+0x88008+4*cluster gets BIT(core-in-cluster). That is one-shot per boot. The
script then samples the PC and impl+0x100 status for a while, and reports
where the core is: inside m1n1 (RVBAR worked), in the secondary-only CTRR_C
window (iBoot's 44 KiB WFI sled), or elsewhere.
"""
import sys, time, pathlib
sys.path.append(str(pathlib.Path(__file__).resolve().parents[1] / "proxyclient"))
from m1n1.setup import *
from m1n1.proxy import ProxyError

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


def h(v):
    return "SERROR" if v is None else f"{v:#x}"


args = [a for a in sys.argv[1:] if not a.startswith("--")]
START = "--start" in sys.argv
target_name = args[0] if args else "cpu1"

adt = u.adt
cpus = {c.name: c for c in adt["/cpus"] if c.name.startswith("cpu") and c.name != "cpus"}
boot = next(c for c in cpus.values() if c.state == "running")
tgt = cpus[target_name]
if tgt is boot:
    sys.exit("pick a secondary, not the boot core")

lwr, upr = mrs((3, 0, 11, 0, 0)), mrs((3, 0, 11, 0, 1))   # CTRR_C_{LWR,UPR}_EL1
img_lo, img_hi = u.base, u.base + 0x1000000
print(f"m1n1 base {u.base:#x}; secondary-only CTRR_C window "
      f"[{h(lwr)}, {h(upr)}]; RVBAR page expected = {u.base & ~0xfff:#x}")


def where(pc):
    if pc is None:
        return "unreadable"
    a = pc & 0xffffffffffff
    if lwr and upr and lwr <= a <= upr:
        return f"in CTRR_C window (+{a - lwr:#x}): iBoot's WFI sled"
    if img_lo <= a < img_hi:
        off = a - u.base
        vec = " (exception vector?)" if 0x800 > off >= 0x0 and off % 0x80 == 0 else ""
        return f"inside m1n1 (+{off:#x}){vec}"
    return "elsewhere"


# The ARM external-debug block (B+0x20000) is not uniformly readable: on the
# boot core, EDPCSRhi (+0xac) hung the bus (2026-10-09). Only the documented
# Apple PC sample (U+0x90) is read by default; --edregs adds the rest.
ED_REGS = {"EDPCSRlo": 0xa0, "EDSCR": 0x88, "EDPRSR": 0x314, "EDLSR": 0xfb4} \
    if "--edregs" in sys.argv else {}


def regs(c):
    ut, im = c.cpu_uttdbg_reg[0], c.cpu_impl_reg[0]
    dbg = c.coresight_reg[0] + 0x20000
    r = dict(status=rd64(im + 0x100), rvbar=rd64(im), pc_utt=rd64(ut + 0x90))
    r.update({k: rd32(dbg + o) for k, o in ED_REGS.items()})
    return r


def show(label, c, r):
    print(f"  {label:<10} {c.name:<6} status={h(r['status'])} rvbar={h(r['rvbar'])}")
    print(f"  {'':<10} utt-pc={h(r['pc_utt'])} -> {where(r['pc_utt'])}")
    if ED_REGS:
        print(f"  {'':<10} " + " ".join(f"{k}={h(r[k])}" for k in ED_REGS))


print(f"\n== control: boot core {boot.name} (its PC sample must be inside m1n1)")
show("before", boot, regs(boot))
print("  unlocking debug (0xc5acce55 -> +0x20fb0)")
p.write32(boot.coresight_reg[0] + 0x20fb0, 0xc5acce55)
show("unlocked", boot, regs(boot))

print(f"\n== target {tgt.name} (cpu-id {tgt.cpu_id}, cluster {tgt.cluster_id}, core "
      f"{tgt.cluster_core_id}, type {tgt.cluster_type}, ADT state {tgt.state})")
im = tgt.cpu_impl_reg[0]
print(f"  status={h(rd64(im + 0x100))} rvbar={h(rd64(im))}  (debug block not touched while parked)")

if not START:
    print("\n(read-only run; add --start to release the core)")
    sys.exit(0)

pmgr0 = adt["/arm-io/pmgr"].get_reg(0)[0]
sb = pmgr0 + 0x88000
print(f"\n== release: [{sb + 4:#x}] |= BIT({tgt.cpu_id}), "
      f"[{sb + 8 + 4 * tgt.cluster_id:#x}] = BIT({tgt.cluster_core_id})")
print(f"  before: +0x4={h(rd32(sb + 4))} +0x8+4c={h(rd32(sb + 8 + 4 * tgt.cluster_id))}")
p.write32(sb + 4, 1 << tgt.cpu_id)
p.write32(sb + 8 + 4 * tgt.cluster_id, 1 << tgt.cluster_core_id)
t0 = time.monotonic()
print(f"  after:  +0x4={h(rd32(sb + 4))} +0x8+4c={h(rd32(sb + 8 + 4 * tgt.cluster_id))}")

p.write32(tgt.coresight_reg[0] + 0x20fb0, 0xc5acce55)
seen = []
for i in range(40):
    r = regs(tgt)
    key = (r["status"], r["pc_utt"]) + tuple(r[k] for k in ED_REGS)
    if not seen or key != seen[-1][1]:
        seen.append((time.monotonic() - t0, key))
        show(f"t+{(time.monotonic() - t0) * 1e3:6.1f}ms", tgt, r)
    time.sleep(0.005 if i < 20 else 0.05)
print(f"\n{len(seen)} distinct states over {(time.monotonic() - t0) * 1e3:.0f} ms; "
      f"final: {where(seen[-1][1][1])}")
