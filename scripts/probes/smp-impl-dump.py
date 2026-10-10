#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Compare a secondary's per-core register windows with the boot core's,
before and after the PMGR release, looking for whatever else steers its reset
fetch (a second locked vector, a hold/halt bit). M5 in m1n1, watchdog armed:

    hv/wdt-arm.py 90
    hv/smp-impl-dump.py cpu7 [--release] [--span 0x200]

Reads cpu-impl-reg+0 .. +SPAN and the whole cpu-uttdbg-reg window (0xc8) as
64-bit words through m1n1's exception guard. Words that look like DRAM
addresses are tagged: m1n1 base (the locked RVBAR page), the secondary-only
CTRR_C window (iBoot's WFI sled), or other.
"""
import sys, pathlib
sys.path.append(str(pathlib.Path(__file__).resolve().parents[1] / "proxyclient"))
from m1n1.setup import *
from m1n1.proxy import ProxyError


def rd64(addr):
    try:
        return u.exec("ldr x0, [x0]\n dsb sy\n isb", addr, silent=True)
    except ProxyError:
        return None


args = [a for a in sys.argv[1:] if not a.startswith("--")]
target = args[0] if args else "cpu7"
span = int(sys.argv[sys.argv.index("--span") + 1], 0) if "--span" in sys.argv else 0x200
release = "--release" in sys.argv
if "--span" in sys.argv:
    args = [a for a in args if a != sys.argv[sys.argv.index("--span") + 1]]
    target = args[0] if args else "cpu7"

adt = u.adt
cpus = {c.name: c for c in adt["/cpus"] if c.name.startswith("cpu") and c.name != "cpus"}
boot = next(c for c in cpus.values() if c.state == "running")
tgt = cpus[target]
lwr, upr = u.mrs((3, 0, 11, 0, 0)), u.mrs((3, 0, 11, 0, 1))


def tag(v):
    if v is None:
        return "SERROR"
    a = v & 0xffffffffff000
    if a == u.base:
        return "<- m1n1 base"
    if lwr <= a <= upr:
        return f"<- CTRR_C window +{a - lwr:#x}"
    if 0x10000000000 <= a < 0x20000000000:
        return "<- DRAM"
    return ""


def dump(c):
    im, ut = c.cpu_impl_reg[0], c.cpu_uttdbg_reg[0]
    return ({o: rd64(im + o) for o in range(0, span, 8)},
            {o: rd64(ut + o) for o in range(0, 0xc8, 8)})


def show(title, rows):
    print(title)
    for name, (impl, utt) in rows.items():
        pass
    keys = list(rows)
    for region, idx in (("impl", 0), ("utt", 1)):
        offs = rows[keys[0]][idx].keys()
        for o in offs:
            vals = [rows[k][idx][o] for k in keys]
            if all(v in (0, None) for v in vals):
                continue
            cells = "  ".join(f"{'SERROR' if v is None else hex(v):>20}" for v in vals)
            print(f"  {region}+{o:#05x}  {cells}  {tag(vals[-1])}")


print(f"m1n1 base {u.base:#x}; CTRR_C window [{lwr:#x}, {upr:#x}]; columns: "
      f"{boot.name} (boot), {tgt.name}")
show("== before release", {boot.name: dump(boot), tgt.name: dump(tgt)})

if release:
    sb = adt["/arm-io/pmgr"].get_reg(0)[0] + 0x88000
    p.write32(sb + 4, 1 << tgt.cpu_id)
    p.write32(sb + 8 + 4 * tgt.cluster_id, 1 << tgt.cluster_core_id)
    show(f"== after releasing {tgt.name}", {boot.name: dump(boot), tgt.name: dump(tgt)})
