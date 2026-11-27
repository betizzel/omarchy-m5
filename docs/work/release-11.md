# Release 11 (work notes)

Started 2026-11-26. Goal: one update through the `[omarchy-m5]` pacman repo that carries everybody's work that has
been tested, nothing that hasn't. Builds live on ush (`~/m5/work/k21`, `~/m5/work/wluma`).

## Contents

| Piece | From | State |
| --- | --- | --- |
| Kernel linux-aurora v272-21 | aurora-silicon/linux main `7f00dc6bc52c` (98 merged PRs since v272-20's `7a4afed5b4d1`) plus our 11 patches | built on ush 2026-11-26 (sha256 `2026eef5…`); **booted, tested and published in `[omarchy-m5]` 2026-11-26** |
| `omarchy-brightness-auto` | joshuaswarren (omacom/omarchy-mac-pkgs #144, open), MIT | packaged unchanged from his commit `2d2ecbc1`; off by default. **Tested on our J714s and published in `[omarchy-m5]` 2026-11-26** |
| Mesa / Vulkan `e705eca833f` (2026-11-22) | omacom edge channel (omacom/omarchy-pkgs 9e1c6ef1; the Asahi/Borealis M5 work of DjDeveloperr, jgoyvaerts, funkzy and others) | **tested on our J714s 2026-11-26, installed; in the release 11 image** |
| `wluma` 5.0.4 for aarch64 | AUR package (torculus), upstream maximbaz/wluma, ISC | built on ush in alarm-builder (`--nocheck`); **published 2026-11-26** |

### Kernel: what the re-pin brings (merged upstream after v272-20)

For the M5 Pro: G17 (M5 GPU) direct render submission, multi-queue and lock work, deferred idle housekeeping, sibling
compute fan-out, render-pair memory instead of a lost device after 26 s (funkzy #2501), frontier, resource and
producer-wait fixes (jgoyvaerts #2732, #3016, #3119), uncached firmware state and timestamp fixes (aurora-silicon);
T6050 AOP ring buffer per endpoint (#2906); macsmc gP GPIO bank (ja-818 #2939); N1 6 GHz networks behind another
beacon (funkzy #2884); JPEG 4:2:2/4:4:4/greyscale encode on T6050 (m0d16l14n1 #3165); Thunderbolt NHI DMA credits
(satchlj #3018); AOP, light and lid angle shared with every M5 (#2329); spin-table holding-pen fix for deep-sleep
wakes (m0d16l14n1 #2192). Also K114s NVRAM and jack (chrisohearn #3103, #3104).

Our patches: all 11 apply. 0010 (J716 jack) conflicted with upstream's K114 entry in the same table; the two
configs were identical, so the J716 compatible now points at `macaudio_k114_cfg` (resolved on ush, rerere recorded).

### Looked at and not taken (survey 2026-11-26)

- chrisohearn/omarchy-m5p-oled: K114s; its decode, light sensor, ESP-space and update-guard ideas are already here; lid-on-battery logic not installed anywhere yet.
- rolotrealanis98/m5pro-linux silent/fast boot: still in his `pending` folder; invite him to PR the loader flags.
- DjDeveloperr aurora-silicon/asahi-audio #30 (J714s mic level, jack switching): draft, "On the J714s itself: pending".
- XY55bqg6iAw8ttP J714c admission branch: one machine, not PR'd.
- IronsideXXVI omacom/omarchy-mac-pkgs #142/#143: measured on a J604 only.
- MLX/ANE (joshuaswarren), omarchy-apple-dev, BlueFerry (erikwb): link only, nothing to package for the J714s.

## Tests on the J714s (after the owner's presentation; the Mac has a demo hold in pacman.conf until then)

1. v272-21 boots (passphrase), `uname -r` is v272-21, no failed units; v272-20 stays the Limine fallback.
2. Wi-Fi, Bluetooth, internal display at 120 Hz, GPU (`glxinfo -B`), camera, sound cards, Touch ID.
3. s2idle with a key wake.
4. `omarchy brightness auto on`: the panel follows the light sensor (cover it, then a lamp); `off` restores manual.

Release when 1-4 pass: sign both packages into `repo-aarch64`, then README, docs/maintenance.md, docs/upstream.md.

## Results

- 2026-11-26, test 4 on v272-20: both packages installed with `pacman -U`; `omarchy brightness auto on` wrote the
  sensor-only config (eDP-1, `capturer = "none"`, idle off), started `wluma.service`, and at 2 lux the panel went
  from 450 to 93 of 1000 (the seeded curve). `off` stopped the unit; brightness set back by hand; no failed units.
  Only the dark direction was seen (the room stayed at 2 lux). Signed into `repo-aarch64`; the Mac lists both from
  the published database.
- 2026-11-26, v272-21 checks without a boot: the package has the same 1754 modules as v272-20 and one
  `t6050-j714s.dtb`; that tree still has the HDMI and macaudio nodes, and against v272-20 it only gains three
  `apple,bw-scratch` properties on dcpext1-3 (upstream's shared dcpext properties). Staged on the Mac as
  `/root/linux-aurora-7.3.0.aurora17.v272-21-aarch64.pkg.tar.zst` (sha256 matches), not installed.

- 2026-11-26, tests 1-3 on v272-21 (owner at the passphrase): v272-20's UKI copied to `omarchy_v272-20-proven.efi` as the
  Limine fallback (v272-19's moved to `/boot/esp-overflow`), `pacman -U` of the staged package, reboot. `uname -r`
  7.3.0-17.v272-21-ARCH, no failed units; Wi-Fi joined, Bluetooth powered, eDP-1 3024x1964 at 120 Hz, Hyprland on
  OpenGL ES 3.2 Mesa (the `bootstrap failed at session: EPROBE_DEFER` lines are the same on v272-20; **correction,
  later the same day: that Mesa, j714s2 043a4c5, was rendering in software, see below**), camera (apple-isp) captured 5 frames, the three audio cards and the DisplayPort audio, Touch ID lists the
  enrolled finger. s2idle: entry 10:34:23, key wake 10:34:46, Wi-Fi, Bluetooth and the panel back. Signed into
  `repo-aarch64` (v272-20 package retired from the database; its release asset stays). The Mac sees
  `7.3.0.aurora17.v272-21` in the published database. Demo hold removed.

- 2026-11-26 evening, Mesa: `eglinfo` showed `llvmpipe` on every platform and `vulkaninfo` found no GPU. With
  `EGL_LOG_LEVEL=debug` the j714s2 build (043a4c5, 2026-11-09, pinned since release 2) says "Apple G17S uses the
  HAL300 command stream, which this driver does not implement", so the desktop and every app drew on the CPU on
  every release so far (earlier "GPU desktop" results only saw Hyprland start). omacom's edge Mesa e705eca833f,
  run from a scratch directory first: OpenGL 4.6 / ES 3.2 on "Apple M5 Pro (G17S B1)"; glmark2-es2-wayland
  (800x600, build/texture/phong/refract/terrain) 3003 against llvmpipe's 89; `--validate` 27 Success, 6 Unknown,
  0 failures; no kernel GPU errors. Installed with `pacman -U` (the j714s2 files kept in `/root/rollback-mesa`);
  Vulkan 1.4.363 on the GPU (Borealis), vkcube 600 frames. Hyprland moves to the GPU at the next login.
- Bar GPU widgets (Argus, hw-monitor) read amdgpu, NVIDIA or Intel counters only. The aurora driver lists
  per-client `drm-engine-*` in fdinfo, but the times stay 0 ns while vkcube runs, so there is nothing to show yet.
- Idle CPU: with nothing playing, PipeWire holds about half a core (speakerguardd-v2's protection stage runs on
  the dummy driver by design, DESIGN.md) and speakersafetyd about 11%. Speaker safety is left as it is.

## Release 11 image (2026-11-26)

- `installer/patches-j714s-r2` 0015: kernel v272-21 (from d3b70d2) and Mesa/Vulkan e705eca833f as omacom edge
  channel packages (the epoch's colon written as a dot in the set's file names); set `j714s-dev-runtime-52a694e7fa94`;
  qualification pins `7.3.0-17.v272-21-ARCH`; TREE `7001f8d0`.
- Inputs: [`installer-build-inputs-j714s-1602c9eab948`](https://github.com/betizzel/omarchy-m5/releases/tag/installer-build-inputs-j714s-1602c9eab948),
  20 packages signed by 547AF6CC...BC5DF9F6; the other 17 are release 10's.
- Image: `installer-image.yml` run 45936405605 (image-version 11).
- Not in the image: `omarchy-brightness-auto` and `wluma` (no role in the profile); they come from `[omarchy-m5]`.

## v272-22: deep sleep (built 2026-11-27, not booted)

`CONFIG_APPLE_SOC_SLEEP` was off in our config since v272-12, so `/sys/power/mem_sleep` offered `[s2idle]` only.
Upstream builds it in (`asahi.config`, `aurora_defconfig`), and the driver treats T6050 as a tested SoC
(`sleep-t6050.h`: `early_context`, not `untested`, so no `apple_sleep.deep` or `untested_commit` is needed). The
J714s tree carries its sleep nodes (`t6050-j714s-sleep*.dtsi`, `apple,display-method-sleep`), and our Aura already
passes `/chosen/aurora,s2r-mailbox`. v272-22 = v272-21 with `CONFIG_APPLE_SOC_SLEEP=y` (d35a0bb): 1754 modules,
`7.3.0-17.v272-22-ARCH`, sha256 `b6e16533…`, draft release `build-linux-v272-22`, staged on the Mac as
`/root/linux-aurora-7.3.0.aurora17.v272-22-aarch64.pkg.tar.zst`. Test with the owner: `mem_sleep` shows `deep`,
lid sleep for some minutes, key wake, Wi-Fi/Bluetooth/panel/sound back, battery drop during the sleep; v272-21 as
the Limine fallback (copy its UKI to `omarchy_v272-21-proven.efi`, v272-20's moves to `/boot/esp-overflow`).

Wi-Fi power save: Omarchy's `omarchy-wifi-powersave.conf` sets `wifi.powersave = 2` (off); erikwb measured about
-0.35 W with it on (weirdware.io/aurora/j716c-energy.html). On our J714s `zz-j714s-wifi-powersave.conf` sets 3;
`iw` reports power save on, ping 0% loss.

## Watching (not in release 11)

- aurora-silicon/aura main `d833bf40` (2026-11-26) has T6050 changes since our m1n1 pin: funkzy's AOP handoff (#474)
  and boot framebuffer / `bw-scratch` offset checks (#492); the single-die MCC handoff (#493) was reverted. Boot
  loader changes, not run on a J714s here: candidates for the next m1n1-aurora, tested on their own boot.
- Open upstream for the J714s: aurora-silicon/linux #2007 (PMIC RTC alarm), #2277 (jack codec on every T6050 board),
  aura #506 (PMP values on aliasless nodes).
- aurora-silicon/asahi-audio #45 (Isaac-Duarte, J714 microphones on the t8152-aop-audio card) merged 2026-11-27 as
  `b2ad98a3`; one WirePlumber file. To test on our J714s as a user override before it reaches a package.
- aurora-silicon/linux #1699 (joshuaswarren, FatBoy721's patch): keeps the T6050 USB DARTs live across system sleep,
  because force-suspending them reset a J714s under `pm_test=devices`. Draft, compile-only. Relevant to the v272-22
  deep sleep test: a reset at lid close points here (v272-21 stays the fallback).
- #12: andyholst offered a second J714s for testing (asked to install release 10 and file a test report).
