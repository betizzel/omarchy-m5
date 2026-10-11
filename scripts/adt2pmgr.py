#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Generate t6050-pmgr.dtsi from a raw ADT binary.

Forked from m1n1's proxyclient/tools/pmgr_adt2dt.py with two changes:
parent IDs that don't resolve to a device (e.g. T6050's die-level/virtual
domains like id 609) are skipped instead of crashing, and --boot-state can
withhold apple,always-on from domains that are off at handover.

Usage:
    scripts/adt2pmgr.py ADT [--boot-state STATE.json] > dt/t6050-pmgr.dtsi

ADT must be the *runtime* tree (tether bundle: ./dump-adt.sh). iBoot prunes
and patches it at boot - e.g. it drops the memory channels this SKU does not
populate - so the on-disk devicetree.img4 describes domains that do not
exist here and pairs labels with the wrong registers.

STATE.json maps domain label -> pwrstate register value at m1n1 handover.
The ADT marks some domains critical that are nevertheless off at handover
(debug fabric, links to unpopulated memory channels, die-to-die links).
Linux force-powers every always-on domain it finds off, and on T6050 that
ends in an asynchronous SError, so those domains are emitted as ordinary
ones instead - m1n1's dt_set_pmgr() does the same for T8012's unused
memory channels.
"""
import argparse
import json
import re
import sys
import pathlib

M1N1 = pathlib.Path(__file__).resolve().parents[1] / "vendor" / "m1n1"
sys.path.insert(0, str(M1N1 / "proxyclient"))

from m1n1 import adt  # noqa: E402
from m1n1.utils import align_up  # noqa: E402

HEADER = """// SPDX-License-Identifier: GPL-2.0+ OR MIT
/*
 * PMGR power domains for the Apple T6050 "M5 Pro" SoC
 *
 * GENERATED from the on-device ADT by scripts/adt2pmgr.py - do not edit
 * by hand; regenerate when the ADT changes (macOS updates can revise it).
 *
 * Copyright The Asahi Linux Contributors / omarchy-m5 contributors
 */
"""


# CPU cores (mcpu*/pcpu*/ecpu*) and their cluster power managers
# (mcpm*/pcpm*/ecpm*) belong to the CPUs, not to genpd: Asahi's Apple
# Silicon trees never describe them. On T6050 the ADT lists them as plain
# pwrstate devices, and they sit "on, targeted off" (0x1f0) because the
# hardware holds them up while a core runs; the Linux driver's AUTO_ENABLE
# write on probe then makes PMGR enforce "off" on the running boot core,
# which ends in an asynchronous SError.
CPU_COMPLEX = re.compile(r"^[mpe]cp[um]\d*(_\d+)?$")

# The SMC firmware's own I2C masters (charger, fuel gauge, USB-C PD). No
# Linux driver claims them and Asahi's trees never describe them; described
# here, the pwrstate probe arms AUTO_ENABLE on the active ones - the same
# move that auto-gated the USB-C port domains and broke the DWC3 reset.
SMC_OWNED = re.compile(r"^smc_i2cm\d+$")


def skipped(dev) -> bool:
    name = dev.name.lower()
    return dev.flags.no_ps or bool(CPU_COMPLEX.match(name) or SMC_OWNED.match(name))


def linux_sees_active(value: int) -> bool:
    """Mirror of Linux's apple_pmgr_ps_is_active()."""
    actual, target = value >> 4 & 0xf, value & 0xf
    return actual == 0xf or (target == 0xf and bool(value & (1 << 28)))


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("adt", type=pathlib.Path)
    ap.add_argument("--boot-state", type=pathlib.Path,
                    help="JSON {label: pwrstate value at handover}")
    args = ap.parse_args()

    boot_state = json.loads(args.boot_state.read_text()) if args.boot_state else {}

    dt = adt.load_adt(args.adt.read_bytes())
    pmgr = dt["/arm-io/pmgr"]

    dev_by_id = {dt.pmgr_dev_get_id(dev): dev for dev in pmgr.devices}

    blocks = {}
    maxaddr = {}
    for dev in pmgr.devices:
        if skipped(dev):
            continue
        block = dt.pmgr_dev_get_block(dev)
        blocks.setdefault(block, []).append(dev)
        offset = dt.pmgr_dev_get_offset(dev)
        maxaddr[block[0]] = max(maxaddr.get(block[0], 0), offset)

    pmgr_compat = pmgr.compatible[0].split(",")[1]
    compatible = f'"apple,{pmgr_compat}-pmgr", "apple,t8103-pmgr", "syscon", "simple-mfd"'
    ps_compatible = f'"apple,{pmgr_compat}-pmgr-pwrstate", "apple,t8103-pmgr-pwrstate"'

    print(HEADER)
    print("&soc {")
    for i, ((base, size), devices) in enumerate(sorted(blocks.items())):
        size = min(size, align_up(maxaddr[base] + 4, 0x4000))
        print(f"\tpmgr{i}: power-management@{base:x} {{")
        print(f"\t\tcompatible = {compatible};")
        print("\t\t#address-cells = <1>;")
        print("\t\t#size-cells = <1>;")
        print()
        print(f"\t\treg = <{base >> 32:#x} {base & 0xffffffff:#x} 0 {size:#x}>;")
        print("\t};")
        print()
    print("};")
    print()
    skipped_parents = set()
    for i, ((base, size), devices) in enumerate(sorted(blocks.items())):
        print(f"&pmgr{i} {{")
        for dev in sorted(devices, key=dt.pmgr_dev_get_addr):
            if skipped(dev):
                continue
            offset = dt.pmgr_dev_get_offset(dev)
            print()
            print(f"\tps_{dev.name.lower()}: power-controller@{offset:x} {{")
            print(f"\t\tcompatible = {ps_compatible};")
            print(f"\t\treg = <{offset:#x} 4>;")
            print("\t\t#power-domain-cells = <0>;")
            print("\t\t#reset-cells = <0>;")
            print(f'\t\tlabel = "{dev.name.lower()}";')
            if dev.flags.critical:
                state = boot_state.get(dev.name.lower())
                if state is not None and not linux_sees_active(state):
                    print(f"\t\t/* ADT critical, but off at handover ({state:#010x}) */")
                else:
                    print("\t\tapple,always-on;")
            domains = []
            for idx in dt.pmgr_dev_get_parents(dev):
                if not idx:
                    continue
                parent = dev_by_id.get(idx)
                if parent is None or parent.flags.no_ps:
                    skipped_parents.add(idx)
                    continue
                domains.append(f"<&ps_{parent.name.lower()}>")
            if domains:
                print(f"\t\tpower-domains = {', '.join(domains)};")
            print("\t};")
        print("};")
        print()

    if skipped_parents:
        print(f"/* NOTE: unresolved parent ids skipped: "
              f"{sorted(skipped_parents)} (die-level/virtual domains) */",
              file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
