# Release 11 (work notes)

Started 2026-11-26. Goal: one update through the `[omarchy-m5]` pacman repo that carries everybody's work that has
been tested, nothing that hasn't. Builds live on ush (`~/m5/work/k21`, `~/m5/work/wluma`).

## Contents

| Piece | From | State |
| --- | --- | --- |
| Kernel linux-aurora v272-21 | aurora-silicon/linux main `7f00dc6bc52c` (98 merged PRs since v272-20's `7a4afed5b4d1`) plus our 11 patches | built on ush 2026-11-26 (sha256 `2026eef5…`, draft release `build-linux-v272-21`); boot test on the J714s pending (needs the owner at the disk passphrase) |
| `omarchy-brightness-auto` | joshuaswarren (omacom/omarchy-mac-pkgs #144, open), MIT | packaged unchanged from his commit `2d2ecbc1`; off by default. **Tested on our J714s and published in `[omarchy-m5]` 2026-11-26** |
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
