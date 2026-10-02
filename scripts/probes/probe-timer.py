#!/usr/bin/env python3
"""Probe T6050 timer -> FIQ delivery and VM_TMR_FIQ_ENA_EL2 from the m1n1 proxy (EL2).

Every sysreg access goes through proxyutils' exception guard, so a fault is
reported instead of taking the proxy down.
"""
import sys, time, pathlib
sys.path.append(str(pathlib.Path(__file__).resolve().parents[1] / "proxyclient"))
from m1n1.setup import *
from m1n1.proxy import ProxyError

VM_TMR_FIQ_ENA = (3, 5, 15, 1, 3)
ISR_EL1 = (3, 0, 12, 1, 0)
CNTP_CTL_EL02 = (3, 5, 14, 2, 1)
CNTV_CTL_EL02 = (3, 5, 14, 3, 1)

def rd(name, reg):
    try:
        v = u.mrs(reg, silent=True)
        print(f"  {name:<22} = {v:#018x}")
        return v
    except ProxyError:
        print(f"  {name:<22} : READ FAULTS")
        return None

def wr(name, reg, val):
    try:
        u.msr(reg, val, silent=True)
        print(f"  {name:<22} <- {val:#x}: ok")
        return True
    except ProxyError:
        print(f"  {name:<22} <- {val:#x}: WRITE FAULTS")
        return False

print("== identity")
rd("MIDR_EL1", MIDR_EL1)
rd("CurrentEL", CurrentEL)
hcr = rd("HCR_EL2", HCR_EL2)
if hcr is not None:
    print(f"  E2H={hcr >> 34 & 1} TGE={hcr >> 27 & 1}")
rd("DAIF", DAIF)

print("== VM_TMR_FIQ_ENA_EL2 (s3_5_c15_c1_3)")
v = rd("VM_TMR_FIQ_ENA_EL2", VM_TMR_FIQ_ENA)
if v is not None:
    wr("  same value", VM_TMR_FIQ_ENA, v)
    wr("  set ENA_P", VM_TMR_FIQ_ENA, v | 2)
    wr("  clear ENA_P", VM_TMR_FIQ_ENA, v & ~2)
    wr("  set ENA_V", VM_TMR_FIQ_ENA, v | 1)
    wr("  restore", VM_TMR_FIQ_ENA, v)
    rd("VM_TMR_FIQ_ENA_EL2", VM_TMR_FIQ_ENA)
rd("CNTP_CTL_EL02", CNTP_CTL_EL02)
rd("CNTV_CTL_EL02", CNTV_CTL_EL02)

def timer_test(label, ctl, cval):
    print(f"== {label}: arm 1 ms, IMASK=0, then watch ISTATUS and ISR_EL1")
    exc0 = p.get_exc_count()
    rd("ISR_EL1 before", ISR_EL1)
    now = u.mrs(CNTPCT_EL0)
    freq = u.mrs(CNTFRQ_EL0)
    u.msr(cval, now + freq // 1000)
    u.msr(ctl, 1)  # ENABLE, IMASK=0
    time.sleep(0.05)
    c = rd(f"{label} CTL", ctl)
    isr = rd("ISR_EL1 after", ISR_EL1)
    if c is not None:
        print(f"  ENABLE={c & 1} IMASK={c >> 1 & 1} ISTATUS={c >> 2 & 1}")
    if isr is not None:
        print(f"  ISR_EL1: A={isr >> 8 & 1} I={isr >> 7 & 1} F={isr >> 6 & 1}")
    print(f"  proxy exceptions taken meanwhile: {p.get_exc_count() - exc0}")
    u.msr(ctl, 2)  # disable, masked
    rd("ISR_EL1 disarmed", ISR_EL1)

print(f"== CNTFRQ = {u.mrs(CNTFRQ_EL0)} Hz")
timer_test("CNTP (EL2 phys via E2H)", CNTP_CTL_EL0, CNTP_CVAL_EL0)
timer_test("CNTV (EL2 virt via E2H)", CNTV_CTL_EL0, CNTV_CVAL_EL0)
