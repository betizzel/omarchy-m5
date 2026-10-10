#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Arm the M5's watchdog from the m1n1 proxy, as a safety net for experiments:

    hv/wdt-arm.py [SECONDS]       # default 30
    ./chainload.sh new-m1n1.bin   # hangs before USB? the M5 resets itself

Every m1n1 disables the watchdog early in init (wdt_disable(), "Primary WDT
disabled"), so a build that gets that far disarms it, and so does each
chainload. One that hangs before then resets the M5 back into the installed
stage-1 m1n1 after SECONDS instead of needing a power-button hold.
Armed right before ./boot-linux.sh instead, it catches a kernel that hangs
before its apple_wdt driver probes; once probed, the kernel keeps an
already-running watchdog fed on its own (WATCHDOG_HANDLE_BOOT_ENABLED).

Same registers as Linux's apple_wdt (WD1 at reg[0], 24 MHz, RESET_EN = bit 2)
and m1n1's wdt_reboot().
"""
import sys, pathlib
sys.path.append(str(pathlib.Path(__file__).resolve().parents[1] / "proxyclient"))
from m1n1.setup import *

WD1_CUR_TIME, WD1_BITE_TIME, WD1_CTRL = 0x10, 0x14, 0x1c
CTRL_RESET_EN = 1 << 2
CLK_HZ = 24_000_000

secs = int(sys.argv[1]) if len(sys.argv) > 1 else 30
if not 5 <= secs <= 170:          # BITE_TIME is 32 bits of 24 MHz ticks
    sys.exit("SECONDS must be 5..170")

base = u.adt["/arm-io/wdt"].get_reg(0)[0]
p.write32(base + WD1_CTRL, 0)
p.write32(base + WD1_CUR_TIME, 0)
p.write32(base + WD1_BITE_TIME, secs * CLK_HZ)
p.write32(base + WD1_CTRL, CTRL_RESET_EN)
print(f"watchdog @ {base:#x} armed: reset in {secs} s unless something disables it "
      f"(ctrl={p.read32(base + WD1_CTRL):#x}, cur={p.read32(base + WD1_CUR_TIME):#x})")
