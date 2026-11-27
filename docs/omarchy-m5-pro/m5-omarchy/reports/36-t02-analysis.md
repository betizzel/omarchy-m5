# 36 — NATIVE t02 (MTP read-only dump): the MTP CPU never runs; its power state reads clock-gated

Source: `reports/native-t02-mtp-dump.txt` (gz16 default boot, loop-v1 kernel, m5_mtp `ba5f9dd9…`). Values were identical in both passes unless noted. Decoded against `drivers/iommu/apple-dart.c` (T8110), `drivers/soc/apple/mailbox.c`, `drivers/soc/apple/rtkit-helper.c` and `drivers/pmdomain/apple/pmgr-pwrstate.c` (field layout), all in our asahi-wip-7.2 tree.

## Decode
| Block | Register | Value | Meaning |
|---|---|---|---|
| DART 0x294800000 | PARAMS 0x0–0xc | 0x1e311020 0x31111007 0x2a2a0204 0x00010010 | Unchanged by anything; probe accepted them (16 streams, 16K pages, AS 42) |
| | ERROR 0x100 / ERROR_MASK 0x104 | 0 / 0 | **No DART fault ever latched** (no errors masked). ERROR_ADDR 0x170/0x174 = 0, ERROR_STREAMS 0x1c0 = 0 |
| | PROTECT 0x200 | 0x1a | `PROTECT_TTBR_TCR` (BIT 0) **clear**: TCR/TTBR writable. Bits 1, 3, 4 undefined in the driver |
| | tunable offsets 0x20c/0x220/0x224/0x300/0x308/0x310 | 0x80000135 0xf0f 0x909 0x1 0x10000000 0x3fffffff | **Every ADT tunable already satisfied** (`(v & mask) == value` for all six): iBoot applied them. t04/t05 are moot |
| | ENABLE_STREAMS 0xc00 | 0xffff | All 16 streams enabled |
| | TCR sid0 0x1000 | 0x9 | TRANSLATE_ENABLE \| FOUR_LEVEL; **BYPASS_DAPF (BIT 2) clear** |
| | TCR sid1–4 | 0x80 | REMAP_ENABLE (BIT 7), REMAP (11:8) = 0: streams 1–4 use sid 0's tables (Linux's `enable_remap` for one group) |
| | TTBR sid0 0x1400 | 0x10074cd1 | VALID; table PA = (v & ~3) >> 2 << 14 = **0x100_74cd_0000** (Linux's L1 table). sid1–4 TTBR 0 (remapped) |
| Mailbox 0x294608000 | A2I_CONTROL 0x110 | **0x00200201 → 0x00400401** (after the re-probe) | FULL (BIT 16) clear. [HYPOTHESIS] bits 23:20 / 11:8 are the FIFO fill, **2 → 4: AP→IOP messages queued and never consumed**. Each failed probe sends two (wake's `SET_IOP_PWR_STATE INIT` + the shutdown attempt) |
| | I2A_CONTROL 0x114 | 0x00020001 (both) | **EMPTY (BIT 17) set: the IOP never posted anything** (no HELLO) |
| ASC 0x294600000 | 0x40 / CPU_CONTROL 0x44 / 0x48 / 0x4c | 0x1 / **0x10 (RUN)** / 0x4c / 0 | RUN is set (the stock probe sets it; the failure path doesn't clear it). 0x48 unknown, unchanged |
| Wrapper 0x294050000 | +0x0 / +0x4 / rest | **0x94c00001** / 0x2 / 0 | [HYPOTHESIS] +0x0 = boot/remap base **0x294c00000 (= __TEXT in SRAM)** \| enable: iBoot set up where the IOP boots from |
| DAPF 0x294810000 | 0x0–0x3c | 0x110, 0, 0x08c81588, 0x204, 0x0d974053, 0x2af, 0, 0, 0xbcc2, 0… | **Not a window table**: no value resembles the ADT `dapf-instance-0` addresses (0x28830c000…). Looks like ID/config/counters (one sample only) |
| PS_PROT 0x2890fc000 | +0x0 | **0x0501a040** | DART-mtp ADT reg[2] (instance `PS_PROT`), outside every PMGR block. **[HYPOTHESIS, strong] PMGR power-state format** (pmgr-pwrstate.c l.20–36): target (3:0) = **0x0 PWRGATE**, actual (7:4) = **0x4 CLKGATE**, PS_MIN = 1, PS_AUTO = 5, AUTO_ENABLE = 0 |

## What blocks the MTP firmware
**The MTP CPU never executes an instruction after RUN.** Evidence:
1. The IOP never consumes its inbox (A2I fill grows 2 → 4) and never posts (I2A EMPTY). Even a firmware stuck later in boot would normally drain or answer the mailbox.
2. No DMA fault: DART ERROR = 0 with translation on. A running firmware touching an unmapped IOVA would latch one. So the DART/IOVA hypothesis (report 31) is **not** the blocker.
3. The image is where iBoot left it: the wrapper boot base points at __TEXT (0x294c00000), the SRAM segments are reserved (report 31), and the tunables are applied.
4. **The likely reason: the MTP block is not clocked.** PS_PROT reads target PWRGATE / actual CLKGATE. The ADT gives the MTP no `clock-gates`/`power-gates`, so no PMGR domain exists for Linux to turn on. iBoot (in macOS boots, the AppleT6050 drivers) evidently raises it through this register, and our chain never does. [HYPOTHESIS] RUN on an unclocked CPU does nothing, which matches every observation.
- DAPF is not ruled out but is secondary: a DAPF block would not stop the IOP from reading its own mailbox.

## "echo: write error: Timer expired"
That is the sysfs `bind` write returning the probe's error. The re-probe failed with **-62 = -ETIME**, whose `strerror` is "Timer expired" (apple_rtkit_wake → apple_rtkit_boot timeout). The driver core hands the probe error back to the writer, so `echo` fails and `bind rc=1`.
- Side note: the re-probe printed "CPU_CONTROL at probe: RUN (started by the bootloader)". The RUN was left by the **boot-time** probe, not the bootloader, so that message wording (patch 0003) is misleading in re-probes. The cold-restart path then ran and also timed out, which is consistent with an unclocked CPU.

## Next experiments (rebuilt; module `m5_mtp.ko` sha256 `85e83d86d29f2d7f519fc37f2a43654d07cb627300ea6e40c00e072c05176526`, vermagic unchanged, gz15 Image untouched)
| Prio | Set | What | Writes | Decides |
|---|---|---|---|---|
| 1 | **t06** | READ-ONLY time series: PS_PROT, DAPF 0–0x3c, mailbox, ASC, each **twice 2 s apart**, before and after a stock re-probe; then wider read-only windows (wrapper 0x40–0xfc, DAPF 0x40–0x3fc, PS_PROT 0x20–0xfc, ASC 0x0–0x3c, 0x50–0xfc; risky ASC last) | none of ours | Do PS_PROT target/actual change on RUN? Are the DAPF words counters? Where is the DAPF window table? |
| 2 | **t07** (!) | `op=ps_on`: PS_PROT target := 0xf (ACTIVE), other bits kept, W1C flags cleared (as `apple_pmgr_ps_set`), poll actual ≤10 ms; then stock re-probe | **PS_PROT +0x0 (1 write)** | If actual reaches 0xf and RTKit boots (`rtkit-helper` bound, keyboards in /proc/bus/input/devices), the power state was the blocker |
| 3 | t08 (!) | t07 + TCR BYPASS_DAPF on sids 0–4 | PS_PROT + 5 TCR | If t07 boots RTKit but HID or DMA fails |
| 4 | t03 | BYPASS_DAPF only (rebuilt, now also dumps PS_PROT) | 5 TCR | Low: no DART/DAPF symptom seen |
| — | t04 | tunables | — | **Moot** (already applied). t05 removed |

(!) **t07/t08 need a PM/owner decision.** PS_PROT is a register of the DART-mtp node (ADT reg[2]), so it's inside "MTP/DART-mtp" by address. But it's a **power-state control**, which is what the no-PMGR rule protects against. The worst case I can see is a hang or SError in the MTP/AOP fabric: a watchdog reset, then macOS. It's still a new class of write, so I recommend running t06 first and t07 only with explicit approval.

## CORRECTION 2026-11-05 (report 37)
PS_PROT 0x2890fc000 is a clock-protection block shared by many DARTs. Each DART selects its own slice via `clock-protection-slice-index`, and dart-mtp's is 13. The +0 word decoded above is not the MTP's power state. The t07 write there was ignored (NATIVE). Text above stays as written.
