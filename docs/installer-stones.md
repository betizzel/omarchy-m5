# Installer stones: the J714s kernel and loader from omarchy-mac-installer

TripleU613 is collecting the public M5 work into one J714s system image in
[TripleU613/omarchy-mac-installer](https://github.com/TripleU613/omarchy-mac-installer)
(see [linux-aurora#293](https://github.com/omacom/linux-aurora/issues/293)).
This page brings that image's kernel and loader into this repo as an extra,
isolated build flavor, so both trees live side by side and can be merged here.

Nothing in the default `vendor/linux`, `aurora` or `aurora-gpu` paths changes.

## Build

```sh
make kernel-aurora-installer   # KERNEL_FLAVOR=aurora-installer scripts/build-kernel-aurora.sh
make m1n1-installer            # build/m1n1-installer, chainloadable
```

| Piece | Base | Series | Reproduces |
| --- | --- | --- | --- |
| Kernel | `34f2f5bb4d03` (same base as `aurora-gpu`) | `patches/linux-aurora-installer/` | tree `291ffd1b50cc`; installer patch sha256 `616d8e7f21f6...` |
| Config | full `.config` | `configs/aurora-j714s-installer.config` | installer `kernel/config` |
| m1n1 | **omacom/m1n1** `02785a35e046` (not AsahiLinux) | `patches/m1n1-installer/` | tree `332d560c2f73`; installer patch sha256 `d634a7aba77b...` |

Both series apply byte-for-byte to their bases (checked). The installer's
package recipes pin the same patch hashes, and its ARM CI built
`linux-aurora 7.3.0.aurora15.j714s2` and `m1n1-aurora 1.6.1.aurora22.j714s2`
from them. Not booted through the normal U-Boot/Limine chain yet.

## What this flavor adds over this repo

- **N1 Wi-Fi / Bluetooth** (none of it exists in `patches/linux-aurora*`):
  Centauri kernel-owned PCIe train, `apple_centauri` Wi-Fi, `btcentauri`,
  bindings, `pcie@1cb0000000` + `wlan`/`bluetooth` DT nodes, and the m1n1 N1
  host-tunable admission/copy it depends on.
  Hardware result on J714s, 2026-11-08: association, DHCP, default route,
  device-bound DNS and HTTPS passed
  ([Omarchy-M5-Pro `198389e`](https://github.com/TripleU613/Omarchy-M5-Pro/commit/198389e167106031f6ea4b60f0ba90150d252a9b)).
  Workaround needed: NetworkManager rejects the passphrase/SAE form with
  `CONNECT = -95`; store the network's 64-hex WPA2 PMK instead (derived
  locally from passphrase + SSID, never on a command line). Reconnect after
  reboot and Bluetooth are unqualified.
- **T6050 USB2/USB3/DP PHY** (`drivers/phy/apple/atc-t6050-*`, `usb-t6050/`).
- **G17S GPU J714s board profile + fuse guard** (upstream form:
  [rolotrealanis98/linux#1](https://github.com/rolotrealanis98/linux/pull/1)).
- cpufreq, WFI idle, SMC hwmon/input/gpio, DART, PCIe, NVMe, AOP/macaudio
  match data and audio DT (audio is **disabled** in this config).

## What it lacks compared with this repo

- DCP internal display (`DRM_APPLE` off, DCP nodes disabled), firmware 27.x
  DCP tables, alpha scanout: use this repo's `patches/linux-aurora` 0008-0015.
- Battery / SMC power (`MACSMC_POWER`, `POWER_RESET_MACSMC` off): this
  repo's 0016 + verified Aurora battery telemetry.
- Framebuffer checkpoint markers, AIC VM-timer and pmdomain fixes in 0001-0004.

## Merge map (toward one series)

The two series describe J714s with **different DT layouts**: this repo's
`t6050.dtsi`/`t6050-jxxx.dtsi`/`t6050-pmgr.dtsi`/`t6050-dcp.dtsi`/... versus
the installer's `t6050-base.dtsi`/`die0`/`dieX`/`max`/`ultra` (Rolo's J716s
layout). Pick one layout, then:

**Cherry-pick as-is** (files only the installer series touches): Centauri
Wi-Fi/BT drivers and bindings, `net/bluetooth/*`, `drivers/phy/apple/*`,
`drivers/pci/*`, `include/linux/pci.h`, cpufreq, `arch/arm64/kernel/idle.c`,
SMC gpio/hwmon/input/mfd, DART, NVMe, dwc3, reset-cio, pinctrl, AOP/audio.

**3-way merge, then test on hardware** (both series change them):

```
arch/arm64/boot/dts/apple/Makefile
arch/arm64/boot/dts/apple/t6050-j714s.dts
drivers/gpu/drm/asahi/driver.rs
drivers/gpu/drm/asahi/g17/fw/m5/initdata.rs
drivers/gpu/drm/asahi/hw/t6050.rs
drivers/gpu/drm/sysfb/simpledrm.c
drivers/pmdomain/apple/pmgr-pwrstate.c
drivers/power/supply/macsmc-power.c
drivers/soc/apple/rtkit.c
drivers/soc/apple/sart.c
```

Port the `pcie@1cb0000000` N1 node with its `wlan`/`bluetooth` children into
whichever DT layout wins.

## Credits

| Who | Work this flavor builds on |
| --- | --- |
| [rolotrealanis98](https://github.com/rolotrealanis98) | T6050 kernel base `34f2f5bb`, J716s DT layout, Centauri N1 kernel train and m1n1 patch0028, G17S M5 initdata |
| [edimoldovan](https://github.com/edimoldovan) | J714c T6050 CPU bring-up, cpufreq and AFE/PCIe work the T6050 pieces were matched against |
| [betizzel](https://github.com/betizzel) | this repo: J714s 15-core SMP, DVFS, WFI idle, s2idle, DCP, battery, GPU/Zink |
| [TripleU613](https://github.com/TripleU613) | J714s DT for this layout, N1 host profile and Wi-Fi bring-up, GPU voltage profile/fuse guard, installer image |
| omacom / aurora-silicon | m1n1 and Aurora kernel upstreams |

Patches keep their upstream licenses (kernel GPL-2.0, m1n1 MIT); new files
carry their own SPDX headers.

Full source inventory:
[installer SOURCES.md](https://github.com/TripleU613/omarchy-mac-installer/blob/main/SOURCES.md).
