# Omarchy on ARM: ecosystem map for the omarchy-m5 project

Research compiled 2026-09-21 for `github.com/Betim-Hodza/omarchy-m5` (boot Linux on an M5 Pro MacBook Pro, dual-boot with macOS, TTY first → Hyprland/Omarchy). All claims link to primary sources; dates are noted per item. "Verified" = checked live this session (repo contents, HTTP probes, release listings).

## Executive summary

- **The ecosystem moved fast in the last 10 days.** Omarchy M was announced 2026-09-11; as of 2026-09-21 (verified live today), `pkgs.omarchy.org` now serves `edge/aarch64` (126 packages incl. `omarchy 4.0.2`, `omarchy-settings`, `hyprland 0.56.2-3`, `quickshell-git`, `omarchy-chromium-bin`, `yay`, `1password`) and `stable/aarch64` (18 packages). The older "aarch64 404s" caveat in community docs is stale.
- **Omarchy Mac is the canonical prior art.** `omarchy-mac/omarchy-mac` redirects to `omacom/omarchy-mac` (moved into the official org; 1.8k stars). It installs Omarchy 4 ("Quattro") onto an Asahi Alarm base with one command, full-disk encryption, btrfs+snapper, its own aarch64 package repo, and a hardware-quirks layer (`install/hardware/apple/`). Releases: v4.0.3rc4 (2026-09-17).
- **M5 Pro is the hard part, not Omarchy.** m1n1 gained initial M5 (t8142)/M5 Pro (t6050) support 2026-06-29; Asahi's Aug-2026 progress report shows NVMe + PCIe enumeration + multi-core boot working on M4/M5, but no installer enablement, no display/GPU, no audio, and Apple's new **N1** Wi-Fi/BT chip replaces Broadcom. Omarchy M's team claims N1 is functional in Linux (Miguel Cruz) — public code is not yet published in an obvious repo (Aurora's N1 research page is a placeholder pointing to their Discord).
- **Try Omarchy** (`omacom/try-omarchy`, v0.4.1 2026-09-15) is a signed/notarized macOS app running the real aarch64 Omarchy desktop in QEMU/HVF — a useful dev/testing vehicle for the userspace/distro layer on the M5 Pro itself, but useless for hardware bring-up (it's a VM).
- **Recommended reuse path for omarchy-m5:** Asahi m1n1/U-Boot/UEFI provision + `omacom/omarchy-mac` fork layer + `pkgs.omarchy.org` aarch64 + `asahi-alarm` repo for kernel/firmware, with a new M5 quirks layer on top.

## 1. Omarchy M — the official Apple Silicon team

Announced by DHH on **2026-09-11**: <https://omarchy.us/news/2026/09/introducing-omarchy-m/> (mirrored at omarchy.org / omarchy.nz). Incubated at 37signals. Contact: `apple@omarchy.org`.

**First-release target is M1/M2 (incl. Pro/Max):** seamless installer (install + try), full GPU, USB-C external monitors, Touch ID, MLX, disk encryption. "Newer machines are being worked on in parallel."

### Roster → public work (verified where linked)

| Member | Area (per announcement) | Public work found |
|---|---|---|
| Marcelo Alcantara (`maralcbr`) | Native macOS installer app; USB-C external monitors | `maralcbr/omarchy-mx-mac` — signed installer script + `Omarchy MX Mac Installer.app` at <https://maralcbr.github.io/omarchy-mx-mac/> (RC image `os-v4.0.3-mac.1.20260913`). App flow: fetch signed release → partition → dual-boot, "no USB stick". Alpha per 2026-09-12 coverage. |
| Naeem Malik (`malik-na`) | Omarchy Mac maintainer (1 yr), Discord ~800+ | `omacom/omarchy-mac` (was `omarchy-mac/omarchy-mac`, `malik-na/omarchy-mac`; also Codeberg mirror history). Discord: <https://discord.gg/KNQRk7dMzy> |
| Scott Jones (`scottjones`) | Linux-side install; M3 Air (j613) DCP display bring-up | `omarchy-mac/omarchy-mac-iso` (79 commits; GPT `.img` live-USB + NVMe-placer installer), `omarchy-mac/omarchy-pkgs-aarch64`, `omacom-io/omarchy-pkgs` commits |
| Eduardo Martinez (`themartiano`) | Try Omarchy | `omacom/try-omarchy` (forked upstream from `themartiano/try-omarchy`; 2.2k stars) |
| Shun Li (`riverscn`) | aarch64 packages, generic ARM64 VM disk images, guest tools | `riverscn/omarchy-aarch64-image` (45★, UTM/QEMU images), `riverscn/omarchy-pkgs-aarch64`, `riverscn/omarchy-aarch64`, `riverscn/omarchy-spice-guest-tools` (SPICE clipboard/resize for VM guests) |
| Dj (`DjDeveloperr`, "djdev") | GPU drivers; Touch ID via Secure Enclave | `DjDeveloperr/mesa` — AGX G15/G16/G17 (M3/M4/M5) fail-closed research, honeykrisp branches; `DjDeveloperr/linux` (`agx/uapi`, `bits/080-wifi`, `bits/210-gpu`); SEP/Touch-ID commits on `aurora-silicon/linux` branch `feat/sep` (2026-09-16..18: "interrupt-driven fingerprint capture", xART gigalocker, key-store endpoint). Aurora research doc: ~4,150 lines C reimplementation, MIT — <https://aurorasilicon.org/research/security/touch-id/> |
| Miguel Cruz (`Acelogic`, "Ace") | N1 Wi-Fi/BT reverse engineering on M5 — "fully functional in Linux" (per announcement) | `Acelogic/q1n1` (m1n1 retargeted to Snapdragon — shows deep m1n1 fluency). **N1 code location: not publicly verified.** Aurora's <https://aurorasilicon.org/research/networking/apple/> page is a placeholder saying "Discord server is the best place to ask." Treat publication venue vs. private Aurora/Omarchy-M trees as open. |
| Liam (`liamray10`) | Speakers/trackpad/power on newest machines | Aurora Silicon member (California), holds an M5 MacBook Pro. No public repos found — likely Aurora/internal trees. |
| Eryk Wieliczko | Aurora Silicon lead; clean-room implementations for upstreaming | <https://aurorasilicon.org> + `github.com/aurora-silicon` org (14 repos: `linux` kernel tree, `u-boot`, `mu*` UEFI, `aurora-installer`, `macvdmtool`/`tuxvdmtool`, `asahi-bless`, `recovery-ssh`). Note: Aurora's own policy says their findings **don't** go upstream themselves — the Omarchy announcement implies Eryk produces separate clean-room impls that *can*. Nuance worth tracking. |
| Jaidip Subedi (`subedijaidip`) | M2 Air external display over USB-C | `subedijaidip/dp-altmode-t8112` — "MacBook Air M2 (t8112/j413): enable USB-C DisplayPort/HDMI on Asahi Linux" |
| Joshua Warren (`joshuaswarren`) | mlx-omarchy | `joshuaswarren/mlx-omarchy` — MLX backend over Vulkan (Mesa Honeykrisp) on Apple GPUs + ANE offload roadmap; patch-set over pinned upstream MLX (`mlx.lock`); "no silent CPU fallback" philosophy |
| Jon Kinney (`jondkinney`) | ARM support (prior), now team coordinator | `jondkinney/armarchy` (`vm-testing` branch = the working one-shot M1/M2 installer; also Parallels/ArchBoot guide for M3/M4 VMs); author of basecamp/omarchy PR #1897 |
| Shawn Yeager | 2016/2017 Touch-Bar MBPs (speakers, Wi-Fi, ALS, Touch Bar) | PRs against upstream omarchy (T1/T2-era Intel Mac support that already landed: `install/hardware/apple/`) |
| Randy | T2 chip RE → Touch ID on Intel Macs | Documenting 2019 MBP fixes (upstream `install/hardware/apple/fix-t2.sh` etc.) |

Supporting coverage: <https://tbreak.com/omarchy-m-apple-silicon-linux/> (2026-09-12), <https://omarchycentral.com/news/omarchy-apple-silicon-m1-m2-alpha-install-dhh/> (2026-09-12 — Marcelo's alpha installer demo).

## 2. `omacom-io/omarchy-pkgs` — aarch64 state (verified live 2026-09-21)

Repo: <https://github.com/omacom-io/omarchy-pkgs> (build system for pkgs.omarchy.org; PKGBUILDs under `pkgbuilds/`, `.omarchy/package.json` metadata per package).

- **Tooling is multi-arch already**: every `bin/repo` command takes `--arch x86_64|aarch64` and `--mirror edge|rc|stable`. Cross-build on x86_64 uses QEMU binfmt: `docker run --privileged --rm tonistiigi/binfmt --install arm64` (README "aarch64 Builds (Optional)"). A 2026-09-18 commit notes builders emulate aarch64 with QEMU 10.2.3.
- **Published now (verified by fetching `omarchy.db` tarballs):**
  - `edge/aarch64`: **126 packages**, `Last-Modified: 2026-09-21 12:42 UTC` — includes `omarchy-4.0.2-1`, `omarchy-settings-4.0.2-1`, `hyprland-0.56.2-3`, `quickshell-git`, `omarchy-chromium-bin-148.*`, `walker`, `elephant-*`, `omacalc/omacut/omawrite`, `tensaku`, `1password` + `1password-cli`, `mise-bin`, `yay`, `xpadneo-dkms`, `v4l2-relayd`, `sunshine`, `omarchy-steam-fex` (FEX x86-emu for Steam on ARM), `omarchy-dev`/`omarchy-settings-dev` tracks.
  - `stable/aarch64`: **18 packages** (mostly CLI/agentic tools + `aether`; no `omarchy` metapackage yet on stable).
  - `rc/aarch64` exists in pacman.conf templates upstream.
- **Notable gaps vs edge/x86_64 (257 pkgs):** `ghostty`, `gpu-screen-recorder`, `cursor-bin`, `spotify`, `dropbox`, `rustdesk`, `lmstudio`, `heroic-games-launcher-bin`, `minecraft-launcher`, `dotnet-*-bin`/`aspnet-*-bin`, `python-mediapipe`, `bambustudio-bin`, `umu-launcher`, `pinta`, `obs` adjacent items, all `linux-omarchy*` kernels (x86-only by nature — ARM uses `linux-asahi` from asahi-alarm), `nvidia-580xx-*`, `lib32-*`, `macbook12-spi-driver-dkms`, `vulkan-*` (those live in distro repos; `vulkan-asahi` comes from asahi-alarm, not omarchy repo).
- **`stable-mirror.omarchy.org` (Omarchy's own Arch core/extra/multilib mirror) is x86_64-only** — verified `…/core/os/aarch64/core.db` = 404 while x86_64 = 200. ARM installs must source base packages from **Arch Linux ARM** mirrors (`mirror.archlinuxarm.org/$arch/$repo`), which is what `omarchy-mac` does.
- Community precursor: `omarchy-mac/omarchy-pkgs-aarch64` (scottjones) serves `omacalc/omacut/omawrite` etc. as unsigned packages via GitHub Releases (`SigLevel = Optional TrustAll`, rolling `edge`/`rc` tags). Largely superseded now that official aarch64 exists, but still referenced by omarchy-mac's pacman.conf.

## 3. Omarchy core — what it is, and what's arch-bound

Upstream repo: `omacom/omarchy` (ex-`basecamp/omarchy`; default branch `quattro` = Omarchy 4 line). Project owner's fork: `Betim-Hodza/omarchy` (quattro, synced 2026-09-20; clone inspected locally).

**What Omarchy 4 ("Quattro") is:** Arch Linux + Hyprland + a Quickshell-based desktop shell (Waybar/Walker/Mako/SwayOSD/hyprlock/hypridle replaced by one IPC-scriptable shell), config in Lua, two Arch packages (`omarchy`, `omarchy-settings` — both `arch=any`) carrying system files under `/etc` + `default/` + `config/` + `bin/omarchy-*` commands + `migrations/`, plus `install/` scripts driven by the ISO. Install path: `omacom-io/omarchy-iso` builds the x86_64 live ISO (archiso; Omarchy Configurator TUI; pacstraps `install/omarchy-base.packages` ≈153 pkgs, plus `omarchy-other.packages` ≈77).

**Portable as-is (arch-agnostic):** essentially all of `config/`, `default/`, `themes/`, `shell/` (QML), `bin/` bash commands, `migrations/`, `manual/`. My grep of the fork found only ~4 files referencing `x86_64|aarch64|uname -m` — the distro layer barely knows about architecture.

**Arch-dependent seams a port must touch:**
- `install/omarchy-base.packages` / `omarchy-other.packages` — contains x86-only entries (`linux`, `linux-omarchy*`, `limine*`, `nvidia-*`, `intel-*`, `broadcom-wl-dkms`, `qemu-user-static-binfmt`, `thermald`, `lib32-*`, `macbook12-spi-driver-dkms`).
- `default/pacman/pacman-{edge,rc,stable}.conf` — `[core]/[extra]/[multilib]` from `*-mirror.omarchy.org/$repo/os/$arch` (no aarch64 upstream → swap to ALARM mirrors; **no multilib on ARM**); `[omarchy] pkgs.omarchy.org/{channel}/$arch` resolves fine now.
- `omacom-io/omarchy-iso` — x86-baked (profiledef arch, `linux-t2`, syslinux+GRUB, BCJ filter, Node x64 tarball, QEMU smoke test). Has `plans/aarch64-support.md` (drafted ~2026-08) for **generic UEFI aarch64** ISO — explicitly excludes Apple Silicon ("Apple Silicon (Asahi) and SBCs are out of scope"). See also `omacom-io/omarchy-iso` PR #121.
- `install/hardware/` quirks — upstream already has `apple/` subdir but it's **Intel-Mac (T1/T2) fixes only** (`fix-t2.sh`, `fix-spi-keyboard.sh`, `fix-suspend-nvme.sh`, `fix-brcmfmac-supplicant.sh`); plus `vulkan-asahi` auto-selection already in `bin/omarchy-upgrade-to-quattro` (lspci-detected Apple GPU → `vulkan-asahi`).
- `manual/44-mac-support.md` — documents Intel-Mac install; says M-series "not directly supported", points to Discord `#omarchy-on-other`.

### PR basecamp/omarchy#876 ("Add aarch64 support", nilszeilon, 2025-08-17)

- +143/−3 across 4 files: arch detection, ALARM mirrorlist handling, skipping x86-only bits, Asahi-Alarm dual-boot flow for M1/M2. DHH liked it ("shocked how little change"); asked for a scripted `install/preflight/asahi.sh` and a dedicated archlinuxarm mirror.
- **Why it stalled:** `pkgs.omarchy.org/aarch64` didn't exist (broke install *and* the `pacman -Syu` update path via `$arch` URL — jondkinney 2025-08-26); `geo.mirror.pkgbuild.com` has no aarch64 repos (dinvlad); 1Password-style x86-only apps needed per-arch config splits.
- **Closed unmerged 2025-10-27** "in favor of #1897". **#1897** (jondkinney, "aarch64 support for Omarchy 3.x", heavier rework incl. user creation) was itself **closed unmerged 2026-07-18** — DHH: "targets the pre-Quattro architecture and can no longer be applied to the current codebase." Lesson for this project: don't PR ARM support upstream piecemeal against quattro — the fork-and-package-repo model (omarchy-mac) is what the team actually converged on.

## 4. Prior-art forks and the Arch-on-Apple base

| Project | What it is | Install flow | Notes for M5 |
|---|---|---|---|
| `omacom/omarchy-mac` (née omarchy-mac, malik-na) | **The** maintained Omarchy-on-Apple-Silicon distro fork; 1.8k★; `quattro` default branch (main = stale v3.x) | `curl …/quattro/bin/omarchy-mac-setup \| bash` on a booted Asahi Alarm Minimal → creates user, LUKS FDE, btrfs+snapper (`@fresh`/`@factory`), builds `omarchy`/`omarchy-settings` from checkout, ~15 min, 3 reboots | `install.sh` has aarch64 preflight + `arm-mirrors.sh` (ALARM mirror setup), `helpers/arm-package-sources.sh` (explicit `omarchy/…` targets only), `omarchy-aarch64-unavailable.packages` (annotated exclusion list: obs-studio, dotnet-runtime, pinta, obsidian, qemu-user-static-binfmt), `install/hardware/apple/` M-series quirks (enable-notch, fix-wifi-resume, video-decode, audio.sh, electron-gl, fix-asahi-hid-race). pacman.conf ordering: `[omarchy]` edge (`Usage=Sync` restricted), `[omarchy-aarch64]` community repo, `[asahi-alarm]`, `[core]/[extra]/[alarm]/[aur]` → ALARM mirrors. |
| `omarchy-mac/omarchy-mac-iso` | Installer media repo (scottjones) — "the ISO" for Apple Silicon | Builds GPT `.img` (FAT32 ESP `OMARCHYISO` + btrfs `OMARCHYLIVE` payload); live USB via U-Boot `bootefi BOOTAA64.EFI`; **NVMe placer** (`scripts/macos/place-nvme-installer.sh`) avoids USB entirely | Requires Asahi **UEFI-only provision** first (iBoot won't boot USB otherwise). M3 Air (j613) needs `linux-asahi ≥7.2` (appledrm V14_7) + bundled j613 DCP DTBO overlay into m1n1 boot.bin. `M0` QEMU harness proves generic ARM64 UEFI build (won't boot a Mac). Very relevant patterns for M5 bring-up docs. |
| `maralcbr/omarchy-mx-mac` | Marcelo's signed-release installer | `install-omarchy-mx-mac.sh` verifies channel/descriptor/6-package manifest/signatures, installs Omarchy 4 directly (no v3 stopover), preserves `linux-asahi`/GRUB/ALARM+Asahi repos; companion macOS Installer.app (alpha) | Signature-verification model to crib. |
| `nilszeilon/armarchy` | Original aarch64 fork (51★), source of PR #876 | `boot.sh` w/ `OMARCHY_REPO`/`OMARCHY_REF` env overrides — the pattern every fork reuses | Last push 2025-09-17; superseded by omarchy-mac but historically important. |
| `jondkinney/armarchy` (`vm-testing`) | One-shot M1/M2 flow + VM paths | Asahi-Alarm minimal → `boot.sh` with `OMARCHY_REPO=jondkinney/armarchy OMARCHY_REF=vm-testing`; self-creates sudo user; also ArchBoot→Parallels/VMware guide for M3/M4 (which Asahi can't install) | Proof that "single command after minimal ALARM boot" works. |
| `asahi-alarm.org` (`github.com/asahi-alarm`) | Arch Linux ARM for Apple Silicon — the base distro | `curl https://asahi-alarm.org/installer-bootstrap.sh \| sh` from macOS Terminal; minimal/desktop(BTRFS option)/custom; calamares desktops incl. Hyprland | pacman repo served from GitHub Releases (`…/releases/download/$arch`), `asahi-alarm-keyring` (key `12CE6799…FB8FEB`); `PKGBUILDs` repo holds `linux-asahi`, `asahi-scripts` (m1n1 update hooks), `mesa-asahi`, firmware tooling; `asahi-alarm-installer` = AsahiLinux/asahi-installer fork; `asahi-alarm-builder` reference image builder. **Package gaps for Omarchy:** covered above — ALARM provides base system + asahi kernel/mesa; Omarchy repo now provides most omarchy-specific aarch64 pkgs; residual x86-only list = §2. |
| `ggalancs/omarchy-arm-utm` | One-script UTM VM (aarch64, HVF) building Omarchy 4 on ALARM | macOS-side script → VM | Useful as zero-risk dev environment on the M5 Pro under macOS. |
| `jmewing/penguin-patcher` | USB-boot enabler | Installs m1n1 Stage-1 stub that chainloads Linux from USB | Alternative boot-path data point. |

**Asahi upstream state (matters most):** Asahi's 2026-08-01 "Linux 7.2" progress report — M4/M5: NVMe fixed (macOS 15.x firmware change), PCIe enumeration works, multi-core boot crash fixed; **"not ready to enable them in the Asahi Installer"**. Device-support page lists M1–M3 families only. `AsahiLinux/m1n1` got initial **T6050/T6051 (M5 Pro/Max)** support 2026-06-29 ("M5 Pro boots on core 0, an M-Core; SMP secondaries then didn't start"). Aurora Silicon's tracker corroborates: `j813` = M5 MacBook Air (t8142) exists in their lab; M5 Pro/Max SoC IDs marked provisional.

## 5. "Try Omarchy" — the macOS app

`omacom/try-omarchy` (v0.4.1, 2026-09-15; 2.2k★; signed + notarized DMG). Packages a pinned aarch64 Arch Linux ARM + Omarchy Quattro image with a custom **QEMU 11.1.1 / Apple Hypervisor.framework** runtime and a Swift/AppKit launcher.

- In-hypervisor **GICv3** (`hw/intc/arm_gicv3_hvf.c`), VirGL graphics via `virglrenderer → ANGLE → Metal` (guest sees plain virtio-gpu — no Apple driver needed), audio routing, camera-as-webcam, two-way clipboard, one shared folder, loopback port forwarding, nested KVM on M3+/macOS 26+. Known limitation: CPU-only video decode.
- **As a dev vehicle for omarchy-m5:** excellent for iterating on Omarchy userspace (packages, configs, shell, migrations, keybindings) on the actual M5 Pro under macOS — no partitioning risk. It cannot validate m1n1/kernel/DCP/N1/GPU bring-up (all virtualized). Same caveat applies to `riverscn/omarchy-aarch64-image` (UTM/QEMU) and `ggalancs/omarchy-arm-utm`.

## 6. What an M5 Pro port needs to touch

| Component | Reuse from | Maturity | M5 Pro gaps |
|---|---|---|---|
| Boot chain (m1n1 → U-Boot/UEFI → GRUB) | AsahiLinux/m1n1, `aurora-silicon/u-boot`, asahi-alarm | M1/M2 solid; M5 bring-up started Jun-2026 | t6050 DTB provisional; M-Core boot only then; need current state of SMP/DCP pins for j773-class MBP |
| Kernel `linux-asahi` + modules | `asahi-alarm/PKGBUILDs`, `aurora-silicon/linux` (asahi-wip branches) | M4/M5: NVMe✓ PCIe-enum✓ multi-core✓ (Aug-2026) | Display (appledrm/DCP) on t6050, SPMI/PD changes, speakers/mic, suspend |
| GPU (AGX G17) | mesa `honeykrisp` (M1/M2 ✓), `DjDeveloperr/mesa` M3–M5 research, `bits/210-gpu` | Research-stage for M5 | No shipping M5 GPU driver; Hyprland needs working DRM/KMS+GLES |
| Wi-Fi/BT (Apple N1) | Miguel Cruz RE (announced working); prior art: Broadcom PCIe BT RE (ArcaneNibble) | Functional claim, no public repo found | Firmware extraction, driver publication status; N1 also breaks bridged-VM networking on macOS side (UTM #7658) — quirk to expect |
| Touch ID (SEP) | `aurora-silicon/linux@feat/sep` (DjDeveloperr), Aurora research docs; T2 sibling: `jmurth1234/t2-touchid-linux` | Protocol layers recovered; ~4.1k-line C reimpl; `-ENOSYS` on live capture as of write-up | Sensor transport pairing, PAM/fprintd wiring |
| Distro layer (omarchy fork) | `omacom/omarchy-mac` quattro | Production on M1/M2; M3 Air partial | Add t6050/j773 quirks; per-machine DTB/notch/audio handling |
| Package repos | `pkgs.omarchy.org` aarch64 (live), `asahi-alarm` repo, ALARM mirrors, `omarchy-mac/omarchy-pkgs-aarch64` | Edge rich (126), stable thin (18) | Residual x86-only packages; signing story on community repo |
| Installer | `omarchy-mac-iso` (USB/NVMe), `omarchy-mac-setup` (on top of ALARM minimal), `maralcbr` signed app, upstream `omarchy-iso` (x86 only) | M1/M2 proven | M5 needs m1n1 provision path first (Asahi installer doesn't offer M5); UEFI-only-provision → `.img` install is the realistic near-term route |
| Hyprland/Omarchy config | upstream `omacom/omarchy` | Portable | Per-arch package lists + `pacman.conf`, Apple hw quirks (already modeled by omarchy-mac), monitors/input Lua tweaks |
| Dev vehicle | `omacom/try-omarchy`, UTM images | Works today on M5 Pro under macOS | Userspace only |
| MLX/AI extras | `joshuaswarren/mlx-omarchy` | Vulkan path real; ANE planned | Depends on M5 GPU driver maturity |

## Confidence notes

- **Verified live today (2026-09-21):** aarch64 package repos (db contents enumerated), `omarchy-mac→omacom` org redirect, omarchy-mac/iso/pkgs repo contents & release tags, m1n1 T6050 commit, Asahi device list (no M4/M5), Aurora Silicon team/feature pages, DjDeveloperr's mesa/linux branches, riverscn/maralcbr/subedijaidip repos, try-omarchy v0.4.1.
- **Inferred / not directly verified:** N1 driver publication venue (announcement says functional; public repo not located — Aurora's own notes unwritten, Discord is the channel); Liam's public footprint (none found beyond Aurora roster); exact maturity of `omarchy-steam-fex`; whether upstream `omacom/omarchy` will absorb `omarchy-mac`'s `install/` changes (none present in quattro today).
- **Stale-doc warnings:** `omarchy-pkgs-aarch64` README's "aarch64 404" predates live publishing; `ggalancs/omarchy-arm-utm`'s similar claims same; upstream `manual/44-mac-support.md` "M-series not supported" refers to the official-supported-path sense only.
