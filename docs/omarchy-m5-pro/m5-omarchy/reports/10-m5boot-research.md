# 10 — m5boot: cited-source research notes (handoff to a fresh session)

**Owner decision (2026-11-04):** m5boot is written by a **fresh session** with no m1n1 exposure. This session read parts of upstream m1n1 in tasks 01–03 (listed in §0), so it supplies only **facts with citations** below, not code or design taken from m1n1. This session also did the kernel/DT safety work (§6), which isn't m5boot.

## 0. Disclosure: what this session read of m1n1 (so the reviewer knows what to look for)
- **Upstream m1n1:**
  - `git show b2d3f5eb` (chickens.c/midr.h/smp.c/soc.h diffs);
  - `src/smp.c` ~300–360 (CPU start-offset switch);
  - grep hits in `src/kboot.c` (`dt_set_pmp`, `excluded_pmp_props`) and `src/dapf.c`;
  - `proxyclient/m1n1/fw/pmp.py`, `proxyclient/experiments/pmp_init.py`, `proxyclient/tools/pmp_assist.py`;
  - the `proxyclient/m1n1/adt.py` PMGR structs;
  - `proxyclient/tools/run_guest.py` argparse;
  - PR and commit message bodies.
- **aura's `adt.py`** (an m1n1 descendant): its PMGR/ptd-range layouts (task 05).
- **Not read:** m1n1's `start.S`, boot_args handling (`xnuboot.h`), memory-map/reserved-memory DT patching, framebuffer/console, `wdt.c`, chainload/payload format, USB.
- None of the facts below come from the read material.

## 1. Sources (AI instructions + license checked 2026-11-04)

| Source | Pin | AI instructions | License / use |
|---|---|---|---|
| apple-oss-distributions/xnu | `f6217f891ac0` (+ tags `xnu-7195.50.7.100.1`, `xnu-8019.41.5`, `xnu-10002.1.13`, `xnu-11215.1.10`) | none | **APSL 2.0.** Read for interface facts; **write your own struct definitions, don't copy the files** (copying makes the copied file APSL Covered Code) |
| AsahiLinux/docs | `5acb80f` | none | Docs. (!) `fw/macho-boot-protocol.md` links to m1n1's `src/xnuboot.h`: **don't follow m1n1 links** |
| Linux (AsahiLinux/linux `asahi-wip-7.2` @ `236788cd`) | local `src/linux-asahi-wip72` | none in tree | GPL-2.0. `Documentation/arch/arm64/booting.rst`; `drivers/watchdog/apple_wdt.c` (SPDX `GPL-2.0-only OR MIT`) |
| libfdt | the kernel copy `scripts/dtc/libfdt/` (upstream dgibson/dtc `54e547173bf0`) | dtc `AGENTS.md`/`CLAUDE.md`: AI allowed; contribution rules (no AI `Signed-off-by`, `Assisted-by` trailer) apply only to contributions | `GPL-2.0-or-later OR BSD-2-Clause`. Choose BSD-2-Clause for an MIT m5boot |
| Our dumps | `reports/02-j714s-dump.txt`, `reports/04-j714s-full.txt` | — | ours |

## 2. iBoot hand-off: sourced facts
1. **Entry state, MMU off, x0 = boot_args.** AsahiLinux/docs `docs/fw/macho-boot-protocol.md`: "iBoot enters us at the entrypoint defined in the (ridiculous) Mach-O data structure as an unslid vaddr. Entry is with the MMU off. `x0` points to the boot_args structure".
   - Corroborated by XNU `osfmk/arm64/start.s` @f6217f89 `start_first_cpu`, which says "x0 - Boot args" and reads `BA_VIRT_BASE`/`BA_PHYS_BASE`/`BA_MEM_SIZE`/`BA_BOOT_FLAGS` via `ldr xN, [x20, …]` **before** building its page tables. It then converts its own PC-relative addresses "to KVA" by adding `virtBase` and subtracting `physBase`, i.e. it runs physically at entry.
