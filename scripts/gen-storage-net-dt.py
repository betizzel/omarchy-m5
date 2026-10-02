#!/usr/bin/env python3
# Generate dt/t6050-storage-net.dtsi from the runtime ADT (no device needed).
import sys
import os
sys.path.insert(0, os.environ.get('M1N1_PROXYCLIENT', os.path.expanduser('~/tether/proxyclient')))
from m1n1 import adt
dt = adt.load_adt(open(sys.argv[1], 'rb').read())

def reg(path, idx):
    n = dt[path]
    a, s = n.get_reg(idx)
    return a, s
def cells(a, s):
    return f"<{a >> 32:#x} {a & 0xffffffff:#010x} 0x0 {s:#x}>"

out = []
w = out.append
w("// SPDX-License-Identifier: GPL-2.0+ OR MIT")
w("/*")
w(" * T6050 storage (ANS NVMe) + USB device-mode (gadget) nodes.")
w(" * GENERATED from the runtime ADT (build/adt-runtime-j714s.bin) by")
w(" * gen-storage-net-dt.py. ADT reg values are translated through /arm-io")
w(" * ranges (+0x200000000 for the low window).")
w(" */")
w("")
w("&soc {")

# ---- ANS / SART / mailbox / NVMe
ans_base, _ = reg('/arm-io/ans', 0)
sart_base, sart_sz = reg('/arm-io/sart-ans', 0)
nvmmu, nvmmu_sz = reg('/arm-io/ans', 3)
nvme, nvme_sz = reg('/arm-io/ans', 9)
ints = list(dt['/arm-io/ans'].interrupts)
idx = dt['/arm-io/ans'].nvme_interrupt_idx
base_irq = min(ints[:4])
mbox = ans_base + 0x8000     # m1n1 src/asc.c: mailbox = reg[0] + 0x8000
w("\tans_mbox: mbox@%x {" % mbox)
w('\t\tcompatible = "apple,t6050-asc-mailbox", "apple,asc-mailbox-v4";')
w("\t\treg = <%#x %#010x 0x0 0x4000>;" % (mbox >> 32, mbox & 0xffffffff))
w("\t\tinterrupt-parent = <&aic>;")
w("\t\t/* ADT order is [n+1, n, n+3, n+2]; Asahi DTs use n..n+3 in name order */")
w("\t\tinterrupts = " + ",\n\t\t\t".join(
    f"<AIC_IRQ {base_irq + i} IRQ_TYPE_LEVEL_HIGH>" for i in range(4)) + ";")
w('\t\tinterrupt-names = "send-empty", "send-not-empty",')
w('\t\t\t"recv-empty", "recv-not-empty";')
w("\t\t#mbox-cells = <0>;")
w("\t\tpower-domains = <&ps_ans>;")
w("\t};")
w("")
w("\tsart_ans: sart@%x {" % sart_base)
w('\t\t/* ADT sart-version = 4 (compatible "sart,coastguard") */')
w('\t\tcompatible = "apple,t6050-sart", "apple,t8132-sart";')
w("\t\treg = " + cells(sart_base, sart_sz) + ";")
w("\t\tpower-domains = <&ps_ans>;")
w("\t};")
w("")
w("\tnvme: nvme@%x {" % nvme)
w('\t\tcompatible = "apple,t6050-nvme-ans2", "apple,t8132-nvme-ans2";')
w("\t\t/* nvme = ADT reg[9] (real NVMe regs; ADT size 0x10000 is too small, the")
w("\t\t * doorbells/LINEAR_SQ regs sit at +0x24908; use 0x60000 like t6030),")
w("\t\t * ans = reg[0] (ASC CPU control, +0x44),")
w("\t\t * nvmmu = reg[3] (NVMMU at +0x28100; m1n1 src/nvme.c T8132 layout) */")
w("\t\treg = " + cells(nvme, 0x60000) + ",")
w("\t\t      " + cells(ans_base, 0x4000) + ",")
w("\t\t      " + cells(nvmmu, 0x60000) + ";")
w('\t\treg-names = "nvme", "ans", "nvmmu";')
w("\t\tinterrupt-parent = <&aic>;")
w("\t\tinterrupts = <AIC_IRQ %d IRQ_TYPE_LEVEL_HIGH>;  /* ADT interrupts[%d] */" % (ints[idx], idx))
w("\t\tmboxes = <&ans_mbox>;")
w("\t\tapple,sart = <&sart_ans>;")
w("\t\tpower-domains = <&ps_ans>;")
w("\t\tresets = <&ps_ans>;")
w("\t};")

