# J714s installer integration (from TripleU613/omarchy-mac-installer)

TripleU613's fork of the Omarchy Mac installer existed only to carry the J714s
normal-system image work. It now lives here; the fork is deleted.

## `patches/`: the installer work

Six commits on top of
[omacom/omarchy-mac-installer `c07e54c2134a`](https://github.com/omacom/omarchy-mac-installer/commit/c07e54c2134a8ec1415e7e2b917589ae1d3d7dc9).
0001-0006 reproduce the fork's final `main` tree exactly (`b3da2a18094e`); with 0007-0010 the tree is `8d8403e67730`.

```sh
git clone https://github.com/omacom/omarchy-mac-installer && cd omarchy-mac-installer
git checkout -b j714s c07e54c2134a8ec1415e7e2b917589ae1d3d7dc9
git am /path/to/omarchy-m5/installer/patches/*.patch
```

| # | What |
| --- | --- |
| 0001 | `Integration/M5/J714s-Normal-System/`: kernel/m1n1 freezes, 15-package candidate manifest, recipes, provenance; `SOURCES.md` contributor inventory |
| 0002 | `j714s-developer` image profile and the manual ARM CI image workflow |
| 0003 | developer image uses the verified `arm-mirror.omarchy.org` ALARM mirror |
| 0004 | select the image profile after the builder installs Python |
| 0005 | native J714s kernel headers build check (not run yet) |
| 0006 | resolve Omarchy desktop packages against matching pinned versions |
| 0007 | merged kernel, loader 0002-0004 and firmware-hook packages from [`recipes/`](recipes); new developer signer `0DA040FF…B6D116B1`; the merged kernel's verified boot arguments |
| 0008 | kernel pkgrel 2 (aurora-n1 0009: the t6050 NVMe compatible U-Boot needs) and the gcc-built `uboot-aurora` (the cross build's arm64 `image_size` was refused by m1n1) |
| 0009 | one image for every J714s: kernel pkgrel 3 (aurora-n1 0010, default DTB `t6050-j714s-gpu-adt-simpledrm.dtb`: GPU voltage bins from the ADT) and m1n1-aurora `j714s4` (m1n1-installer 0005 passes them) |
| 0010 | speakers, microphones, headphone jack and an always-on trackpad: kernel pkgrel 4 (aurora-n1 0011-0012, AOP audio drivers) and `omarchy-aurora-firmware` `j714s3` (edimoldovan's J714 speaker-safety profile and graphs) |
| 0011 | lid sleep, quiet idle clocks, N1 6 GHz: kernel pkgrel 5 (aurora-n1 0013-0016 from FatBoy721 and rolotrealanis98, `UCLAMP_TASK`) and `omarchy-aurora-firmware` `j714s4` (edimoldovan's realtime uclamp sysctl and N1 iwd default) |
| 0012 | the internal display through the DCP by default at full panel height, GPU-rendered desktop: `m1n1-aurora` j714s5 (m1n1 0006-0007), kernel pkgrel 6 (DCP device tree), `omarchy-aurora-firmware` j714s5 (two-card Hyprland session) and the new `hyprland-m5` support package (the builder installs it in the hyprland role); `finish-inputs` counts the profile's roles instead of a fixed 15 |
| 0013 | speakers and jack in PipeWire: `omarchy-aurora-firmware` j714s6 (edimoldovan's J714 UCM profiles, kazuhidet's busy-card discovery) |
| 0014 | hardware video decode: kernel pkgrel 7 (aurora-n1 0017, DjDeveloperr's J714s decoder DT) and `omarchy-aurora-firmware` j714s7 (avd-fw v5-t2 built from source) |
| 0015 | FatBoy721's precheck log fix (keep pacman's reason when the package precheck fails; his PR #4 0008) |
| 0016 | lid angle and ambient light sensors: kernel pkgrel 8 (aurora-n1 0018, DjDeveloperr's AOP sensors) |
| 0017 | USB 2.0 host on USB-C ports 0 and 2: kernel pkgrel 9 (aurora-n1 0019-0023, edimoldovan's T6050 USB 2.0 host PHY) |
| 0018 | USB host on all three USB-C ports: kernel pkgrel 10 (aurora-n1 0024-0032, the rest of edimoldovan's USB series) |
| 0019 | updates keep the J714s packages: the image pin covers every package the set takes from this repo (kernel, m1n1, U-Boot, Mesa, Hyprland, firmware), found by the `update-check` workflow (edge's m1n1-aurora aurora23 would have replaced ours) |

The kernel and m1n1 in 0001 are the same sources as
[`patches/linux-aurora-installer`](../patches/linux-aurora-installer) and
[`patches/m1n1-installer`](../patches/m1n1-installer).

## Status when moved (2026-11-09)

The last CI image run (on 0004) got past the Python fix and failed with "the
package set does not resolve against the pinned databases"; 0006 targets that
and has not been built. No normal-chain (U-Boot/Limine) J714s boot yet. Native
kernel headers/DKMS are an open gap.

## `omarchy-pkgs/`: package recipe build records

The two build-record tags from TripleU613's omarchy-pkgs fork, each 3 commits
on omacom/omarchy-pkgs `master` `30a33ee435db`: the native ARM Mesa candidate
build and the exact runtime-pair (kernel + loader) candidate recipes.

## Build inputs release

The CI-built J714s packages (linux-aurora 7.3.0.aurora15.j714s2, m1n1-aurora,
uboot-aurora, mesa/vulkan-aurora, firmware) plus the pinned omacom packages are
in this repo's release
[`installer-build-inputs-j714s-76004483a972`](https://github.com/betizzel/omarchy-m5/releases/tag/installer-build-inputs-j714s-76004483a972)
(bundle sha256 `76004483a9722fb5...`, with its provenance JSON). Build inputs
only, not an installer release.

## Image build (2026-11-10)

`.github/workflows/installer-image.yml` (manual dispatch) rebuilds the tree
above and builds the image from the bundle in release
[`installer-build-inputs-j714s-1d32202bb6f2`](https://github.com/betizzel/omarchy-m5/releases/tag/installer-build-inputs-j714s-1d32202bb6f2).
The old bundle (`76004483a972`, freeze kernel) got through package resolution
with 0006 and failed in mkinitcpio (`dm_integrity`, `mt7932-fullmac` missing);
0007 and the recipes fix both. Its signing key did not survive the fork, so
0007 replaces it; the new key's private half is kept off the repo.

**Result:** run [42883681094](https://github.com/betizzel/omarchy-m5/actions/runs/42883681094)
built `omarchy-2026.11.10-aarch64-apple-silicon-mac-edge-os-package.zip`
(3.6 GB; root.img 12.9 GB) and its `installer_data.json` for device class
`j714sap`; the image inspection and payload contract checks passed. It is a
CI artifact (kept 7 days), not a release, and has **not been installed on
hardware yet**. Next: install it on a J714s (normal m1n1 → U-Boot → Limine →
EFI Linux chain), then first boot, Wi-Fi, encryption prompt input.

**Boot-chain findings (m1n1 HV, before any disk write):** the first image's
`boot.bin` stopped in m1n1 (`Assertion failed: 'size <= kernel->image_size'`,
the U-Boot payload) and, with that fixed, U-Boot found no NVMe (merged tree's
`apple,t8140-nvme-ans2` only). 0008 fixes both; with them U-Boot reads the
J714s GPT under the HV.

## omarchy-j714s: one image line on the 27.2 stub (2026-11-13)

The J714s moves off the 27.3 beta stub and the raw Stage 1 to the way
aurora-silicon boots M5 on 27.2: the stub comes from Apple's non-beta
`UniversalMac_27.2_26B123_Restore.ipsw` (J714s iBoot `mBoot-20457.41.3`), and
Stage 1 is Aura's Mach-O boot object without `__TEXT_BOOT_EXEC` (kcbz 0, so
SPTM is off), padded for the 128 MiB execute window and enrolled with
`kmutil configure-boot --compress`. Product name `omarchy-j714s`, plain
version numbers, no channel suffix.

Patch set [`patches-j714s/`](patches-j714s) goes on top of `patches/` and
`patches-upstream-27.3/` (tree in its `TREE`):

| # | What | Credit |
| --- | --- | --- |
| 0001 | Engine: 26B123 IPSW row (RestoreLongVersion `26.2.123.0.0,0` from the IPSW), T6050/j714sap minimum 27.2, new `aurora_stage1` kind `board-macho-ctxr-v1`, `omarchy_macho.py` (fill the raw Stage 1 config, carry it into the boot object), Recovery staging in Mach-O mode. Engine `v0.9.2-omarchy.20261113.b25a51d6df57`, two identical repacks of the authenticated engine.28 base | Mach-O layout/fill ported from aurora-silicon/aurora-installer `AuraStage1.swift` (MIT) |
| 0002 | Recovery app: Mach-O mode; pads the object for the window, checks `kmutil inspect` (kcbz 0, kcrz), `bputil -nc`, `kmutil --compress` (60 min allowed) | `MachOBootObject`, `ExpandedMachOBootObject`, padding, inspection and its check ported from aurora-installer (MIT) |
| 0003 | The app's Recovery handoff verifies a Mach-O install's payloads | ours |
| 0004 | Image profile `j714s`: `esp/aurora/stage1-j714s.{bin,macho}`, `esp/m1n1/boot-ctxr.bin` (kept current by a pacman hook), payload `omarchy-j714s-<N>-aarch64-apple-silicon-mac-os-package.zip` | ours |
| 0005 | Candidate manifest pins for `linux-aurora 7.3.0.aurora17.v272-1` and `m1n1-aurora 1.6.1.aurora24.v272-1` (recipes `recipes/linux-aurora-j714s`, `recipes/m1n1-aurora-j714s`); sha256/size still zero until the packages are built | ours |
| 0006 | Developer builds admit `apple,j714s` from a developer-only sealed catalog | ours |
| 0007 | The built packages in the manifest: `linux-aurora` `7ed98691…` and `m1n1-aurora` `1f30e3ff…` (source 0b813e9), the 27.2 rebuilds of `aurora-sep` `6fa7ec89…` and `libfprint-aurora` `6f4c2ca4…` (88be5ff); set `j714s-dev-runtime-60db92441590`. Recovery provenance: the app run 43379125218 built from this set's `Recovery/` (tree `21baedbc`, commit `8029657`, which `rebuild-installer-tree.sh` reproduces), artifact 14015278818 (zip `36cf0a27…`), inventory `725aab0c…` | ours |

Builds:
- Image: `installer-image.yml` with `patch-set: upstream-27.3 j714s`, `image-profile: j714s`, the bundle's Recovery tree/inventory, and a bundle made by `finish-inputs.py` with the engine above.
- App: `installer-app.yml` (macOS runner) builds an ad hoc developer app with a sealed catalog signed by a per-run key, as an offline package (engine and image inside, split into `.partN`) and an online one (downloads the image parts from the image release).

Built (2026-11-13):
- Inputs: release `installer-build-inputs-j714s-d96c04cf8da5` (finish-inputs on the tree `rebuild-installer-tree.sh` makes, HEAD 5982b6f).
- Image: run 43392759505 (headSha 1dd43b4) → release `j714s-developer-image-omarchy-j714s-1`, `omarchy-j714s-1-aarch64-apple-silicon-mac-os-package.zip` sha256 `a0a0ebad…26c5`. Inspection and provenance checks passed.
- update-check: run 43395221712. `pacman -Syu` changed 0 packages and kept every J714s package.
- App: `installer-app.yml` → prerelease `omarchy-j714s-1`.

Left out of the set: `linux-aurora-headers` (no headers role in the j714s profile; `mac-image-check` drops it for this profile) and speakerguardd v2 / `aurora-speaker-upgrade`. They aren't in the profile's 18 package roles, and v2 ships enabled units and gate drop-ins on the existing speaker services, untried on a J714s. Adding them is a separate decision.

Checked: engine overlay tests (426), engine tooling tests, `test/all`, image-builder tests, the Recovery fixtures and build on macOS-26 (throwaway run 43369240212). The engine's config fill is byte-identical to aura's `fill_stage1_config.py` on the real 27.2 Aura build, `aura-boot.macho` passes the layout check (`aura.macho` does not), and aura pads the carried object to kcrz 153141248, the value this Mac's 2026-11-07 Mach-O trial enrolled. Not booted on any J714s.

## omarchy-j714s 2 (built 2026-11-13)

Patch set [`patches-j714s-r2/`](patches-j714s-r2) goes on top of `patches/`,
`patches-upstream-27.3/` and `patches-j714s/` 0001-0010 (tree in its `TREE`). With `patches-j714s`
0008 (15000 ms Stage 1 proxy window, a `compress` switch that stays on), 0009 (the Finish setup
instructions) and 0010 (engine `v0.9.2-omarchy.20261113.774d9abc59d3`: the J714s camera setfiles
and light-sensor calibration).

| # | What |
| --- | --- |
| 0001 | Two new support roles, `speakerguardd-v2` and `aurora-speaker-upgrade` (20 roles); `omarchy-aurora-firmware 20261014.j714s8` (one speaker path, the v2 UCM condition, the speaker auto-switch, VRR range on, first-boot camera setfile); kernel and Aura v272-2 (later replaced by 0003) |
| 0002 | The Recovery app built from this set: `installer-recovery.yml` run 43477703681, artifact 14062718355 (zip `15143a71…`), inventory `7347ba8a…`, Recovery tree `2f10aee7`, commit `f3375020` |
| 0003 | `linux-aurora 7.3.0.aurora17.v272-3` (the 27.2 ANE pin, FatBoy721's J714s HDMI) and `m1n1-aurora 1.6.1.aurora24.v272-3` (Aura 22b71758 with #213, FatBoy721's fixed DP PHY tunables), from ce20db7; set `j714s-dev-runtime-39ff82133d63`; qualification pins `7.3.0-17.v272-3-ARCH` |
| 0004 | release 3: `linux-aurora 7.3.0.aurora17.v272-4` (kernel 0019, Jens Axboe's #1645: the 27.2 AOP) and `omarchy-aurora-firmware 20261014.j714s9` (loads `aop` at boot on the J714s), from ac63a3d; set `j714s-dev-runtime-7cd4572ff7ef`; qualification pins `7.3.0-17.v272-4-ARCH`; TREE `437d6908` |

Built (2026-11-13):
- Engine: release `engine-v0.9.2-omarchy.20261113.774d9abc59d3`.
- Inputs: release `installer-build-inputs-j714s-96a3ddc4c077` (finish-inputs on the tree `rebuild-installer-tree.sh DEST upstream-27.3 j714s j714s-r2` makes, HEAD 4911902). `717e8649f3af` (v272-2) is superseded; it fed only check run 43479464407.
- Image: `installer-image.yml` run 43490619162 (headSha 3ae33a1, `image-version` 2) → release `j714s-developer-image-omarchy-j714s-2`, `omarchy-j714s-2-aarch64-apple-silicon-mac-os-package.zip` sha256 `e0141d54442be9422f7fd5ea157b0ccf84db3623ce92f931e5f5f46b8cf20aa6`. Inspection and provenance checks passed; `m1n1/boot-ctxr.bin` is m1n1-aurora v272-3's Stage 2 (`1.0.0b13-g22b71758`).
- update-check: run 43503843852.
- App: `installer-app.yml` run 43503847960 → prerelease `omarchy-j714s-2`.

Release 2's packages boot on TripleU613's J714s (installed over release 1 with pacman). Known
issues on 27.2: no built-in sound card (the AOP doesn't come up; aurora-silicon/linux #1645 is the
likely fix) and `ufw.service` fails. See
[`patches/j714s-27.2/RELEASE-2.md`](../patches/j714s-27.2/RELEASE-2.md).

## omarchy-j714s 3 (built 2026-11-13)

Release 2 plus `patches-j714s-r2` 0004 (above): kernel v272-4 and firmware j714s9. Same engine
(`v0.9.2-omarchy.20261113.774d9abc59d3`) and Recovery app (run 43477703681) as release 2.

- Inputs: release `installer-build-inputs-j714s-6d03ea37204e` (finish-inputs on the tree `rebuild-installer-tree.sh DEST upstream-27.3 j714s j714s-r2` makes, HEAD 1e32b6f).
- Image: `installer-image.yml` run 43508507939 (headSha cfbe533, `image-version` 3) → release `j714s-developer-image-omarchy-j714s-3`, `omarchy-j714s-3-aarch64-apple-silicon-mac-os-package.zip` sha256 `1156ef803f0131cb8c071aec461510bdd2b2095f6a1a97250d41a8b8e78ede0a`. Inspection and provenance checks passed; `m1n1/boot-ctxr.bin` is m1n1-aurora v272-3's Stage 2 (`1.0.0b13-g22b71758`).
- update-check: run 43511484883.
- App: `installer-app.yml` run 43511488985 → prerelease `omarchy-j714s-3`.

The kernel change was tested on TripleU613's J714s as a hand-built `aop.ko` on v272-3 (sound
cards, mics, AOP sensors; speakerguardd v2 passed its checks and owns the speakers, not yet
confirmed by ear). The at-boot `aop` load (firmware j714s9) has not run on the Mac yet.
