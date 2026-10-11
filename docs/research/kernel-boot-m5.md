# Kernel & Boot-Chain State for Apple M5 / M5 Pro (Asahi Linux)

Research date: **2026-09-21**. Scope: Linux kernel + boot chain for Apple M5-generation SoCs, with emphasis on the **M5 Pro MacBook Pro** (14"/16", announced 2026-03-03, shipping since 2026-03-11). Primary sources only where possible; each claim carries its date.

---

## 1. Executive summary

- **Nothing M5 exists upstream.** Mainline Linux stops at M3-family device trees (t8122 + t603x). `linux-next` gained *minimal* **t8132 (base M4)** DTs in August 2026 (patch series v3, Yureka Lilian, 2026-08-11). There are **no public kernel device trees for t8142 (M5), t604x (M4 Pro/Max), or t605x (M5 Pro/Max)** - in AsahiLinux/linux, linux-next, or any public fork found.
- **m1n1 is ahead of the kernel.** Released **m1n1 v1.6.1 (2026-08-08)** contains "Initial support for T8142 and T6040/T6041 and T6050/T6051" plus the macOS-15+ NVMe fix. m1n1 runs on real M5 Pro/Max and M4 Pro hardware (UART/fb/USB-gadget confirmed in logs on PR threads).
- **The M5 Pro's hard blocker is SMP.** M5 Pro/Max use "Fusion Architecture" (two dies; Apple newsroom 2026-03-03) and a new core type - m1n1 calls it **M-Core** (6 "super cores" + 12 "performance" cores, no E-cores). M5 Pro boots on core 0 which is an M-Core; **secondary cores power on (visible in PMGR) but never fetch the reset vector**. Unresolved as of 2026-09-21 - an independent contributor (qspqww) has spent July 2026 tracing this into `iBoot.j716c` / `AppleT6050PMGR` kernelcache disassembly without cracking it.
- **Base M5 (t8142) is in much better shape than M5 Pro**: it keeps classic P/E cores, SMP start offset confirmed working on hardware (m1n1 commit b72e664f, 2026-07-17).
- **What works on M4/M5-class silicon per the Aug-26 progress report**: kernel boots, PCIe enumerates devices, NVMe works (macOS-15.x firmware ABI change reverse-engineered by Yureka+Sven, implemented in m1n1 and Linux), and the multi-core crash-on-boot bug was fixed. "Not much else is working" and neither chip is installer-enabled.
- **SPTM is the RE-tooling break**: SPTM is mandatory for XNU on M4+, which broke the m1n1 hypervisor (the project's main MMIO-tracing tool). Sven's SPRR/GXF emulation restored it - XNU can again be loaded and traced (slower). This is the "which tooling M4/M5 broke" item.
- **For the omarchy-m5 goal**: a TTY on an M5 Pro is plausible-but-frontier - m1n1 → kernel with `maxcpus=1`, serial/dockchannel or m1n1 boot-framebuffer console, USB-C Ethernet for networking (the new **Apple N1** Wi-Fi chip has zero driver work - it's a fresh RE target, not Broadcom). The largest missing piece is a t6050/j716c kernel device tree, which does not exist publicly anywhere.

---

## 2. SoC identifiers (verified 2026-09-21)

From Asahi docs (https://asahilinux.org/docs/hw/soc/soc-codenames/) + m1n1 source:

| Marketing | Internal | Codename | SoC ID | Notes |
|---|---|---|---|---|
| M5 | H17G | Hidra | **T8142** | single die; classic P/E cores; board j704 (14" MBP M5) |
| M5 Pro | H17S | Sotra_S | **T6050** | dual-die "Fusion Architecture"; super + M-cores |
| M5 Max | H17C | Sotra_C | **T6050 / T6051** | docs table lists T6050; m1n1 commit says T6050/T6051; qspqww's M5 Max reports chip-id 0x6050 - minor ambiguity, likely Pro=T6050, Max=T6051 |
| - | - | Sotra_D | - | listed without SoC ID (possibly future M5 Ultra) |
| M4 | H16G | Donan | T8132 | base M4 - the current bring-up frontier upstream |
| M4 Pro/Max | H16S/H16C | Brava (Chop) | T6040/T6041 | m1n1 supported; **no kernel DTs anywhere** |
| A18 Pro | H17P | Tahiti | T8140 | "MacBook Neo" - parallel bring-up in same repos |

Device/board IDs seen on hardware: **j716c** (M5 Pro/Max MBP, `Mac17` family, ApChipID 0x6050, ApBoardID 0x0e - from qspqww's dumps and m1n1 PR #631 title "T6050 j716c bringup"). Base M5 14" MBP: **j704** (from ImAtomiskk/asahim5).

CPU cores on M5 Pro/Max (per m1n1 commit b2d3f5e, 2026-06-29): marketing's "super cores" remain ADT/MPIDR P-cores; the other cluster is a **new "M-Core" type - not E-cores** (no `SYS_IMP_APL_E_*` registers). Boot CPU = core 0 = M-Core.

AIC: AICv3 spans **all SoCs from M3 (t8122) through M5 (t8142)** per the upstream AICv3 binding series (lore, 2026-01-28) - interrupt topology is not a blocker for t6050.

---

## 3. State of the trees (verified 2026-09-21)

### m1n1 - github.com/AsahiLinux/m1n1

| Item | State | Date |
|---|---|---|
| v1.6.1 release | Tagged; notes: "Initial support for T8142 and T6040/T6041 and T6050/T6051", "Fix NVMe with OS firmware from macOS 15 and later", M3 ISP/AOP/system cache | 2026-08-08 |
| v1.6.0 | Rust toolchain now required for **all** builds (stage-1 Rust, no_std aarch64-softfloat) | ~2026-06 |
| T6050/T6051 initial support (EARLY_UART_BASE, smp offset, features; `src/chickens.c midr.h smp.c soc.h`) | **merged, main** (commit b2d3f5e) | 2026-06-29 |
| "utils: do not detect m-core as e-core" | merged | 2026-06-29 |
| T8142 initial support (UART base from ADT; MIDR parts + smp_start_offset verified on hw by rhlvista) | merged (b72e664f) | 2026-07-17 |
| t6041 initial support | merged (d3699d53) | 2026-06-21 |
| CPUSTART for T8132/T8140/T6034/T6040 (HV/proxyclient) | merged (0ec216de) | 2026-06-18 |
| pcie: t8132/t6040 support | merged (0f221fc7) | 2026-07-21 |
| nvme: T8132 + M4+ support | merged (53f8ee9b; PR #652 merged 2026-08-17) | Jul-Aug 2026 |
| mcc (memory/system cache): t8132, T8122/T6030 SLC carveouts | merged | 2026-08 |
| kboot: CTRR_M4 reserved region; kboot_atc t8132; t8122 Thunderbolt | merged | Aug 2026 |
| SPRR/GXF emulation work (HV runs XNU+SPTM again) | commits merged Jun-Aug; **PR #643 still open** (2026-07-28) | 2026-07/08 |
| pmgr: M4 Pro/Max + A18 Pro + M5 (fixes device-mode USB on M5 Max MBP) | merged (PR #578) | 2026-05-15 |
| AGX G15/G15X version IDs added to constructutils - M5-gen GPU generation | merged | **2026-09-16** |
| Open, M5-relevant: **#563** smp boot-core switching (2026-04-16); **#672** kboot auto-disable wfi/wfit on state loss (2026-08-29); **#664** mcc t604x/t8140 (2026-08-16); **#662** SARTv3/4 rework; **#618** PSCI via EFI | open | - |
| PR #631 "T6050 j716c bringup" (qspqww) - real-hw M5 Pro/Max RE notes+dumps | **closed unmerged** 2026-07-19; work continues in `qspqww/m1n1` branch `t6050-j716c-bringup` | 2026-07 |

Verified on-hardware log (PR #578 thread, M4 Pro Mac16,11/j773s): dockchannel UART init, pmgr enumeration (485 devices/1 die), fb console init, USB2 dart/USB init, `cpufreq: Chip 0x6040 is unsupported`, "No valid payload found" - i.e. m1n1 itself runs fine on the new Pro silicon.

### Linux kernel - github.com/AsahiLinux/linux (branch `asahi`, `asahi-wip`, `asahi-wip-7.2`, `apple-soc/dt-7.4`)

- Apple DTs present through **t8132 (M4 base)**: t8132-j604/j623/j624/j713/j715/j773g + dtsi/pmgr. **Absent: t604x (M4 Pro/Max), t8142 (M5), t605x (M5 Pro/Max).**
- `b4/nvme-fwabi` branch holds the macOS-15+ NVMe compatibility series (2026-08-06): PRP null-check chicken-bit drop, NVMMU TCB opcode fix, DMA-direction fix, page-aligned admin-queue quirk, admin-queue destroy - this is the patch staging for the "NVMe on M4/M5" work.
- Driver note: `drivers/nvme/host/apple.c` on `asahi` still lists only `apple,t8015-nvme`/`apple,t8103-nvme`/`apple,nvme` compatibles - new-gen support binds via generic + fw-ABI negotiation, not per-SoC strings.

### Upstream

- `linux-next` (git.kernel.org, checked 2026-09-21): **t8132 minimal DTs merged** - CPUs (`apple,donan-e`/`donan-p`, spin-table), pmgr syscon, **AICv3** (`apple,t8132-aic3`), pinctrl, serial. No NVMe/PCIe/SPI/USB nodes upstream yet. `drivers/soc/apple` upstream has mailbox + pmgr-misc + rtkit; upstream `pcie-apple.c` has `apple,pcie`/`apple,t6020-pcie`; upstream `apple.c` nvme driver has `nvme-ans2` compatibles only.
- torvalds/linux mainline: DTs through M3 family only (t8122, t603x).
- Patch history: M4 DT series v1 posted 2026-07-05, v3 2026-08-11 (author Yureka Lilian), merged into linux-next; targets the 7.4 merge window via `apple-soc/dt-7.4`.

### U-Boot - AsahiLinux/u-boot

- SoC-agnostic: m1n1/kboot supplies the FDT; no per-SoC apple DTBs in-tree. Current asahi branch is at upstream v2026.07 + Asahi patches. Not a blocker once m1n1 hands off a valid DT - but untested on t6050.

---

## 4. Aug-2026 "Linux 7.2" progress report - M4/M5 details

Source: https://asahilinux.org/2026/08/progress-report-7-2/ (James Calligeros, 2026-08-26). Directly relevant items:

1. **WFI / idle crash (M4+)**: starting with M4, mBoot sets chicken bits and *locks* the registers; WFI now loses core state → crashes whatever ran on it. Yureka added a kernel cmdline parameter to pick idle-park behavior (incl. nop loop); patches **already in linux-next**. The real cpuidle driver (downstream, deep-WFI + state save) takes over after init.
2. **NVMe breaking change**: Apple changed the NVMe controller firmware ABI in the macOS 15.x firmware bundle affecting M4/M5; Yureka+Sven reverse-engineered and implemented it in **both m1n1 and Linux** → "we now have working NVMe on M4 and M5."
3. **PCIe**: works to the point that devices on the bus enumerate under Linux (M4/M5).
4. **Multicore crash**: fixed a bug where Linux crashed shortly after boot with >1 CPU core enabled (on M4; M5 Pro's separate M-Core SMP issue is *not* this - see §6).
5. **SPTM broke RE tooling**: SPTM is mandatory for XNU on M4+ (lives in GL2 + SPRR inside GXF). It killed the m1n1 hypervisor - the project's MMIO-tracing workhorse. Sven taught the HV to **emulate SPRR/GXF**, so it can now load Apple's SPTM blob + patched XNU and trace MMIO again (slower, usable). "This will allow us to continue bringing up new hardware."
6. **PSCI via UEFI Runtime Services**: Sven implemented m1n1 as resident firmware offering PSCI through a UEFI-RT conduit (kernel RFC on LKML). This is the path to upstreamable cpuidle - important long-term.
7. M3 series is ~installer-ready (release "coming weeks"); M4/M5 explicitly **not** enabled in the installer.
8. M3 targets macOS 14.8.3 firmware ABI; M4/M5 generation firmware = macOS 26.x (Tahoe) - mBoot era.

Prior report (Linux 7.1, 2026-06): m1n1 1.6.0 = Rust mandatory; groundwork for M4 + A18 Pro ("MacBook Neo"); M3 audio/cpufreq/EAS landed.

---

## 5. What a minimal TTY boot requires on Apple Silicon - vs. M5 Pro today

Chain: SecureROM → LLB → mBoot → **m1n1 stage1** (installed into a stub macOS via 1TR + `kmutil`) → **m1n1 stage2** (from ESP) → payload: **U-Boot** (UEFI → GRUB) or **direct kernel via kboot** (kernel+DTB+initramfs as m1n1 payload). For development: `proxyclient` over USB device-mode, or chainload m1n1 for test builds.

| Requirement | How it works on Apple Silicon | M5 Pro status (2026-09-21) |
|---|---|---|
| Load m1n1 | 1TR + `kmutil configure-boot` on a stub macOS install; or chainload | Manual flow only - Asahi installer doesn't cover M5; m1n1 has initial t6050 support. Tested on macOS 26.2b2/27.0b2; note mBoot replaced iBoot in macOS ~26.4 (community install notes verified only on 26.0.1) |
| CPU bring-up | m1n1 starts secondaries via RVBAR/spin-table | **BROKEN on t6050** - secondaries power up but never execute (commit b2d3f5e; qspqww's July RE). Single-core `maxcpus=1` boot likely feasible (unverified publicly) |
| Early console | m1n1 EARLY_UART over dockchannel USB-C debug (needs serial-capable cable/adapter) or m1n1 USB gadget (proxyclient) | Dockchannel UART works (seen on M4 Pro log; t6050 UART base added in b2d3f5e) |
| Display console | m1n1 initializes boot framebuffer → kernel `simplefb`/`simpledrm` console - **no DCP needed for TTY** | m1n1 does fb init on new silicon (M4 Pro log); DCP itself is far off but irrelevant for TTY |
| Kernel DT | Hand-authored minimal DTS (cpus, aic3, pmgr, pinctrl, serial, fb) | **MISSING - must be written** (no public t6050/t8142 DTS; ImAtomiskk has a hand-made t8142.dts for j704; qspqww published j716c ADT dumps usable as reference) |
| Kernel idle/WFI | Needs `idle=`/wfi-disable workaround until cpuidle driver | Fix exists: cmdline param in linux-next; m1n1 PR #672 (auto-disable) open |
| Interrupts/timer | AICv3 driver (same since M3) + arch timer | OK - AICv3 confirmed t8122→t8142; compatible-listed in linux-next t8132.dtsi |
| Power gating for IO | PMGR syscon + per-device power domains | pmgr works in m1n1 on t6050 (PR #578); kernel side needs t6050 pmgr.dtsi (per-SoC offsets - biggest part of each new dtsi, e.g. t8132-pmgr.dtsi is 1130 lines) |
| Rootfs on NVMe | apple-nvme + DART IOMMU + ASC mailbox + RTKit + SART | fwabi fixes exist (`b4/nvme-fwabi`, m1n1 ≥1.6.1); SARTv3/v4 rework open (PR #662); needs DT nodes |
| Input | Built-in keyboard/trackpad = SPI (spi-apple upstream + spi-hid-apple downstream); or USB2 keyboard via dwc3 + USB PHY + ACE3/SPMI port control | All pieces exist for older gens; none wired for t6050 yet |
| Network | USB-C Ethernet dongle over dwc3, or PCIe→Wi-Fi (brcmfmac) | **N1 is a new Apple Wi-Fi/BT chip - no driver exists, full RE project.** Practical: USB-C GbE dongle (needs USB2 host path first) |
| Out of scope for TTY | DCP display, AGX GPU (G15 gen on M5), audio, webcam/ISP, suspend, Thunderbolt 5 | all TBA/WIP |

---

## 6. Open blockers - priority order (power-on → m1n1 → kernel → TTY → net)

1. **M-Core SMP startup (t6050/t6051)** - blocker for multi-core; single-core boot is the workaround. Root cause under RE (iBoot pre-fills RVBAR/CPU-NUB SRAM; Apple's `ApplePMGR::enableCPUCore → enableCPUCores → configMiscCores` path decoded; failure converged to "CPU1 never performs first fetch at locked RVBAR" despite PMGR going active). Evidence: m1n1 b2d3f5e; qspqww PR #631 + `qspqww/m1n1@t6050-j716c-bringup` progress/findings notes (July 2026).
2. **No kernel DT for t6050/j716c** (nor t604x for that matter). Needs authoring from ADT dumps (available via qspqww's repo artifacts / on-device `/proc` dump; jannau-style minimal series as template - cf. t8132 series structure).
3. **WFI state loss** - kernel must boot with idle workaround (param in linux-next) or via m1n1 auto-disable (PR #672 open).
4. **NVMe/fwabi** for macOS-26-era firmware - patches staged on `b4/nvme-fwabi` (Aug 6) + m1n1 ≥1.6.1; needs DT plumbing (nvme, dart, sart - SART rework PR #662 open).
5. **USB-C port stack** for input/network dongles: ACE3-over-SPMI port controller + SPMI driver + dwc3/PHY - exists for M3 Pro/Max, unwired for t6050.
6. **Serial/fb console verification on t6050** - dockchannel UART base exists; fb init unverified publicly on M5 Pro.
7. **Networking**: Apple **N1** (Wi-Fi 7/BT 6) - no driver, no RE yet. USB-Ethernet after #5.
8. **Install path**: installer doesn't support M5; manual 1TR flow required; macOS 26.4+ mBoot changes may alter documented steps.
9. Later: cpufreq/cpuidle/MCC (t6050 SLC), DCP display, AGX G15 GPU, suspend - all needed long before Hyprland, none needed for TTY.

---

## 7. Where M5 work actually lands

| Tree / person | What |
|---|---|
| `AsahiLinux/m1n1` (main) | all SoC bring-up lands first; releases v1.6.0/1.6.1 |
| `AsahiLinux/linux` - `asahi`, `asahi-wip`, `asahi-wip-7.2`, `apple-soc/dt-7.3/7.4`, `b4/nvme-fwabi` | downstream kernel; b4/* = patch-staging for upstream |
| **Yureka Lilian** (`yuyuyureka/linux`, `yuyuyureka/m1n1`) | primary M4/M5 bring-up author; branch `disable-cpuidle-m4` |
| **Sven Peter** (`svenpeter42/linux` `upstream-bringup*`; m1n1) | SPRR/GXF emulation, PSCI-via-UEFI-RT, NVMe fwabi co-work |
| `jannau/linux`, `chadmed/linux` | DT/pinctrl/audio + upstreaming (t603x/t8122 landed via jannau series) |
| `linux-next` | t8132 minimal DTs now; expect t604x → then t8142/t605x |
| `lore.kernel.org/asahi`, LKML | patch submissions (AICv3 Jan-2026, M4 DTs Aug-2026, PSCI RFC) |
| Community M5 efforts | `qspqww/m1n1` `t6050-j716c-bringup` (real-hw SMP RE, IPSW/kernelcache disasm - most detailed public M5 Pro investigation); `ImAtomiskk/asahim5` (t8142/j704 bringup, ADT dumps, m5_t8142.dts - fresh Sept 2026); cephalochromoscope.net Vinix OS notes (AGX t6050 work) |

Public dev statements: 39C3 talk by Sven (Dec-2025/Jan-2026 coverage, Phoronix) - "M4/M5 changes broke existing Asahi RE tools" (= SPTM/HV); Aug-26 report is the canonical status statement; no public M5-Pro-specific timeline from Asahi devs.

---

## 8. Confidence

- **High (verified this session)**: SoC IDs (t8142/t6050/t6051), m1n1 commit/tag/PR state and dates, DT presence/absence per branch, linux-next t8132 contents, 7.2/7.1 report text, M5 Pro dual-die Fusion architecture + N1 chip + Mar-2026 ship date, SMP blocker wording (from the commit message itself), installer non-support.
- **Medium**: board↔model mapping (j716c = M5 Pro/Max MBP 14" - consistent across sources but Apple doesn't document it); T6050 vs T6051 Pro/Max split (docs vs commit discrepancy); t8142 SMP working on real hw (implied by rhlvista-tested `smp_start_offset`, not a literal "SMP works" statement).
- **Inference**: `maxcpus=1` viability on t6050 (standard Linux mechanism, untested publicly on this SoC); fb-console availability on M5 Pro (fb init verified on M4 Pro only); N1 being PCIe/SIO-attached (unknown - could be neither).

*Field velocity warning: m1n1 main and the asahi branches moved multiple times within August-September 2026; re-check before acting on this report.*
