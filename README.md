<p align="center">
  <img src="assets/header.svg" alt="omarchy-m5: Omarchy on the 14-inch MacBook Pro with M5 Pro" width="100%">
</p>

<p align="center">
<a href="https://github.com/betizzel/omarchy-m5/stargazers"><img alt="Stars" src="https://img.shields.io/github/stars/betizzel/omarchy-m5?style=for-the-badge&logo=github&color=7aa2f7&labelColor=1a1b26"></a> <a href="https://github.com/betizzel/omarchy-m5/watchers"><img alt="Watchers" src="https://img.shields.io/github/watchers/betizzel/omarchy-m5?style=for-the-badge&logo=github&color=bb9af7&labelColor=1a1b26"></a> <a href="https://github.com/betizzel/omarchy-m5/actions/workflows/update-check.yml"><img alt="Update check" src="https://img.shields.io/github/actions/workflow/status/betizzel/omarchy-m5/update-check.yml?style=for-the-badge&label=omarchy%20update&labelColor=1a1b26"></a> <a href="https://github.com/betizzel/omarchy-m5/releases"><img alt="Latest release" src="https://img.shields.io/github/v/release/betizzel/omarchy-m5?include_prereleases&style=for-the-badge&color=9ece6a&labelColor=1a1b26&label=image"></a> <a href="https://github.com/betizzel/omarchy-m5/commits/main"><img alt="Last commit" src="https://img.shields.io/github/last-commit/betizzel/omarchy-m5?style=for-the-badge&color=e0af68&labelColor=1a1b26"></a> <a href="LICENSE"><img alt="License" src="https://img.shields.io/github/license/betizzel/omarchy-m5?style=for-the-badge&color=7dcfff&labelColor=1a1b26"></a>
</p>

<p align="center">
  <a href="#the-goal">Goal</a> ·
  <a href="#whats-new">What's new</a> ·
  <a href="#what-works">What works</a> ·
  <a href="#try-it">Try it</a> ·
  <a href="#who-we-collect-from">Who we take from</a> ·
  <a href="CONTRIBUTING.md">Send your work</a>
</p>

## The goal

**Omarchy on the M5 Pro MacBook Pro, working like a normal laptop, through plain `omarchy update`.**

We don't reinvent anything. A lot of people are getting Linux running on the M5 Macs, each in their own repo. We
collect the parts that already work, test them on a real J714s, ship them as one signed update, and say who made
each part. When their pull request lands upstream, our copy goes away.

<p align="center"><img src="assets/pipeline.svg" alt="Collect, test on a real J714s, ship through omarchy update, send upstream" width="100%"></p>

## Get updates

```sh
curl -fsSLO https://raw.githubusercontent.com/betizzel/omarchy-m5/main/tools/update-source/enable
bash enable        # once: adds the signed [omarchy-m5] repo (key E86FAF98…9F69AE22)
omarchy update     # from then on, like any other package
```

