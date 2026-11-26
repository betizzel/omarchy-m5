# J714s developer image package recipes

Recipes for the four packages the J714s developer installer image takes from
this repo (the rest of its 15-package set is unchanged, see
[`../README.md`](../README.md)). They started as the prepared recipes of
omacom/omarchy-mac-installer `Integration/M5/J714s-Normal-System/prepare`
(omacom/omarchy-pkgs `30a33ee435db`) and differ as follows.

| Package | Version | Change |
| --- | --- | --- |
| `linux-aurora` | `7.3.0.aurora16.j714s3-3` | The merged kernel: rolotrealanis98/linux `34f2f5bb4d03` plus this repo's `patches/linux-aurora` and `patches/linux-aurora-n1` 0001-0010 as one diff (`j714s-merged-source.patch`, harness tree `63cef437e`). Config `configs/aurora-j714s-n1.config` as built, plus `DM_CRYPT=m` and `DM_INTEGRITY=m` (sd-encrypt). Release `7.3.0-16.j714s3-3-j714s-merged-ARCH` (pkgrel 2 added 0009, the t6050 NVMe compatible U-Boot needs; pkgrel 3 adds 0010, GPU voltage bins from the ADT). Source is the GitHub tarball, so its sha256 is pinned. |
| `m1n1-aurora` | `1.6.1.aurora22.j714s5-1` | Adds `patches/m1n1-installer` 0002-0007 (3-cell AIC GPU mailboxes; DCP handoff phandles and firmware-compat; the chip's GPU voltage bins copied from the ADT; the internal display handed over by default and the full panel including the notch rows, `chosen.asahi,t6050-display=0` / `chosen.asahi,show-notch=0` to opt out) on the frozen loader. |
| `uboot-aurora` | `2026.07.aurora6.j714s3-1` | Same source and config, built natively with gcc. The `.j714s2` build (x86 cross) had arm64 header `image_size` 0x80000 for a 752 KB image, and m1n1 refused it (`Assertion failed: 'size <= kernel->image_size'`); this one is 708 KB with 0x11dcf8. |
| `omarchy-aurora-firmware` | `20261014.j714s2-1` | `aop`, `aop_als` and `mt7932-fullmac` are optional in the `aurora-vendor-order` initcpio hook. The J714s has an N1, not the Neo's MT7932, and mkinitcpio failed on the missing module. |

**Unit device tree.** Boot loaders pick `t6050-j714s.dtb`. `linux-aurora`
installs `t6050-j714s-gpu-adt-simpledrm.dtb` under that name, which fits any
J714s: the GPU voltage bins are fused per chip, and the kernel now takes them
from the ADT (m1n1-installer 0005 copies them into the gpu node; aurora-n1 0010
validates them against the M5 Pro profile and refuses to start the GPU without
them). The per-unit trees (`-tripleu`, betizzel's `-n1`) remain and can be
picked with `_j714s_unit_dtb=`.

Build natively on an aarch64 Arch Linux ARM host (clang 23, rustup) with
`PKGEXT=.pkg.tar.zst makepkg` (ALARM defaults to `.xz`, which the installer
refuses). m1n1's pinned commit is no longer on an omacom/m1n1 branch: fetch it
into the source mirror first
(`git --git-dir=m1n1 fetch origin 02785a35e046901d5686ab9059b2c08b6256752a`).

## Repo-only packages (release 11)

Not in the installer image; they reach installed Macs through the `[omarchy-m5]` pacman repo.

| Package | Version | Source |
| --- | --- | --- |
| `omarchy-brightness-auto` | `0.1.20261118-1` (any) | joshuaswarren's `omarchy-brightness-auto` (omacom/omarchy-mac-pkgs #144, commit `2d2ecbc1`, MIT), unchanged. Off by default: `omarchy brightness auto on`. Goes away once omarchy-mac ships it. |
| `wluma` | `5.0.4-1` (aarch64) | The AUR package unchanged (ISC), built in the alarm-builder image with `--nocheck`, recompressed to `.zst`. |
