# Upstream tracker

One table for everything from this repo that should land upstream. Each row moves left to right:
**found → proven here → sent → merged**. A row is sent only when its evidence column is filled in
from a real J714s. Rows that need more testing stay in "Waiting on a test" until that test is done.

Rules for sending:

- One small change per pull request, from a TripleU613 fork, with a sign-off where the project asks for one.
- Technical description only: the problem, the cause, the change, how it was tested.
- Other people's work is theirs to send. From us they get a test report on their pull request.
- Check the target project for an existing fix or pull request first.

## Sent

| Change | Where | Status |
| --- | --- | --- |
| T6050 PCIe: let the auto-PM storage domain gate itself | [aurora-silicon/aura#203](https://github.com/aurora-silicon/aura/pull/203) | merged 2026-11-13 |
| drm/apple: soft-depend on the T6050 combo PHY module | [aurora-silicon/linux#1745](https://github.com/aurora-silicon/linux/pull/1745) | merged 2026-11-13 |
| AVE: T6050 encoder on the 27.3 firmware | [aurora-silicon/linux#1747](https://github.com/aurora-silicon/linux/pull/1747) | merged 2026-11-13 |
| Sleep: admit the 15-core M5 Pro J714s (the J714s profile was measured on 18 cores); deep sleep and wake work on our J714s, the PMP doesn't come back (reported in the PR) | [aurora-silicon/linux#3419](https://github.com/aurora-silicon/linux/pull/3419) | open 2026-11-27 (our patch 0012); 2026-11-28: approved in review, pr-text fixed (head 530e995f, same tree), head row posted |
| ANE: T6050 on the 27.3 firmware | [aurora-silicon/linux#1746](https://github.com/aurora-silicon/linux/pull/1746) | closed 2026-11-15 (27.3 beta; the 27.2 pin follows after the upstream 27.2 retarget) |
| R1: two Omarchy installs on one disk share the boot filesystem IDs (issue, generator offered as one possible fix) | [omacom/omarchy-mac-installer#219](https://github.com/omacom/omarchy-mac-installer/issues/219) | issue opened 2026-11-14; allanclempe confirmed it on a J616c with a stricter generator, invited to open the PR (2026-11-19) |
| J714s in the installer: the installer changes offered, with what they depend on (issue, not a PR: upstream's engine has no T6050 entry and its pinned kernel no T6050 device tree; plan in [upstream-installer-plan.md](upstream-installer-plan.md)) | [omacom/omarchy-mac-installer#221](https://github.com/omacom/omarchy-mac-installer/issues/221) | issue opened 2026-11-15 |
| "Finish setup" text: name Install in Finish setup and the Startup Security Utility wrong turn (#221 item 5, any Mac) | [omacom/omarchy-mac-installer#228](https://github.com/omacom/omarchy-mac-installer/pull/228) | PR opened 2026-11-19 |
| T1 + T2: J714s on 27.2 results, with FatBoy721's HDMI v2 and Jens Axboe's #1645 | [omacom/linux-aurora#293 comment](https://github.com/omacom/linux-aurora/issues/293#issuecomment-6886977253) | posted 2026-11-14 |

## Ready to send (proven on the J714s)

Nothing left here. Checked 2026-11-14:

| # | Change | What upstream has | Outcome |
| --- | --- | --- | --- |
| R1 | Mount `/boot` and `/boot/efi` from the partitions the system booted from | omacom/omarchy-mac-installer `c07e54c` (head) still gives every image the same IDs (`build-mac-image` lines 27-30) and writes `/etc/fstab` by them. The app refuses to add a second install by design (b1dade4); #157 (open) plans multi-install. The fstab is written at image build, before any partition exists, and a generator would be new boot-critical code in omarchy-mac-boot, so the right place is the maintainers' call | issue [#219](https://github.com/omacom/omarchy-mac-installer/issues/219), generator offered as one option |
| R2 | Kernel config: `NETFILTER_XT_MATCH_HL`, `IP6_NF_MATCH_HL`, `IP6_NF_MATCH_RT` (ufw's IPv6 rules) | omacom/omarchy-pkgs `pkgbuilds/linux-aurora/config` (master) already builds all three as modules (with the `asahi.config` fragment), so the gap does not exist there; it was only in our J714s recipe's config | not sent: already upstream |
| R3 | J714s: load `aop` at boot | omacom/omarchy-pkgs `omarchy-aurora-firmware` (master) has the same `blacklist aop`, but its `aurora-peripheral-firmware.sh` has no J714s branch: every machine but the Neo reaches the final `modprobe aop`, in the initrd and again in the root stage (`20-aurora-vendor-order.conf`). The skip came from our own J714s (Centauri) branch. None of the 200 latest open omarchy-pkgs pull requests touches `pkgbuilds/omarchy-aurora-firmware/` | not sent: already handled upstream |

## Test reports for other people's work

| # | Whose | What we saw on the J714s | Where to report | Status |
| --- | --- | --- | --- | --- |
| T1 | FatBoy721: T6050 HDMI (v2) | Samsung Odyssey G9 (G91SD), 27.2, kernel v272-7: 5120x1440 at 60/120/144 Hz and 3840x2160 at 60 Hz. With v1: 5120x1440 at 60 Hz worked, 3840x2160 at 60 Hz stayed blank | he has no upstream pull request, issue or discussion for it (checked aurora-silicon/linux, omacom/linux-aurora), so it went into the T2 post, credited to him | sent in [#293](https://github.com/omacom/linux-aurora/issues/293#issuecomment-6886977253) |
| T2 | Jens Axboe: 27.2 AOP endpoints (#1645, merged) | sound cards, sensors, speakerguardd v2 gate passes, speakers heard | owners' thread [omacom/linux-aurora#293](https://github.com/omacom/linux-aurora/issues/293) | sent: [comment](https://github.com/omacom/linux-aurora/issues/293#issuecomment-6886977253) (whole J714s 27.2 status; the right-port DisplayPort line left out the fault count) |
| T3 | Isaac-Duarte: #1921 dock third display | applied on v272-7 together with the HDMI device tree; boots; USB-C DisplayPort on the left non-DFU port works. No dock tried. With HDMI and #1921 together no display engine is left as a merged-mode peer | nothing to report until a dock is tried | waiting on a test |

| T4 | Isaac-Duarte: J714s fan targets (aurora-silicon/linux #1944) | target 3000 gave 2989 rpm, 0 hands back; on v272-8..11 and the fresh install | [#1944 comment](https://github.com/aurora-silicon/linux/pull/1944#issuecomment-6900377583) | sent 2026-11-15 |
| T5 | Isaac-Duarte: dock third display (#1921) with FatBoy721's HDMI DT | HDMI 5120x1440@144 and 3840x2160@60, left-front DP 5120x1440@144 work with both in the tree; no dock tried; merged-mode-peer observation from the code | [#1921 comment](https://github.com/aurora-silicon/linux/pull/1921#issuecomment-6900377857) | sent 2026-11-15 |

| T6 | Isaac-Duarte #2012/#2018 + sithglan/Jens Axboe #1647: J714s s2idle | lid sleep works on v272-12 (2 cycles, 3 s and 3 min 37 s); USB-C left-front and right alive after wake | [#2012](https://github.com/aurora-silicon/linux/pull/2012#issuecomment-6901870977), [#2018](https://github.com/aurora-silicon/linux/pull/2018#issuecomment-6901871277), [#1647](https://github.com/aurora-silicon/linux/pull/1647#issuecomment-6901871583) | sent 2026-11-15 |

## Waiting on a test

| # | Change | The test it waits for |
| --- | --- | --- |
| W1 | J714s in the installer: 27.2 Mach-O Stage 1, "Finish setup" text, the Stage 1 window, admission | test done: fresh install of release 6 on 2026-11-15. Offered in [#221](https://github.com/omacom/omarchy-mac-installer/issues/221); the order and what each pull request waits for are in [upstream-installer-plan.md](upstream-installer-plan.md) |
| W2 | J714s camera and DCP rows for 27.2 (Aura tables) | compare with what upstream has now; a camera capture on v272-7 |
| W3 | ANE 27.2 pin (retarget #1746 from 27.3 to 27.2) | an ANE workload on 27.2, not just the device coming up |
| W4 | AVE 27.2 layout | an encode on 27.2 (today: probe only) |
| W5 | Deep sleep on the J714s: DjDeveloperr's suspend-to-RAM series, [aurora-silicon/linux#1963](https://github.com/aurora-silicon/linux/pull/1963) (draft, 23 commits, opened 2026-11-15) | his public series alone leaves the internal panel dark and external displays gone after a wake; his measured runs used a private stack on top (display coprocessor restart, DART/power steps, device-tree values). Take it when the panel lights after a wake with the public commits, and test from RAM first: a failed wake needs the owner at the Mac |

## Open problems found here (no fix yet)

| # | Problem | Notes |
| --- | --- | --- |
| P1 | DisplayPort on the right USB-C port never trains (twelve `link fault 22`, 640x480 fallback) | same on v272-4 and v272-7; left non-DFU port works |
| P2 | The left DFU port shows no plug event and no display in Linux | the port is device-only in our build; check upstream's device tree |
| P3 | A DisplayPort cable plugged in at boot was not detected once (replug fixed it) | seen once on v272-7 |
| P4 | Every installer image writes the same filesystem IDs | R1 works around it for the boot partitions; the root ID is still shared. Reported upstream in [omacom/omarchy-mac-installer#219](https://github.com/omacom/omarchy-mac-installer/issues/219) |

## Gathered from others, built, booted on the J714s (2026-11-15)

**v272-11 is installed and booted on the logo (27.2) install, 2026-11-15 00:37 EST:** boot 25.6 s, no failed units, no new kernel errors; fan targets writable, fast-die effort on all three clusters, `rfcomm` and `pkcs8_key_parser` loaded, `sched_util_clamp_min_rt_default` 0, Wi-Fi, camera, ANE, GPU and DCP devices, three sound cards, speakerguardd-v2 and ufw active, `/boot` and `/boot/efi` on p5/p4. The Dock and HDMI-related changes (#1930, #1721) were not exercised (no dock or monitor attached).

Each kernel builds on the one above it. The first boot after installing v272-8 on the logo install sat on an Omarchy logo with no disk prompt; that was most likely not v272-8: a reboot from the logo install goes to the Mac's default startup disk (the older stub), whose stage 1 waits on its logo when the PC's catcher is not running, and the catcher was down then. On 2026-11-15 v272-8 (its own kernel and device tree) booted from RAM on the dev path (27.3 stub, older Aura) in about a minute, Wi-Fi up, so neither of its device-tree changes hangs a boot by itself; v272-11 booted the same way (about a minute, Wi-Fi up); the logo install then booted the v272-8 kernel when picked in the boot picker. The logo ESP now has v272-7's device tree with v272-8's kernel, so the next boot shows which part hangs. Until then v272-9 and v272-10 are not installed.

| Kernel | Adds | Source | Their hardware evidence |
| --- | --- | --- | --- |
| v272-8 | J714s fans take a userspace target | Isaac-Duarte, aurora-silicon/linux #1944 (open) | his J714s: hotspot 114 C with the firmware curve, builds back to 47-57 s. **Ours, 2026-11-15:** fan1_target 3000 gave 2989 rpm, 0 handed it back (0 rpm idle) |
| v272-8 | appledrm stops waiting on a DP tunnel the dock withdrew | Isaac-Duarte, #1930 (merged 2026-11-16) | his J714s with a Thunderbolt 5 dock |
| v272-8 | no LDCM command to a dry SN201202x port | DjDeveloperr, #1721 (merged 2026-11-17; drop 0020 at the next re-pin) | 19 boots on a J714s |
| v272-8 | the PMP's power domains stay on through s2idle | Jens Axboe, #1789 (open, sent by sithglan) | two clean s2idle cycles on a K116s |
| v272-9 | `BT_RFCOMM`, `BT_RFCOMM_TTY`, `PKCS8_PRIVATE_KEY_PARSER` | chrisohearn, betizzel/omarchy-m5#9 | the bluetoothd and modules-load errors on his K114s. **Ours:** `rfcomm` and `pkcs8_key_parser` load on v272-11 |
| v272-10 | three G17 fixes merged upstream after our pin | Diljit Singh, #1925, #1946, #1948 (merged) | merged into integration/aurora |
| v272-11 | J714s clusters enforce the PMP's fast-die effort | DjDeveloperr, #1950 (open) | his J714s's default DT since 2026-11-14: sustained all-core 49-56 to 115-119 Gfma/s, CPU die 114 to 109 C **Ours, 2026-11-15 (v272-11 from RAM, dev path):** the property is on all three performance controllers; with 15 busy cores for 90 s the clusters' `scaling_max_freq` follows the effort (P 4608 to 3648 to 3180 MHz) and TCMb holds 107-109 C |
| hyprland-m5 0.57.2-3 | the latch members at the end of `CMonitor`, so stock-built plugins keep their offsets | chrisohearn's report betizzel/omarchy-m5#8 (fix 1 of 3) | **tested on the J714s** (dev Linux, nested): `offsetof(m_layerSurfaceLayers)` = 0x790 as in stock; with Omarchy's `omarchy-hyprland-titlebars 0.4.0-1` (edge, sha256 30683a99) and a background-layer surface, the plugin's `tools/verify.py` crashes 0.57.2-2 on the first titlebar press (SIGSEGV, `layerSurfaceAt` from `inputIsValid()+0x414`, as in #8) and passes all 10 checks on 0.57.2-3 with no crash report. Package sha256 531fc814 |

## Looked at and not taken (2026-11-15)

| Item | Why not |
| --- | --- |
| DjDeveloperr's J714s deep-sleep series, up to #1785 | closed as a draft; its J714s validation was still in progress, and the loader data it needs is not in Aura |
| #1947 dwc3: stop a host for deep sleep outside the PM notifier chain | only matters once deep sleep is the default (the series above); the standalone commit is compile-tested only |
| #1618 PCI: mask Clock PM on adopted T6050 endpoints | evidence is from a J775c bisection; the rebased head was not booted, and no J714/J716 result |
| #1873 drm/apple: alpha-only formats on the T6050 internal primary plane | its boot check on the M5 is listed as not verified yet |
| #1698 nvme: post-M4 ANS keep-live across s2idle, opt-in | draft; its default-off rework was not rebuilt or booted |
| aura #214 T6050 SIO tables and sleep wake sources | merged 2026-11-15 (52af355c): comes with the next Aura bump; its kboot part only acts on an `apple,t6050-sleep` node, which our device tree does not have (no deep sleep yet) |
| aura #230 GPU firmware-version hint (merged) | only removes harmless log lines on 27.2; goes in with the next Aura bump |
| satchlj `t6050-smc-key-inventory` | read-only SMC key dump for research, no user-facing change |
| aura #259 T6050 internal display handoff on the 27.3 beta (joshuaswarren) | 27.3 beta only (our stub is 27.2), a draft not booted |
| IronsideXXVI omarchy-mac-pkgs `apple-powerprofiles-floor` (6ca225ea88): a uclamp CPU floor that follows the power profile | measured on an M4 J604 only, and it runs the runtime's `omarchy-powerprofiles-floor` (omacom/omarchy#18745), which Omarchy 4.5.0 may not ship; revisit with a J714s measurement |
| aura #260 M4 ANE preload hand-off (erikwb) | M4 (T8132) only |
