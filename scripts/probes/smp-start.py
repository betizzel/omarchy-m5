#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Ask the running m1n1 to start every secondary core (smp_start_secondaries)
and report which ones checked in. Run from the tether bundle with the M5 in
m1n1, ideally with hv/wdt-arm.py armed first:

    hv/smp-start.py        # m1n1 prints "Starting CPU n (d:c:c)... Started/Failed!"

Prints the memory layout the secondaries depend on first: m1n1's base (the
locked RVBAR page), top_of_kernel_data (m1n1's heap, hence the pre-#682
secondary stacks, starts there) and the secondary-only CTRR_C window. On the
installed stage-1 the heap starts above the window; after a chainload it
only does with the fixed chainload.py (top_of_kernel_data preserved).
"""
import sys, pathlib
sys.path.append(str(pathlib.Path(__file__).resolve().parents[1] / "proxyclient"))
from m1n1.setup import *

top = u.ba.top_of_kernel_data
lwr, upr = u.mrs((3, 0, 11, 0, 0)), u.mrs((3, 0, 11, 0, 1))   # CTRR_C_{LWR,UPR}_EL1
print(f"m1n1 base (RVBAR page) {u.base:#x}")
print(f"top_of_kernel_data     {top:#x}  (= heap start)")
print(f"CTRR_C window          [{lwr:#x}, {upr:#x}]  base+{lwr - u.base:#x}, ends top-{top - upr:#x}")
print(f"heap starts {'ABOVE' if top > upr else 'BELOW (secondary stacks may land in the window)'} the window")

p.smp_start_secondaries()
alive = [i for i in range(64) if p.smp_is_alive(i)]
print(f"\nalive per m1n1: {alive or 'none'}")
