# What works on the J714s

Checked on one J714s (TripleU613's) on Apple's 27.2 firmware. On 2026-11-15 release 6 was
installed **from scratch** there: the installer shrank macOS, installed, Finish setup in Recovery
worked and the first boot came up on kernel v272-11. Release 8's kernel (v272-12) and then
release 9's four packages (kernel v272-17, firmware j714s14, hyprland-m5 0.57.2-4, m1n1-aurora
v272-4) were installed by package on that install and booted (2026-11-16). "Seen" and "heard" mean
its owner looked or listened; HDMI was seen again on v272-16, the speakers were heard on release 5's
kernel (v272-7) and USB-C DisplayPort was last seen there too.

| Thing | Now (release 11 and the 2026-11-27 updates) | Whose work |
| --- | --- | --- |
| Boots from the Mac's own disk, all 15 CPU cores at EL2 | **Works** | aurora-silicon, DjDeveloperr, rolotrealanis98, betizzel, RyanTheTide |
| Keyboard, backlight, trackpad | **Works** | rolotrealanis98, edimoldovan |
| Wi-Fi | **Works** | rolotrealanis98, betizzel, TripleU613, DjDeveloperr, edimoldovan |
| Bluetooth | **Partly**: on; RFCOMM loads (for hands-free and headset profiles); headset audio not tried | same, chrisohearn (report) |
| GPU acceleration | **Works**: since 2026-11-27 (Mesa/Vulkan e705eca833f): OpenGL 4.6 / ES 3.2 and Vulkan 1.4 on "Apple M5 Pro (G17S B1)", glmark2 3003 against llvmpipe's 89, `glmark2 --validate` no failures, vkcube runs, Hyprland renders on the GPU (zink). Releases 1 to 11 rendered in software (the j714s2 Mesa has no G17S support); earlier works here only saw Hyprland start | DjDeveloperr, jgoyvaerts, funkzy (Mesa Borealis/AGX M5, kernel G17), omacom (edge packages), aurora-silicon |
| Auto-brightness from the light sensor | **Works**: `omarchy brightness auto on`: at 2 lux the panel went from 450 to 93 of 1000; `off` gives manual control back (only the dark direction seen) | joshuaswarren (omacom/omarchy-mac-pkgs #144), wluma (maximbaz) |
| Screen: full panel, 3024x1964 at 120 Hz | **Works**: seen | FatBoy721, edimoldovan, rolotrealanis98, betizzel |
| Speakers, with speaker protection | **Works**: heard at the first-start 30% (release 5's kernel); on release 6's fresh install the switch-over to speakerguardd v2 ran too early at first boot and passed when run by hand (fixed in 7: it waits for the speaker card; not yet seen through a first boot); nobody has played loud yet | DjDeveloperr (speakerguardd v2), Jens Axboe (27.2 AOP fix) |
| Microphones | **Works**: since firmware j714s16-2 (2026-11-27): the J714 mic graph attaches to the new "J714 HPAI" card; speech -37 dBFS peak against -55 before (+17.5 dB). Still quieter than Isaac's -18 dBFS | Isaac-Duarte (asahi-audio #45), edimoldovan, kazuhidet |
| Headphone jack | untested on 27.2 | rolotrealanis98, edimoldovan |
| HDMI | **Works**: seen on a Samsung Odyssey G9: 5120x1440 at 60/120/144 Hz, 3840x2160 at 60 Hz (release 5's kernel); 5120x1440 at 60 Hz again on v272-16 (2026-11-16). After a sleep HDMI stayed dark until a reboot ([#22](https://github.com/betizzel/omarchy-m5/issues/22), reproduced here on v272-16); FatBoy721's fix (kernel 0021, [#26](https://github.com/betizzel/omarchy-m5/pull/26)) brought HDMI back after two wakes on his J714s and is in kernel v272-18, booted here, owner's G9 sleep test still to do | FatBoy721 |
| DisplayPort over USB-C, the left port that is not the DFU port | **Works**: seen: 5120x1440 at 144 Hz, 10-bit (release 5's kernel; not re-checked on 6 to 9 yet) | DjDeveloperr, erikwb, this repo |
| DisplayPort over USB-C, right port | **No**: the link does not come up (640x480 fallback only) | open |
| DisplayPort over USB-C, left DFU port | **No**: nothing shows in Linux; no charging or USB there either | open (Isaac-Duarte's aurora-silicon/linux #2017 describes the port) |
| Thunderbolt dock, three displays | untested (Isaac-Duarte's dock route #1921 and dark-display fix #1930 are upstream now) | Isaac-Duarte |
| DisplayPort audio | **Partly**: three DP audio cards on v272-17 (release 9); nothing played through them yet | DjDeveloperr (#2079) |
| Front camera | **Works**: 1920x1080 at 30 fps, a sharp picture (checked 2026-11-16, kernel v272-12); captures on v272-21 (2026-11-26). Since v272-19, upstream's tuning (aurora-silicon/linux #2233) and **the green camera light stays off** ([#33](https://github.com/betizzel/omarchy-m5/issues/33)); upstream shows an indicator on the display instead | edimoldovan, Jens Axboe, sithglan, Erik Bourget, DjDeveloperr, Isaac-Duarte |
| Neural Engine | **Partly**: device up; no workload run | DjDeveloperr, Joshua Warren, Nick, this repo |
| Hardware video encode | **No**: probe only on 27.2 | DjDeveloperr, this repo |
| Hardware video decode | **Works**: H.264 and HEVC through the AVD decoder, 60 of 60 test frames bit-identical to software (2026-11-16); by default since release 9 (firmware j714s14): VA-API lists 8 profiles with no environment variable | DjDeveloperr |
| Touch ID | **Works**: enrol and match on 27.2 (2026-11-16, kernel v272-15; the enrolled finger still listed on v272-21; owner opt-in, writes the Secure Enclave store macOS shares, read [the warning](../installer/recipes/aurora-sep-upstream/README.md)); match after a reboot not yet checked | DjDeveloperr, aurora-silicon |
| Variable refresh on the panel | off: offered up to firmware j714s14 (release 9), not offered from j714s15 on, because turning it on crashed the K114s OLED's display coprocessor on 27.2 ([#25](https://github.com/betizzel/omarchy-m5/issues/25)) and it was never proven on 27.2 here | rolotrealanis98 |
| Hyprland colour management on displays with degenerate EDID colour data | **Works**: the primaries are treated as missing, so the panel isn't blanked (hyprland-m5 0.57.2-4, release 9; [#21](https://github.com/betizzel/omarchy-m5/issues/21) was seen on a K114s OLED) | chrisohearn (#24) |
| Firewall (`ufw`) | **Works** | this repo, chrisohearn (report) |
| Sleep | **Partly**: lid sleep works (s2idle; release 8: 3 s and 3 min 37 s; v272-21: 23 s with a key wake; the panel, Wi-Fi, Bluetooth, sound and both working USB-C ports come back). Deep sleep: in kernel v272-23 (published 2026-11-27) and opt-in (`echo deep | sudo tee /sys/power/mem_sleep`): it sleeps and wakes on our 15-core J714s, but the power-management coprocessor doesn't come back, so the CPUs stay capped at about 1.3 GHz until a reboot ([#3419](https://github.com/aurora-silicon/linux/pull/3419)); firmware j714s16-4 keeps s2idle as the default. With an external display plugged in, closing the lid does not sleep (logind treats it as docked) | Isaac-Duarte (#2012, #2018), Jens Axboe and sithglan (#1647), DjDeveloperr (#1963) |
| Fans | **Works**: Linux can set fan targets (tested: target 3000 gave 2989 rpm) | Isaac-Duarte (#1944) |
| Sustained CPU load | **Works**: the clusters follow the fast-die limit; the die held 107–109 C with 15 busy cores | DjDeveloperr (#1950) |
| Updates (`omarchy update`) | **Works**: checked in CI ([`update-check`](../.github/workflows/update-check.yml)); our tested kernel, firmware, m1n1, Hyprland and GPU drivers come from the signed [`[omarchy-m5]`](../tools/update-source/README.md) repository | this repo |
| Wi-Fi power save | **Works**: on by default since firmware j714s16-3 (2026-11-27, `zz-j714s-wifi-powersave.conf`, after Omarchy's file that turns it off); `iw` reports it on, no ping loss; erikwb measured about -0.35 W with it on a J716c | erikwb (measurement) |
| Two Omarchy installs on one disk | **Works**: each mounts its own boot partitions ([why](duplicate-boot-ids.md)) | this repo |

**Works** · **Partly** · **No**

Also known: every boot pauses about 15 seconds at the logo, and a DisplayPort cable plugged in
at boot was once not detected until it was plugged in again.


[Back to the README](../README.md)