2. **Raw boot objects.** AsahiLinux/docs `platform/introduction.md` §fuOS: "Custom kernel images can be flat ARM64 executable images; the entrypoint and (virtual; mostly meaningless) load address are specified when the image is configured". asahi-installer `src/step2/step2.sh:125`: `kmutil configure-boot -c boot.bin --raw --entry-point 2048 --lowest-virtual-address 0 -v $system_dir`. So entry = file offset **2048**, and the code must be position-independent.
3. **RVBAR lock.** macho-boot-protocol.md: "iBoot sets and locks the RVBAR of the boot CPU to be the top of the page that the entrypoint lives in. This cannot be changed after boot".
4. **Physical layout.** macho-boot-protocol.md diagram:
   - `boot_args->phys_base` (VM = `virt_base`) → ADT (`/chosen/memory-map.DeviceTree`), TrustCache, kernel image, SEP firmware, BootArgs;
   - `boot_args->top_of_kdata` → "(Free memory) (incl. iBoot trampoline)";
   - up to `top_of_kdata + mem_size` → "Video memory, SEP carveout, and more";
   - … `0x8_0000_0000 + boot_args.mem_size_actual` (M1 DRAM base; T6050 DRAM starts at `0x100_0000_0000` per edimoldovan's `apple-j714c.rst`, REPORTED-NATIVE).
   - "For our purposes, a vaddr is just `paddr + ba.virt_base - ba.phys_base`."
5. **boot_args layout** (XNU `pexpert/pexpert/arm64/boot.h` @f6217f89), field order:
   1. `uint16 Revision`, `uint16 Version`
   2. `uint64 virtBase`, `physBase`, `memSize`, `topOfKernelData`
   3. `Boot_Video` = 6 × `unsigned long` (`v_baseAddr`, `v_display`, `v_rowBytes`, `v_width`, `v_height`, `v_depth`)
   4. `uint32 machineType`
   5. `void *deviceTreeP`
   6. `uint32 deviceTreeLength`
   7. `char CommandLine[BOOT_LINE_LENGTH]`
   8. `uint64 bootFlags`, `uint64 memSizeActual`

   Natural alignment on LP64 applies, so there's padding after Version, machineType and deviceTreeLength.
   - Depth: `v_depth & 0xFF` = bpp; bits 8/16/24 = rotate/scale/boot-rotate (`kBootVideoDepth*Shift`).
   - XNU's `pe_init.c:425-431` uses exactly these, and sets pixel format `"BBBBBBBBGGGGGGGGRRRRRRRR"` (that's XNU's own console, not necessarily the panel format).
6. **BOOT_LINE_LENGTH:** 608 in `xnu-7195.50.7.100.1` and `xnu-8019.41.5`; **1024** in `xnu-10002.1.13` and `xnu-11215.1.10`. Current XNU takes it from the non-public `<iBoot/boot_args_abi.h>` (`IBOOT_MAX_ENV_VAR_DATA_SIZE`).
7. **ADT container** (XNU `pexpert/pexpert/device_tree.h` + `pexpert/gen/device_tree.c` @f6217f89):
   - Node = `{uint32 nProperties; uint32 nChildren;}`, then the properties, then the children (recursively).
   - Property = `{char name[32]; uint32 length;}` + value.
   - Next property = `(prop + 36 + length + 3) & ~3` (`next_prop_region`: `os_add3_overflow(prop, prop->length, sizeof(DeviceTreeNodeProperty) + 3, …); next_addr &= ~3`). This version uses `length` unmasked.
8. **`/chosen/memory-map`** property names on J714s (our dump; macOS zeroes the values after boot, so **real values exist only in iBoot's live ADT**):
   - `TrustCache*`, `SPTM-*`, `TXM-*`, `BootKC-*`, `AuxKC*`, `CL4-*`, `DeviceTree-*`, `ExclaveOSIntegrityCatalog`, `MemoryMapReserved-4…15`, … (full list in `04-j714s-full.txt` from line 1567).
   - `/chosen` also has `carveout-memory-map` with `region-id-N` = 16-byte values (e.g. `region-id-68` = base `0x105ffe00000`, size `0x200000000`?; decode as `{u64 base, u64 size}` and verify).
9. **Watchdog:**
   - ADT `wdt@8836C000`, `compatible = "wdt,t8101","wdt,s5l8960x"`, macOS `IODeviceMemory` reg0 = **PA `0x2_8836_C000`**, length 0x4000 (our dump).
   - That matches edimoldovan's "watchdog at 0x28836c000" and "ADT arm-io child address plus 0x200000000" (`apple-j714c.rst`, REPORTED-NATIVE).
   - Linux `apple_wdt.c` `apple_wdt_stop()` is a single write: `writel_relaxed(0, regs + APPLE_WDT_WD1_CTRL)` with `WD1_CTRL = 0x1c` (`CTRL_RESET_EN = BIT(2)`).
10. **Linux entry contract** (`booting.rst`):
    - "x0 = physical address of device tree blob (dtb) in system RAM", x1–x3 = 0.
    - "All forms of interrupts must be masked in PSTATE.DAIF".
    - "either in EL2 (RECOMMENDED …), or in EL1".
    - "The MMU must be off".
    - "The address range corresponding to the loaded kernel image must be cleaned to the PoC … by VA rather than set/way".
    - "CNTFRQ must be programmed … If entering the kernel at EL1, CNTHCTL_EL2 must have EL1PCTEN (bit 0) set".
    - Image placed `text_offset` from a 2 MiB-aligned base, with `image_size` bytes free.
11. **Framebuffer:** J714c reports `simple-framebuffer` 3024×1890 `x2r10g10b10` (edimoldovan, REPORTED-NATIVE); betizzel reports m1n1's console "at native 3024x1964" on J714s. Read geometry from boot_args at runtime.

## 3. HYPOTHESES: unsourced, and how the first native boot tests each
| # | Hypothesis | Native test |
|---|---|---|
| H1 | A **raw** (`--raw`) boot object gets the same entry state as the Mach-O case in §2.1 (MMU off, x0 = boot_args) | First m5boot instructions save `x0`, `CurrentEL`, `SCTLR_ELx`, PC; print them first on the framebuffer |
| H2 | **EL2** at entry (edimoldovan: m1n1 "running at EL2", REPORTED-NATIVE, not iBoot documentation) | Print `CurrentEL` |
| H3 | `x0` and `boot_args` fields `topOfKernelData`, `Video.v_baseAddr` are **physical**; `deviceTreeP` is a **virtBase-relative VA** | Classify each pointer at runtime: in `[physBase, physBase+memSize)` → PA; in `[virtBase, virtBase+memSize)` → convert with `−virtBase+physBase`. Print the classification |
| H4 | `BOOT_LINE_LENGTH` on macOS 26 = 1024 | Check that `memSizeActual` read at the 1024 offset is plausible (≥ `memSize`, 24 GiB-ish, GiB-aligned); else try 608; print which |
| H5 | The WDT is armed at entry | Read `WD1_CTRL` before the disable write and print it |
| H6 | The framebuffer is live (lit, scanning out) at entry, in the format implied by `v_depth` (30-bit `x2r10g10b10` per J714c) | Draw a test pattern first |
| H7 | No kmutil/iBoot size limit below ~65 MB for raw objects (46 MB uncompressed `Image` + DTB + 2.4 MB initramfs) | **Unknown.** No public source found. If the boot fails before any m5boot output, retry with a small loader-kernel payload |
| H8 | Free RAM = `[topOfKernelData, physBase+memSize)` minus `/chosen/memory-map` + `carveout-memory-map` ranges and the framebuffer | Print the computed free window and carveouts before relocating |

## 4. `finish-install.sh` with a non-m1n1 binary
Yes, it accepts it unchanged.
- **Preflight** (`scripts/finish-install.sh` @15cd70c1 lines 129–135): only `[ -f "$M1N1" ]`, plus a CHAINLOADING grep that runs **only** when `$M1N1` equals the vendor path `vendor/m1n1/build/m1n1.bin`.
- **Line 308:** `cp "$M1N1" "$RES/boot.bin"`.
- **`step2.sh`** (lines 278–279) runs the generic `kmutil configure-boot -c "$resources/boot.bin" --raw --entry-point 2048 --lowest-virtual-address 0 -v "$system_dir"`.

So `sudo scripts/finish-install.sh --m1n1 build/m5boot.bin` works, and no `arm-stub.sh` is needed. The option name is cosmetic. finish-install is SPDX MIT.

## 5. Recovery statement (addendum wording)
- A hang: hold power → Startup Options → **Macintosh HD** (macOS's own LocalPolicy, untouched).
- Uninstall: delete the stub (08 §4).
- **The DFU path is verified only as far as device detection/identification** (`irecovery`: Mac17,9 j714sap, Port DFU). A TSS signing check (`idevicerestore -t`) is planned. **Revive/restore is untested.**

## 6. Kernel/DT safety audit for the first native boot (done here)
- **Owner decision:** keep `t6050-pmgr.dtsi` + `pd_ignore_unused`.
- **Disabled:** `tools/kernel/m5-safe.config`, merged last by `tools/build-kernel.sh`:
  - sound: `SOUND`, `SND` (whole subsystem: MCA, TAS2764/2770, CS42L84, macaudio), plus `APPLE_SIO`;
  - SMC: `MFD_MACSMC`, `GPIO_MACSMC`, `INPUT_MACSMC_INPUT`, `SENSORS_MACSMC_HWMON`, `MACSMC_POWER`, `RTC_MACSMC`;
  - `ARM_APPLE_SOC_CPUFREQ`;
  - `DRM_APPLE`, `DRM_ASAHI`.
- **DT** (applied to the copied tree by `build-kernel.sh`): removed `#include "t6050-cpufreq.dtsi"` and `"t6050-smc.dtsi"` from `t6050.dtsi`, and the `hwmon-common/fan-dual/laptop.dtsi` includes (SMC-backed) from `t6050-j714s.dts`.
- **Audio nodes:** betizzel's DT has none (grep `mca|speaker|tas|cs42l|sn012776|codec` → none); GPU/DCP/PMP have none either.
- **Kept, and their risk:** PMGR power domains (the kernel may write PS registers, per owner decision); NVMe (SART + ANS), DockChannel MTP (keyboard/trackpad), DWC3 gadget, SPMI. These match betizzel's native J714s boots.
- The probe module stays read-only. `maxcpus=1` stays on the cmdline.
- **Rebuilt artifacts:** see the build result appended below.

## 7. Final state (2026-11-04)
- **Spec for the fresh implementer:** `~/m5boot/spec/m5boot-spec.md`.
  - It contains **only** XNU, AsahiLinux/docs, Linux, libfdt and our-dump facts, each with a quote.
  - Nothing from m1n1 or aura. Also excluded, because they were obtained via m1n1/aura loaders: edimoldovan's loader-requirement notes and betizzel's m1n1 console notes. Facts they had stated, such as the arm-io offset, the WDT address and DRAM base/size, were re-derived from our own dump.
  - HYPOTHESES H1–H9 each carry a native test.
- **Inputs list:** `~/m5boot/spec/inputs.md`, with every artifact path + SHA-256 and the safe-kernel description. `work.pub` is copied to `~/m5boot/spec/work.pub`.
- **Safe kernel rebuilt** (§6):
  - `Image` `d226395f…3065`, `Image.gz` `ac798600…740e`, `t6050-j714s.dtb` `23dabefb…1d6d`.
  - Checked: the audio/SMC/cpufreq/DRM_APPLE config symbols are not set; the DTB has no smc/cpufreq/codec/dcp/gpu nodes (only the PMGR labels `scodec*`) and keeps 273 pmgr-pwrstate nodes; `modules.order` has 1389 modules, none sound/macsmc/drm-apple.
- **Rootfs rebuilt** with the safe module set: `rootfs-alarm.tar.zst` `39592200…9d5e`, 0 sound/SMC modules.
- Initramfs images unchanged (`20eef155…`, `f11e0a88…`).
