# M5 Pro MacBook Pro — Linux bring-up hardware matrix

**Project:** omarchy-m5 — boot Linux on an M5 Pro MacBook Pro (Apple Silicon), dual-boot with macOS, TTY-first, stretch goal Wayland/Hyprland (Omarchy).
**As-of date:** 2026-09-21. All sources dated; confidence flagged per claim.

---

## 1. Executive summary

- The M5 Pro MacBook Pro shipped **2026-03-11** (announced 2026-03-03). It is a **two-die chiplet SoC** ("Fusion Architecture": CPU chiplet + GPU chiplet, SoIC-X face-to-face hybrid bonding on a silicon interposer) — the first non-monolithic Apple Silicon. Internal SoC ID is **T6050** (M5 Pro, "Sotra_S", H17S); M5 Max is **T6051**-class ("Sotra_C", H17C); base M5 is **T8142** ("Hidra", H17G). Machine IDs: 14" M5 Pro = **Mac17,9 / J714sAP**, 16" M5 Pro = **Mac17,8 / J716sAP**, 16" M5 Max = Mac17,6.
- **Bare-metal Linux on M5 Pro is at "kernel boots, NVMe works, multicore fixed" stage** — not installer-ready. Asahi's 2026-08-26 (Linux 7.2) report: M4 and M5 boot Linux, enumerate PCIe, NVMe works after RE'ing the macOS 15.x NVMe firmware ABI; "not much else is working." Public trees have **no T6050/T8142 device trees** as of this date (Asahi `asahi-wip-7.2` carries T8132 = base M4 only).
- **TTY is a realistic near-term target**: m1n1 main has initial T6050/T6051 support (2026-07-10) and SARTv4 (2026-08-16); a firmware/simplefb framebuffer + SPI keyboard + NVMe rootfs is the same path M1–M3 used before DCP existed.
- **Wayland is the stretch**: on M5 Pro it needs (a) a working display path (DCP coprocessor or the firmware framebuffer — even installer-supported M3 still lacks full DCP today), and (b) a GPU driver — the fastest-moving option is the new clean-room **G16/G17 AGX driver** (GLES 3.0 conformant on M4, M5 userspace "mostly" RE'd, published ~2026-09-15 by Cody Ho + Niklas Sheth) and/or Omarchy M's in-house GPU work ("Dj").
- **Wi-Fi/BT is a new chip problem**: M5 Pro MacBooks dropped Broadcom for Apple's **N1** (Wi-Fi 7 + BT 6 + Thread). Omarchy M claims Miguel Cruz has N1 Wi-Fi/BT "fully functional in Linux" — announced 2026-09-11, no public tree located yet. Until then, USB-C Ethernet/tethering is the fallback.
- **Virtualization is a solid interim vehicle**: stock Apple Virtualization.framework/UTM gives virtio-gpu 2D only (llvmpipe); QEMU+HVF with VirGL patches gives real GPU acceleration — this is exactly what Omarchy's `try-omarchy` app ships (Arch ARM64 + Omarchy Quattro in a macOS app). Nested virt (KVM-in-VM) exists on M3+ with macOS 26+.

---

## 2. Hardware: what the M5 Pro is, and what changed vs M1–M4

### 2.1 Verified facts

| Item | Value | Source (date) |
|---|---|---|
| Announce / ship | 2026-03-03 / 2026-03-11 | Apple newsroom 2026-03-03; theapplewiki |
| 14" M5 Pro IDs | Mac17,9, J714sAP, A3426, board platform t6050 | theapplewiki; appledb |
| 16" M5 Pro IDs | Mac17,8, J716sAP, A3428, t6050, CPID 24656 | theapplewiki; ipswfile |
| 16" M5 Max | Mac17,6 | Apple Support "Identify your MacBook Pro" |
| SoC | T6050 "Sotra_S" (H17S); Max = "Sotra_C" H17C (m1n1 commit covers T6050/**T6051**) | Asahi soc-codenames; m1n1 commit b2d3f5eb |
| Package | **Fusion Architecture**: CPU chiplet + GPU chiplet, TSMC SoIC-X face-to-face hybrid bonding on silicon interposer; Pro and Max share the *same* CPU chiplet, differ on GPU chiplet | TechInsights package analysis 2026-06-30, die analysis 2026-09-02 |
| CPU | 18c (6 "super" + 12 "performance") or 15c (5S+10P binned) | Apple newsroom; Wikipedia |
| CPU core types | New "**M-core**" type on M5 generation — *not* E-cores (no `SYS_IMP_APL_E_*` regs); fastest cores = "super" (adt/MPIDR still call them P-cores). **M5 Pro boots on core 0 = an M-core.** | m1n1 commit b2d3f5eb (2026-07-10, Yureka) |
| GPU | 16- or 20-core, next-gen AGX with per-core Neural Accelerator; AGX generation **G17** (M5) vs G16 (M4) per clean-room RE naming | Apple newsroom; ADevWithAnIdea/agx-re |
| Memory | 24–64 GB LPDDR5X-9600, 307 GB/s, unified across the package | Apple; Wikipedia |
| I/O | 3× Thunderbolt 5, each with a dedicated on-chip TB5 controller | Apple newsroom; Wikipedia |
| Wireless | **Apple N1** — Wi-Fi 7 (802.11be), Bluetooth 6, Thread. Broadcom is gone on this machine. | Apple tech specs (support.apple.com 126318/126319) |
| Base clock | ~4.6 GHz P-core | everymac (third-party reports) |

### 2.2 What changed vs. M4 that affects Linux bring-up

| Change | Impact on bring-up | Confidence |
|---|---|---|
| **Two heterogenous dies** (CPU die + GPU die on interposer) | Linux still sees one SoC/one DT (like T600x/T602x multi-die `die0/dieX` pattern already in linux-asahi), but PMGR/power domains, memory init, and any die-crossing DART/SART views need new handling. GPU being on a *separate die* may isolate GPU bring-up from the rest. | Packaging verified (TechInsights); Linux-side impact = inference |
| **New "M-core" CPU type** (not an E-core; lacks `SYS_IMP_APL_E_*`) | m1n1 SMP bring-up differs; m1n1 noted (2026-07-10) secondaries powered on but didn't start executing — since fixed enough in Linux that multicore no longer crashes (7.2 report). Scheduling/cluster topology differs (S + M, not P + E). | Verified in m1n1 commit + Asahi 7.2 |
| **SPTM mandatory for XNU (M4+)** | m1n1 hypervisor tracing was broken; Sven taught m1n1 to emulate SPRR/GXF (GL2) and load Apple's SPTM blob → MMIO tracing works again (slower). Prerequisite for all further RE on M4/M5. | Verified (7.2 report) |
| **Chicken bits locked by mBoot (M4+)** | Can't tune per-core WFI retention; WFI loses state → crash. Workaround: idle-loop kernel cmdline param (in linux-next); real fix = Sven's PSCI-over-UEFI-runtime conduit (RFC on LKML). | Verified (7.2 report) |
| **NVMe firmware ABI change (macOS 15.x+)** | Newer ANS NVMe firmware is stricter; Sven's series fixes panic-on-init-fail, a missing chicken bit, page-aligned admin-queue quirk required for M4+. **Working on M4 and M5** in Asahi trees. | Verified (Phoronix 2026; 7.2 report) |
| **SARTv4 on T6050** | NVMe's address-filter block rev'd again (SART v1→v4 across gens); m1n1 gained SARTv4 support 2026-08-16. | Verified (m1n1 9bfdf8ae) |
| **AICv3** | M4/T8132 DT uses `apple,t8132-aic3` (same family as M3's t8122-aic3). M5 expected to continue AICv3. | Verified for M4 DT; M5 = inference |
| **I2C/PMU blocks unchanged** | t8132 dtsi reuses `apple,t8103-i2c` compatibles — peripheral register blocks keep recycling. Expect the same for T6050. | Verified pattern; M5 = inference |
| **N1 replaces Broadcom** | All prior Wi-Fi/BT work (brcmfmac + Apple cal-blob plumbing) does not apply. N1 needs a brand-new driver; claims exist (below). | Verified chip; driver state = claim |
| **TB5 controllers on-die (Pro/Max)** | Prior gens hung TB off PCIe switches; on-chip per-port TB5 is new IP — same "RE + driver + convince blocks to cooperate" story as ATCPHY/DPTX on earlier gens. | Verified arch; driver state unknown/WIP |
| **macOS 27 boot-picker flag** | Apple's boot tools now require a "bootable volume" APFS flag; Asahi installer sets it (fix mode exists). | Verified (7.1 report, June 2026) |
| **macOS 27 SMC battery ABI change** | u32→u8 field change could trigger false "battery failed → shutdown"; fixed downstream in linux-asahi ≥7.0.12. | Verified (7.1 report) |
| **Firmware-ABI targeting** | DCP/AGX ABIs are per-macOS-version. M1/M2 target macOS 13.5 ABI; M3 targets 14.8.3; **M5 will target a macOS 26.x/27.x ABI** — pick which build to track early. | Verified mechanism; specific version = open question |

### 2.3 Boot chain (unchanged shape, new quirks)

iBoot/mBoot → m1n1 (EL2, HV optional) → U-Boot (UEFI) → GRUB/systemd-boot → Linux. m1n1 1.6.0 tagged; `psci-via-efi` and `hv-sprr` work live on branches. Asahi install requires the stub-macOS APFS container trick + reduced-security policy set from recoveryOS — unchanged on M5, plus the new macOS-27 bootable-flag quirk (installer handles it).

---

## 3. Per-subsystem status matrix (as of 2026-09-21)

**State key:** ✅ working (in some tree) · 🟡 partial/WIP-public · 🔴 not started/blocked · ❓ claim-only/no public artifact.
**Needed-for key:** TTY = usable text console; WL = Wayland/Hyprland session; DD = daily-driver polish.

| Subsystem | State on M5 Pro (2026-09-21) | Where the work lives / who | Needed for |
|---|---|---|---|
| **Boot chain** (mBoot→m1n1→U-Boot) | 🟡 m1n1 `main` has initial T6050/T6051 (2026-07-10) + SARTv4 (2026-08-16); SMP secondaries were non-functional in m1n1 at that commit | AsahiLinux/m1n1 `main`; Yureka | TTY |
| **CPU SMP / interrupt (AICv3)** | 🟡 Linux boots, multi-core crash fixed (7.2 report). AICv3 family unchanged vs M3/M4. | linux-asahi (private/staging); Yureka, Sven | TTY |
| **NVMe storage (ANS + SARTv4)** | 🟡 **Working** on M5 in Asahi trees after macOS-15.x firmware ABI RE; SARTv4 in m1n1 | linux-asahi + m1n1; Sven (NVMe fw), Yureka (SARTv4) | TTY |
| **Keyboard + trackpad (SPI HID)** | ❓ Not publicly demonstrated on M5 Pro. Path unchanged since M1 (SPI + HID-over-SPI + `apple,z2-spi`); likely "DT entry + compat" work once base boots. omarchy-mac carries `fix-spi-keyboard.sh` for earlier gens. | linux-asahi; Liam (Omarchy M) bringing up trackpad "on the newest machines" | TTY (keyboard); WL (trackpad) |
| **Keyboard backlight** | ❓ Works on M1/M2 via dedicated driver path; no M5 statement | linux-asahi | DD |
| **Display — early TTY** | 🟡(inferred) Firmware framebuffer → simplefb/simpledrm gives console without DCP; this is exactly how M3 ships today (no full DCP yet but TTY/desktop work) | m1n1/U-Boot/kernel simplefb | TTY |
| **Display — real modes (DCP/dcpext)** | 🔴 Nothing public for T6050. M3's DCP (macOS 14.8.3 ABI) only reached near-parity Aug 2026; M5 pairs to a macOS 26/27 ABI and likely needs EPIC/dcpext re-RE. Fusion puts display HW on the CPU die (per package analysis) — probably not architecturally new, but unverified. | linux-asahi `drivers/gpu/drm/apple` (DCP); Scott Jones got M3 Air DCP up for Omarchy; no public M5 work | WL (internal panel) |
| **GPU (AGX G17)** | ❓/🟡 Two efforts: (a) **Cody Ho + Niklas Sheth** — clean-room kernel+Mesa driver, GLES 3.0 conformant on M4 (G16), "**mostly**" M5 (G17) userspace RE'd, Vulkan planned, published 2026-09-15, repos: `ADevWithAnIdea/agx-re`, `apple-silicon-re`, `linux`, `m1n1` forks; (b) **Omarchy M "Dj"** writing GPU drivers (no public repo found). Asahi's own Mesa stack (asahi GL + Honeykrisp VK) is upstreamed but covers M1/M2 only — even M3 lacks GPU in the installer today. | agx-re repos; Omarchy M; Mesa upstream (M1/M2) | WL (real accel); TTY works without it |
| **Wi-Fi + Bluetooth (N1)** | ❓ Claim: Miguel Cruz (Omarchy M) "reverse-engineered Apple's proprietary N1 chip in the M5 machines and now has its Wi-Fi and Bluetooth fully functional in Linux" (2026-09-11). **No public repo/tree located** as of 2026-09-21. Eryk Wieliczko (Aurora Silicon — actually a Windows-on-ARM project) is clean-rooming "all of this" for upstreaming per the same post. | Omarchy M announcement; publication venue TBD | DD (TTY/WL usable via USB-C NIC) |
| **USB-C / TB5 / DP alt-mode** | 🟡 USB3+DP alt-mode exists only in Asahi's **`fairydust`** branch (as-is, dev-only: one "blessed" port, plug quirks); TB host mode WIP. M5 Pro adds **on-chip TB5** (new IP, per-port controllers). Jaidip Subedi lit USB-C external displays on M2 Air (Omarchy); Marcelo Alcantara cut a build lighting external monitors over USB-C. | AsahiLinux/linux `fairydust` (Sven, Janne, marcan); Omarchy M | DD; WL if external display needed |
| **Audio (speakers/HP/mic)** | 🔴 M5 nothing public. I2S/NCO unchanged since M1 → porting is mostly DT + asahi-audio/speakersafetyd config once base boots (M3 took "trivial" effort). Liam (Omarchy M) doing speakers on newest machines. | linux-asahi, asahi-audio; chaos_princess (M3 ref), Liam | DD |
| **Webcam (ISP)** | 🔴 Nothing public on M5. M3 needed one skipped-init fix (M3 Max); expect similar small delta once base runs. | linux-asahi ISP driver; chaos_princess | DD |
| **Touch ID (SEP)** | ❓ Dj (Omarchy M) "got Touch ID working by talking directly to the Secure Enclave" — novel; Asahi's SEP driver is still WIP and doesn't expose Touch ID. No public artifact found. | Omarchy M claim | DD |
| **Battery / power mgmt (SMC, AOP, PMGR, cpufreq)** | 🟡 cpufreq unchanged since M2 (DT-only on M3 — likely same for M5 once DT lands); SMC battery ABI patched for macOS 27 (≥7.0.12); charge thresholds exist via SMC. cpuidle: downstream WFI-save driver works but can't upstream; **PSCI-via-UEFI-runtime conduit** (Sven) is RFC'd and m1n1-side implemented — the real fix path. | linux-asahi, m1n1 `psci-via-efi`; Sven; Liam (Omarchy power mgmt) | DD (battery info); battery life WL+ |
| **Suspend / sleep** | 🔴 M5 nothing public; even M3 (installer-supported 2026-09-06) has **sleep broken** pending full DCP. Treat suspend as post-DCP work. | linux-asahi | DD |
| **Video decode (AVD)** | 🔴 on M5. Asahi runs own firmware on AVD (no kext-extraction); works M1–M3; VA-API↔V4L2-stateless shim (sofus fork of megi) for desktop apps. | linux-asahi; sofus | DD |
| **Neural Engine / MLX** | 🔴 Linux: out-of-tree ANE driver on M1/M2 only. Omarchy M advertises MLX-over-Vulkan as a goal (userspace-level, not kernel). | Omarchy M roadmap | DD stretch |
| **Installer / distro** | 🔴 Asahi installer does **not** offer M4/M5 (2026-08-26). Omarchy M installer (Marcelo Alcantara) targets M1/M2 first. Asahi Alarm (`asahi-alarm.org`, the Arch ARM port omarchy-mac builds on) follows Asahi's machine support. | asahi-installer; omacom/omarchy-mac (`quattro`); omacom/omarchy-mac-iso | first boot |

### Bottom line for "usable at TTY"
Needed: m1n1 (✅ initial T6050) → SMP/AIC (✅ boots, multicore fixed) → NVMe+SARTv4 (✅) → UART or simplefb console (expected) → SPI keyboard (likely-small port) → PMIC/PMGR basics. **Every hard blocker for TTY is already proven working in trees**; remaining work is DT authoring (t6050.dtsi, j714s/j716s dts) + SPI/trackpad + integration. No T6050 DTs are public yet — expect them to land in `asahi-wip` or Yureka's tree first.

### Bottom line for Wayland
Needed: DCP (real modes/backlight/notch) **or** accept simplefb + `wlroots` on KMS/FB (slow but boots); GPU acceleration needs one of: Cody/Niklas G17 bring-up extended to T6050, Dj's driver, or Asahi's AGX stack catching up (M3 still doesn't have it). Framebuffer-composited Hyprland is plausible before DCP; hardware-accelerated Hyprland is a G17-driver-shaped dependency.

---

## 4. Who's doing what (key people/trees)

| Person/team | Area | Venue |
|---|---|---|
| **Yureka** (yuka@yuka.dev / GH `yuyuyureka`) | M4/M5/Linux-on-Neo bring-up: T6050/T6051 + T8142 initial m1n1, SARTv4, PCIe, multicore fix, MCC/ATC branches | AsahiLinux/m1n1 `main`; github.com/yuyuyureka/m1n1 |
| **Sven Peter** | NVMe macOS-15 firmware ABI, SPRR/GXF emulation in m1n1 HV, PSCI-over-UEFI conduit, fairydust (DP/TB) | AsahiLinux/linux, LKML RFC, 39C3 talk 2025-12 |
| **chaos_princess** | Audio (M3), webcam/mic, macOS-27 boot-picker fix | linux-asahi |
| **James Calligeros** | Asahi progress reports, DCP Interchange wiring w/ Oliver Bestmann | asahilinux.org |
| **Alyssa Rosenzweig / Asahi Lina** | AGX driver foundation (M1/M2), Interchange groundwork | Mesa upstream |
| **Cody Ho + Niklas Sheth** | G16/G17 AGX clean-room driver (kernel + Mesa GLES3; M5 userspace mostly done) | codyho.dev; github.com/ADevWithAnIdea/{agx-re,apple-silicon-re,linux,m1n1} |
| **Omarchy M** (announced 2026-09-11, omarchy.org) | Dj — GPU drivers + Touch ID/SEP; Miguel Cruz — N1 RE; Liam — speakers/trackpad/power; Marcelo Alcantara — native installer + USB-C displays; Naeem Malik + Scott Jones — omarchy-mac (M1/M2, M3 Air DCP); Eduardo Martinez — Try Omarchy app; Eryk Wieliczko — clean-room upstreaming (Aurora Silicon); Jaidip Subedi — M2 Air USB-C display | github.com/omacom/omarchy-mac (quattro branch), omacom/try-omarchy, omarchy-mac/omarchy-pkgs-aarch64 |
| **Asahi Alarm** | Arch Linux ARM port — the base omarchy-mac installs on | asahi-alarm.org |

---

## 5. The virtualization alternative (bring-up vehicle)

| Option | Graphics | Notes |
|---|---|---|
| **Apple Virtualization.framework** (UTM "Apple" backend) | virtio-gpu **2D only** → llvmpipe; no VirGL in VZ | Solid for TTY/SSH dev; Wayland desktop will be CPU-rendered but usable. Rosetta-for-Linux gives x86_64 binaries in the VM (macOS 13+). |
| **QEMU + HVF** (UTM "QEMU" backend) | VirGL/venus possible **only via out-of-tree patches** (startergo mega-patch lineage) | This is what `omacom/try-omarchy` vendors: QEMU 11.1.1 + in-hypervisor GICv3 + trimmed render patchset; hardware-accelerated ARM64 Arch/Omarchy guest, camera/audio/clipboard/WireGuard-ish port forwards. Fork fixed idle CPU 71%→15%. |
| **Nested virt** | KVM inside the guest on M3+ running macOS 26+ | Enables VM-in-VM dev workflows on the M5 Pro host. |
| Arch boot specifics | UTM can boot ARM64 via EFI or direct kernel image ("Linux kernel ARM64 boot executable, 4K pages"); Archboot images used in practice | vkhitrin.com guide (2023), UTM issues #5602/#5482 confirm the VirGL gap in VZ. |

**Recommendation:** for omarchy-m5, a QEMU-HVF/VirGL VM (or Try Omarchy) is a realistic daily-usable Omarchy on the M5 Pro *today* while bare metal matures; keep a bare-metal track for TTY via m1n1 → linux-asahi + t6050 DT work.

---

## 6. Risks / open questions

1. **N1 driver provenance** — Omarchy M's claim is 10 days old with no public tree found; verify code exists/licensable before planning around it.
2. **Dj's GPU work vs. agx-re** — two possibly-parallel G17 efforts; unclear if coordinated.
3. **DCP on T6050** — biggest TTY→WL unknown; no public work. If firmware framebuffer suffices for fixed-mode TTY/SDDM→Hyprland, DCP can be deferred (that's the M3 status quo: no sleep, no HDMI, but usable).
4. **Dual-die effects** — memory init lives where? PMGR domain granularity? No public T6050 DT to confirm yet.
5. **macOS 27 vs 26 shipping** — M5 Pro ships 26.x; upgrading host macOS to 27 pulls the SMC ABI fix + boot-picker flag requirements (both handled by current Asahi tooling).
6. **Upstream lag** — even the working M4/M5 bits are downstream-only; plan to carry linux-asahi-derived patches (as omarchy-mac already does for M1/M2 quirks).

## 7. Primary sources

- Apple newsroom, M5 Pro/Max announce — 2026-03-03 — https://www.apple.com/newsroom/2026/03/apple-debuts-m5-pro-and-m5-max-to-supercharge-the-most-demanding-pro-workflows/
- Apple tech specs (N1, TB5) — support.apple.com/en-us/126318, /126319
- Asahi Linux progress reports — 7.1 (2026-06): macOS 27 boot-picker + SMC fixes, m1n1 1.6.0; 7.2 (2026-08-26): PSCI-via-UEFI RFC, WFI/chicken-bit lockdown, SPTM/GXF emulation, **NVMe+PCIe+multicore working on M4/M5**, DCP/Interchange direct-scanout path — asahilinux.org/2026/06/progress-report-7-1/, /2026/08/progress-report-7-2/
- "M2: Episode 1 (or, Asahi Linux on M3)" — 2026-09-06 — M3 merged into installer; still no full DCP/GPU/sleep on M3 — asahilinux.org/2026/09/m2-episode-1/
- Asahi docs: SoC codenames (T6050/Sotra_S, T8142/Hidra), device list, feature-support pages (M4 page all-TBA; no M5 page yet) — asahilinux.org/docs/hw/soc/soc-codenames/
- m1n1 commits — b2d3f5eb "Initial support for T6050/T6051" (2026-07-10, M-core discovery, SMP secondaries not starting), 9bfdf8ae "sart: add SARTv4 support" (2026-08-16), b72e664f "Initial support for T8142" (2026-07-19) — github.com/AsahiLinux/m1n1
- linux-asahi tree — `asahi-wip-7.2` has T8132 (M4) DTs only; `fairydust` branch = DP-alt-mode dev tree — github.com/AsahiLinux/linux
- Phoronix: Apple NVMe macOS-15 firmware fixes (Sven), 39C3 Sven talk coverage — phoronix.com
- TechInsights M5 Pro package analysis (SoIC-X F2F hybrid bonding, CPU+GPU chiplets) — 2026-06-30; die-level GPU analysis — 2026-09-02 — techinsights.com
- Cody Ho blog — "Building a GPU Driver From Scratch in One Month" + hypervisor/SPTM docs — codyho.dev/blog/gpu-driver/ (~2026-09-15); repos under github.com/ADevWithAnIdea
- Omarchy M announcement — 2026-09-11 — omarchy.org/news/2026/09/introducing-omarchy-m/ (N1/TouchID/GPU claims); omacom/omarchy-mac + omarchy-mac/omarchy-pkgs-aarch64 + omarchy-mac/omarchy-mac-iso; omacom/try-omarchy (QEMU/HVF/VirGL app)
- theapplewiki/ipswfile/appledb — Mac17,9=J714sAP, Mac17,8=J716sAP, t6050, CPID 24656
- UTM/VZ: UTM #5602, discussion #5482 (no VirGL in VZ); vkhitrin.com Arch-on-VZ guide
- Wikipedia "Apple M5" (Fusion arch, SKU table, M5 Ultra Aug 2026) — en.wikipedia.org/wiki/Apple_M5

## 8. Confidence notes

- **Verified (primary)**: identifiers/SoC IDs, Fusion package structure, core types/M-core, m1n1 T6050+SARTv4+T8142 commits, NVMe/PCIe/multicore status, M3 installer status and its no-DCP/no-sleep caveats, N1 in M5 Pro spec sheets, fairydust scope/quirks, VZ VirGL limitation, macOS-27 SMC/boot-picker changes.
- **Claimed, unverified artifact**: N1 fully-working driver (Miguel Cruz), Touch ID via SEP + Omarchy GPU driver (Dj), "M5 userspace mostly RE'd" (Cody/Niklas — repo exists, M5 completeness not independently verified).
- **Inferred**: AICv3/I2C/SPI/audio block reuse on T6050 (strong precedent: T8132 reuses T8103/T8122 compatibles); T6051 = M5 Max (m1n1 commit covers both names); DCP unchanged architecturally on M5 (display HW on CPU die); simplefb path sufficing for TTY.
