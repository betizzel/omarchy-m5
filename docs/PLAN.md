# Omarchy on M5 Pro — Project Plan

> Last updated: 2026-09-21, after Phase 0 research. Sources: `docs/research/`.

## Objective

Boot Omarchy (Arch Linux ARM + Hyprland) natively on an M5 Pro MacBook Pro,
partitioned alongside macOS (dual-boot preserved), usable at a TTY.
Stretch goal: Wayland/Hyprland on the internal display.

## What we now know (Phase 0 findings)

**The machine.** M5 Pro = SoC **T6050 "Sotra_S"** — Apple's first dual-die
"Fusion" chip (CPU chiplet + GPU chiplet on an interposer). Mac17,9/j714s (14"),
Mac17,8/j716s (16"). New "M-Core" CPU type replaces E-cores. Wireless is Apple's
**N1** (Wi-Fi 7 + BT 6) — Broadcom is gone.

**Boot chain.** m1n1 v1.6.1 (2026-08-08) already has initial T6050/T6051 +
SARTv4 + the macOS-15 NVMe ABI fix, and runs on real M5 Pro hardware. The kernel
boots on M4/M5-class silicon with NVMe + PCIe enumeration per Asahi's Aug-26
Linux-7.2 report.

**The #1 blocker is SMP on M5 Pro.** Secondary cores power on but never execute
the reset vector — unresolved; deepest public RE is qspqww's July 2026
iBoot/AppleT6050PMGR disassembly. `maxcpus=1` is the expected workaround; a
single-core TTY is the realistic first milestone.

**The #2 gap is a device tree.** No public kernel DT exists for any M5 or any
M4/M5 Pro/Max. Authoring `t6050.dtsi` + `j714s/j716s` board DTs (starting from
t8132/M4 DTs, which landed in linux-next Aug 2026) is *the* central work item.

**Console path.** Firmware/simplefb framebuffer (the path M3 ships with today)
+ dockchannel-UART via m1n1. DCP is needed only for Wayland, not TTY.

**Install path is manual-only for now.** The Asahi installer gates on hardcoded
chip tables (v0.9.2 added M3 only); Omarchy M's native installer wraps a pinned
Asahi engine and fail-closes on M4+. So: `diskutil apfs resizeContainer` +
2.5 GB stub macOS container + `kmutil configure-boot` of m1n1 from the paired
recoveryOS in 1TR. Layout: stub 2.5 GB + 500 MB ESP + 2 GB boot + btrfs/LUKS2 root.

**The userland is nearly free.** omarchy-mac (github.com/omacom/omarchy-mac) is
the canonical Apple Silicon fork; pkgs.omarchy.org already serves aarch64
(126 edge pkgs incl. omarchy 4.0.2 + hyprland 0.56.2), with an
`install/hardware/apple/` quirks layer and omarchy-mac-iso for installer media.
Phase 3 is "add a t6050 profile to omarchy-mac", not "port Omarchy".

**Wayland stretch.** Needs either (a) DCP display driver (nothing public for
T6050; M3's DCP only reached near-parity Aug 2026) or fb-composited Hyprland on
simplefb, plus (b) a G17 GPU driver — watch Cody Ho + Niklas Sheth's clean-room
`agx-re` (GLES3-conformant on M4, M5 userspace mostly RE'd) and Omarchy M's Dj.

**Coordination.** Omarchy M (apple@omarchy.org) claims Miguel Cruz has N1 Wi-Fi/BT
fully working in Linux — unpublished as of today; verify provenance before
planning around it. Aurora Silicon is clean-rooming for upstream.

## Phases

### Phase 0 — Research ✅
Four reports in `docs/research/`: kernel/boot chain, hardware matrix,
Omarchy ARM ecosystem, dual-boot mechanics.

### Phase 1 — Bring-up loop + TTY (current focus)
Goal: `m1n1 → kernel → console` on the M5 Pro, tethered dev loop before
partitioning.
1. Build m1n1 for T6050; establish chainload/proxy dev boot from macOS
   (no partition changes yet — DFU-safe iteration).
2. Fork linux-asahi; author `t6050.dtsi` + `j714s.dts`/`j716s.dts` from the
   t8132 template; boot with `maxcpus=1`.
3. Console: dockchannel-UART for logs + simplefb for the panel.
4. SPI keyboard driver check; USB-C Ethernet dongle for networking
   (N1 = zero driver work exists publicly).
- Success metric: reproducible boot to getty, single core, on-device display.

### Phase 2 — Dual-boot install (after Phase 1 boots)
- Manual Asahi-style install: APFS resize → stub container → 1TR pairing
  ceremony → m1n1 stage2 + U-Boot + ESP → NVMe-resident boot.
- Script it; only consider installer-app polish once the manual path is proven.

### Phase 3 — Omarchy userland
- Arch Linux ARM (asahi-alarm lineage) rootfs + omarchy-mac install path +
  pkgs.omarchy.org aarch64 + a new `apple/t6050` hardware profile.
- Parallel track (usable today): Try Omarchy / QEMU-HVF+VirGL VM on the M5 Pro
  for userspace dev while bare metal matures.

### Phase 4 — SMP + Wayland (long poles, run in parallel w/ 2–3)
- **SMP:** continue the AppleT6050PMGR/iBoot RE; this is the difference between
  a demo and a usable machine. Track qspqww's work and m1n1 PRs.
- **Wayland:** DCP bring-up (macOS 26/27 ABI pairing) and/or G17 driver bring-up;
  fb-composited Hyprland is the fallback "it works" milestone.

## Key risks

- **SMP may stay broken for months** — single-core usability is the floor.
- **N1 provenance** — Omarchy M's Wi-Fi/BT claim has no public artifact.
- **RecoveryOS pairing** — one wrong boot-policy move can force a DFU restore;
  iterate only via tethered m1n1 until Phase 2.
- **Upstream churn** — M4/M5 land in `asahi-wip`/dev trees weekly; plan to rebase.

## Links

- linux-asahi: https://github.com/AsahiLinux/linux · m1n1: https://github.com/AsahiLinux/m1n1
- Asahi feature support: https://asahilinux.org/docs/platform/feature-support/
- omarchy-mac: https://github.com/omacom/omarchy-mac · pkgs: https://github.com/omacom/omarchy-pkgs
- agx-re GPU driver: https://github.com/ADevWithAnIdea/agx-re · codyho.dev
- Omarchy M announcement: https://omarchy.us/news/2026/09/introducing-omarchy-m/
- Asahi ALARM: https://asahi-alarm.org · prior art: github.com/jondkinney/armarchy
