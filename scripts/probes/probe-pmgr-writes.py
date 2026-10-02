#!/usr/bin/env python3
"""Replay, on the live machine, the AUTO_ENABLE write Linux's
apple_pmgr_ps_probe() makes to already-active PMGR domains, and report the
registers that raise an SError.

Candidates mirror the patched driver (patches/linux/0003): a domain Linux
sees as active gets the write unless AUTO_ENABLE is already set, and only
when the write changes the register.

Each test is one guarded instruction sequence: store Linux's value, dsb/isb
(so an SError lands inside the guard), store the original value back,
dsb/isb. The domain spends nanoseconds with auto-PM on, so nothing - m1n1's
own USB link included - gets a chance to power-gate.

Some writes hang the machine outright instead of faulting. Every label is
appended to pmgr-writes-progress.log *before* its write, so after a hang the
last line names the culprit; add it to pmgr-writes-skip.txt (one label per
line), hold the power button, and rerun to continue past it.

Usage: hv/probe-pmgr-writes.py hv/pmgr-probe.json   (from probe-pmgr.py)
"""
import sys, json, os, pathlib
sys.path.append(str(pathlib.Path(__file__).resolve().parents[1] / "proxyclient"))
from m1n1.setup import *
from m1n1.proxy import ProxyError

FLAGS = (1 << 9) | (1 << 8)     # WAS_CLKGATED | WAS_PWRGATED (write-1-to-clear)
AUTO_ENABLE = 1 << 28


def linux_is_active(v):
    return (v >> 4 & 0xf) == 0xf or ((v & 0xf) == 0xf and bool(v & AUTO_ENABLE))


here = pathlib.Path(__file__).parent
cands = []
for d in json.load(open(sys.argv[1])):
    v = d["value"]
    if v is None or not linux_is_active(v) or v & AUTO_ENABLE:
        continue
    new = (v & ~(FLAGS | AUTO_ENABLE)) | AUTO_ENABLE
    if new != v:
        cands.append(dict(d, new=new))
skip_file = here / "pmgr-writes-skip.txt"
skip = set(skip_file.read_text().split()) if skip_file.exists() else set()
log = open(here / "pmgr-writes-progress.log", "w")
SEQ = "str w1, [x0]\n dsb sy\n isb\n str w2, [x0]\n dsb sy\n isb"

bad = []
for i, d in enumerate(cands):
    if d["label"] in skip:
        continue
    log.write(f"{i} {d['label']} {d['addr']:#x}\n")
    log.flush()
    os.fsync(log.fileno())
    print(f"[{i:3d}/{len(cands)}] {d['label']:<24}", end=" ", flush=True)
    try:
        u.exec(SEQ, d["addr"], d["new"], d["value"], silent=True)
        print("ok", flush=True)
    except ProxyError:
        print("SERROR", flush=True)
        bad.append(d)

print(f"\n{len(bad)} of {len(cands) - len(skip)} tested AUTO_ENABLE writes raise an SError"
      f" ({len(skip)} skipped as known hangs: {sorted(skip)})")
for d in bad:
    print(f"  {d['addr']:#014x}  {d['label']:<24} {d['value']:#010x} -> {d['new']:#010x}")
