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

## ⚠️ Strategic reframe (2026-10-10): the blocker is SPTM, and the hv-trace is a dead end

New information changes the conclusion of everything below. On macOS 26.5 the
**Secure Page Table Monitor (SPTM) is a boot-active, signed component on T6050**
(and on M2/M3/M4/A18 Pro/M5 — every current Apple-Silicon Mac chip *except* the
original M1 t8103). SPTM runs at **GL2, above EL2**, and owns the page tables.

Consequences, from independent static RE of the SPTM/iBoot blobs (see Prior art):

- **The "boot macOS as a guest under m1n1 and trace its MMIO" method cannot work
  on T6050.** SPTM intercepts the guest's page-table operations; a hypervisor can
  no longer transparently observe macOS. Our own attempt died at the Apple
  `AVNCR_EL2`/GXF wall (`HANDOFF-smp-trace.md`) — that was a *symptom* of this
  deeper architectural block, not a mere porting gap. **This leg is abandoned.**
- **The secondary-CPU reset entry is SPTM-mediated.** On SPTM silicon the reset
  vector lands in SPTM's bootstrap (e.g. `0xfffffff0270af000` on T8132), which
  runs *under iBoot, before m1n1*; SPTM then installs guarded (GL2) vectors and a
  runtime dispatcher. **Multi-die (Pro/Max) per-die secondary-CPU GL2 bring-up is
  explicitly SPTM's job.** This is the most likely reason a released T6050
  secondary **powers up but executes nothing we can observe** (everything below):
  the core comes up in SPTM's guarded domain, and m1n1 — which is not registered
  with SPTM as a dispatch domain — cannot direct it.
- **The path forward is the XNU-shim, not the hypervisor.** Proposed by Sven
  Peter (CCC Dec 2025): a minimal m1n1 stub that satisfies SPTM's boot protocol
  (register a valid dispatch table, masquerade as the XNU domain, drive SPTM's
  state machine from bootstrap into running), then hands off to Linux. Secondary
  bring-up would then go through SPTM's per-die protocol, not the raw
  PMGR+RVBAR dance that worked pre-SPTM on M1–M3.

