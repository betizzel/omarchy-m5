#!/usr/bin/env python3
"""Stage 0 of the T6050 SMC bring-up: talk to the SMC from the m1n1 proxy,
before any Linux driver does, and change nothing.

Runs from the tether bundle (hv/ next to proxyclient/) with the M5 in m1n1:

    hv/smc-proxy-probe.py

- Starts the SMC's RTKit endpoint 0x20 (mailbox = ADT /arm-io/smc reg[0]
  + 0x8000, as for ANS) and checks the shared-memory pointer it returns.
- Lists every key (name, size, type, flags) and reads the values of the keys
  the Linux macsmc drivers depend on. SMC key reads have no side effects;
  nothing is written.
- Reads the SPMI controller's first register behind m1n1's exception guard
  (nub-spmi0 sits in an auto-PM, clock-gated power domain at handover).
- Does NOT stop the SMC endpoint or put it to sleep: the ADT marks the SMC
  no-shutdown, and the SMC is the machine's power controller.

Writes smc-keys.json next to this script: {"keys": [...], "values": {...}}.
"""
import sys, json, pathlib
sys.path.append(str(pathlib.Path(__file__).resolve().parents[1] / "proxyclient"))
from m1n1.setup import *
from m1n1.proxy import ProxyError
from m1n1.fw.smc import SMCClient, SMCError

# Keys the drivers use (drivers/rtc/rtc-macsmc.c, power/supply/macsmc-power.c,
# input/misc/macsmc-input.c, power/reset/macsmc-reboot.c, gpio-macsmc.c) plus
# a few temperature/fan keys for hwmon.
WANT = ["#KEY", "CLKH", "CLKM", "MSLD", "bHLD", "B0AV", "B0RM", "B0FC", "B0CT",
        "BITV", "BCF0", "CHIS", "CHTE", "CH0C", "CH0I", "AC-W", "AC-i", "MBSE",
        "TB0T", "TB1T", "F0Ac", "F1Ac", "F0Mx", "F1Mx", "PSTR", "PHPC", "gP01"]
SPMI = 0x28a014000          # ADT /arm-io/nub-spmi0 reg[0]
LOAD = "ldr w0, [x0]\n dsb sy\n isb"

smc_base = u.adt["arm-io/smc"].get_reg(0)[0]
smc = SMCClient(u, smc_base, None)
smc.verbose = 0
smc.start()
smc.start_ep(0x20)
ep = smc.smcep
lo, hi = 0x28de00000, 0x28de00000 + 0x140000     # ADT iop-smc-nub region
print(f"SMC shmem {ep.shmem:#x} ({'inside' if lo <= ep.shmem < hi else 'OUTSIDE'} "
      f"the ADT region {lo:#x}..{hi:#x})")

count = ep.read32b("#KEY")
print(f"{count} keys")
keys = []
for i in range(count):
    name = ep.get_key_by_index(i)
    size, typ, flags = ep.get_key_info(name)
    keys.append(dict(name=name, size=size, type=typ, flags=flags))
names = {k["name"]: k for k in keys}

values = {}
for name in WANT:
    k = names.get(name)
    if k is None:
        values[name] = None
        print(f"  {name}: (absent)")
        continue
    try:
        v = ep.read_type(name, k["size"], k["type"])
    except SMCError as e:
        v = f"error {e}"
    values[name] = v if isinstance(v, (int, float, str)) or v is None else repr(v)
    print(f"  {name}: {k['type']}/{k['size']} flags={k['flags']:#x} = {values[name]}")

try:
    spmi = u.exec(LOAD, SPMI, silent=True) & 0xffffffff
    print(f"SPMI {SPMI:#x}: {spmi:#010x}")
except ProxyError:
    spmi = None
    print(f"SPMI {SPMI:#x}: SError (clock-gated?)")

out = pathlib.Path(__file__).parent / "smc-keys.json"
out.write_text(json.dumps(dict(shmem=ep.shmem, keys=keys, values=values, spmi0=spmi),
                          indent=1, default=str))
print(f"wrote {out} - SMC endpoint left running (no-shutdown)")
