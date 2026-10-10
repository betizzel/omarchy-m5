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