Turned it on before 2026-11-27? Run `bash enable` once more to get the GPU drivers.
[What it does and why it's safe](tools/update-source/README.md).

> **On release 7 to 9 and `omarchy update` fails with `aurora_drv_video.so exists in filesystem`?** Install [firmware j714s16](https://github.com/betizzel/omarchy-m5/releases/tag/firmware-j714s16) once, then update again ([#34](https://github.com/betizzel/omarchy-m5/issues/34)).

## What's new

**2026-11-27, also through `omarchy update`:** **real GPU acceleration.** Every earlier release drew the desktop on the
CPU (the pinned Mesa had no M5 Pro support); Mesa/Vulkan `e705eca833f` from the omacom edge channel runs OpenGL 4.6 and
Vulkan 1.4 on the M5 Pro's GPU (glmark2 3003 against 89 in software) and Hyprland renders on it. **Microphones** about
17 dB louder (firmware j714s16-2, Isaac-Duarte's asahi-audio #45).

**Release 11 (2026-11-26), through `omarchy update` with [`[omarchy-m5]`](tools/update-source/README.md) on:** kernel
v272-21 on aurora-silicon/linux main `7f00dc6bc52c` (98 merged upstream PRs since v272-20: M5 GPU submission and recovery
work, T6050 AOP ring per endpoint, N1 6 GHz networks, Thunderbolt NHI credits, deep-sleep wake fix and more; credits in
[docs/work/release-11.md](docs/work/release-11.md)), plus auto-brightness from the light sensor (joshuaswarren's
`omarchy-brightness-auto` with `wluma`, off until `omarchy brightness auto on`). Booted on our J714s: Wi-Fi, Bluetooth,
120 Hz panel, camera, sound cards, Touch ID and s2idle pass.

**The image: [omarchy-j714s 10](https://github.com/betizzel/omarchy-m5/releases/tag/omarchy-j714s-10)** (prerelease, 2026-11-24): kernel
v272-19 on a newer aurora-silicon/linux (M5 Pro sleep work, DisplayPort and Wi-Fi fixes; 11 own patches, was 26),
firmware j714s16 (`omarchy update` works again, #34; VRR off by default, #25), Wi-Fi on WPA/WPA2 mixed routers (#30)
and a new developer signer. The camera's green light stays off on v272-19 (#33).

**Release 10's installer ran on hardware (2026-11-25):** a from-scratch install on our J714s (macOS shrunk to 160 GB, 769 GB for
Omarchy) booted, including release 10's new Stage 1. If you keep a fallback kernel, set `LIMIT_USAGE_PERCENT=50` in
`/etc/limine-snapper-sync.conf` first: otherwise the 500 MB ESP fills up and the next kernel update can't write its boot image
([details](docs/work/release-10.md#release-10-installed-on-hardware-2026-11-25)).

<p align="center"><img src="assets/status.svg" alt="What works on our J714s" width="100%"></p>

## Built from their work

<p align="center">
<a href="https://github.com/rolotrealanis98" title="rolotrealanis98"><img src="https://github.com/rolotrealanis98.png?size=96" width="56" height="56" alt="rolotrealanis98"></a>
<a href="https://github.com/edimoldovan" title="edimoldovan"><img src="https://github.com/edimoldovan.png?size=96" width="56" height="56" alt="edimoldovan"></a>
<a href="https://github.com/DjDeveloperr" title="DjDeveloperr"><img src="https://github.com/DjDeveloperr.png?size=96" width="56" height="56" alt="DjDeveloperr"></a>
<a href="https://github.com/betizzel" title="betizzel"><img src="https://github.com/betizzel.png?size=96" width="56" height="56" alt="betizzel"></a>
<a href="https://github.com/TripleU613" title="TripleU613"><img src="https://github.com/TripleU613.png?size=96" width="56" height="56" alt="TripleU613"></a>
<a href="https://github.com/FatBoy721" title="FatBoy721"><img src="https://github.com/FatBoy721.png?size=96" width="56" height="56" alt="FatBoy721"></a>
<a href="https://github.com/ja-818" title="ja-818"><img src="https://github.com/ja-818.png?size=96" width="56" height="56" alt="ja-818"></a>
<a href="https://github.com/Isaac-Duarte" title="Isaac-Duarte"><img src="https://github.com/Isaac-Duarte.png?size=96" width="56" height="56" alt="Isaac-Duarte"></a>
<a href="https://github.com/joshuaswarren" title="joshuaswarren"><img src="https://github.com/joshuaswarren.png?size=96" width="56" height="56" alt="joshuaswarren"></a>
<a href="https://github.com/erikwb" title="erikwb"><img src="https://github.com/erikwb.png?size=96" width="56" height="56" alt="erikwb"></a>
<a href="https://github.com/chrisohearn" title="chrisohearn"><img src="https://github.com/chrisohearn.png?size=96" width="56" height="56" alt="chrisohearn"></a>
<a href="https://github.com/funkzy" title="funkzy"><img src="https://github.com/funkzy.png?size=96" width="56" height="56" alt="funkzy"></a>
<a href="https://github.com/jgoyvaerts" title="jgoyvaerts"><img src="https://github.com/jgoyvaerts.png?size=96" width="56" height="56" alt="jgoyvaerts"></a>
<a href="https://github.com/axboe" title="axboe"><img src="https://github.com/axboe.png?size=96" width="56" height="56" alt="axboe"></a>
<a href="https://github.com/sithglan" title="sithglan"><img src="https://github.com/sithglan.png?size=96" width="56" height="56" alt="sithglan"></a>
<a href="https://github.com/RyanTheTide" title="RyanTheTide"><img src="https://github.com/RyanTheTide.png?size=96" width="56" height="56" alt="RyanTheTide"></a>
<a href="https://github.com/kazuhidet" title="kazuhidet"><img src="https://github.com/kazuhidet.png?size=96" width="56" height="56" alt="kazuhidet"></a>
<a href="https://github.com/IronsideXXVI" title="IronsideXXVI"><img src="https://github.com/IronsideXXVI.png?size=96" width="56" height="56" alt="IronsideXXVI"></a>
<a href="https://github.com/satchlj" title="satchlj"><img src="https://github.com/satchlj.png?size=96" width="56" height="56" alt="satchlj"></a>
<a href="https://github.com/m0d16l14n1" title="m0d16l14n1"><img src="https://github.com/m0d16l14n1.png?size=96" width="56" height="56" alt="m0d16l14n1"></a>
</p>

<p align="center"><sub>M5 owners, Aurora Silicon and omacom people whose work is in here or watched. Full list with what came from whom: <a href="#who-we-collect-from">who we collect from</a>.</sub></p>

**Send your M5 work here.** If you have something working on an M5 Mac, open a pull request under your own name
([how](CONTRIBUTING.md)); keep your upstream pull request, and we drop our copy when it merges there. Every release is
an edge prerelease: it works on the hardware listed as tested, and the known gaps are listed, not hidden.

---

## What works

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
| Touch ID | **Works**: enrol and match on 27.2 (2026-11-16, kernel v272-15; the enrolled finger still listed on v272-21; owner opt-in, writes the Secure Enclave store macOS shares, read [the warning](installer/recipes/aurora-sep-upstream/README.md)); match after a reboot not yet checked | DjDeveloperr, aurora-silicon |
| Variable refresh on the panel | off: offered up to firmware j714s14 (release 9), not offered from j714s15 on, because turning it on crashed the K114s OLED's display coprocessor on 27.2 ([#25](https://github.com/betizzel/omarchy-m5/issues/25)) and it was never proven on 27.2 here | rolotrealanis98 |
| Hyprland colour management on displays with degenerate EDID colour data | **Works**: the primaries are treated as missing, so the panel isn't blanked (hyprland-m5 0.57.2-4, release 9; [#21](https://github.com/betizzel/omarchy-m5/issues/21) was seen on a K114s OLED) | chrisohearn (#24) |
| Firewall (`ufw`) | **Works** | this repo, chrisohearn (report) |
| Sleep | **Partly**: lid sleep works (s2idle; release 8: 3 s and 3 min 37 s; v272-21: 23 s with a key wake; the panel, Wi-Fi, Bluetooth, sound and both working USB-C ports come back). Deep sleep: upstream's driver is in since v272-22 but its J714s profile was measured on the 18-core M5 Pro and refuses the 15-core one; v272-23 admits the 15-core part, built, test pending. With an external display plugged in, closing the lid does not sleep (logind treats it as docked) | Isaac-Duarte (#2012, #2018), Jens Axboe and sithglan (#1647), DjDeveloperr (#1963) |
| Fans | **Works**: Linux can set fan targets (tested: target 3000 gave 2989 rpm) | Isaac-Duarte (#1944) |
| Sustained CPU load | **Works**: the clusters follow the fast-die limit; the die held 107–109 C with 15 busy cores | DjDeveloperr (#1950) |
| Updates (`omarchy update`) | **Works**: checked in CI ([`update-check`](.github/workflows/update-check.yml)); our tested kernel, firmware, m1n1, Hyprland and GPU drivers come from the signed [`[omarchy-m5]`](tools/update-source/README.md) repository | this repo |
| Wi-Fi power save | **Partly**: works when set (`wifi.powersave = 3` in NetworkManager), `iw` reports it on, no ping loss; set by hand on our J714s, not in a package yet; erikwb measured about -0.35 W with it on a J716c | erikwb (measurement) |
| Two Omarchy installs on one disk | **Works**: each mounts its own boot partitions ([why](docs/duplicate-boot-ids.md)) | this repo |

**Works** · **Partly** · **No**

Also known: every boot pauses about 15 seconds at the logo, and a DisplayPort cable plugged in
at boot was once not detected until it was plugged in again.

---

## Try it

It runs on a Mac, not from a Linux PC. You need:

- A **MacBook Pro 14-inch, M5 Pro** (J714s). Not M5 Max, not the 16-inch, not yet.
- **macOS 27.2 or newer** on it, FileVault on, an administrator account.
- About **35 GB free** on the Mac's disk, the charger, and about an hour.

Steps (the [release page](https://github.com/betizzel/omarchy-m5/releases/tag/omarchy-j714s-9) has every detail):

1. **Download** the installer package from the release (online: small; offline: the `.partN`
   files joined) and check it against `SHA256SUMS`.
2. **Install and run** Omarchy Installer. It shrinks macOS, adds a new startup disk (Apple's 27.2
   firmware, downloaded from Apple) and writes Omarchy.
3. **Finish setup in Recovery:** shut down, hold the power button, pick the **Omarchy with the
   logo icon**, sign in, click **Install** in Omarchy's own "Finish setup" window and wait (up to
   30 minutes). Don't use Startup Security Utility.
4. **Restart.** First boot asks for a disk password, then your name and password.

**To go back to macOS:** hold the power button at startup and pick macOS.

**Before turning the speakers up,** follow the low-level test in
[the speaker recipe](installer/recipes/speakerguardd-v2-upstream/README.md).

Stuck? Open an [issue](https://github.com/betizzel/omarchy-m5/issues) and paste what you see.

Earlier releases (1 to 6) and the older developer images are superseded; what each one was and
why it was replaced is in [`docs/status-and-history.md`](docs/status-and-history.md). What is
being sent upstream, and what waits on a test first, is in [`docs/upstream.md`](docs/upstream.md).

---

## Other M5 boards

- **K114s** (14-inch OLED, M5 Pro, `apple,k114s`): admitted in developer builds, experimental, tested on one machine by chrisohearn; no image here, and admission alone gives a keyboard-only system.
  Notes: [`docs/boards/k114s.md`](docs/boards/k114s.md) and [chrisohearn/omarchy-m5p-oled](https://github.com/chrisohearn/omarchy-m5p-oled).
- **J716s** (16-inch, M5 Pro, `apple,j716s`): admitted in developer builds, experimental, tested on one machine by ja-818 on the 27.2 stub with release 9's image ([#28](https://github.com/betizzel/omarchy-m5/issues/28), [#29](https://github.com/betizzel/omarchy-m5/pull/29)). Works there: all 18 CPUs, panel, keyboard, trackpad, USB, Bluetooth, lid sleep; Wi-Fi with a device-tree change not carried here yet.
  In kernel v272-19 (built and booted on our J714s, not released yet; 0009-0011 there): front camera ([#31](https://github.com/betizzel/omarchy-m5/pull/31)); jack, microphones and light sensor with the speakers held off ([#32](https://github.com/betizzel/omarchy-m5/pull/32)). Not tested on a J716s in this build.
  Earlier report on the 27.3 beta with rolotrealanis98's own kernel: [#23](https://github.com/betizzel/omarchy-m5/issues/23).
---

## Who we collect from

These are the people and repos we watch. A script ([`tools/watch/watch.sh`](tools/watch/watch.sh))
checks all of them every 30 minutes for new commits, and anything new that works on a J714s
gets pulled in here.

### M5 Mac owners doing the bring-up

| Who | Mac | Their repo | What we took |
| --- | --- | --- | --- |
| [rolotrealanis98](https://github.com/rolotrealanis98) | 16" M5 Pro (J716s) | [m5pro-linux](https://github.com/rolotrealanis98/m5pro-linux), [m4-m5-linux](https://github.com/rolotrealanis98/m4-m5-linux) (status tracker) | the T6050 kernel base, audio, many fixes |
| [edimoldovan](https://github.com/edimoldovan) | 14" M5 Max (J714c) | [linux-aurora](https://github.com/edimoldovan/linux-aurora), [omarchy-mac-pkgs](https://github.com/edimoldovan/omarchy-mac-pkgs) | trackpad reset, speaker safety + sound profiles, 6 GHz Wi-Fi, quiet idle fans |
| [DjDeveloperr](https://github.com/DjDeveloperr) | 14" M5 Pro (J714s) | via [aurora-silicon/linux](https://github.com/aurora-silicon/linux) and [aura](https://github.com/aurora-silicon/aura) | the upstream J714s device tree: USB-C, USB4, displays, GPU handoff (testing now) |
| [betizzel](https://github.com/betizzel) | 14" M5 Pro (J714s) | this repo | the first J714s boot, display, GPU |
| [TripleU613](https://github.com/TripleU613) | 14" M5 Pro (J714s) | this repo | Wi-Fi, GPU, the installer image |
| [FatBoy721](https://github.com/FatBoy721) | 14" M5 Pro (J714s) | | lid sleep fixes; first install by someone else (#293) |
| [ja-818](https://github.com/ja-818) | 16" M5 Pro (J716s) | [omarchy-m5 fork](https://github.com/ja-818/omarchy-m5) | J716s admission, camera, jack and mics; N1 joins WPA/WPA2 mixed networks (0022, every M5 Pro) |
| [cameroncooper](https://github.com/cameroncooper) | 16" M5 Max (J716c) | | watched (Aura stage 1, accelerated Hyprland on J716c) |
| [joshuaswarren](https://github.com/joshuaswarren) | | | J714c PMP and USB-C upstream, PMP analysis in #293 |
| [sithglan](https://github.com/sithglan) | K116s (M5 Pro/Max) | via [aurora-silicon/linux](https://github.com/aurora-silicon/linux) and [aura](https://github.com/aurora-silicon/aura) | watched: K116s bring-up on 27.2, camera hand-off (aura #188) |
| [erikwb](https://github.com/erikwb) | | | T6050 USB4 and external displays upstream (J716c) |

### The Omarchy-on-Mac team ([omacom](https://github.com/omacom))

[maralcbr](https://github.com/maralcbr) (Marcelo Alcantara) ·
[scottjones](https://github.com/scottjones) (Scott Jones) ·
[chriskearney](https://github.com/chriskearney) (Chris Kearney) ·
[malik-na](https://github.com/malik-na) (Naeem Malik) ·
[DjDeveloperr](https://github.com/DjDeveloperr) (Dj) ·
[joshuaswarren](https://github.com/joshuaswarren) (Joshua Warren) ·
[themartiano](https://github.com/themartiano) (Eduardo Martinez) ·
[riverscn](https://github.com/riverscn) (Shun Li) ·
[RyanTheTide](https://github.com/RyanTheTide) (Ryan Murray) ·
[Acelogic](https://github.com/Acelogic) (Miguel Cruz) ·
[LiamRay11](https://github.com/LiamRay11) (Liam) ·
[erykwieliczko](https://github.com/erykwieliczko) (Eryk Wieliczko) ·
[subedijaidip](https://github.com/subedijaidip) (Jaidip Subedi) ·
[shawnyeager](https://github.com/shawnyeager) (Shawn Yeager) ·
[jondkinney](https://github.com/jondkinney) (Jon Kinney) ·
Randy (GitHub name unknown: tell us)

Also watched: [satchlj](https://github.com/satchlj), [joske](https://github.com/joske).

### M4 neighbours (one generation older, fixes often carry over)

| Who | Mac | Their repo |
| --- | --- | --- |
| [IronsideXXVI](https://github.com/IronsideXXVI) | 14" M4 (J604) | [omarchy-j604](https://github.com/IronsideXXVI/omarchy-j604): 120 Hz 10-bit, all 6 speakers, video decode |
| [jgoyvaerts](https://github.com/jgoyvaerts) | 16" M4 Pro (J616s) | [omarchy-m4](https://github.com/jgoyvaerts/omarchy-m4) |
| [kazuhidet](https://github.com/kazuhidet) | M4 Air 15" (J713) | [Omarchy-M4-Native](https://github.com/kazuhidet/Omarchy-M4-Native) |
| [andreinita21](https://github.com/andreinita21) | M4 Mac mini | [OmarchyM4Mini](https://github.com/andreinita21/OmarchyM4Mini) |
| [fbalazsy](https://github.com/fbalazsy) | 16" M4 Pro (J616s) | [j616s-omarchy-m4-tutorial](https://github.com/fbalazsy/j616s-omarchy-m4-tutorial) |
| [Blueemi](https://github.com/Blueemi) | M4 Pro | [omarchy-dots](https://github.com/Blueemi/omarchy-dots): macOS-like trackpad and scrolling |
| [pixbroker](https://github.com/pixbroker) | 16" M4 Pro | 120 Hz GPU desktop, sound, sleep (posts) |

Posting on X but not found on GitHub: StudioXRadio (M4 Air installer), jefehollis (M4 Air GPU fix),
thellmgenius (M4 Air Thunderbolt monitor). Know their GitHub names? Tell us.

### Sent upstream from this repo

| Change | Where | Status |
| --- | --- | --- |
| T6050 PCIe: let the auto-PM storage domain gate itself (boot hang / missing Wi-Fi) | [aurora-silicon/aura#203](https://github.com/aurora-silicon/aura/pull/203) | merged 2026-11-13 |
| drm/apple: soft-depend on the T6050 combo PHY module (USB-C external displays) | [aurora-silicon/linux#1745](https://github.com/aurora-silicon/linux/pull/1745) | merged 2026-11-13 |
| AVE: T6050 encoder on the 27.3 firmware | [aurora-silicon/linux#1747](https://github.com/aurora-silicon/linux/pull/1747) | merged 2026-11-13 |
| ANE: T6050 on the 27.3 firmware | [aurora-silicon/linux#1746](https://github.com/aurora-silicon/linux/pull/1746) | closed 2026-11-15 (27.3 beta; the 27.2 pin follows after the upstream 27.2 retarget) |

### Repos we watch

| Repo | What it is |
| --- | --- |
| [aurora-silicon/linux](https://github.com/aurora-silicon/linux) | the Apple Silicon kernel everyone lands work in |
| [aurora-silicon/aura](https://github.com/aurora-silicon/aura) | the bootloader (m1n1 fork) |
| [aurora-silicon/mesa](https://github.com/aurora-silicon/mesa), [u-boot](https://github.com/aurora-silicon/u-boot) | graphics drivers, U-Boot |
| [omacom/linux-aurora](https://github.com/omacom/linux-aurora), [m1n1](https://github.com/omacom/m1n1) | Omarchy's kernel and bootloader |
| [omacom/omarchy-mac-pkgs](https://github.com/omacom/omarchy-mac-pkgs), [omarchy-mac-installer](https://github.com/omacom/omarchy-mac-installer) | Omarchy's Mac packages and installer |
| [omacom/linux-aurora#293](https://github.com/omacom/linux-aurora/issues/293) | the thread where M5 owners post results |
| [omarchyarchive.com](https://omarchyarchive.com/search/?q=M5) | community posts about the M5 Macs (X, blogs) |

Plus every repo the people above push to, and a GitHub-wide search for `t6050`, `j714s`,
`j714c`, `j716s`, `m5 pro linux`, `m5 max linux`. Know someone we missed? Open an issue.

---

## Help out (dev)

You don't need to be a kernel hacker. The easiest ways to help:

- **Got a J714s?** Try the image and tell us what works and what doesn't.
- **Found someone's M5 work that we don't have?** Open an issue with the link. That's the whole job here.
- **Want to watch the repos yourself?** `tools/watch/watch.sh` (needs `gh` logged in). The first
  run just records where everything is; after that it prints what changed.

Want to build it yourself? The kernel and bootloader patches are in [`patches/`](patches/), the
image recipe in [`installer/`](installer/README.md), and the full build guide is
[`docs/bringup.md`](docs/bringup.md). What we know of but left out on purpose, and why: [`docs/left-out.md`](docs/left-out.md). Everything detailed (status history, how each piece was
found, the old notes) lives in [`docs/status-and-history.md`](docs/status-and-history.md).

---

Built on [Asahi Linux](https://asahilinux.org), [Aurora Silicon](https://github.com/aurora-silicon)
and [omacom](https://github.com/omacom). [MIT](LICENSE) for this repo's own scripts and docs;
patches keep the license of the project they apply to. No Apple firmware is shipped here.
