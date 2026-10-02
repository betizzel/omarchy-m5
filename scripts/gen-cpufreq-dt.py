#!/usr/bin/env python3
# Generate dt/t6050-cpufreq.dtsi from the runtime ADT (no device needed):
#   scripts/gen-cpufreq-dt.py build/adt-runtime-j714s.bin > dt/t6050-cpufreq.dtsi
#
# Measured on the M5 (cluster 0, apple,sawtooth; boot state 6), with
# tools/cpuhz.c and writes to CLUSTER_PSTATE (base + 0x20020):
#   p-state  6 -> 2649 MHz   ADT table entry [4]  2652 MHz
#   p-state  7 -> 2961 MHz   entry [5]            2964 MHz
#   p-state 12 -> 4041 MHz   entry [10]           4044 MHz
#   p-state 15 -> 4303 MHz   entry [13]           4308 MHz
#   p-state 16 -> refused, the cluster settles at 15 (entry [14] 4380 MHz).
# So p-state N is entry N-2 of the cluster's pmgr voltage-states<k>-sram
# (kHz, mV); 16 is left out. The status register at +0x20050 uses the T8112
# layout, so the stock driver's apple,t8112-cluster-cpufreq path fits.
#
# Only the M clusters are emitted: the P cluster's offset is unverified (it
# has never run). Its CPUs get no OPP table, which leaves them unmanaged.
import sys
import os
sys.path.insert(0, os.environ.get('M1N1_PROXYCLIENT', os.path.expanduser('~/tether/proxyclient')))
from m1n1 import adt
dt = adt.load_adt(open(sys.argv[1], 'rb').read())

PSTATE_OFFSET = 2      # p-state N = table entry N - 2 (measured, see above)
MAX_PSTATE = 15        # 16 is refused by the hardware
DT_PREFIX = {0: 'm0', 1: 'm1'}   # ADT cluster-id -> dt/t6050.dtsi cpu label prefix

pmgr = dt['/arm-io/pmgr']._properties
# pmgr acc-clusters: (cluster << 8) | voltage-states index, per cluster
acc = {}
raw = pmgr['acc-clusters']
for i in range(0, len(raw), 8):
    v = int.from_bytes(raw[i:i + 4], 'little')
    acc[v >> 8] = v & 0xff

clusters = {}
for cpu in dt['/cpus']:
    p = cpu._properties
    cl = p['cluster-id']
    # DVFS block = cpm-impl-reg - 0x40000 (as on M1: cpm 0x210e40000, DVFS 0x210e00000)
    clusters.setdefault(cl, (p['cluster-type'], p['cpm-impl-reg'][0] - 0x40000))

out = []
w = out.append
w("// SPDX-License-Identifier: GPL-2.0+ OR MIT")
w("/*")
w(" * T6050 CPU cluster DVFS (apple-soc-cpufreq).")
w(" * GENERATED from the runtime ADT (build/adt-runtime-j714s.bin) by")
w(" * gen-cpufreq-dt.py; see there for the measured p-state/frequency mapping.")
w(" */")
w("")
w("/ {")
for cl, (ctype, base) in sorted(clusters.items()):
    if cl not in DT_PREFIX:
        continue
    assert ctype == 'M', (cl, ctype)
    states = list(pmgr[f'voltage-states{acc[cl]}-sram'])
    pairs = list(zip(states[0::2], states[1::2]))
    name = DT_PREFIX[cl]
    w(f"\t{name}_opp: opp-table-{name} {{")
    w('\t\tcompatible = "operating-points-v2";')
    w("")
    for level in range(PSTATE_OFFSET, MAX_PSTATE + 1):
        khz, mv = pairs[level - PSTATE_OFFSET]
        w(f"\t\topp{level:02d} {{")
        w(f"\t\t\topp-hz = /bits/ 64 <{khz * 1000}>;")
        w(f"\t\t\topp-level = <{level}>;")
        w(f"\t\t\topp-microvolt = <{mv * 1000}>;")
        w("\t\t\tclock-latency-ns = <8000>;")
        w("\t\t};")
    w("\t};")
    w("")
w("};")
w("")
w("&soc {")
for cl, (ctype, base) in sorted(clusters.items()):
    if cl not in DT_PREFIX:
        continue
    name = DT_PREFIX[cl]
    perf = base + 0x20000
    w(f"\tcpufreq_{name}: performance-controller@{perf:x} {{")
    w('\t\tcompatible = "apple,t6050-cluster-cpufreq", "apple,t8112-cluster-cpufreq",')
    w('\t\t\t     "apple,cluster-cpufreq";')
    w(f"\t\treg = <{perf >> 32:#x} {perf & 0xffffffff:#010x} 0x0 0x1000>;")
    w("\t\t#performance-domain-cells = <0>;")
    w("\t};")
    w("")
w("};")
for cl in sorted(clusters):
    if cl not in DT_PREFIX:
        continue
    name = DT_PREFIX[cl]
    for core in range(6):
        w("")
        w(f"&cpu_{name}_{core} {{")
        w(f"\toperating-points-v2 = <&{name}_opp>;")
        w(f"\tperformance-domains = <&cpufreq_{name}>;")
        w("};")
print("\n".join(out))