# ---- USB: 3 DRDs in peripheral mode, plain snps,dwc3, no PHY driver
for i in range(3):
    d = f'/arm-io/usb-drd{i}'
    dd = f'/arm-io/dart-usb{i}'
    core, _ = reg(d, 0)
    d0, _ = reg(dd, 0)
    d1, _ = reg(dd, 1)
    dsz = 0xc000
    irq = list(dt[d].interrupts)[0]
    dirq = list(dt[dd].interrupts)[0]
    port = dt[d].port_number
    w("")
    w(f"\t/* usb-drd{i}: port-number {port} */")
    w("\tdwc3_%d: usb@%x {" % (i, core))
    w('\t\tcompatible = "snps,dwc3";')
    w("\t\treg = <%#x %#010x 0x0 0xcd00>;" % (core >> 32, core & 0xffffffff))
    w("\t\tinterrupt-parent = <&aic>;")
    w("\t\tinterrupts = <AIC_IRQ %d IRQ_TYPE_LEVEL_HIGH>;" % irq)
    w('\t\tdr_mode = "peripheral";')
    w('\t\tmaximum-speed = "high-speed";')
    w("\t\tiommus = <&dwc3_%d_dart_0 0>, <&dwc3_%d_dart_1 1>;" % (i, i))
    w("\t\t/* No PHY driver: the eUSB2 PHY runs as m1n1's usb_phy_bringup() left")
    w("\t\t * it, and nothing can bring it back out of suspend. So keep the link")
    w("\t\t * awake like m1n1's own gadget does: no USB 2.0 LPM in the BOS (else")
    w("\t\t * the host xHCI parks the link in L1 right after enumeration and")
    w("\t\t * SET_CONFIGURATION times out, -110) and no SUSPHY/ENBLSLPM. */")
    w("\t\tsnps,usb2-gadget-lpm-disable;")
    w("\t\tsnps,dis_u2_susphy_quirk;")
    w("\t\tsnps,dis_u3_susphy_quirk;")
    w("\t\tsnps,dis_enblslpm_quirk;")
    w("\t\t/* no phys/power-domains/resets: m1n1 usb_phy_bringup() left the PHY,")
    w("\t\t * PMGR and DWC3 reset exactly as its own gadget needs them. */")
    w('\t\tstatus = "okay";')
    w("\t};")
    for k, a in ((0, d0), (1, d1)):
        w("")
        w("\tdwc3_%d_dart_%d: iommu@%x {" % (i, k, a))
        w('\t\tcompatible = "apple,t6050-dart", "apple,t8110-dart";')
        w("\t\treg = <%#x %#010x 0x0 %#x>;" % (a >> 32, a & 0xffffffff, dsz))
        w("\t\tinterrupt-parent = <&aic>;")
        w("\t\tinterrupts = <AIC_IRQ %d IRQ_TYPE_LEVEL_HIGH>;" % dirq)
        w("\t\t#iommu-cells = <1>;")
        w("\t};")
w("};")

# ---- USB-C port power domains: hands off.
# m1n1's usb_phy_bringup() powered these for its own gadget; with no consumer
# in this DT, the pmgr-pwrstate probe would set AUTO_ENABLE on them (floor 0),
# and the DWC3 cores then time out in their soft reset (-110), presumably
# because the USB2 PHY clock goes away. Disabled nodes are never probed, so
# the hardware stays exactly as m1n1 left it - same as the PHY itself.
w("")
w("/* Leave the USB-C port domains as m1n1 left them (see gen-storage-net-dt.py). */")
for i in range(3):
    for dom in ("common", "usb_aon", "usb", "phymxwrap"):
        w('&ps_atc%d_%s { status = "disabled"; };' % (i, dom))
print("\n".join(out))
