#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Generate t6050-pmgr.dtsi from a raw ADT binary.

Forked from m1n1's proxyclient/tools/pmgr_adt2dt.py with one fix: parent
IDs that don't resolve to a device (e.g. T6050's die-level/virtual
domains like id 609) are skipped instead of crashing.

Usage:
    scripts/adt2pmgr.py /path/to/adt.bin > dt/t6050-pmgr.dtsi

Get adt.bin on-device: extract devicetree.img4 from Preboot
(usr/standalone/firmware/devicetree.img4), strip the IM4P header, and
LZFSE-decompress the bvx2 payload — or retrieve it live via m1n1
proxyclient (`adt` object / adt.py --retrieve).
"""
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
 * GENERATED from the on-device ADT by scripts/adt2pmgr.py — do not edit
 * by hand; regenerate when the ADT changes (macOS updates can revise it).
 *
 * Copyright The Asahi Linux Contributors / omarchy-m5 contributors
 */
"""


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2

    dt = adt.load_adt(pathlib.Path(sys.argv[1]).read_bytes())
    pmgr = dt["/arm-io/pmgr"]

    dev_by_id = {dt.pmgr_dev_get_id(dev): dev for dev in pmgr.devices}

    blocks = {}
    maxaddr = {}
    for dev in pmgr.devices:
        if dev.flags.no_ps:
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
            if dev.flags.no_ps:
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