**Prior art (do not re-derive): [`antiapplefox/m5-linux`](https://github.com/antiapplefox/m5-linux)**
has closed much of the SPTM static RE end-to-end from the 25F71 IPSW — the
`genter` dispatch internals, `dispatch_state_machine`, the
`sptm_register_dispatch_table` contract, a 148-entry `(subsys, idx)` call map,
and m1n1 scaffolding patches (chip IDs / MIDR / `features_m4` stubs / an
xnu-shim boot-handoff stub). It is static-only and aligns with Aurora Silicon's
M5 track. Credit also to **Sven Peter / Asahi Linux** for the method and the
shim framing.

**What this repo uniquely adds (complementary, not duplicate):** live T6050
hardware. m5-linux explicitly *lacks* hardware (it lists M5 MIDR part IDs as
"unknown — need `mrs midr_el1` on real metal"). We have the running machine: the
real MIDR/MPIDR, the PMGR `CPU_START` layout and the `configMiscCores` release
sequence (below), the ADT-derived device trees (`dt/`), and the on-hardware m1n1
USB fix for T6050 (`patches/m1n1/0005`). The measurements below remain valid and
useful **as the hardware-side ground truth** the shim work will need to validate
against — they are just no longer a route to a *hypervisor* trace.

### What SPTM does with a secondary CPU (RE'd from the T6050 SPTM binary, 2026-10-10)

This is the one piece the m5-linux static RE does **not** cover — it focused on
the primary boot handoff and peripherals, not secondary-CPU bring-up — so it is
net-new and directly on our SMP question. Reversed from the panic/assert strings
in the real `sptm.t6050.release` Mach-O (the same callee-side method m5-linux
used; `~/guest/sptm.macho`), cross-referenced with their `(subsys, idx)` map:

- **SPTM registers and validates every CPU.** Subsystem-0 calls on the boot
  path: `0x0e` = CPU-topology query (`_ml_get_topology_info`), `0x12` =
  `sptm_register_cpu` / `cpu_init`, `0x13` = `sptm_n_cpus`. The binary carries
  `sptm_cpu_init`, `sptm_parse_cpu_ranges`, `sptm_cpu_id`, and per-CPU state via
  `cpu_data->logical_id` / `calling_domain(sptm_cpu_data_ptr_fast())`.
- **An unregistered / wrong-ID core is a hard SPTM violation**, not a no-op:
  `VIOLATION_ILLEGAL_CPU_REGISTRATION`, `VIOLATION_INVALID_CPU_PHYSICAL_ID`,
  `VIOLATION_SART_CPU_RACE`, and `assert 'cluster_id <= MAX_CPU_CLUSTER_PHY_ID'`.
  There is also an `ignore-secondary` concept (an ADT/boot property SPTM reads,
  not present in our Linux DT).
- **Why this matches our hardware symptom exactly.** When we release a secondary
  the old (pre-SPTM) way — PMGR `CPU_START` write, secondary resets toward
  m1n1's locked RVBAR — on T6050 the core instead enters **SPTM's** reset path
  in its guarded domain. With no prior `sptm_register_cpu` for it and no XNU
  dispatch domain registered, SPTM has nowhere valid to send it, so it never
  runs anything m1n1 can observe. That is the concrete form of "powers up,
  executes nothing" documented below.
- **Consequence for any fix.** Bringing up SMP on T6050 is not a reset-vector
  tweak; the boot object must be SPTM-aware — register as the XNU domain, then
  drive `sptm_register_cpu` (idx `0x12`) per core with a valid physical/cluster
  ID before (or as part of) releasing it. This is the SMP-specific slice of the
  XNU-shim and the natural thing to split with the m5-linux / Aurora track.

**Disassembly-confirmed (not just strings).** The `sptm_register_cpu` handler in
`sptm.t6050.release` is at vaddr `0xfffffff0270bc8a0` (found via xrefs to its
assert string `__TEXT.__cstring:0xfffffff0270062f5`; disassembled with
`aarch64-linux-gnu-objdump`). Its body:
1. converts each of the CPU's register ranges to 16 KB page frames
   (`(addr + 0x3fff) >> 14`);
2. **retypes those MMIO frames into SPTM ownership** — three `bl 0xfffffff0270ddb00`
   (the retype/claim helper), one per range;
3. records the frames into a per-CPU structure (`str x,[x24,#0x1440/#0x1448/…]`);
4. marks the CPU registered with a release-store flag (`mov w8,#1; stlrb w8,[x24]`),
5. all behind a cluster of assert/panic sites (`bl 0xfffffff0270fc830`,
   `0xfffffff0270fc870` with code `0x16`) — the `VIOLATION_*CPU*` failures.

So registration is not a formality: SPTM *takes ownership of the core's register
pages*. A bare PMGR release does none of this, which is the mechanism behind the
hardware symptom below. Next RE step: the `sptm_cpu_init` handler
(`xref @ 0xfffffff0270e0f78`) and the secondary **entry** vector, best anchored
against live `mrs midr_el1` / cluster IDs from this machine — which we have and
the static-only track does not.

Everything from here down is the original hardware investigation, preserved.

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

## What the firmware reset entry does (SPTM, readable even though unused here)

SPTM is the one piece of the macOS reset path that *is* in a readable blob
(`sptm.t6050.release`), so it shows what a secondary is meant to do on reset.

- **One reset vector for all cores.** SPTM's Mach-O `LC_UNIXTHREAD` entry is
  `0xfffffff0270ac388` (`__TEXT_EXEC`). It gates first-core vs. later-core on
  a global flag (`DAT_…0ae008`), so every core — boot and secondary — resets
  to the *same* SPTM entry.
- **It is heavyweight EL2 bring-up.** At `currentel == EL2` it sets
  `vbar_el1 = 0xfffffff0270ad000`, ORs host/VHE bits into `HCR_EL2`
  (`|0x408000000`), zeroes `cntvoff_el2`, then **builds its own page tables**
  (the `__LATE_CONST`/`__BOOTDATA` loops) before dispatching. A core cannot
  reach XNU without this running first.
- **`sptm_cpu_init` (`0xfffffff0270e0e30`)** is per-CPU bookkeeping: it indexes
  a `cpu_data` table by cpu-id (stride `0x1640`), refuses to re-init a started
  CPU, records the per-CPU stack/handoff, and sets the cluster-present bit from
  `MPIDR` Aff1 (`1 << ((mpidr>>8)&0x1f)`), flagging the first core in each
  cluster. `sptm_resume_cpu` (seen earlier) is the part that programs
  `CTXR_{A..D}_CTL_EL1`.

**Why this matters for m1n1.** On macOS the secondary reset vector points at
this SPTM entry, which does the EL2/MMU/vbar setup and only then hands to the
OS. m1n1's own `_vectors_start` does equivalent setup and the **boot** core
reaches it fine from iBoot's cold hand-off — so m1n1 can bootstrap a core from
reset. The unresolved gap is purely that a *released secondary* never executes
its reset vector at all (proven: no crumb, no watchdog write), while on macOS
the identical PMGR release lands the core in SPTM. That difference is a live,
per-core property (what state the core resets into, whether the PMGR release
fully deasserts reset on an M-core), which only a hypervisor trace of macOS's
own start can show — not more static disassembly.

## Hardware register dump (2026-10-09, `scripts/probes/smp-ctrr-dump.py`)

Read-only, boot core, under m1n1 (`m1n1 base 0x10004574000`,
`top_of_kernel_data 0x10004d84000`):

| register | value | region |
|---|---|---|
| `CTRR_A_CTL_EL1` | `0x8000000000000001` | **locked+enabled** (kernel-text RO) |
| `CTRR_B_CTL_EL1` | `0x8000000000000001` | **locked+enabled** |
| `ACC_CTRR_C_CTL_EL2` | `0x8000000000000001` | **locked+enabled** |
| `ACC_CTXR_{A,B,C}_CTL_EL2` | `0xc000000000aa02aa` | **locked+enabled** |
| `ACC_CTXR_D_CTL_EL2` | `0xc000000000aa0199` | **locked+enabled** |
| `CTXR_{A,B,C,D}_CTL_EL1` | `0x0` | per-core: unset |
| `CTRR_C` (EL1 and EL2) | `[base+0x804000, base+0x80f000)` | the sled, ends at `top_of_kernel_data` |
| `CTXR_A/B/C` | three 0x3000 slices of the sled | — |
| `CTXR_D` | `[base-0x114000, base-0x1000)` | iBoot runtime just below m1n1 |
| `RVBAR_EL2` | `0x1fc08c000` | LLB SRAM |
| every core `cpu-impl-reg+0` | `…04574001` | m1n1 base, locked |

Two things settle the question:

- **The ACC (cluster) CTXR control values are exactly what SPTM's
  `sptm_resume_cpu` writes** (`0xc0000000…aa…`). So iBoot already left the
  cluster-level execute-transition regions locked and *enabled* — the CTXR
  state a running core needs is already in place, not missing.
- **m1n1's base is OUTSIDE every one of these locked regions** (CTRR_C ends at
  `top`, CTXR_D ends at `base-0x1000`), yet the **boot core executes m1n1 from
  there without trouble.** Identical register state on a secondary therefore
  cannot be why it fails.

