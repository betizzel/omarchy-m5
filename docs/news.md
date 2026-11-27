# What's new

Newest first. The full work notes are in [work/](work/).

**The image: [omarchy-j714s 11](https://github.com/betizzel/omarchy-m5/releases/tag/omarchy-j714s-11)** (prerelease,
2026-11-27, not yet installed from scratch on hardware): kernel v272-23, Mesa/Vulkan e705eca833f (the desktop on the
GPU), hyprland-m5 0.57.2-5, firmware j714s16-4 (microphones, Wi-Fi power save, s2idle default), auto-brightness. Every
package was booted and tested on our J714s through `omarchy update`. Image run 46047199618, app run 46049804181 (the
first attempt hung on the macOS runner after the Recovery template built; the re-run passed). A second J714s owner was
asked to install it ([#12](https://github.com/betizzel/omarchy-m5/issues/12)).

**2026-11-27, also through `omarchy update`:** **real GPU acceleration.** Every earlier release drew the desktop on the
CPU (the pinned Mesa had no M5 Pro support); Mesa/Vulkan `e705eca833f` from the omacom edge channel runs OpenGL 4.6 and
Vulkan 1.4 on the M5 Pro's GPU (glmark2 3003 against 89 in software) and Hyprland renders on it. **Microphones** about
17 dB louder (Isaac-Duarte's asahi-audio #45), **Wi-Fi power save** on (erikwb's measurement), and **kernel v272-23**
with the M5 Pro deep sleep driver (opt-in for now; lid sleep stays s2idle) in firmware j714s16-4.

**Release 11 (2026-11-26), through `omarchy update` with [`[omarchy-m5]`](../tools/update-source/README.md) on:** kernel
v272-21 on aurora-silicon/linux main `7f00dc6bc52c` (98 merged upstream PRs since v272-20: M5 GPU submission and recovery
work, T6050 AOP ring per endpoint, N1 6 GHz networks, Thunderbolt NHI credits, deep-sleep wake fix and more; credits in
[docs/work/release-11.md](work/release-11.md)), plus auto-brightness from the light sensor (joshuaswarren's
`omarchy-brightness-auto` with `wluma`, off until `omarchy brightness auto on`). Booted on our J714s: Wi-Fi, Bluetooth,
120 Hz panel, camera, sound cards, Touch ID and s2idle pass.

**The image: [omarchy-j714s 10](https://github.com/betizzel/omarchy-m5/releases/tag/omarchy-j714s-10)** (prerelease, 2026-11-24): kernel
v272-19 on a newer aurora-silicon/linux (M5 Pro sleep work, DisplayPort and Wi-Fi fixes; 11 own patches, was 26),
firmware j714s16 (`omarchy update` works again, #34; VRR off by default, #25), Wi-Fi on WPA/WPA2 mixed routers (#30)
and a new developer signer. The camera's green light stays off on v272-19 (#33).

**Release 10's installer ran on hardware (2026-11-25):** a from-scratch install on our J714s (macOS shrunk to 160 GB, 769 GB for
Omarchy) booted, including release 10's new Stage 1. If you keep a fallback kernel, set `LIMIT_USAGE_PERCENT=50` in
`/etc/limine-snapper-sync.conf` first: otherwise the 500 MB ESP fills up and the next kernel update can't write its boot image
([details](work/release-10.md#release-10-installed-on-hardware-2026-11-25)).

[Back to the README](../README.md)
