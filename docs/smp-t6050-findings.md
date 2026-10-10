# T6050 (M5 Pro, J714s) secondary CPUs: what we measured

Status as of 2026-10-09. MacBook Pro 14" M5 Pro, Mac17,9 / J714sAP, 15-core
bin, macOS 26.5 (25F71) boot objects (mBoot-18000.120.36), raw m1n1 installed
as the custom boot object. Linux runs single-core. Probe scripts are in
[`scripts/probes/`](../scripts/probes/). Raw probe output is in
[`research/probe-logs/`](research/probe-logs/).

## Short version

A released secondary powers up but executes **nothing** we can observe. That
covers its locked RVBAR and iBoot's WFI sled. The test does not depend on
cache coherency.

## Setup that makes this repeatable

- Everything ran on the *installed* stage-1 m1n1 with no chainload. The
  pinned m1n1 is `4184923` plus small patches.
- Before each experiment, the WD1 watchdog is armed from the proxy
  (`wdt-arm.py`). A probe that hangs the bus then resets the machine into
  stage-1 within about 90 s.
- The release is XNU's `configMiscCores` sequence:
  - `PMGR reg[0] + 0x88004` gets `BIT(cpu-id)`.
  - `+0x88008 + 4*cluster` gets `BIT(core)`.

## Results

1. **The release works as far as power goes.**
   - CPU_START `+0x0` and `+0x4` both read `0x3fffe` at rest, and the
     release clears the core's bit in both.
   - The core's PMGR device goes from `0x100` to `0x1f0`.
   - `cpu-impl-reg+0x100` changes from `...d800` to `...caef20d102`
     (cluster 0) or `...4aef205102` (clusters 1 and 2).
   - Its low byte, `0x02`, matches the boot core's. Bits 15:14 and 39:38
     (cluster 0), or 14 and 38 (clusters 1 and 2), are set where the boot
     core instead has bit 37.
2. **Nothing executes at RVBAR.**
   - `cpu-impl-reg+0` is locked to m1n1's base on all 15 cores.
   - We replaced vector slot 0 with a stack-free stub, written with m1n1's
     MMU off.
   - The stub stores MPIDR to a cleaned and invalidated DRAM buffer.
   - No crumb appears from M cores in clusters 0 and 1 or from P cores in
     cluster 2.
3. **Nothing executes in the sled either.**
   - The secondary-only `CTRR_C` window is exactly
     `[top_of_kernel_data - 0xc000, top_of_kernel_data)`. It holds 12288
     `wfi` instructions.
   - `CTXR_A` and `CTXR_B` (EL1) cover its first and second 16 KiB.
   - iBoot builds the window itself on the raw-image path: it allocates
     0xc000 bytes, fills them with `0xd503207f` and keeps the address in a
     global.
   - Rewritten from the boot core as a `bl` sled into a crumb stub, it
     produces no crumb. Fast IPIs (`IPI_RR_LOCAL`/`IPI_RR_GLOBAL`) to wake
     WFI make no difference.
4. **The result does not depend on caches.** Both traps' first instructions
   arm the watchdog for a reset 3 s (RVBAR) or 8 s (sled) later. No reset
   ever follows a release.
5. **Other observations:**
   - The boot core's architectural `RVBAR_EL2` reads `0x1fc08c000`, which is
     LLB's link base in SRAM. That memory hangs the bus, even with the MMU
     off.
   - External debug is closed. `EDPCSRlo` and `cpu-uttdbg-reg+0x90` read 0,
     and `EDPCSRhi` hangs the bus.
   - These also hang the bus: `cpm-impl-reg+0x40f8` (read or write), which
     is macOS `restoreACC`'s `0xe440f8` and m1n1 cpufreq's `+0x440f8` on
     M1–M3; and scans of `cpu-impl-reg+0..0x200`.
6. **Things that are not the cause:**
   - Chainload and heap placement. They are real issues (the heap must stay
     above the window, as in GravityLinux `e779ec7`), but SMP also fails on
     the cold stage-1.
   - The CPU_START bit numbering. It is one bit per ADT cpu-id, which for
     cluster 0 equals m1n1's.

## Working theory

Released cores fault on their first fetch, or run somewhere else entirely.
Because iBoot points CTXR (execute regions) at the WFI sled on the raw-image
path, the leading idea is an execute restriction on secondaries that m1n1's
RVBAR target cannot satisfy. Next we reverse iBoot (and SPTM, for the macOS
path) to see how a raw-image boot is meant to hand secondaries over.