**This kills the execute-region theory for good.** Every CTRR/CTXR/ACC region
is locked identically for all cores, m1n1 lives outside all of them, and the
boot core runs anyway. The per-core `CTXR_*_CTL_EL1 = 0` (the thing
`sptm_resume_cpu` would set on a secondary) is also 0 on the running boot core,
so that is not the gate either.

**What's left is below any register we can read:** the M-core is released
(PMGR `0x100 → 0x1f0`, status changes) but never begins fetching its reset
vector. The reset-deassert / fetch-start step that macOS+SPTM perform after the
same PMGR writes is the only remaining difference, and it is observable only by
tracing macOS's own secondary start under the hypervisor — not by any static or
boot-core-register means.

Toolchain: `rea-agents` (rea.tools) driving Ghidra 12.1.4 headless; the
`.snap` caches make follow-up queries fast. Firmware came from the J714s 26.5
IPSW via `scripts/extract-tpmtfw.py`'s range reader.

## Toward the macOS hypervisor trace (foundation unblocked, 2026-10-10)

The only way left to see the reset-deassert is to watch macOS start a
secondary under the m1n1 hypervisor. Progress:

- **Upstream main m1n1 now runs on T6050 with a working USB proxy.** The
  blocker was `usb_init` probing the `usbc,sn201202x,spmi` PD controllers
  (`hpm0/1/2/5` on `nub-spmi-a0/a1`, gen-4 SPMI m1n1 can't drive); it hung
  before the proxy. `patches/m1n1/0005` skips the PD manager on T6050.
  Verified: `v2.0.0-2-g2460b` + our patches chainloads, reaches
  `Running proxy`, and re-enumerates `/dev/m1n1`.
- **The SPTM hosting path exists upstream**, not yet merged: PR #695
  (`hv_sptm`: emulate the IMPDEF sysregs SPTM uses on M4+; virtualise SPRR/GXF
  exception regs; **copy CTRR/CTXR to secondary cores** — Sven: "SPTM expects
  the secondary cores to come up with correct CTRR values") and PR #698
  (basic nested virt + a loader that stages XNU macho + SPTM + TXM +
  TrustCache + ADT + bootargs as a guest via `run_guest`, `xnu_mode`).
  Tested on M2 only; T6050 is unproven.

Progress (2026-10-10): **the SPTM-capable m1n1 builds and runs on T6050.**
`pr698` (= main + PR#695 + PR#698) + patches 0003/0004/0005 (0001/0002 not
needed for a bare proxy boot; main already upstreamed the T6050 DAPF skip)
builds, and `v2.0.0-4-ga8b1a` chainloads to `Running proxy` with `/dev/m1n1`
re-enumerating — the hypervisor base with SPTM/GXF emulation, verified on hw.

J714s guest objects (26.5 BuildManifest): kernelcache `kernelcache.release.mac17j`,
`sptm.t6050.release` (have it), `txm.macosx.release`, TrustCache
`Firmware/094-56195-095.dmg.trustcache` — all in the IPSW.

**Decision point — how to stage the macOS guest.** `run_guest.py`'s
`load_raw`/`load_macho` pulls SEPFW, **TrustCache, the ADT and bootargs from the
*running* m1n1's boot** (`self.u.adt["chosen"]["memory-map"]`). On our boot
those belong to the **Omarchy stub + m1n1**, not macOS, so a guest XNU gets the
wrong trust/ADT/bootargs. Two ways:
- **(a) Install the SPTM m1n1 on the macOS volume** (`kmutil configure-boot` in
  1TR, like the stub ceremony) so iBoot stages macOS's *real* boot objects and
  the hv runs the real XNU as a guest. Clean, but touches the user's macOS boot
  policy (reversible, needs consent + a 1TR ceremony).
- **(b) Assemble a guest from the IPSW objects** and override ADT/TrustCache/
  bootargs ourselves under the stub's Permissive security. Less invasive, but
  SPTM/XNU auth and the hand-built ADT are unproven and may not boot.

Remaining, to actually trace (multi-session, T6050-SPTM is the risk):
1. Build `main + PR#695 + PR#698 + our patches` (0002 hv-timer, 0003 wcslen,
   0004 chainload/wdt, 0005 usb; 0001 kboot not needed to host macOS). The
   patches need path fixups — main moved `src/hv.c` → `src/hv/`.
2. Assemble the macOS guest from this install's boot objects (SPTM
   `sptm.t6050.release`, the XNU kernelcache, TXM, TrustCache, the runtime
   ADT, bootargs) and boot it under the hv.
3. Hook the PMGR CPU_START block (`pmgr reg0 + 0x88000`) and each
   `cpu-impl-reg+0x100` while macOS brings a secondary up; capture the step
   between the `+0x88004/+0x88008` writes and the core checking in.

## Guest-boot attempt via option (b): blocked on `AVNCR_EL2` (2026-10-10)

Built the SPTM m1n1 (`main @ PR#698 a8b1ae46` = incl. PR#695, + patches
0003/0004/0005; 0.0 `make CHAINLOADING=1` → `/tmp/m1n1-sptm.bin`), chainloaded
it on T6050 ("Running proxy", USB up), extracted + LZFSE-unwrapped the macOS
objects from the 26.5 IPSW (`xnu.macho` 115 MB, `sptm.macho`, `txm.macho`,
restore trust cache), and ran `run_guest.py -P --sptm --txm xnu`. Result:

- `SPRR/GXF: emulating in EL2` activates — the SPTM path is live on T6050.
- m1n1's own `smp_start_secondaries()` **fails for all 14** (the very bug we
  are chasing): the hv cannot host the guest on real secondaries, only emulate
  guest starts by trapping PMGR on the boot core.
