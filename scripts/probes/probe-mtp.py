#!/usr/bin/env python3
"""Read-only probe of everything the MTP keyboard/trackpad path touches, run
from the tether bundle (hv/ next to proxyclient/) with the M5 sitting in m1n1:

    hv/probe-mtp.py

Every access is a single guarded 32-bit load followed by dsb sy; isb inside the
same u.exec() call (same convention as probe-pmgr.py), so an SError is counted
against the right register. NOTHING is written and no FIFO/mailbox register
that pops data (RX_8/RX_32, I2A_RECV*) is read.

Addresses come from the runtime ADT through m1n1's get_reg() (already
translated), so the script follows whatever dump-adt.sh captured. Expected
values for a clean iBoot hand-over are in the comments; the answers decide:

  - ASC CPU_CONTROL.RUN (bit 4)  -> iBoot really left the pre-loaded MTP
    firmware running (iop-mtp-nub pre-loaded = 1).
  - DART PROTECT bit 0           -> if set, TCR/TTBR are locked and Linux's
    apple-dart cannot attach MTP at all (it would skip hw_reset and the
    remap/TTBR writes are ignored).
  - DART PARAMS3 VA width        -> ias; the ADT vm-base 0x10000004000 needs
    ias >= 41 for apple,dma-range to be accepted by apple_dart_probe().
  - mailbox A2I/I2A control      -> mailbox is the apple,asc-mailbox-v4 layout
    (0x110/0x114 relative to reg[0]+0x8000): EMPTY(17)/FULL(16) bits sane.
  - dockchannel IRQ_MASK/FLAG    -> whose bits are live: Linux assumes TX=bit2,
    RX=bit3 for the MTP pair. Compare against channel-number = 0 in the ADT.
"""
import sys, pathlib
sys.path.append(str(pathlib.Path(__file__).resolve().parents[1] / "proxyclient"))
from m1n1.setup import *
from m1n1.proxy import ProxyError

LOAD = "ldr w0, [x0]\n dsb sy\n isb"


def rd(addr):
    try:
        return u.exec(LOAD, addr, silent=True) & 0xffffffff
    except ProxyError:
        return None


def show(name, addr, note=""):
    v = rd(addr)
    s = "SERROR" if v is None else f"{v:#010x}"
    print(f"  {addr:#014x}  {name:<28} {s}  {note}")
    return v


mtp = u.adt["/arm-io/mtp"]
dart = u.adt["/arm-io/dart-mtp"]
dc = u.adt["/arm-io/dockchannel-mtp"]

asc = mtp.get_reg(0)[0]
print(f"ASC block   {asc:#x}   (ADT reg[0], size {mtp.get_reg(0)[1]:#x})")
v = show("CPU_CONTROL", asc + 0x44, "bit4 RUN expected 1")
if v is not None:
    print(f"      RUN={bool(v & 0x10)}")

mbox = asc + 0x8000
print(f"\nmailbox     {mbox:#x}   (apple,asc-mailbox-v4 layout)")
a2i = show("A2I_CONTROL", mbox + 0x110, "EMPTY=bit17 FULL=bit16")
i2a = show("I2A_CONTROL", mbox + 0x114, "non-empty => MTP already queued a message (HELLO?)")

dbase = dart.get_reg(0)[0]
print(f"\ndart-mtp    {dbase:#x}   (t8110, m1n1 uses reg[0] as base)")
p1 = show("PARAMS1", dbase + 0x00)
p2 = show("PARAMS2", dbase + 0x04)
p3 = show("PARAMS3", dbase + 0x08, "VA width [21:16], PA width [29:24]")
p4 = show("PARAMS4", dbase + 0x0c, "NUM_SIDS [8:0]")
prot = show("PROTECT", dbase + 0x200, "bit0 = TTBR/TCR locked (BAD for Linux)")
show("ENABLE_STREAMS[0]", dbase + 0xc00)
for sid in range(6):
    show(f"TCR[{sid}]", dbase + 0x1000 + 4 * sid, "iBoot state; Linux rewrites it")
for sid in range(2):
    show(f"TTBR[{sid}]", dbase + 0x1400 + 4 * sid)
err = show("ERROR", dbase + 0x100, "bit31 = fault latched")
if p3 is not None:
    print(f"      VA width = {(p3 >> 16) & 0x3f}, PA width = {(p3 >> 24) & 0x3f}")
if prot is not None:
    print(f"      DART locked: {bool(prot & 1)}")

irq = dc.get_reg(1)[0]
cfg = dc.get_reg(2)[0]
dat = dc.get_reg(3)[0]
rcfg = dc.get_reg(4)[0]
rdat = dc.get_reg(5)[0]
print(f"\ndockchannel-mtp irq={irq:#x} cfg={cfg:#x} data={dat:#x} rmt-cfg={rcfg:#x} rmt-data={rdat:#x}")
show("IRQ_MASK", irq + 0x0)
show("IRQ_FLAG", irq + 0x4, "bit2 TX / bit3 RX are what the DT uses")
show("cfg TX_THRESH", cfg + 0x0)
show("cfg RX_THRESH", cfg + 0x4)
show("data TX_FREE", dat + 0x14, "FIFO size 0x800 expected when idle")
show("data RX_COUNT", dat + 0x2c, "bytes waiting from MTP")
show("rmt cfg TX_THRESH", rcfg + 0x0)
show("rmt data TX_FREE", rdat + 0x14)
show("rmt data RX_COUNT", rdat + 0x2c)

print("\nfirmware segments (ADT iop-mtp-nub segment-ranges):")
import struct
seg = getattr(u.adt["/arm-io/mtp/iop-mtp-nub"], "segment-ranges")
names = getattr(u.adt["/arm-io/mtp/iop-mtp-nub"], "segment-names").split(";")
for i, n in enumerate(names):
    phys, iova, remap, size, unk = struct.unpack_from("<QQQII", seg, 32 * i)
    print(f"  {n:<10} phys={phys:#x} iova={iova:#x} remap={remap:#x} size={size:#x} unk={unk}")
print("pre-loaded:", getattr(u.adt["/arm-io/mtp/iop-mtp-nub"], "pre-loaded"))
