# Pickup: trace T6050 secondary-CPU reset entry via macOS-under-m1n1-hv (2026-10-10)

> For the next agent continuing the goal **"keep digging into the iBoot reset
> entry"** — i.e. *why do T6050 (M5 Pro) secondary CPUs power up but never
> execute our code?* Read `docs/smp-t6050-findings.md` first (the proven
> negative results and the shareable write-up). This file is the live state
> of the **dynamic** approach: boot macOS as a guest under m1n1's hypervisor
> on the M5 itself and watch what its kernel does to a secondary that we
> cannot reproduce bare-metal.

## TL;DR of where we are

- **Static RE is exhausted.** The secondary reset-deassert path is in
  ROM-resident / SPTM-protected iBoot code (see findings doc §"Firmware RE").
  We cannot read it statically. The remaining lead is to **trace macOS live.**
- **Dynamic plan = run macOS as a guest under m1n1's SPTM hypervisor** and hook
  the PMGR `CPU_START` block + per-core impl status while XNU brings a
  secondary up. m1n1 upstream grew this capability (PRs #643/#695/#698); it was
  only ever tested on M1/M2.
- **This session got the guest to *load* under the hv on T6050** (SPRR/GXF
  emulation activates), then fully root-caused the `hv_init` crash and found
  the *real* blocker. The chain: `hv_init` UNDEFs writing Apple `AVNCR_EL2`
  because that register is **GL2-only on T6050**, and **GXF is disabled** in
  m1n1's hv on T6050 — because T6050 maps to the `features_m4` stub (no
  `.mmu_sprr`), so `supports_gxf()` is false and `gxf_init()` never runs.
  Patch `0006` routes AVNCR through GL2 (correct, but inert until GXF is on).
  Naively setting `.mmu_sprr=true` to enable GXF **breaks m1n1's own MMU
  bring-up on T6050** (chainload never reaches "proxy"). So the blocker is now
  **"port SPRR/GXF init to T6050"**, which is real m1n1 work. Details below.

## Hardware / repo state (verified this session)

