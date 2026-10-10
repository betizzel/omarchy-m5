# Docs index

Where everything is, and the order to read it in. Dates are the last substantive
update.

## If you're reviewing the SMP / iBoot‑reset RE

Read these two, in order — they are the whole story and spell out the negative
results so nobody re‑runs them:

1. **[`smp-t6050-findings.md`](smp-t6050-findings.md)** (2026‑10‑10) — the
   shareable write‑up. What was measured on T6050, and the theories disproven on
   hardware (locked RVBAR, iBoot WFI sled, CTRR/CTXR execute‑regions).
2. **[`HANDOFF-smp-trace.md`](HANDOFF-smp-trace.md)** (2026‑10‑10) — live state of
   the dynamic approach (trace macOS under m1n1's hypervisor): the fully
   root‑caused T6050 GXF / `AVNCR_EL2` wall and the exact next step, with a
   copy‑paste resume recipe.

Supporting evidence: [`../scripts/probes/`](../scripts/probes/) (the probe
scripts), [`../patches/m1n1/`](../patches/m1n1/) (bootloader changes), and
[`research/probe-logs/`](research/probe-logs/) (raw captures).

## Current machine state

- **[`HANDOFF.md`](HANDOFF.md)** (running log, latest 2026‑10‑10) — the detailed
  state of the bring‑up: what boots, the device‑tree work, NVMe / keyboard /
  trackpad / USB‑net, disk layout, and dated SMP progress notes. The canonical
  "where are we" document.

## Build & install

- **[`bringup.md`](bringup.md)** — the tethered dev loop (`make` targets, macOS
  quirks) and the **one‑time on‑device install** (partitioning + `kmutil`),
  including resize / re‑install.

## Completed task‑handoffs (historical)

These drove the 2026‑10‑09 partition re‑install and are **done** — kept for the
record, not pending work:

- **[`HANDOFF-mac.md`](HANDOFF-mac.md)** — the macOS‑side half (stub container,
  `prep-stub.sh`, `finish-install.sh`). ✅ completed 2026‑10‑09.
- **[`HANDOFF-thinkpad.md`](HANDOFF-thinkpad.md)** — the ThinkPad‑side half
  (ceremony check, writing the Linux root over USB). ✅ completed 2026‑10‑09.

## Background / planning

- **[`PLAN.md`](PLAN.md)** (2026‑09‑21) — the original phased plan and Phase‑0
  findings. Historical framing; current status lives in `HANDOFF.md` and the
  root `README.md`.
- **[`research/`](research/)** — four Phase‑0 deep‑dives:
  `kernel-boot-m5.md`, `m5-pro-hardware-matrix.md`, `omarchy-arm-ecosystem.md`,
  `dualboot-partitioning.md`, plus `research/probe-logs/` and
  `research/smc-keys-j714s.json`.
