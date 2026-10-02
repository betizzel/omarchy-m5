#!/usr/bin/env python3
"""Read every PMGR power-state register a t6050-pmgr.dtsi describes, one at
a time behind m1n1's exception guard, and report SErrors and the domains
Linux would see as off.

Runs from the tether bundle (hv/ next to proxyclient/) with the M5 in m1n1:

    hv/probe-pmgr.py hv/t6050-pmgr.dtsi

SErrors are asynchronous, so each load is followed by dsb sy; isb inside the
same guarded call: the abort is taken (and counted) before the guard is
dropped, and lands on the right register. Read-only.

Writes, next to this script:
  pmgr-probe.json       [{label, addr, always_on, value}]  (value None = SError)
  pmgr-boot-state.json  {label: value}  -> scripts/adt2pmgr.py --boot-state
"""
import sys, json, re, pathlib
sys.path.append(str(pathlib.Path(__file__).resolve().parents[1] / "proxyclient"))
from m1n1.setup import *
from m1n1.proxy import ProxyError

AUTO_ENABLE = 1 << 28


def linux_is_active(v):
    """apple_pmgr_ps_is_active(): actually on, or targeted on with auto-PM."""
    return (v >> 4 & 0xf) == 0xf or ((v & 0xf) == 0xf and bool(v & AUTO_ENABLE))


def parse_pmgr_dtsi(text):
    """Domains from scripts/adt2pmgr.py output: block base + child offset."""
    bases = {m[1]: int(m[2], 16) << 32 | int(m[3], 16) for m in re.finditer(
        r"(pmgr\d+): power-management@\w+ \{.*?reg = <(0x[0-9a-f]+) (0x[0-9a-f]+)", text, re.S)}
    doms = []
    for sec in re.finditer(r"^&(pmgr\d+) \{(.*?)^\};", text, re.S | re.M):
        for nd in re.finditer(r"\t(\w+): power-controller@\w+ \{(.*?)\n\t\};", sec[2], re.S):
            body = nd[2]
            doms.append(dict(
                label=re.search(r'label = "([^"]+)"', body)[1],
                addr=bases[sec[1]] + int(re.search(r"reg = <(0x[0-9a-f]+)", body)[1], 16),
                always_on="apple,always-on" in body))
    return doms


here = pathlib.Path(__file__).parent
doms = parse_pmgr_dtsi(pathlib.Path(sys.argv[1]).read_text())
LOAD = "ldr w0, [x0]\n dsb sy\n isb"

for d in doms:
    try:
        d["value"] = u.exec(LOAD, d["addr"], silent=True) & 0xffffffff
    except ProxyError:
        d["value"] = None

bad = [d for d in doms if d["value"] is None]
print(f"{len(bad)} of {len(doms)} registers raise an SError on read")
for d in bad:
    print(f"  {d['addr']:#014x}  {d['label']}")

off = [d for d in doms if d["value"] is not None and d["always_on"] and not linux_is_active(d["value"])]
print(f"{len(off)} always-on domains Linux sees as off (it would force them on):")
for d in off:
    print(f"  {d['addr']:#014x}  {d['label']:<24} = {d['value']:#010x}")

json.dump(doms, open(here / "pmgr-probe.json", "w"), indent=1)
json.dump({d["label"]: d["value"] for d in sorted(doms, key=lambda d: d["label"])
           if d["value"] is not None}, open(here / "pmgr-boot-state.json", "w"), indent=1)
print(f"wrote {here / 'pmgr-probe.json'} and {here / 'pmgr-boot-state.json'}")