- **M5**: Mac17,9 / J714s / **T6050**, macOS 26.5 (25F71), 15 cores (5+5+5).
  Arch on the SSD, reachable at `ssh bay@10.55.2.2` when booted to Linux.
  Boot into m1n1: `cd ~/tether && ./boot-m5.sh` (shows a harmless "pyserial
  error" at handoff; `/dev/m1n1` appears ~15–20 s after a `systemctl reboot`).
- **Repo**: `~/tether/omarchy-m5` **and** `~/Work/omarchy-m5`, branch `main`,
  HEAD **`89e1edb`**, both clean + pushed to `betizzel/omarchy-m5` (private).
- **Watchdog safety net** (always use it for hv experiments):
  `cd ~/tether && python3 hv/wdt-arm.py <secs>` arms a hardware WDT that
  resets the M5 back to stage-1 m1n1 if an experiment hangs; `--off` disarms.
  The experimental m1n1 keeps it armed across chainload via the
  `m1n1.wdt=keep` boot arg (patch 0004).

## The SPTM-capable m1n1 (built + verified on T6050 this session)

- Tree: **`/tmp/m1n1-up`** = upstream m1n1 clone, checked out at PR #698 HEAD
  `a8b1ae46` ("hv: Basic nested virtualization for SPTM support"), which already
  contains PR #695 (hv SPTM sysreg emulation). On top, these **patches are
  applied as uncommitted working-tree edits** (not committed):
  - `patches/m1n1/0003-*` chainload below the CTRR window,
  - `patches/m1n1/0004-*` `m1n1.wdt=keep`,
  - `patches/m1n1/0005-usb-skip-gen4-spmi-pd-on-t6050.patch` — the USB fix that
    unblocked upstream main on T6050 (gen-4 SPMI PD probe via
    `tps6598x_foreach_hpm` hangs; skip it: `if (chip_id != T6050)`).
  - `patches/m1n1/0006-hv-route-avncr-el2-through-gl2.patch` — routes the Apple
    `AVNCR_EL2` write through `gl2_call` (see Root cause). Correct but inert
    until GXF is enabled on T6050; the currently-staged `/tmp/m1n1-sptm.bin`
    includes it. **Do NOT re-add `.mmu_sprr=true` to `features_m4`** to force
    GXF — it hangs m1n1's MMU on T6050 (tried; needs a proper SPRR/GXF port).
  - (Patches 0001/0002 target the **old** `src/hv.c` layout; main moved it to
    `src/hv/`. For a bare proxy boot only 0005 is strictly needed; 0003/0004
    are the watchdog/chainload conveniences, 0006 is the AVNCR groundwork.)
- Build: `cd /tmp/m1n1-up && export PATH="$(dirname "$(~/.cargo/bin/rustup which cargo)"):$PATH" && make -j$(nproc) CHAINLOADING=1`
- Output already built: **`/tmp/m1n1-sptm.bin`** (4.9 MB). 3.8–4.9 MB images
  need `--no-sepfw` to fit below the CTRR window on chainload.
- **Verified**: chainloads to `v2.0.0-4-ga8b1a`, "Running proxy", USB
  enumerates on T6050.

## The macOS guest objects (extracted + unwrapped this session)

In **`~/guest/`**, all unwrapped to arm64e Mach-O and parse cleanly with the
proxyclient `MachO` loader:
- `xnu.macho` (115 MB) — `kernelcache.release.mac17j`, IM4P `krnl`/`bvx2`
  (LZFSE) unwrapped. Has all segments `load_macos_sptm` needs
  (`__DATA_SPTM __TEXT_EXEC __TEXT_BOOT_EXEC __PRELINK_INFO __DATA __LINKEDIT`);
  entry `0xfffffe000bd98000`, vmin `0xfffffe0007004000`.
- `sptm.macho` (1.3 MB) — from `/tmp/fw/sptm.t6050.release.raw`.
- `txm.macho` (475 KB) — `txm.macosx.release.im4p`, IM4P `trxm`/`bvx2` unwrapped.
- `094-56195-095.dmg.trustcache` (11 KB) — the restore trust cache (see caveat).
- **IPSW** (source for all of the above):
  `https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-58869/DFB1CEEF-5619-4591-9924-E20DB2C8FED0/UniversalMac_26.5_25F71_Restore.ipsw`
  Extract without a full download with `scripts/extract-tpmtfw.py`'s
  `HTTPRangeFile` + stdlib `zipfile`; LZFSE via `/tmp/lzfse/build/bin/lzfse`.

## What the guest-boot attempt showed (the key result)

Command (from the SPTM tree, against a chainloaded `/tmp/m1n1-sptm.bin`):
```
cd /tmp/m1n1-up && M1N1DEVICE=/dev/m1n1 \
  python3 proxyclient/tools/run_guest.py -P -l /tmp/guest.log \
    --sptm ~/guest/sptm.macho --txm ~/guest/txm.macho ~/guest/xnu.macho
```
(`-v` is `--volume`, NOT verbose; pass XNU boot args as positionals after a
`--` separator if needed.)

Observed, in order:
1. `SPRR/GXF: emulating in EL2 (guest image will be patched)` — the hv's
   SPRR/GXF emulation activates. Good: the SPTM path is live on T6050.
2. `Starting secondary CPUs... Starting CPU 1..16 ... Failed!` for **all 14** —
   this is **m1n1's own `smp_start_secondaries()` failing**, i.e. the *exact
   bare-metal SMP bug we are chasing*. So the hv cannot natively put the guest
   on real secondaries; it can only run single-core on the boot core (and would
   have to *emulate* guest secondary starts by trapping the PMGR writes).
3. `HV: Initializing for 42-bit PA range` (hv_pt_init ran).
4. **Crash**: `Exception: SYNC` from `EL2h`, `ESR 0x2000000` (EC=0, "unknown
   reason" = UNDEF), `FAR 0x0`, at **`hv_init+0x58` (m1n1 rel `0x3c138`)**.
   Decoded the instruction from the image bytes: `0xd51cfae0` =
   **`msr s3_4_c15_c10_7, x0` = `msr SYS_IMP_APL_AVNCR_EL2, x0`**
   (`src/cpu_regs.h:848`). The architectural `VNCR_EL2` write (`0x3c130`,
   `s3_4_c2_c2_0`) just before it succeeds; only the **Apple** AVNCR UNDEFs.
   m1n1 prints the register dump and self-reboots to stage-1.

Source context — `src/hv/hv.c hv_init()` nested-virt setup (new in #698):
```c
hv_write_hcr(HCR_NV2 | HCR_NV | HCR_API | HCR_APK | HCR_TEA | HCR_E2H | HCR_RW | HCR_AMO | HCR_VM);
msr(VNCR_EL2, &nvMem[0]);              // OK on T6050
msr(SYS_IMP_APL_AVNCR_EL2, &anvMem[0]);// <-- UNDEF on T6050  (hv_init+0x58)
```

### Characterization probe (read-only, on bare stage-1 m1n1)
`u.mrs` of each register from EL2 on the boot core:
- `VNCR_EL2 (3,4,2,2,0) = 0x0`  — readable.
- **`AVNCR_EL2 (3,4,15,10,7) = 0x0` — readable!**  So AVNCR is *not* simply
  absent/locked on T6050. It reads fine when nested virt is **off**.
- `ID_AA64MMFR2_EL1 = 0x1201011102001011`, `HCR_EL2 = 0x32488000038` (no
  NV2/NV bits on stage-1).

### Root cause (CONFIRMED this session, not a hypothesis)

Traced end to end with the SPTM/XNU machos + m1n1 source + live probes:

1. `hv_init` writes `msr SYS_IMP_APL_AVNCR_EL2, x0` directly from EL2
   (`src/hv/hv.c:157`, and `:321` for secondaries). On **M1/M2** AVNCR is
   EL2-writable; on **T6050 it is GL2-only**, so the direct write UNDEFs.
2. m1n1 already knows Apple EL2 regs can be GL2-only: `hv_write_hcr`/
   `hv_write_hacr` route through `gl2_call()` when `gxf_enabled() && !in_gl12()`.
   The #698 nested-virt code just forgot to do the same for AVNCR. **Patch
   `patches/m1n1/0006-*` adds `hv_write_avncr()` that does exactly this** and
   repoints both call sites. Correct, but see step 4.
3. SPTM confirms the idiom: it writes AVNCR from **GL2** at 3 sites
   (`sptm.macho` file offs `0xe7958/0xf6840/0xf7c60`), each next to GL2
   registers (`TPIDR_GL2`, `GXF_STATUS/ENTER_EL1`, `APVMKEYLO/HI_EL2`).
4. **The real blocker: GXF is disabled in m1n1's hv on T6050.** With patch
   0006 applied, the crash *moves into* `hv_write_avncr` because
   `gxf_enabled()` returns **false** → it falls to the direct `msr` anyway.
   `gxf_enabled()` needs `(AIDR_EL1.GXF) && cpu_features->mmu_sprr`.
   Live probe: `AIDR_EL1 = 0x12bd170699696` → **GXF bit 16 SET** (hardware has
   GXF), but `SPRR_CONFIG_EL1 = GXF_CONFIG_EL1 = GXF_STATUS_EL1 = 0` (disabled).
   The reason: **T6050 maps to the `features_m4` stub** in
   `src/chickens.c:164-165` (`"M5 Pro Sotra"`, `NULL` init, `&features_m4`),
   and `features_m4` does **not** set `.mmu_sprr` → `supports_gxf()` is false →
   `main.c:156` never calls `gxf_init()` → SPRR/GXF stay off.
5. **Naively setting `.mmu_sprr = true` is not enough and is harmful:** it was
   tried this session — m1n1's own MMU bring-up (`src/memory.c` SPRR path) then
   **hangs on T6050** and the chainload never reaches "proxy". So T6050 needs a
   *real* SPRR/GXF port, not just the feature flag.

## Next steps (in priority order)

1. **Port SPRR/GXF init to T6050** (the actual blocker). Needs an M5
   `init_cpu` path (the `midr_parts` entry is `NULL`) + whatever SPRR config /
   chicken bits T6050 wants, so that `gxf_init()` + the `memory.c` SPRR MMU
   setup work. Start by diffing the M3 (`features_m3`, `init_t6030_*`) SPRR/GXF
   setup against what T6050 needs; compare `SPRR_CONFIG_EL1`/`GXF_CONFIG_EL1`
   bit layouts (read how iBoot/SPTM program them — SPTM enables GXF itself).
   Use `wdt-arm.py` as the net (a bad MMU hangs before "proxy"; the installed
   stage-1 m1n1 is untouched, so a power-cycle always recovers).
   - Cheaper interim experiment: find out whether a **single-core** guest trace
     even needs AVNCR/NV2. Try guarding the `HCR_NV2|HCR_NV` bits + the
     `VNCR/AVNCR` writes behind `if (chip_id != T6050)` and boot the guest with
     nested virt off — but note XNU-on-SPTM likely *requires* NV2, so this may
     just move the failure into SPTM/XNU. Still informative.
2. **Mind the TrustCache caveat.** `load_macos_sptm`
   (`proxyclient/m1n1/hv/__init__.py:1925`) sources `TrustCache`, `SEPFW`,
   `RTBuddySeg`, `preoslog`, and the `DeviceTree` from the **running m1n1's**
   `adt["chosen"]["memory-map"]` — i.e. **our Omarchy stub's** boot, *not*
   macOS. The stub's trust cache will not authorize the macOS kernelcache, so
   even past GXF/AVNCR, TXM/SPTM may reject XNU. Plan to inject
   `~/guest/094-56195-095.dmg.trustcache` (or the kernelcache's loadable trust
   cache from the BuildManifest) into the guest's `TrustCache` slot — patch the
   loader to take a `--trustcache` file instead of copying the stub's.
3. **Once the guest runs far enough to start a secondary**, add the hv tracer:
   hook the PMGR `CPU_START` block (`pmgr reg0 (0x280600000) + 0x88000`;
   release = `+0x88004 = BIT(cpu-id)` then `+0x88008 + 4*cluster = BIT(core)`)
   and each core's `cpu-impl-reg+0x100` status, and record the exact
   reset-deassert step macOS performs between the `+0x88004/+0x88008` writes
   and the core checking in. Write it up in `docs/smp-t6050-findings.md`.

## Resume recipe (copy/paste)

```bash
# 0. M5 should be in Linux (ssh bay@10.55.2.2). If in m1n1 already, skip reboot.
ssh root@10.55.2.2 systemctl reboot        # or: cd ~/tether && ./boot-m5.sh
# wait ~20 s for /dev/m1n1
cd ~/tether && python3 hv/wdt-arm.py 170    # safety net
# chainload the SPTM m1n1 (must use --no-sepfw; keep the watchdog armed)
./proxyclient/tools/chainload.py -r --no-sepfw /tmp/m1n1-sptm.bin m1n1.wdt=keep
# attempt the guest (adjust after the AVNCR fix)
cd /tmp/m1n1-up && M1N1DEVICE=/dev/m1n1 \
  python3 proxyclient/tools/run_guest.py -P -l /tmp/guest.log \
    --sptm ~/guest/sptm.macho --txm ~/guest/txm.macho ~/guest/xnu.macho
python3 ~/tether/hv/wdt-arm.py --off        # when done
# back to a usable machine:
#   let it reboot to stage-1, then ./boot-linux.sh, or just power-cycle to Arch.
```

## Gotchas / don't-repeat-these

- Bus-hang addresses (need a watchdog reset, no SError): `cpm-impl-reg+0x40f8`,
  `EDPCSRhi` (`coresight+0x20000+0xac`), `cpu-impl-reg+0..0x200` scans, and a
  read of the boot core's `RVBAR_EL2` target `0x1fc08c000` (LLB SRAM). See
  findings doc.
- The execute-region (CTRR/CTXR) theory is **dead** — hardware proved the boot
  core has identical locked regions yet runs m1n1 fine (findings §CTRR/CTXR).
- Share results with **omarchy-mac / aurora-silicon**, not Asahi (user pref).
- `run_guest.py -P` sets a 1024 MiB m1n1 heap; the guest loads above it.
- Community prior art: m1n1 **PR #610** ("the cores turn on … but never start
  executing our code"), same on M5 Max — this is an open upstream problem, so a
  clean macOS trace of the reset-deassert is genuinely novel and worth sharing.
