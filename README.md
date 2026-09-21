# omarchy-m5

Bringing [Omarchy](https://omarchy.org) — Arch Linux ARM + Hyprland — to the **M5 Pro MacBook Pro** (Apple Silicon), dual-booted alongside macOS.

**Goal:** power on → Linux boots → usable TTY. Stretch: Wayland/Hyprland on the built-in display.

This is frontier work. Asahi Linux has M4/M5 *booting* (PCIe + NVMe enumerated, multicore fixed as of the Aug 2026 "Linux 7.2" report) but nothing installer-ready; the newly-announced **Omarchy M** team already has M5 Wi-Fi/Bluetooth working via the N1 chip. This project builds on both.

## Layout

- [`docs/PLAN.md`](docs/PLAN.md) — phased project plan, risks, open questions
- `docs/research/` — deep-dive reports (kernel/boot chain, hardware matrix, Omarchy ARM ecosystem, dual-boot mechanics)

## Status

Phase 0 research complete — see `docs/research/` (kernel/boot chain, M5 Pro
hardware matrix, Omarchy ARM ecosystem, dual-boot mechanics). Entering Phase 1:
m1n1 + linux-asahi bring-up on T6050. See `docs/PLAN.md`.
