# omarchy-m5

Bringing [Omarchy](https://omarchy.org) — Arch Linux ARM + Hyprland — to the
**M5 Pro MacBook Pro**: Apple **T6050 "Sotra"**, Mac17,9 / J714s, dual-booted
beside macOS, Asahi-style.

This is frontier bring-up. No public installer supports the M5, and **no kernel
device tree existed for any M5** before this repo. Everything here builds on
[m1n1](https://github.com/AsahiLinux/m1n1) and
[linux-asahi](https://github.com/AsahiLinux/linux), driven from a **tethered dev
loop**: a Linux ThinkPad drives m1n1 on the Mac over USB‑C, so kernel/DT/RE
iterations never touch the Mac's boot policy.

> **Reviewing this?** Start with **[`FOR-AURORA.md`](FOR-AURORA.md)** — the three
> things worth your time, and what to skip.

## Status — verified on hardware

| Area | State |
| --- | --- |
| Boot chain | ✅ iBoot → m1n1 → Linux kernel, single‑core |
| Root filesystem | ✅ Arch on the **internal SSD** (`nvme0n1p5`), dual‑boot, macOS preserved |
| Storage | ✅ NVMe (ANS2 + NVMMU + SARTv4) |
| Console | ✅ framebuffer (simplefb / simpledrm) |
| Input | ✅ built‑in keyboard **and** trackpad (DockChannel MTP + `tpmtfw`) |
| Networking | ✅ USB‑C gadget (CDC EEM) — host reaches the Mac over the cable |
| m1n1 on upstream `main` | ✅ USB enumeration unblocked on T6050 (`patches/m1n1/0005`) |
| **SMP — secondary CPUs** | ❌ **the open blocker** — cores power up but execute nothing; deep RE done (below) |
| Wayland / GPU, Wi‑Fi/BT (N1) | ⏳ not started |

Today the machine boots Arch to a **single‑core userspace shell**; the kernel is
staged over the USB tether (`boot-m5.sh`) and roots on the SSD. `maxcpus=1` is
the current floor because of the SMP blocker — which is the main open problem.

## The SMP / iBoot‑reset investigation — start here

This is the deepest open problem. On T6050 the secondary cores **power on**
(PMGR `0x100 → 0x1f0`) but never run a single instruction we can observe — same
symptom m1n1 upstream reports on M5 (PR #610).

**The 2026‑10‑10 conclusion: the blocker is SPTM.** On current macOS, Apple's
Secure Page Table Monitor runs at GL2 (above EL2) and is boot‑active on T6050.
It owns the page tables and mediates secondary‑CPU bring‑up, so (a) the reset
entry is SPTM's, not m1n1's — which is why released secondaries execute nothing
m1n1 can see — and (b) the classic "boot macOS under m1n1 and trace it" method
is **architecturally dead** here. The real path is the **XNU‑shim** (Sven Peter,
CCC 2025). Read, in order:

1. **[`docs/smp-t6050-findings.md`](docs/smp-t6050-findings.md)** — start with
   §"Strategic reframe" (the SPTM conclusion + prior art), then the hardware
   measurements and the theories **disproven on hardware** (locked RVBAR, iBoot
   WFI sled, CTRR/CTXR execute‑regions).
2. **[`scripts/probes/`](scripts/probes/)** — the probe scripts behind every
   claim (`smp-*.py`, `wdt-arm.py`), and **[`patches/m1n1/`](patches/m1n1/)** —
   the bootloader changes (USB on T6050, `AVNCR_EL2`→GL2, watchdog, chainload).

If you're from **[Aurora Silicon](https://github.com/aurora-silicon)** / omarchy‑mac
or **[antiapplefox/m5-linux](https://github.com/antiapplefox/m5-linux)** (the SPTM
static‑RE track): our contribution is the **live‑hardware** side — real T6050
MIDR/PMGR, ADT‑derived DTs, and on‑metal m1n1 fixes — complementary to the
static SPTM shim work, not a duplicate of it.

## Repo map

- **[`docs/`](docs/)** — everything written down; **[`docs/README.md`](docs/README.md)**
  indexes it (current state, SMP RE, build guide, Phase‑0 research).
- `dt/` — the T6050 device trees, authored from **this machine's real ADT**
  (`scripts/adt2pmgr.py`), not guessed.
- `patches/m1n1/`, `patches/linux/` — the bootloader and kernel changes.
- `scripts/` — the dev harness (build / install / tether) and
  `scripts/probes/` (the hardware RE tooling).
- `configs/` — kernel configs · `tools/` — tiny on‑device C helpers ·
  `Makefile` — `make setup fetch m1n1 dtbs kernel`.

## Build & dev loop

See **[`docs/bringup.md`](docs/bringup.md)**. Short version:

```sh
make setup fetch m1n1 dtbs kernel   # toolchain, vendor clones, m1n1, DTBs, kernel
```

The one‑time on‑device install (partitioning + `kmutil`) is in
`docs/bringup.md` → *"One‑time on‑device step"*; after that the loop is
memory‑only over USB.

## Credits & upstreams

Built on the Asahi Linux project and the omarchy‑mac / Aurora Silicon ecosystem.
The hardware reverse‑engineering here is interoperability work on the author's
own Mac.

- [m1n1](https://github.com/AsahiLinux/m1n1) ·
  [linux-asahi](https://github.com/AsahiLinux/linux) ·
  [Asahi feature support](https://asahilinux.org/docs/platform/feature-support/)
- [omarchy-mac](https://github.com/omacom/omarchy-mac) ·
  [Aurora Silicon](https://github.com/aurora-silicon)
- [antiapplefox/m5-linux](https://github.com/antiapplefox/m5-linux) — the SPTM
  static‑RE / XNU‑shim track this builds on for the SMP work.
