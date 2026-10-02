#!/usr/bin/env python3
"""Replay, on the real T6050 core at EL2, every Apple sysreg access Linux's
irq-apple-aic.c makes in aic_init_cpu(), then test a fast self-IPI the way
aic_ipi_send_fast() sends it. All accesses are exception-guarded."""
import sys, pathlib
sys.path.append(str(pathlib.Path(__file__).resolve().parents[1] / "proxyclient"))
from m1n1.setup import *
from m1n1.proxy import ProxyError

REGS = {
    "IPI_RR_LOCAL_EL1": (3, 5, 15, 0, 0),
    "IPI_RR_GLOBAL_EL1": (3, 5, 15, 0, 1),
    "IPI_SR_EL1": (3, 5, 15, 1, 1),
    "VM_TMR_FIQ_ENA_EL2": (3, 5, 15, 1, 3),
    "IPI_CR_EL1": (3, 5, 15, 3, 1),
    "PMCR0_EL1": (3, 1, 15, 0, 0),
    "UPMCR0_EL1": (3, 7, 15, 0, 4),
    "UPMSR_EL1": (3, 7, 15, 6, 4),
    "ICH_HCR_EL2": (3, 4, 12, 11, 0),
}

def try_rd(reg):
    try:
        return u.mrs(reg, silent=True)
    except ProxyError:
        return None

def try_wr(reg, val):
    try:
        u.msr(reg, val, silent=True)
        return True
    except ProxyError:
        return False

mpidr = u.mrs(MPIDR_EL1)
print(f"MPIDR_EL1 = {mpidr:#x}  aff0(cpu)={mpidr & 0xff} aff1(cluster)={mpidr >> 8 & 0xff} aff2={mpidr >> 16 & 0xff}")
print(f"{'register':<20} {'read':>20}  write-back-same-value")
for name, reg in REGS.items():
    v = try_rd(reg)
    if name.startswith("IPI_RR"):
        print(f"{name:<20} {'(write-only, skipped)':>20}")
        continue
    w = "n/a" if v is None else ("ok" if try_wr(reg, v) else "FAULTS")
    print(f"{name:<20} {'FAULTS' if v is None else hex(v):>20}  {w}")

# The exact aic_init_cpu() writes:
print("\naic_init_cpu() replay:")
print("  IPI_SR <- PENDING          :", "ok" if try_wr(REGS["IPI_SR_EL1"], 1) else "FAULTS")
v = try_rd(REGS["PMCR0_EL1"])
if v is not None:
    new = v & ~((7 << 8) | (1 << 11))
    print(f"  PMCR0 {v:#x} -> {new:#x}  :", "unchanged (no write)" if new == v else ("ok" if try_wr(REGS["PMCR0_EL1"], new) else "FAULTS"))
v = try_rd(REGS["UPMCR0_EL1"])
if v is not None:
    new = v & ~(7 << 16)
    print(f"  UPMCR0 {v:#x} -> {new:#x} :", "unchanged (no write)" if new == v else ("ok" if try_wr(REGS["UPMCR0_EL1"], new) else "FAULTS"))
v = try_rd(REGS["VM_TMR_FIQ_ENA_EL2"])
if v is not None:
    new = v & ~3
    print(f"  VM_TMR_FIQ_ENA {v:#x} -> {new:#x}:", "unchanged (no write)" if new == v else ("ok" if try_wr(REGS["VM_TMR_FIQ_ENA_EL2"], new) else "FAULTS"))

# Fast self-IPI, FIQ+IRQ masked for the whole sequence so nothing can storm.
blob = f"""
    msr daifset, #3
    msr s3_5_c15_c0_0, x0
    isb
    mov x9, #0x400000
1:  subs x9, x9, #1
    b.ne 1b
    mrs x1, isr_el1
    mrs x2, s3_5_c15_c1_1
    mov x3, #1
    msr s3_5_c15_c1_1, x3
    isb
    lsl x2, x2, #8
    orr x0, x1, x2
    msr daifclr, #3
"""
idx = mpidr & 0xff
print(f"\nfast self-IPI via IPI_RR_LOCAL (cpu idx {idx}), interrupts masked:")
try:
    r = u.exec(blob, idx, silent=True)
    print(f"  ISR_EL1: I={r >> 7 & 1} F={r >> 6 & 1}   IPI_SR.PENDING={r >> 8 & 1}")
except ProxyError:
    print("  sequence FAULTED")
