# omarchy-m5

**[Omarchy](https://omarchy.org) on the 14-inch MacBook Pro with M5 Pro (J714s).**

We don't reinvent anything. A lot of people are getting Linux running on the M5 Macs, each
in their own repo. We collect the parts that already work, put them together in one image,
test it on a real J714s, and say who made each part.

---

## What works

Two images. **Stable** (`2026.11.11-7`) is the one to install. **Upstream** (`upstream-2026.11.13-8`,
a prerelease) moves to aurora-silicon's kernel and the Aura bootloader on Apple's 27.3 firmware: every row
below was tested on a real J714s by booting -7's kernel from RAM. -8's kernel (newer upstream, plus the
external display fix) has not booted yet. -7 has been installed and booted end to end on one J714s.

| Thing | Stable | Upstream (experimental) | Whose work |
| --- | --- | --- | --- |
| Boots from the Mac's own disk, all 15 CPU cores | ✅ | ✅ (RAM-booted; install untested) | Apple's firmware fix, rolotrealanis98, betizzel, DjDeveloperr, aurora-silicon |
| Keyboard, backlight, trackpad | ✅ | ✅ | rolotrealanis98, edimoldovan |
| Wi-Fi, Bluetooth | ✅ | ✅ (boot fix in Aura, [aura#203](https://github.com/aurora-silicon/aura/pull/203)) | rolotrealanis98, betizzel, TripleU613, DjDeveloperr, edimoldovan |
| GPU (Vulkan, the desktop renders on it) | ✅ | ✅ 27.3 firmware | TripleU613, betizzel, DjDeveloperr, rolotrealanis98, joshuaswarren |
| Screen: full panel incl. the notch, 3024x1964 at 120 Hz | ✅ | ✅ | FatBoy721, edimoldovan, rolotrealanis98, betizzel |
| Variable refresh (ProMotion) | ❌ | 🟡 opt-in (`appledrm.fw27_panel_vrr=1`) | rolotrealanis98 |
| Speakers | ✅ (capped at -30 dB, with speaker protection) | ❌ held off until J714 speaker files are public | rolotrealanis98, edimoldovan, kazuhidet |
| Headphone jack, microphones | ✅ | 🟡 cards show up, untested | rolotrealanis98, edimoldovan, kazuhidet |
| Hardware video decode (H.264/H.265) | ✅ | ✅ | DjDeveloperr |
| Hardware video encode (H.264/HEVC) | ❌ | ✅ (27.3 port here) | DjDeveloperr, this repo |
| Front camera (1080p/1440p, 30 fps) | ❌ | ✅ needs [`save-camera-setfiles.py`](tools/camera-setfiles/save-camera-setfiles.py) once in macOS | edimoldovan, Jens Axboe, sithglan, Erik Bourget, DjDeveloperr |
| Touch ID | ❌ | 🟡 enrol + match work on TripleU613's J714s (owner opt-in; writes the Secure Enclave store macOS shares, read [the warning](installer/recipes/aurora-sep-upstream/README.md)) | DjDeveloperr, aurora-silicon |
| Neural Engine | ❌ | ✅ starts on 27.3 (27.3 port here) | DjDeveloperr, this repo |
| Power profiles, brightness up to max | ❌ | ✅ | DjDeveloperr |
| Lid angle sensor | ✅ | ✅ | DjDeveloperr |
| Ambient light sensor | 🟡 needs this Mac's calibration ([`save-als-cal.py`](tools/als-calibration/save-als-cal.py)) | 🟡 same | DjDeveloperr, aurora-silicon |
| Sleep (lid close) | ✅ | untested | FatBoy721, betizzel |
| USB host on all three USB-C ports | ✅ | ✅ | edimoldovan, DjDeveloperr |
| USB4, external displays | ❌ | 🟡 USB-C: all four display engines come up with -8's fix (tried as a config line on -7's kernel), no monitor tried yet; HDMI ❌ | DjDeveloperr, erikwb, this repo |
| Quiet fans at idle | ✅ | ✅ | edimoldovan |
| Updates (`omarchy update`) | ✅ (checked in CI, [`update-check`](.github/workflows/update-check.yml)) | ✅ | this repo |

✅ works · 🟡 partly · 🔜 coming · ❌ no

---

## Try it

**One image, one installer: [omarchy-j714s 2](https://github.com/betizzel/omarchy-m5/releases/tag/omarchy-j714s-2)**
(prerelease). It runs on a Mac, not from a Linux PC.

You need:

- A **MacBook Pro 14-inch, M5 Pro** (J714s). Not M5 Max, not the 16-inch, not yet.
- **macOS 27.2 or newer** on it, FileVault on, an administrator account.
- About **35 GB free** on the Mac's disk, the charger, and about an hour.

Steps (the release page has every detail):

1. **Download** the installer package from the release (online: small; offline: the `.partN`
   files joined) and check it against `SHA256SUMS`.
2. **Install and run** Omarchy Installer. It shrinks macOS, adds a new startup disk (Apple's 27.2
   firmware, downloaded from Apple) and writes Omarchy.
3. **Finish setup in Recovery:** shut down, hold the power button, pick the **Omarchy with the
   logo icon**, sign in, click **Install** in Omarchy's own "Finish setup" window and wait (up to
   30 minutes). Don't use Startup Security Utility.
4. **Restart.** Each boot pauses about 15 seconds at the logo. First boot asks for a disk password,
   then your name and password.

Known gaps on 27.2: no built-in sound yet (speakers, headphone jack, microphones; fix planned for
the next kernel). To go back: hold the power button at startup and pick macOS.

Older images are **superseded** by omarchy-j714s 2 and no longer the way to install:
`j714s-developer-image-2026.11.11-7` (stable, 27.3 beta stub, installed from Linux with
`docs/bringup.md`), the `upstream-2026.11.1x-N` developer images, and `omarchy-j714s 1` (boot-loops
after install; fixed in 2). The table above still describes those two older images.

Stuck? Open an [issue](https://github.com/betizzel/omarchy-m5/issues) and paste what you see.

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
| ANE: T6050 on the 27.3 firmware | [aurora-silicon/linux#1746](https://github.com/aurora-silicon/linux/pull/1746) | open |

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
