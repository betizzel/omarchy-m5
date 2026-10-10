#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Read-only dump of the T6050 boot core's CTRR/CTXR/ACC_CTRR execute-region
registers and lock state, to pin down how iBoot restricts secondaries.
M5 in m1n1, watchdog armed:

    hv/wdt-arm.py 60
    hv/smp-ctrr-dump.py
    hv/wdt-arm.py --off

All reads are guarded sysreg reads (u.mrs behind m1n1's exception guard), so an
UNDEF/SError is reported, not fatal. It never touches the MMIO that hangs the
bus (cpu-impl-reg+0x100 scans, cpm-impl-reg+0x40f8, the ARM debug block). The
only MMIO reads are cpu-impl-reg+0 (the reset-vector register), already known
safe. Encodings from m1n1 PR #688 (commit 442c7a28) + iBoot's own CTRR/CTXR
setters.
"""
import sys, pathlib
sys.path.append(str(pathlib.Path(__file__).resolve().parents[1] / "proxyclient"))
from m1n1.setup import *
from m1n1.proxy import ProxyError

# name -> (op0, op1, CRn, CRm, op2)
REGS = {
    "CTRR_C_LWR_EL1":  (3, 0, 11, 0, 0), "CTRR_C_UPR_EL1":  (3, 0, 11, 0, 1),
    "CTRR_D_LWR_EL1":  (3, 0, 11, 0, 2), "CTRR_D_UPR_EL1":  (3, 0, 11, 0, 3),
    "CTRR_C_LWR_EL2":  (3, 0, 11, 1, 0), "CTRR_C_UPR_EL2":  (3, 0, 11, 1, 1),
    "CTRR_D_LWR_EL2":  (3, 0, 11, 1, 2), "CTRR_D_UPR_EL2":  (3, 0, 11, 1, 3),
    "CTRR_C_CTL_EL1":  (3, 0, 11, 1, 4), "CTRR_D_CTL_EL1":  (3, 0, 11, 1, 5),
    "CTXR_A_LWR_EL1":  (3, 0, 11, 2, 2), "CTXR_A_UPR_EL1":  (3, 0, 11, 2, 3),
    "CTXR_B_LWR_EL1":  (3, 0, 11, 2, 4), "CTXR_B_UPR_EL1":  (3, 0, 11, 2, 5),
    "CTXR_C_LWR_EL1":  (3, 0, 11, 2, 6), "CTXR_C_UPR_EL1":  (3, 0, 11, 2, 7),
    "CTXR_D_LWR_EL1":  (3, 0, 11, 3, 0), "CTXR_D_UPR_EL1":  (3, 0, 11, 3, 1),
    "CTXR_A_CTL_EL1":  (3, 0, 11, 5, 2), "CTXR_B_CTL_EL1":  (3, 0, 11, 5, 3),
    "CTXR_C_CTL_EL1":  (3, 0, 11, 5, 4), "CTXR_D_CTL_EL1":  (3, 0, 11, 5, 5),
    "ACC_CTRR_C_LWR_EL2": (3, 0, 11, 6, 6), "ACC_CTRR_C_UPR_EL2": (3, 0, 11, 6, 7),
    "ACC_CTRR_D_LWR_EL2": (3, 0, 11, 7, 0), "ACC_CTRR_D_UPR_EL2": (3, 0, 11, 7, 1),
    "ACC_CTXR_A_LWR_EL2": (3, 0, 11, 7, 2), "ACC_CTXR_A_UPR_EL2": (3, 0, 11, 7, 3),
    "ACC_CTXR_B_LWR_EL2": (3, 0, 11, 7, 4), "ACC_CTXR_B_UPR_EL2": (3, 0, 11, 7, 5),
    "ACC_CTXR_C_LWR_EL2": (3, 0, 11, 7, 6), "ACC_CTXR_C_UPR_EL2": (3, 0, 11, 7, 7),
    "ACC_CTXR_D_LWR_EL2": (3, 0, 11, 8, 0), "ACC_CTXR_D_UPR_EL2": (3, 0, 11, 8, 1),
    "ACC_CTRR_C_CTL_EL2": (3, 0, 11, 8, 2), "ACC_CTRR_D_CTL_EL2": (3, 0, 11, 8, 3),
    "ACC_CTXR_A_CTL_EL2": (3, 0, 11, 8, 4), "ACC_CTXR_B_CTL_EL2": (3, 0, 11, 8, 5),
    "ACC_CTXR_C_CTL_EL2": (3, 0, 11, 8, 6), "ACC_CTXR_D_CTL_EL2": (3, 0, 11, 8, 7),
    "CTRR_A_CTL_EL1":  (3, 4, 15, 2, 5), "CTRR_B_CTL_EL1":  (3, 4, 15, 2, 2),
    "RVBAR_EL2":       (3, 4, 12, 0, 1),
}


def mrs(enc):
    try:
        return u.mrs(enc, silent=True)
    except ProxyError:
        return None


def h(v):
    return "UNDEF/SError" if v is None else f"{v:#x}"


top = u.ba.top_of_kernel_data
print(f"chip {u.adt['/chosen'].chip_id:#x}  m1n1 base {u.base:#x}  "
      f"top_of_kernel_data {top:#x}  boot MPIDR {u.mrs(MPIDR_EL1):#x}\n")

for name, enc in REGS.items():
    v = mrs(enc)
    note = ""
    if v and 0x10000000000 <= v < 0x20000000000:
        note = f"  base+{v - u.base:#x}" if v >= u.base else ""
        if v == top:
            note += "  == top_of_kernel_data"
        elif abs(v - top) < 0x20000:
            note += f"  top{v - top:+#x}"
    print(f"  {name:20} = {h(v):>18}{note}")

print("\n== CTRR_C window vs sled / m1n1 ==")
lwr, upr = mrs(REGS["CTRR_C_LWR_EL1"]), mrs(REGS["CTRR_C_UPR_EL1"])
if lwr and upr:
    print(f"  CTRR_C = [{lwr:#x}, {upr:#x})  size {upr - lwr:#x}  "
          f"ends at top? {upr + 0x1000 == top or upr == top}")
    print(f"  m1n1 [{u.base:#x}..] is {'inside' if lwr <= u.base < upr else 'OUTSIDE'} CTRR_C")

print("\n== per-core reset-vector register (cpu-impl-reg+0, MMIO) ==")
for c in u.adt["/cpus"]:
    if not c.name.startswith("cpu") or c.name == "cpus":
        continue
    im = c.cpu_impl_reg[0]
    try:
        rv = p.read64(im)
    except ProxyError:
        rv = None
    inm1 = "" if rv is None else ("  -> m1n1 base" if (rv & 0xffffffffff000) == u.base else "")
    print(f"  {c.name:6} impl {im:#x}  RVBAR {h(rv)}{inm1}")