## Firmware RE: iBoot/LLB reset entry and the (absent) SPTM path

Disassembling `sptm.t6050.release` (the SPTM blob iBoot loads for macOS on
this chip; symbols survive in log strings) with Ghidra:

- `sptm_resume_cpu` (`0xfffffff0270c042c`) is on the per-CPU resume path. It
  reprograms the **execute-transition** control registers
  `CTXR_{A,B,C,D}_CTL_EL1` (`s3_0_c11_c5_{2,3,4,5}`): first disabled
  (`0x4000...000`), then with packed region descriptors, then enabled
  (bits 63:62). It also writes per-CPU TPIDR-indexed state at `+0xa30`,
  `+0xa60`, `+0xa68` and sets up handoff pages.
- `sptm_register_cpu` (`0xfffffff0270bc6bc`) walks `/cpus`, matches a node by
  its `reg` (ADT cpu-id) and records `cpu-impl-reg` into a per-CPU table.
- iBoot locks these CTXR/CTRR registers (its own
  `%s: CTRR-A/B per-core register not locked by iBoot` checks confirm it);
  they are the family m1n1 PR #688 named for exactly this SoC.

**Correction (CTXR is not the gate).** The t0 probe already read the *boot*
core's CTXR and CTRR_C, and they point at the **same sled** a secondary has:
`CTXR_A = [0x…5fb0000, …5fb3000)`, `CTXR_B = […5fb4000, …5fb7000)`,
`CTRR_C = […5fb0000, …5fbb000)`. The boot core runs m1n1 regardless, so
"CTXR/CTRR_C set to the sled" is the *normal* running state and does not stop
a core executing m1n1. Scratch the "execute-region never set" theory.

**What the reset entry actually is.**

- iBoot loads SPTM only on the **kernelcache** path (`lay_out_sptm_objects`,
  `sptm-path`, tied to `load_kernelcache`). m1n1 is installed `--raw`
  (`kmutil … --raw --entry-point 2048`), so it takes iBoot's raw-image path
  and **no SPTM is loaded at all** — there is no SPTM resume path on our boot.
- iBoot's raw path builds the 48 KiB WFI sled in DRAM and locks a set of
  CTRR/CTXR regions through one generic routine
  `FUN(index, lower, upper, pagecount≤256, …)` (`0x100c1c9e41c`), which
  writes `CTRR_{A..D}` / `CTXR_{A..D}` per index. This is what sets CTRR_C to
  the sled.
- The MMIO "RVBAR" at `cpu-impl-reg+0` reads m1n1-base on **every** core
  including the boot core, yet a crumb planted at that target never runs on a
  secondary. So the secondary does **not** fetch from the MMIO-RVBAR vector.
- The architectural `RVBAR_EL2` is `0x1fc08c000` — LLB's SRAM link base. That
  SRAM hangs the proxy bus on read (it is firmware-protected). LLB's reset
  vector there is the standard relocation stub; its secondary path runs from
  that protected SRAM.
- LLB's own early MPIDR-dependent code (`llb+0x2dc18`) is **cluster-enable**
  (`S3_3_C15_C7_0`, a core/cluster-enable sysreg), not a per-core reset
  handler, so the handler is not sitting in the LLB payload either. It is
  ROM/firmware-resident.

**Conclusion.** A released T6050 secondary resets into a **protected SRAM
reset handler** (LLB/ROM), not into m1n1. That handler reads a per-core
handoff/mailbox to decide where to go next; on macOS this is wired to
SPTM/XNU, on the raw boot path it is never wired to m1n1, so control never
reaches us. The handler is not in the iBoot image and the SRAM is unreadable
from the proxy, so static iBoot RE cannot crack it from here.

**Next (needs hardware/hypervisor, not more statics).** Trace macOS's own
secondary start under the m1n1 hypervisor and watch what the reset handler
reads (the per-core mailbox), which is the only route that does not require
reading protected SRAM. That needs the hypervisor + SPTM emulation working on
T6050 first. Smaller on-hardware checks worth doing in one m1n1 session:
read each secondary's architectural `RVBAR_EL2` is impossible from the boot
core (EL2, per-core), but we can dump the full CTRR/CTXR/ACC_CTRR CTL+lock
set on the boot core and re-confirm the sled bounds track `top_of_kernel_data`
across boots.

Toolchain: `rea-agents` (rea.tools) driving Ghidra 12.1.4 headless; the
`.snap` caches make follow-up queries fast. Firmware came from the J714s 26.5
IPSW via `scripts/extract-tpmtfw.py`'s range reader.