- `hv_init` then **UNDEFs at `hv_init+0x58`** (`ESR 0x2000000`, EC=0, `FAR 0`).
  The faulting word `0xd51cfae0` decodes to `msr s3_4_c15_c10_7, x0` =
  **`msr SYS_IMP_APL_AVNCR_EL2, x0`** (the Apple nested-virt register, new #698
  code). The architectural `VNCR_EL2` write immediately before it succeeds.
- **Root cause (confirmed):** `AVNCR_EL2` is **GL2-only on T6050** (EL2-writable
  on M1/M2). The write must go through `gl2_call` like m1n1 already does for
  `HCR_EL2`/`HACR_EL2`; patch `0006` adds `hv_write_avncr()` to do that. But the
  deeper block is that **GXF is disabled in m1n1's hv on T6050**: `gxf_enabled()`
  needs `AIDR_EL1.GXF && cpu_features->mmu_sprr`. The hardware has GXF
  (`AIDR_EL1 = 0x12bd170699696`, bit 16 set; `SPRR/GXF_CONFIG = 0`), but T6050
  maps to the **`features_m4` stub** (`chickens.c:164`, `NULL` init, no
  `.mmu_sprr`), so `supports_gxf()` is false and `gxf_init()` never runs. With
  patch 0006 the crash just moves into `hv_write_avncr` (the `else` path).
  Naively setting `.mmu_sprr=true` to enable GXF **hangs m1n1's own MMU on
  T6050** (chainload never reaches "proxy"), so a proper T6050 SPRR/GXF port is
  required.

**Next:** port SPRR/GXF init to T6050 (M5 `init_cpu` + SPRR config, modelled on
M3), then AVNCR writes via GL2 work (patch 0006); then handle the TrustCache
mismatch (`load_macos_sptm` copies the *stub's* trust cache, which won't
authorize the macOS kernelcache). Full live state: `docs/HANDOFF-smp-trace.md`.
