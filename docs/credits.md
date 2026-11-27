# Who we collect from

These are the people and repos we watch. A script ([`tools/watch/watch.sh`](../tools/watch/watch.sh))
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
| Sleep: admit the 15-core M5 Pro J714s (the J714s profile was measured on 18 cores); deep sleep and wake work on our J714s, the PMP doesn't come back (reported in the PR) | [aurora-silicon/linux#3419](https://github.com/aurora-silicon/linux/pull/3419) | open 2026-11-27 (our patch 0012) |

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


[Back to the README](../README.md)
