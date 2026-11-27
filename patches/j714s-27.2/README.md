# J714s on the macOS 27.2 stub (one image line)

Kernel and Aura for the one J714s (14" MacBook Pro, M5 Pro, T6050) Omarchy image on Apple's
non-beta firmware 27.2: restore image `UniversalMac_27.2_26B123_Restore.ipsw` (sha256
`6613b34e...8534f`), J714s boot firmware `mBoot-20457.41.3`. Stage 1 is Aura as a padded Mach-O
boot object with no `__TEXT_BOOT_EXEC` (`kcbz` 0, so iBoot does not start SPTM), enrolled with
`kmutil configure-boot --compress` after `bputil -nc`; Linux runs at EL2 on every CPU inside the
128 MiB code-execute window, as aurora-silicon targets 27.2 (`docs/move-to-27.2.md`).

Status (2026-11-16, latest): v272-18 = v272-17 plus 0021 (FatBoy721, PR #26 for #22): after an s2idle the T6050 fixed HDMI
output on dcpext3 is set up again (`dcp_fixed_hdmi_sleeps()`; the atc3 crossbar output selected again before the HPD
sample reconnects). Same pin `677be395b9d2`, no re-pin; 0001-0020 unchanged (only their `[PATCH n/21]` numbering).
diffconfig empty, `CONFIG_APPLE_SOC_SLEEP` still off, DTBs byte-identical to v272-17's. Built, not booted. Package
`linux-aurora-7.3.0.aurora17.v272-18-aarch64.pkg.tar.zst`, sha256 `f63f3a040389e330160bf59fb1af54cd37b26603ecaba592bc646938e5726712` (44466134 bytes).

Previous: v272-17: re-pinned to aurora-silicon/linux `integration/aurora` `677be395b9d2`
(53 commits past `6e2043af8c5e`: #2046 #2084 #2053 #2057 #2073 #2079 #2080 #2056 #2055 #2067, G17 #1978 #1979 #2052
#2066 #2076, #2064 #2005). No patch dropped (`git cherry` all "+"); series 0001-0020 unchanged, range-diff "=" for 0002-0020.
One both-sides edit in 0001 (#1173), composed: #2080 removed `Board::calibration` and the calibration gate in
`g17/initdata/m5.rs`, #1173 binds the same value to `controller_defaults` for its `relayout_m5_policy`; the composition is
`let controller_defaults = board.controller_defaults;`, so #1173's 26B123 controller words now follow #2080 onto every J714
part (owner's call to keep). Context-only: `variant.rs` (#1978's `objects_after_release` beside `m5_layouts`, M5 variants
inherit `false`) and `fw/m5/initdata.rs` (#2080's doc comment after #1173's `m5_policy_source`). Deep sleep driver still off
(`CONFIG_APPLE_SOC_SLEEP` not set, `[s2idle]` only), diffconfig empty: #2046/#2084's router sleep in place, #2073's GPU floor
raise, #2066's wake queue restore and #2053's teardown are deep-sleep only (idle or compiled out). Live in s2idle: #2046's DT
binds the right port's PCIe tunnel DART at probe, so a right-port tunnel whose link is not kept now refuses s2idle (-EBUSY).
J714s DTB: #2079 (DP audio on dcpext1/dcpext2), #2073 `apple,sleep-ps-min`, #2046 PS_PROT/`apple,cio-phy`/clock protection;
HDMI on dcpext3 untouched (no audio port, as before). Built, not booted. Package
`linux-aurora-7.3.0.aurora17.v272-17-aarch64.pkg.tar.zst`, sha256
`6d7adebd0b3602af99e7b6bca2b3f130d60b11b6067f09e30a4b5b51522f52ed` (44463376 bytes).

Before that: v272-16: re-pinned to aurora-silicon/linux `integration/aurora` `6e2043af8c5e`
(48 commits past `6612865ee100`); #1921 and #1930 merged upstream, so the old 0020-0024 are dropped (patch-identical per
`git cherry`) and the old 0025 is replaced by #1930's merged `56793eff52dc`, which differs from ours (it also watches a tiled
split's second tunnel and runs only on T6050). The series is now 0001-0020: 0001-0019 as before, old 0026 (#1721) is 0020.
One context conflict: 0001 (#1173) in `g17/fw/variant.rs`, where #1981 added `render_id_at_create` beside #1173's
`m5_layouts`; both are kept, and the 27.2/27.3 M5 variants inherit `false`. New upstream: #2006 (dcpext1 also gets a
tunnel-only route to the left-front port, plus that router's DP IN interrupts), #2034 (tunnel-only routes first), #2032
(external EDID defaults), #2031 (J714s resume tail: N1 link watch, SD reader port after the resume, cd321x wake state), #2045
(ATC USB2 restart), #2047 (SN201202x probe retry with a reset), G17 changes and other boards' DT. HDMI on dcpext3 does not
clash with #2006 or #1921 (see "HDMI and #1921"). Deep sleep driver still off (`CONFIG_APPLE_SOC_SLEEP` not set, `[s2idle]`
only); no Kconfig changes upstream, diffconfig empty. J714s DTB: only #2006 changed (tunnel-only routes 1 -> 2). Built, not
booted. Package `linux-aurora-7.3.0.aurora17.v272-16-aarch64.pkg.tar.zst`, sha256
`d8eda4d5f891c98a2e9b6d80fe7fab5a2c7239727a9a5abdd936a81ae02a5119` (44405999 bytes).

Before that: v272-15: re-pinned to aurora-silicon/linux `integration/aurora` `6612865ee100`
(37 commits past `c0a2a7522b4e`); 6 patches dropped as upstream (patch-identical per `git cherry`): old 0024 #1944
(`7a479d4a41c9`), 0028 #1789 (`f61eb4550a95`), 0029-0030 #1647 (`aa16d423cf8a`, `70bf8ed1867b`), 0031 #2012
(`56b02059cfc8`), 0032 #2018 (`64d473f5321d`). Deep sleep driver still off (`CONFIG_APPLE_SOC_SLEEP` not set,
`mem_sleep` offers `[s2idle]` only); built, not booted. The series is now 0001-0026: 0001-0023 unchanged, old
0025-0027 renumbered 0024-0026 (#1930, #1721). One context conflict: 0026 (#1721) in `tps6598x.h`, where #2039
(the J714s MagSafe port registered again) removed `sleep_only`; only `ldcm_requested` is added now. New upstream:
DjDeveloperr's J714s deep-sleep completion (#2027-#2030: display coprocessor restart during the wake, its DART and
power words, the J714s deep-sleep SoC data; the DCP wake code is built only with `CONFIG_APPLE_SOC_SLEEP`, so it is
compiled out here, and its entry points are gated on `pm_suspend_via_firmware()`), dwc3
teardown out of the PM notifier chain (#1947), the rtkit crash log, the merged-mode platform limit (#2035; it
withdraws pair-only modes only with three external displays), the DP tunnel clock (#2036), DPTX DP IN naming
(#2037), the host DP IN bandwidth allocation (#2038), the ATC tunnel PHY (#2033) and the MagSafe port (#2039).
No Kconfig changes upstream: the resolved config equals v272-14's (diffconfig empty). J714s DTB vs v272-14: 89
lines added, none removed, all #2030's sleep data; fan-manual-control, PMP and ATC usb-aon (atc1/2/3) always-on,
the HDMI nodes and the tunnel-only route as before. Package `linux-aurora-7.3.0.aurora17.v272-15-aarch64.pkg.tar.zst`,
sha256 `67863904c81ca6befdec60939b24c5b386307b33c5f226389cfece44e4521611` (44392032 bytes).

Before that: v272-14: v272-13 plus chrisohearn's 38 network options (#19); built, not booted.
Same pin and series as v272-13 (patch byte-identical); only `config` and `j714s-required.config` change (BBR, fq,
fq_codel, cake, policy routing, connmark, MARK, MASQUERADE/NAT/REDIRECT/TCPMSS, BNEP, the ufw IPv4/IPv6 matches).
The resolved config differs from v272-13's in exactly #19's 57 symbols; 21 modules added, none removed; all DTBs
byte-identical to v272-13. Package `linux-aurora-7.3.0.aurora17.v272-14-aarch64.pkg.tar.zst`, sha256
`a19d0bc3a5d8312565860f33f8e4bef1f73a2ab2aaa5d222585eabff54d1543e` (44369616 bytes).

Before that: v272-13: #2018 reworked as Isaac-Duarte's DT change, #2012 updated,
#17 as a DT always-on for the HDMI PHY (already in the tree, so no new patch); built, not booted. Same pin as v272-12 (`c0a2a7522b4e`);
0001-0030 unchanged. 0031 is #2012's current last commit `56b02059cfc8` (`af590f044ca2` with
only its commit message changed: it now points at the DT change instead of the PHY hold; the code
is identical). 0032 is #2018's new single commit `64d473f5321d` ("arm64: dts: apple: t6050: keep
the ATC usb-aon power domains on", Isaac-Duarte, unchanged): `apple,always-on` on every T6050 ATC
usb-aon domain. It replaces the old 0032 (`ad7f44429aab`, the PHY-side s2idle hold), so
`atc-t6050-dp` is upstream's source again, as Isaac asked for the re-test on #2018.
**betizzel's 0033 (#17) is dropped, and no DT 0033 replaces it.** His patch gave the HDMI
converter's DP-only PHY (ATC3, `apple,t6050-dp-phy` at `0x38b000000`) the old 0032's notifier
hold. That notifier is gone with #2018's rework. The DT form of his fix, in the spirit of #2018,
is ATC3's usb-aon (`ps_atc3_usb_aon`, `power-controller@190`, the PHY's first power domain)
`apple,always-on`, and that is already in the tree twice: #1963's `t6050-j714s-sleep.dtsi`
(upstream since the v272-12 re-pin) and #2018's `t6050-die0.dtsi` line. v272-12's DTB already
had it; v272-11's, where betizzel saw the `bank39+4` timeout, did not. So HDMI across s2idle
in v272-13 behaves as in v272-12. The HDMI lid test is the first test of usb-aon alone for the
DP-only PHY: betizzel's patch also held `common` and `wrapper`. If HDMI still fails after a
sleep, his analysis (PR #17) is the starting point for holding more than usb-aon.
Package `linux-aurora-7.3.0.aurora17.v272-13-aarch64.pkg.tar.zst`, sha256 `849c7e5f743e72993ffbb6dc3a478a801b04069e6001856c50defdcc264a68f8` (44292311 bytes);
self-tests: J714s DTB has `apple,always-on` on atc1/atc2/atc3 usb-aon (`power-controller@{160,178,190}`), `atc-t6050-dp` built from
the pin's source (no `combo_s2idle_hold`), #2012's J714s allowlist in pcie-apple, release `7.3.0-17.v272-13-ARCH`.

Status (2026-11-15): v272-12: v272-11 plus the J714s s2idle stack #1647/#2012/#2018; built, not
booted. Re-pinned to upstream `integration/aurora` `c0a2a7522b4e`, which carries DjDeveloperr's
T6050 sleep series #1963 that #2018 is built on. The series is rebased onto it. 0029-0032 are
Jens Axboe's #1647 at `70bf8ed1867b` (two commits), Isaac-Duarte's #2012 last commit
`af590f044ca2` and his #2018 at `ad7f44429aab`, all unchanged. Dropped because upstream now
carries them: the old 0029-0031 (G17 #1925/#1946/#1948) and 0032 (#1950 fast-die). The recipe
config leaves `CONFIG_APPLE_SOC_SLEEP` off, so `/sys/power/mem_sleep` offers `s2idle` only.
Package `linux-aurora-7.3.0.aurora17.v272-12-aarch64.pkg.tar.zst`, sha256 `d2dcbe315bd5577367ff405e19f6d91506c4914bd7fa3f5d66d38349c301a4fb` (44289449 bytes).

**v272-12 booted on TripleU613's J714s, 2026-11-15** (fresh release-6 install, firmware j714s13): 44 s boot, no failed units, `mem_sleep` offers only `[s2idle]`, the rebuilt `atc-t6050-dp` loaded. **Lid sleep works:** two s2idle cycles by lid close/open (3 s and 3 min 37 s), `suspend_stats` success 2 / fail 0; after the wake panel, Wi-Fi, Bluetooth, sound and speaker protection back, and on the left-front and right USB-C ports a charger charged and a USB device enumerated (the left-back/DFU port gives no response, as before; #2017). Test reports: aurora-silicon/linux #2012, #2018, #1647. Not tried: a dock or display across a sleep, long sleeps.

Status (2026-11-14, latest): kernel v272-7 is v272-6 plus the firewall matches (`xt_hl`,
`ip6t_rt`: ufw's IPv6 rules), same sources and patches. **Booted on TripleU613's J714s on 2026-11-14** (installed by
package over release 4): sound cards, Neural Engine device and ufw up at boot. External displays
on a Samsung Odyssey G9 (G91SD), seen by the owner: HDMI (FatBoy721's v2) at 5120x1440 at 60, 120
and 144 Hz and at 3840x2160 at 60 Hz (that 4K mode stayed blank with v1 on v272-4); USB-C
DisplayPort at 5120x1440 at 144 Hz, 10-bit with DSC, after a replug (plugged in at boot it was
not detected once; on v272-4 the same port only offered 640x480-class fallback modes). Two
`link fault 22` lines still show at plug-in. Not tried: a dock, three displays (#1921), and the
merged-mode fallback. Package
`linux-aurora-7.3.0.aurora17.v272-7-aarch64.pkg.tar.zst`, sha256 `96d8f4b0...1620d2aa`.

Status (2026-11-14, later): kernel v272-6 is **built, not booted** (not installed, not in any
release). It replaces v272-5, which was never installed. It re-pins the kernel to upstream
`a5ebec5fd092` (Ryan Murray's revert of the GPU deferred BO cleanup drain, the H17 ANE work, DCP
fixes) and adds Isaac-Duarte's #1921 (a third dock display on the right port) as 0020-0023.
**Decide before installing:** with 0017's HDMI on dcpext3 and #1921's route on dcpext1, no
external output has a merged-mode peer left (see "HDMI and #1921" below). See the v272-6 notes
under "Packages".

Status (2026-11-14): kernel v272-5 was **built but has not been booted or installed** (superseded by v272-6). It re-pins
the kernel to upstream `a31b32f72efd`, drops 0019 (upstream now carries #1645) and replaces
FatBoy721's HDMI v1 hold with his v2 plus his IRQ_HPD forwarder. See the v272-5 notes under "Packages" below.

Status (2026-11-13, later): release 3 (`omarchy-j714s-3`) is release 2 plus kernel v272-4 (0019,
Jens Axboe's AOP fix #1645: the 27.2 sound cards, microphones and AOP sensors) and
omarchy-aurora-firmware j714s9 (loads `aop` at boot on the J714s).

Status (2026-11-13): release 1 (`omarchy-j714s-1`) installed and enrolled correctly, then looped
at the logo: its Aura (main 2232ae7a) handed U-Boot a powered-off NVMe controller (aura #213,
`docs/install-failure-2026-11-13.md`). With a #213 Stage 2 the 27.2 stub booted on TripleU613's
J714s (15 CPUs at EL2, GPU 26B123, 120 Hz display through the DCP, Wi-Fi, camera) and gave the
27.2 ANE TEXT pin. Release 2 (`omarchy-j714s-2`) carries kernel v272-3 (that pin and FatBoy721's
HDMI) and Aura v272-3 (#213, HDMI PHY tunables); neither has booted yet. The kernel also keeps
every 27.3 beta 1 row, so it can be RAM-tested on a 27.3 setup first.

Recipes: [`installer/recipes/linux-aurora-j714s`](../../installer/recipes/linux-aurora-j714s)
(`linux-j714s-27.2.patch` is `linux/*.patch` concatenated) and
[`installer/recipes/m1n1-aurora-j714s`](../../installer/recipes/m1n1-aurora-j714s)
(`aura-j714s-27.2.patch` is `aura/*.patch` concatenated).

## v272-26 (2026-11-27): speaker sense from a driver-owned ring (0014-0017)

Same pin (`7f00dc6bc52c`). 0014-0017 are aurora-silicon/linux #3084 (Erik Bourget, merged on main
2026-11-26, after our pin), the four commits unchanged; with them `t8152_aop_audio.rs` is byte-identical to
upstream main's. Before, the 12 V/I sense words of the J714s's six amplifiers kept whatever word offset the
ADMAC restarted at when PipeWire restarted the sense capture under a running serializer, so speakerguardd v2
modelled each speaker from another amplifier's voltage and current until the next restart. On our J714s, a
tone test with the sense read from the protect stage's input (4 kHz on one side, PipeWire stalled 150 ms to
force restarts): v272-24 held shifts of 2, 3, 4, 6 and 10 (0 is right); v272-26 held 0 in every steady
stretch, over two runs and six forced restarts. After 2 of those 6 restarts the shift was off for under a
second (4, then 2) and came back to 0 with no further restart; to report on #3084. Amp fault status 0 on all
six amplifiers in both kernels.

## v272-21 (2026-11-26): re-pinned on aurora-silicon/linux main `7f00dc6bc52c`

98 merged upstream PRs since `7a4afed5b4d1` (list in docs/work/release-11.md). The same 11 patches; 0010
conflicted with upstream's K114 macaudio entry in the same table. The two configs were identical, so the J716
compatible now uses `macaudio_k114_cfg` and our duplicate struct is gone. Booted on the J714s 2026-11-26
(docs/work/release-11.md).

## v272-20 (2026-11-25): re-pinned on aurora-silicon/linux main `7a4afed5b4d1`

Adds #2190 (WFI idle once built-in drivers probe), #3110, #3120 and about 100 other upstream commits. The
same 11 patches; 0006 needed a context-only fix (upstream's `WRITE_ONCE(dcp->pipe_off, false)` sits on the
line where 0006 adds `dcp_hdmi_hold_presents(dcp, "power on")`; both kept). Booted on the J714s 2026-11-25
(docs/work/release-10.md).

## v272-19 (2026-11-24): re-pinned on aurora-silicon/linux main `0c1f7e707784`

The 26 patches of v272-18 (plus #30-#32) were rebased from `677be395b9d2`; 11 remain. Upstream now
carries the 27.2 GPU, ANE and K114/K116 identities, the IRQ_HPD forwarder, #1721 and a new camera tuning
(#2233), so those patches are gone. Decisions taken here (the "NEEDS DECISION" rows below): the camera
follows upstream #2233 (setfile 2224_01, computed noise reduction, binned config 8) and the old 0007-0013
are dropped, so **the camera's green light stays off** (upstream shows an indicator on the display
instead); 0014 (VRR, off since j714s15, #25) and 0006 (27.3-beta ANE) are dropped; 0009 (LSC 84, scene
metering) is dropped as untested with #2233. The first base, `93e92d293a25`, did not build
(`drm/asahi/m3/m3_recovery.rs`); upstream's 5de20ebf39e5 fixed it, hence `0c1f7e707784`.

New numbering: 0001-0003 = old 0002-0004, 0004 = old 0015 (AVE half), 0005 = 0017, 0006 = 0018,
0007 = 0021, 0008 = 0022, 0009-0011 = 0024-0026.

| Old | New | Status |
| --- | --- | --- |
| 0001 GPU InitData 27.2/27.3 (rolotrealanis98) | - | DROPPED: upstream #1173 (merged 2026-11-24); same 26B123 G17S row, digest 2b4613c6...913f0fd9 identical. The 27.3 beta 1 (26C5035r) GPU row is not upstream (unused on the 27.2 stub) |
| 0002 fw27 adaptive sync parameter name | 0001 | applied clean |
| 0003 no panel brightness after a DCP crash | 0002 | applied clean |
| 0004 27.3 IOMFB method table | 0003 | applied clean |
| 0005 K114/K116 26B8125 G17S (axboe) | - | DROPPED: upstream #1650 (merged) |
| 0006 ANE on 27.3; AVE builds by TEXT CRC | - | NEEDS DECISION (proposed: drop). AVE-by-CRC is upstream (#1747 and later); ANE on the 27.3 beta is not upstream and does not port cleanly (ane_fw_platform redesigned by #1957). Only matters on a 27.3 stub |
| 0007 IMX958 setfile 2226_02 (edimoldovan) | - | NEEDS DECISION (proposed: drop). Upstream #2233 (Isaac-Duarte, merged 2026-11-20) keeps 2224_01 on every T6050, computes the noise-filter gains from lens shading for every setfile, and moves the J714s to binned config 8; measured on a J714s (luma noise 18.6 -> 1.2). Our J714s camera changes from 2226_02 to upstream's tuning |
| 0008 computed noise reduction radial gains | - | DROPPED: same technique upstream in #2233, for every setfile |
| 0009 LSC ideal percent 84 + FD scene metering | 0005 | ported: only `lsc_ideal_percent`/`ae_fd_scene_metering` kept in apple_isp_hw_t6050 (`imx958_2226`, `setfile_radial_gain` belonged to 0007/0008). Not tested with 2224_01 + #2233 |
| 0010 J714s 2560x1440 preset (config 6) | - | NEEDS DECISION (proposed: drop). Upstream moved the J714s presets to binned config 8 (1520x1440); a config-6 preset beside them mixes sensor modes |
| 0011-0012 camera light driven by the driver (edimoldovan) | - | NEEDS DECISION. Upstream added a best-effort software camera indicator via the DCP in the same place (isp-cam.c) with its own ISP watchdog handling; merging the hardware light pin into that design is new logic, not a port. The camera streams upstream without it (#2233 tested on a J714s); the green light stays off |
| 0013 J714s camera light DT | - | NEEDS DECISION: goes with 0011-0012 |
| 0014 VRR on the fw27 panel (rolotrealanis98) | - | NEEDS DECISION (proposed: drop). Upstream reworked VRR_ENABLED/adaptive sync (#3052 and others) in the same code; ours is off by default since firmware j714s15 (#25) |
| 0015 ANE + AVE on 27.2 | 0004 | ANE half DROPPED (upstream #1957: T6050 27.2 build with a code pin). AVE half ported: 26B123 (CRC 0xd33ed3b4) recognised, probe only unless apple_ave.ave_t6050_27_2_layout=1 |
| 0016 27.2 ANE TEXT pin b15dd8fb | - | DROPPED: upstream #1957 admits 26B123 with a code pin over TEXT with the loader-filled sections zeroed |
| 0017 J714s HDMI port DT (FatBoy721) | 0006 | applied clean |
| 0018 HDMI hold presents (FatBoy721) | 0007 | ported: conflict was 0014's VRR function in the context (left out); hold call placed before the new ext26 early return in iomfb_poweron |
| 0019 HDMI IRQ_HPD on T6050 | - | DROPPED: upstream dcp-hdmi.c now forwards IRQ_HPD for every coprocessor with a fixed HDMI-A connector and HPD GPIO |
| 0020 no LDCM to a dry SN201202x port | - | DROPPED: upstream #1721 (merged) |
| 0021 HDMI set up again after sleep (FatBoy721, #22) | 0008 | ported: resume calls dcp_fabric_hdmi_reinit() unconditionally (0021 gates it in dcp_fixed_hdmi_sleeps()), upstream's new dcp_hdmi_unplugged_in_sleep() call kept |
| 0022 N1 WPA/WPA2 mixed (ja-818) | 0009 | applied clean |
| 0023 IMX958 setfile by board (ja-818) | - | DROPPED: built on 0007's imx958_2226; upstream already selects 2224_01 (what the J716s wants) on every T6050. 0024's `apple,imx958-setfile = <0x2224>` is now an unread property and its comment about imx958_setfile=0x2226 is stale |
| 0024 J716s front camera DT | 0010 | applied clean |
| 0025 J716 macaudio, jack only | 0011 | applied clean |
| 0026 J716s AOP, jack, mics, light sensor | 0012 | applied (on top of 0024, as fixed in d7fe51d) |

Tested on our J714s (unattended boot, 2026-11-24): boots by itself, no failed units, 15 CPUs, GPU firmware
admitted at once (v272-18 logged 14 "not admitted" errors first), Hyprland on the GPU at 3024x1964@120,
Wi-Fi (CCMP network) and Bluetooth, AppleJ714 and DisplayPort sound cards, speakerguardd v2 running,
camera streams 1080p on 2224_01, ANE device present. Not yet: s2idle and HDMI after a sleep (need the owner).

## Bases (kernel re-pinned 2026-11-14 for v272-6; Aura as of release 2)

- **Kernel (v272-6):** aurora-silicon/linux `integration/aurora` at `a5ebec5fd092` (2026-11-14,
  after #1926), 52 commits past `a31b32f72efd`. New there and so in v272-6: Ryan Murray's revert
  of "drm/asahi: drain deferred BO cleanup after immediate GEM close" (018c588abf87; v272-5 still
  had the reverted change); the H17 ANE work: an H17 task stream that opens with 1 (37796b7b114b,
  Joshua Warren), programs from Apple's zin_ane_compiler 10.205 (aff6fcc1120b, Nick) and the
  T8142 (M5) ANE (79e1e9f88449, b0f0900a9af0, f3dc931ecad9 and DT, Nick); DCP fixes by Ryan
  Murray (no warning for a brightness change pending while the panel is off, 629e81bc2dd6; the
  slot of a re-announced singleton compact service, 31db2f51a049) and `update_notify_clients` as
  client flags (#1891, 9cc4c9d79ea0); G17 GPU scheduling work (shared UAT execution context per
  VM, compute input ordering, watchdog reason; Diljit Singh); Thomas Glanzmann's macaudio fixed speaker ceiling
  (8360c9788f29: no machine sets it, so nothing changes on the J714s); T8132/T8142/T6041 DT work
  that does not touch the J714s. No Kconfig file changes.
- **Kernel (v272-5):** aurora-silicon/linux `integration/aurora` at `a31b32f72efd` (2026-11-14,
  after #1866), 190 commits past `a34d26c2`. New there and so in v272-5: Jens Axboe's AOP endpoints
  (#1645, commit 367e36d02939, was our 0019); DjDeveloperr's T6050 GPU mailboxes by interrupt
  (#1844; the J714s GPU mailbox nodes already carry their send-empty/recv-not-empty interrupts);
  joshuaswarren's firmware 27 mode gate (a4a0fb67bfe8, 3176918ba21e, 84b3b93c04e6: the T6050
  internal panel, `apple,t6050-dcp`, now lists **only its 120 Hz mode**, by upstream's choice;
  external `apple,t6050-dcpext` outputs, HDMI included, keep every mode); Mariano Miguel's die0
  range over the ISP watchdog (403f0bc409ed); the T8142 AVE (55b7401a4b03) and ce546479986d's
  refused-session message; Satya Benson's ISP exposure bound (8f9ffa30bbfb); K116s/J713/J575c
  work that does not touch the J714s. No new Kconfig symbols (one help-text change).
- **Kernel (v272-2 to v272-4):** aurora-silicon/linux `integration/aurora` at `a34d26c255c2` (2026-11-13, after #1752).
  Already merged there and so in the image: DjDeveloperr's display ADMAC and firmware 27 DisplayPort
  audio (#1748, #1749) and the J714s dcpext0 DP audio node (#1750); the J714s left-front USB-C
  USB4/Thunderbolt router (#1791) and the J714s camera sizes from sensor config 6 (#1835); the
  J714s Secure Enclave (#1325) and SEP sse/skdl/hibe (#1763); CLPC floors and sampling (#1324,
  #1555, #1556) and platform profiles (#1655, #1656); the T6050 CPU PMU (#1628); JPEG encode
  (#1675); ProRes (#1586; no T6050 init rows public, so it stays unused); the MagSafe PD
  controller (#1686); USB4 and external displays (#1515 and follow-ups), tiled 5K displays
  (#1634, joshuaswarren); the SEP pnon digest and trusted-accessory service (#1720, #1734);
  joshuaswarren's GPU mailbox polling (#1601); erikwb's #1608/#1609 and GPU GEM residency
  (#1610), GPU stats (#1611) and the compute timeout (#1752); Jens Axboe's T6050 EL2 errata
  (#1724, was our 0006-0007), the appledrm combo-PHY softdep (#1745, was our 0017) and the
  27.3 AVE build (#1747, was half of our 0008).
- **Aura:** aurora-silicon/aura `main` at `22b71758` (2026-11-13). Includes DjDeveloperr's display
  ADMAC tunables for DP audio (#207), sithglan's chainload copy stub (#186), the MTE tag store
  (#184), the M5 Pro boot path (#173), `firmware: add macOS 27.2` and `27.3 beta` (#216), the
  ANE/AVE hand-offs (#169, #171), the T6050 storage auto-PM fix (#203, was our 0006), the K116s
  26B8125 GPU build (#187, was our 0007) and the T6050 camera table (#188, was our 0004), post-M4
  ANS for the payload (#213) and the K114c camera (#206). The Stage 1 tooling and config layout
  are unchanged since 2232ae7a: the engine's fill is byte-identical to Aura's
  `fill_stage1_config.py` on this build, `aura-boot.macho` passes the layout check, and the padded
  object has kcrz 153141248, as before.

Release 1 was built on linux `572eb88e8642` and Aura `2232ae7a` (git history of this file).

## Kernel patches (`linux/`, apply in order with `git am` or `patch -Np1`)

| # | What | Whose |
| --- | --- | --- |
| 0001 | GPU InitData and firmware identity for 27.2 (26B123) and 27.3 (26C5035r), aurora-silicon/linux #1173 (open), resolved against the Graph refactor; v272-17: `initdata/m5.rs` composed with #2080 (no calibration gate, `controller_defaults` applies on every part). The 26B123 fwid digest `2b4613c6...913f0fd9` was re-derived from the IPSW (below) | Rolando Trevino (rolotrealanis98) |
| 0002-0004 | Firmware 27 adaptive-sync parameter name; no panel brightness after a DCP crash; the full 27.3 IOMFB method table and swap record (only used on a 27.3 stub; 27.2 uses upstream's `dcp_methods_27_2`) | Rolando Trevino |
| 0005 | The K114/K116 27.2 (26B8125) G17S identity, #1650 (open) | Jens Axboe (via sithglan) |
| 0006 | ANE on 27.3; AVE builds selected by TEXT CRC on top of #1747 (27.2 and 27.3 share segment sizes) | this repo |
| 0007-0009 | Front camera: IMX958 setfile 2226_02, noise reduction gains, lens shading target and metering (omacom/linux-aurora #422) | Eduard Moldovan (edimoldovan) |
| 0010 | 2560x1440 added to #1835's J714s presets (config 6, the centre 1:1) | this repo, from edimoldovan's J714c preset |
| 0011-0013 | The camera light and its J714s pin (#422; J714s DT by this repo) | Eduard Moldovan; this repo |
| 0014 | VRR on the firmware 27 panel, `appledrm.fw27_panel_vrr` (j716s-next 8ab10100a4); off by default since omarchy-aurora-firmware j714s15 (it crashed the K114s DCP on 27.2, #25), and not proven on 27.2 elsewhere | Rolando Trevino |
| 0015 | ANE and AVE on 27.2 (26B123): layouts from the IPSW. ANE: 27.2 layout recognised, refused until its TEXT pin is known, and the refusal prints the digest. AVE: 26B123 admitted, probe only unless `apple_ave.ave_t6050_27_2_layout=1` | this repo |
| 0016 | The 27.2 ANE TEXT pin `b15dd8fb...c40e`, read from the first J714s 27.2 boot's refusal | this repo |
| 0017 | **J714s HDMI port** (DT): dcpext3 → the atc3 display crossbar → ATC3 as a fixed four-lane DP PHY → the on-board DP-to-HDMI converter; frees AOP pin 14 (HPD) from `t6050-max-atc2.dtsi`'s reserved range, atc3_dpxbar power domains. Tested on his J714s on 27.3 (HP E240c, 1920x1080@60: cold plug, hotplug, replug); not tried on 27.2. His `0010-linux-t6050-j714s-hdmi-dt.patch` at 267c7ea3cb gives a tree identical to this one | FatBoy721 (FatBoy721/omarchy-m5 898d8ad6cb), ported unchanged |
| 0018 | **HDMI v2 hold** (v272-5, replaces v1): while a T6050 fixed HDMI output connects (sink at boot, power-on, HPD edge) complete its flips locally for 8 s, so a present the DCP swallows during the monitor's wake HPD cycle can't time out the IOMFB queue and leave the DCP crashed. Per-DCP state, only `apple,t6050-dcpext` with an HDMI HPD GPIO; `appledrm.hdmi_hold_presents=0` turns it off. Tested on his J714s on 27.3 | FatBoy721 (`j714s-hdmi-upstream273` 267c7ea3cb, his 0012 v2), applied unchanged |
| 0019 | **HDMI IRQ_HPD** (v272-5, new): `dcp-hdmi.c`'s converter IRQ_HPD forwarder enabled for `apple,t6050-dcpext` as macOS does on the J714s (T6030 only before). Booted on his J714s on 27.3, no visible change on its own | FatBoy721 (267c7ea3cb, his 0013), applied unchanged |
| 0020 | No LDCM command to a dry SN201202x port, as macOS (`ldcm_requested`); v272-15: `tps6598x.h` context follows #2039. Old 0026; the PR head `de9a01da6442` has the same patch-id | DjDeveloperr (aurora-silicon/linux #1721, open) |
| 0021 | **HDMI after a sleep** (new): after an s2idle the atc3 crossbar wakes with its select register cleared and the HDMI link never trains (faults 22/24, #22). The fixed-HDMI re-setup that `dcp_platform_resume()` ran only for the T6030 (`external_native`) now also runs for `apple,t6050-dcpext` (`dcp_fixed_hdmi_sleeps()`): converter power enables, crossbar output deselected and selected again, before the HPD sample reconnects. Tested on his J714s: stock reproduces #22, with the patch HDMI is back 1 s after each of two wakes, replug and cold boot fine | FatBoy721 |
| 0022 | **N1 joins WPA/WPA2 mixed networks** (new): accept a TKIP group cipher with CCMP as the only pairwise cipher (a common ISP router default); pairwise TKIP and SAE with a TKIP group stay refused, and the firmware still runs the handshake and installs the keys. Tested on a J716s with v272-17 as a module (#28); not tested on a J714s | ja-818 (aurora-silicon/linux #2872, open) |
| 0023 | **J716s camera, setfile by board** (new): the IMX958 setfile can be named by the board's tree (`apple,imx958-setfile`), the SoC default otherwise; `apple_isp.imx958_setfile=` for A/B. The J716s runs 2224_01. Seen on one J716s | ja-818 |
| 0024 | **J716s front camera** (new): the shared T6050 ISP nodes (upstream #2275 adds the same include), the camera light, 1080p/720p presets on config 5, setfile 2224. Seen on one J716s: streams with the light on | ja-818 |
| 0025 | **J716 macaudio entry** (new): jack only, speakers refused (no safe level, speakers disabled, as the J873) | ja-818 (aurora-silicon/linux, to be opened) |
| 0026 | **J716s AOP, jack, microphones, light sensor** (new): the J714s's nodes checked against the J716sAP ADT (upstream #2285 and #2277 add the same), a jack-only card, the six amps not described and their shutdown line (AP pin 107) held low. Seen on one J716s: jack plug detected, mics record, light sensor reads; jack playback not listened to | ja-818 |

Dropped in v272-16 (upstream merged them): old 0020-0023 (#1921: own tunnel slots for DP IN 2/3, `apple,tunnel-only`
routes, dcpext1 on the right port) and old 0024 (#1930's first commit), all patch-identical per `git cherry`; old 0025
(#1930's second commit) is replaced by upstream's merged `56793eff52dc`, which differs from ours:
`dcp_tb_tunnel_withdrawn(dcp, port)` also watches the tunnel of a tiled split's second tile (port 1, `split.binding`), and
the watch runs only on T6050 (`dcp_watches_tunnel_withdrawal()`).

Dropped in v272-13: the old 0032 (#2018 at `ad7f44429aab`, the PHY's s2idle domain hold), replaced
by #2018's DT commit `64d473f5321d`; and 0033 (betizzel/omarchy-m5#17, the HDMI DP-only PHY's hold
on that notifier), whose DT equivalent (ATC3 usb-aon always-on) the tree already carries (#1963,
#2018). Credit for the HDMI analysis stays with betizzel (#17).

Dropped in v272-5: the old 0019 (AOP endpoints, Jens Axboe's #1645, ported by sithglan) is
upstream as 367e36d02939 (our patch reverse-applies cleanly on `a31b32f7`); the old 0018 (HDMI v1 hold) is replaced
by FatBoy721's v2 (new 0018). Rebased with `git am -3`; `git range-diff` shows 0001-0005,
0007-0014, 0016 and 0017 unchanged. Two context conflicts, both keep-both merges: in 0006
(`ave-sess.c`) the HEVC refusal for 27.3 now follows upstream's new "only 30 fps with 3 B-frames"
`dev_info` block; in 0015 (`ave-fw.c`) the 26B123 TEXT CRC row sits beside upstream's new T8142
row in `ave_known_text_crc[]`. Upstream's 120 Hz-only gate (`dcp_mode_settable()`) and 0014's
VRR do not fight: VRR fills only `min_vrr`, the panel timing's `drm_mode_vrefresh()` stays 120,
and the VRR switch reselects that same mode.

v272-6: nothing dropped (none of 0001-0019 is upstream; #1173 and #1650 are still open). Rebased
with `git am -3`; `git range-diff` shows 0002-0005 and 0007-0019 unchanged. 0001 has only a
context change (upstream's new `traversal_exclusion` field in `variant.rs`; our 26B123/26C5035r
variants inherit it from `V26A428_M5`). 0006 conflicted with upstream's T8142 ANE work in
`ane_fw_handoff_present()` (`ane_fw_cold.c`) and was merged by hand, keeping both: upstream now
hashes the handed-off TEXT even when the layout is not this SoC's and prints the digest and the
layout; 0006 picks the TEXT pin per admitted build. The merge hashes whenever the reservations
are present, admits only a build's pin, and folds 0006's "no admitted build has TEXT ..." line
into upstream's layout line ("layout as expected" / "no admitted build has this layout").
Isaac-Duarte's #1921 (0020-0023) applies without conflict on top: none of its files changes
between its base `7c71d6df6563` and `a5ebec5fd092`.

**HDMI and #1921 (the decision to take before installing).** `t6050-j714s-display.dtsi` is
touched by 0023 (dcpext1's route, hpm2 `endpoint@2`); 0017 adds its own
`t6050-j714s-hdmi.dtsi` (dcpext3, atc3) and does not touch the same nodes, so the two apply and
compile together. They interact at run time: a merged-mode peer (the second pipeline for a mode
wider than one engine, such as 3840x2160@240) must have no Type-C routes and no fixed PHY
(`dcp-peer-v27.inc`), and dcpext0 may pair with dcpext1/2/3, dcpext1 with dcpext2/3, dcpext2
with dcpext3 only. With 0017 dcpext3 is the HDMI engine (fixed PHY); with 0023 dcpext1 is
routed. So in v272-6 **no external output has a peer**: such modes fall back to single-engine
modes ("no eligible idle peer"). In v272-5 dcpext0 still had dcpext1; upstream with #1921 alone
keeps dcpext3 for all three. The comments in both DT patches ("dcpext0/dcpext1 keep theirs",
"pair with dcpext3") are each true only without the other. 27.2 runs the firmware 27 interface
(`DCP_FIRMWARE_V_27_0`), so this applies on our stub. Choices: keep both (HDMI plus a third dock
display, no high-refresh merged modes), drop 0020-0023, or drop 0017-0019.
v272-16: #1921 is upstream, and #2006 also gives dcpext1 a tunnel-only route to the left-front port (route@1, atc1
crossbar source 2, typec1 `endpoint@2`, acio1's DP IN interrupts). Neither touches the nodes 0017 changes (dcpext3,
atc3, atc3_dpxbar, AOP pin 14, `smc_pcio`, usb_drd3), and the HDMI path uses the atc3 crossbar, not atc1's or atc2's.
#2034's "tunnel-only routes first" rule looks only at a Type-C port's routes, which never include the fixed-PHY dcpext3.
So the picture above still holds: HDMI on dcpext3 plus up to three Type-C/tunnel displays, and no merged-mode peer for
any output. Upstream's comments in `t6050-j714s-display.dtsi` and #2034's message ("dcpext3 is the merged-mode peer",
"dcpext0, dcpext1 and dcpext2 then pair with dcpext3") are not true with 0017: here 4K240-class modes that need two
pipelines fall back to single-pipeline modes. The "0023" and "drop 0020-0023" above are the old numbers of #1921,
now upstream (0020 is now #1721); the remaining choice is keeping or dropping 0017-0019.

Camera presets: #1835 (DjDeveloperr, merged) gives seven sizes on config 6 (1920x1080, 640x480,
1280x720, 1760x1328, 1328x1760, 1552x1552, 1080x1920). Our release-1 presets (edimoldovan's
J714c ones: 1920x1080 and 2560x1440 on config 6, 1280x720 on config 7) were not a subset of
them, so #1835's replace them and 0010 adds back the one size it lacks, 2560x1440, in #1835's
form. On T6050 the driver uses `apple,input-size` only to bound the crop (the P010 matching that
compares it with the firmware's config is T6040-only), so both forms stream the same crop. All
eight sizes are untested on the 27.2 ISP firmware.

v272-6: `patch -Np1` of `linux-j714s-27.2.patch` on the `a5ebec5f` GitHub tarball (sha256
`6789feab...e8341ed`) gives the tree that was built, identical to ush `~/m5-build/up272-6/src`
(branch `up-2726`: the series as 23 commits on `a5ebec5fd092`). Config: unchanged.

v272-5: `patch -Np1` of `linux-j714s-27.2.patch` on the `a31b32f7` GitHub tarball (sha256
`14030d01...5c1d193b`) gives the tree that was built, identical to ush `~/m5-build/up272-5/src`
(branch `up-2725`: the series as 19 commits on `a31b32f72efd`). Config: unchanged.

v272-2 to v272-4: `patch -Np1` of that release's `linux-j714s-27.2.patch` on the `a34d26c2` GitHub tarball (sha256
`315c7a76...6d627f72`) gives the tree that was built (ush `~/m5-build/up272-2/src`, branch
`up-2722`). Config: unchanged; #1791 is device tree only. `j714s-required.config` also requires
`ARM64_CTXR_EXECMEM`, `APPLE_ADMAC` and `SND_SOC_APPLE_T8152_AOP_AUDIO`.

## Aura patches (`aura/`, `git am` on main 22b71758)

| # | What | Whose |
| --- | --- | --- |
| 0001 | T6050 GPU: the 27.2 (26B123) and 27.3 beta 1 (26C5035r) G17S rows in #187's build table; DCP hand-off on 27.3 beta 1 (`V27_3B`, #216) with compat `<27 3 0>` | this repo, values from #1173 (Rolando Trevino) |
| 0002 | Notch rows shown by default on M5 (`chosen.asahi,show-notch=0` opts out) | this repo, after FatBoy721/edimoldovan's m1n1 work |
| 0003 | The M5 Max 27.3 G17S digest (aura #172) | joshuaswarren |
| 0004 | J714s camera on 27.3 beta 1 (a row in #188's table) | this repo |
| 0005 | **Internal display on 27.2:** admit `V27_2`, publish compat `<27 2 0>` (the kernel's `dcp_methods_27_2` key), pin the 27.2 DCP image `C51FB0C8-C45D-39B0-85BC-520E600FC950` | this repo |
| 0006 | **J714s camera on 27.2:** sensor 0x74, the IPSW's ISP segments | this repo |
| 0007 | ATC tunables for a fixed DP PHY (`apple,t6050-dp-phy`, the J714s ATC3 behind HDMI), needed by kernel 0017. Tested on 27.3 with 0017 | FatBoy721 (060831d4f8), ported unchanged |
| 0008 | **K114s and K116s internal panel on 27.2:** aura #226's pin table, with the 26B8125 DCP image `3D6C8857-E6F1-3D2E-9DFF-587028AE0C6E` (the K116s's, and the K114s's on `dcp` and all four `dcpext`) admitted for the internal panel only; the external engines stay with iBoot. The 27.0 and J714s `C51FB0C8-...` rows, 0005's gate and its log lines are unchanged. Not booted in this form | Jens Axboe (aura #226, 023eb3a01a), adapted onto 0005 by chrisohearn |
| 0009 | **J716s camera on 27.2:** sensor 0x76, the J714s's ISP firmware (byte for byte in 26B123). Seen on one J716s. Upstream aura #362 replaces the board table | ja-818 |

The recipe also packages the Stage 1 tooling: `aura-j714s-stage1 --esp-partuuid UUID OUT` fills
the raw Stage 1 in place (Aura's `fill_stage1_config.py`, Stage 2 `m1n1/boot-ctxr.bin` by default)
and pads it with `macho_boot_object.py --execute-window`. A test object gave `kcrz 153141248`,
the value the 2026-11-07 padded trial on this J714s enrolled with; `--unpadded` makes the
rollback object. Nothing enrolls anything.

## 27.2 values, from the IPSW

Read on ush from the J714s identity ("Customer Erase Install (IPSW)", ApChipID 0x6050, ApBoardID
0x08) of `UniversalMac_27.2_26B123_Restore.ipsw`, with `pyimg4` and a Mach-O parser. Each method
was first checked against 27.0 (26A428, range reads), where the answer is known.

| Piece | Manifest member | 27.2 value | Method check on 27.0 |
| --- | --- | --- | --- |
| GPU | `Firmware/agx/armfw_g17x.im4p` + `armfw1_g17x.im4p` | G17S images `6299EB93-B771-3834-89CB-05410554188F` (TEXT 0x50000) and `28166DD7-1246-3583-A4AE-4B7CFD146DE5` (TEXT 0x54000); fwid digest with #1173's boot-filled ranges zeroed: `2b4613c62a8a007f22a94101702c9ac6c4e90f2e123f3b36fbe6ffea913f0fd9` = #1173 and Aura 0001 | - |
| DCP | `Firmware/dcp/t605xdcp.im4p` | image UUID `C51FB0C8-C45D-39B0-85BC-520E600FC950` | 27.0's pinned `64863924-...` is the Mach-O at 0x10f8608; 27.2's at 0x1114608, and each UUID appears at the same five payload offsets |
| ANE | `Firmware/ane/h17_ane0_fw_hyperion_j71y.im4p` | TEXT 0xbc000, DATA 0x2b0000 (span 0x36c000) | sizes match 27.0's row; the file's TEXT sha256 (`d4a64be9...` on 27.0) is **not** the preloaded pin (`93ae3a37...`), so the 27.2 pin can't come from the IPSW |
| AVE | `Firmware/ave/AppleAVE2FW_H17D.im4p` | TEXT 0x158000 CRC32 `d33ed3b4`, DATA 0x134000 | 27.0 TEXT CRC `87279429` = the kernel's constant |
| ISP | `Firmware/isp_bni/adc-nyx-sc7x.im4p` | TEXT 0xc1c000, DATA 0x13d0000, uuid `889F5ADB-BDE7-3B93-A531-24587C4CF3D5` | 27.0 sizes = Aura's pinned sizes |

## What the first 27.2 boot must collect

Everything below is fail-closed until confirmed: a mismatch refuses that one device and the boot
goes on.

1. `/proc/device-tree/chosen/firmware-version` (or Aura's log) = `mBoot-20457.41.3`, and "All
   CPU(s) started at EL2" on 15 CPUs, `/chosen/aurora,ctxr-exec-window` present.
2. **ANE TEXT pin.** Collected: `b15dd8fb...c40e` (0016, kernel v272-3). On the first v272-3 boot
   check `READY` and `/dev/accel/accel0`. Also
   log the ADT `ane0` segment-ranges from Aura (expect TEXT 0xbc000 at DVA 0x10000000000).
3. **DCP UUID.** Aura logs `DCP image <uuid>, firmware-compat 27.2.0` when it hands over, or
   `DCP image <uuid> is not C51FB0C8-...` when it refuses (simpledrm). If refused, the logged UUID
   goes into Aura 0005.
4. **GPU:** `GPU firmware build: 26B123 ... G17S`; the ADT `iop-gfx-nub`/`iop-gfx1-nub` `uuid`s
   should be `6299EB93-...` and `28166DD7-...`.
5. **Camera:** Aura's `isp0` sensor type (0x74) and segment-ranges (TEXT 0xc1c000, DATA
   0x13d0000, remap 0x10000000000 / 0x10000c1c000) and their physical addresses; `/dev/video0`
   streams at each of the eight preset sizes. The IMX958 setfile comes from the installed macOS's
   `appleh16camerad` (`aurora-j714s-camera-setfile.service` reads it at first boot, the camera has
   it from the next boot); whether a 27.3 setfile suits the 27.2 ISP firmware is untested.
6. **AVE:** `firmware build 26B123 (TEXT 0x158000 CRC d33ed3b4 ...)`, `probe only`. Then reboot
   with `apple_ave.ave_t6050_27_2_layout=1` and encode H.264 and HEVC (30 frames each, decode,
   PSNR) before making it the default.
7. **Wi-Fi port 0** (Aura's `storage after ...` lines), trackpad, NVMe, SError/Oops-free journal,
   and a reboot (`macsmc-reboot`; there is no PSCI reset under the window).


## Packages, release 2 (built 2026-11-13 on ush)

**v272-6 (built 2026-11-14, not in any release): built, NOT booted, NOT installed.** It
replaces v272-5, which was never installed. Full cross build on ush as for v272-5, in
`~/m5-build/pkg272-2/linux-aurora-j714s-v272-6` (log `build-v272-6.log`); `check()` 35 tests OK.
The compiler warning set equals v272-5's (35 lines, all in files the series does not touch; no
device tree warning for the J714s). Modules carry vermagic `7.3.0-17.v272-6-ARCH`; the file list
equals v272-5's. `t6050-j714s.dtb` has the HDMI nodes and #1921's `apple,tunnel-only` route with
hpm2 `endpoint@2`; `appledrm.ko` has `apple,tunnel-only` and the `hdmi_hold_presents` parameter.
To check on the first boot, beyond v272-5's list: the GPU without the reverted BO cleanup drain,
the ANE on 27.2 (the merged hand-off check in 0006), and with a dock on the right port a third
display on DP-5 (dcpext1); and that a mode wider than one pipeline now falls back (no peer, see
"HDMI and #1921").

| Package | sha256 | Bytes |
| --- | --- | --- |
| `linux-aurora-7.3.0.aurora17.v272-6-aarch64.pkg.tar.zst` (`7.3.0-17.v272-6-ARCH`) | `f75b8ba0f297f02a42ae7f841fb38ac45bfe7337a4c1c9da22356382dbe8f390` | 44219527 |

**v272-5 (built 2026-11-14, never installed, superseded by v272-6): built, NOT booted, NOT installed.** Full cross
build on ush (`OMARCHY_CROSS_KERNEL=1`, `makepkg --config ../makepkg-aarch64.conf -d -f`) of this
commit's recipe in `~/m5-build/pkg272-2/linux-aurora-j714s-v272-5` (log `build-v272-5.log`);
`check()` 35 tests OK; no C compiler warning in a file the series touches, and the Rust
`dead_code` warnings are v272-3's set plus two in upstream files (`mmu/context.rs`, `pgtable.rs`). Modules carry vermagic
`7.3.0-17.v272-5-ARCH`; the file list equals v272-4's; `t6050-j714s.dtb` has the HDMI nodes and
`appledrm.ko` the `hdmi_hold_presents` parameter. To check on the first boot, beyond the list
below: the internal panel at 3024x1964@120 (upstream now lists only 120 Hz modes there), the GPU
with #1844's mailbox interrupts on 27.2, the AOP sound cards with upstream's #1645, the camera
(upstream's ISP watchdog range with 0011's light-gated feeding), and HDMI v2 on 27.2.

| Package | sha256 | Bytes |
| --- | --- | --- |
| `linux-aurora-7.3.0.aurora17.v272-5-aarch64.pkg.tar.zst` (`7.3.0-17.v272-5-ARCH`) | `3ede08e66eced7c9811e5fdb11cae1e76a401f05e38669eb810d38a75feb04cd` | 44213354 |

**v272-4 (what release 3 ships):** the kernel adds 0019 (Jens Axboe's #1645, the 27.2 AOP), and
omarchy-aurora-firmware j714s9 loads `aop` at boot on the J714s (it is blacklisted for autoload so
it waits for the vendor firmware, and the J714s branch of `aurora-peripheral-firmware.sh` never
loaded it; now the root stage does, non-fatally). The kernel was built incrementally in v272-3's
build tree on ush (`makepkg -e` after setting `localversion.10-pkgrel` and `build/base/version` to
v272-4 by hand; `patch -Np1` of the new `linux-j714s-27.2.patch` on the tarball reproduces that
tree exactly); `check()` 35 tests OK. Every module carries vermagic `7.3.0-17.v272-4-ARCH`, the
file list equals v272-3's, and the packaged `aop.ko`'s `.text`/`.rodata` equal the build tree's
and those of the module tested on the J714s with `modprobe aop` (built in the same tree before
the version bump). The at-boot load from j714s9 has not run on the Mac yet. The firmware package was built in the Arch
Linux ARM container; only `aurora-peripheral-firmware.sh` differs from j714s8.

| Package | sha256 | Bytes |
| --- | --- | --- |
| `linux-aurora-7.3.0.aurora17.v272-4-aarch64.pkg.tar.zst` (`7.3.0-17.v272-4-ARCH`) | `964cd9a3e5863320ef11b272e34852a58e79f2c401b287163dcee79622bab246` | 44136582 |
| `omarchy-aurora-firmware-20261014.j714s9-1-aarch64.pkg.tar.zst` | `8170bde1480eba36936bd3c14612e43bb0521f611dfde1cea6c5b259b4e145c3` | 48022 |

**v272-3 (what release 2 ships):** the kernel adds 0016 (the 27.2 ANE pin) and FatBoy721's HDMI
(0017-0018), and comments in `speakersafetyd-hold.conf` (no longer citing `j714.conf`); Aura adds
FatBoy721's 0007. Cross-built on ush from the recipes in this commit; kernel `check()` 35 tests
OK, Aura `check()` filled and padded a Stage 1 (kcrz 153141248, Stage 2 `1.0.0b13-g22b71758`).
Not installed or booted.

| Package | sha256 | Bytes |
| --- | --- | --- |
| `linux-aurora-7.3.0.aurora17.v272-3-aarch64.pkg.tar.zst` (`7.3.0-17.v272-3-ARCH`) | `0e720d3f9cbd6f49c08f5a53cd26d1c0cd1da36d1d119778b002b0c1bd7b48fc` | 44134953 |
| `m1n1-aurora-1.6.1.aurora24.v272-3-aarch64.pkg.tar.zst` | `bf09a9e13163bbdf342c8c14dd86f1f1b28ee7e94644bbda7e3e0407d970d833` | 2471050 |

**v272-2 and the support packages (from 1b9d5ef):**

Kernel cross-built (`OMARCHY_CROSS_KERNEL=1`, kernel package only; `check()` 35 tests OK); Aura
built on x86 (bare metal, same code; `check()` filled and padded a Stage 1, kcrz 153141248); the
rest in an Arch Linux ARM container under qemu-user, every `check()` passed (speakerguardd-v2:
cargo tests and the provision/wiring/verify suites; aurora-speaker-upgrade: 37 tests). No file of
the three new or changed support packages collides with another package in the set. Files on ush
in `~/m5-build/pkg272-2/out/`. None has been installed or booted.

| Package | sha256 | Bytes |
| --- | --- | --- |
| `linux-aurora-7.3.0.aurora17.v272-2-aarch64.pkg.tar.zst` (`7.3.0-17.v272-2-ARCH`) | `a13a255980fb6aee481b3dbc6c2f1eecfadd56410ce7a7abe9ae7c362700dfc6` | 44127181 |
| `m1n1-aurora-1.6.1.aurora24.v272-2-aarch64.pkg.tar.zst` | `ec19c40e838c1e2c6d8bc170063e2d5d0da83c43fa0f60943e3488b35400d161` | 2469202 |
| `omarchy-aurora-firmware-20261014.j714s8-1-aarch64.pkg.tar.zst` | `e31dcfd14435cb38692ad86a6e920e7f2e170ed28ddef5947db1e1680b9a4ac5` | 47835 |
| `speakerguardd-v2-1.0.0alpha.1-41.1-aarch64.pkg.tar.zst` | `c918f58ca81ba251c183fbf4ae7d092ad87fbdf85638fb61c1316ebebfd17b0c` | 1760691 |
| `aurora-speaker-upgrade-0.1-16-any.pkg.tar.zst` | `3bd6790ac86ee3620020ffe9249c60824e01b93e53898dbd87c3cc19fdfb876e` | 66126 |

Unchanged from release 1: aurora-sep `6fa7ec89…`, libfprint-aurora `6f4c2ca4…`, hyprland-m5,
mesa/vulkan-aurora, uboot-aurora and the omacom packages. The device trees grow by 7.5 KB
(5709462 bytes in all, #1791's USB4 router), well under the boot.bin limit that refused 13.6 MB.

Release 1's packages (linux `7ed98691…`, m1n1 `1f30e3ff…`, built on 572eb88e/2232ae7a) are in
this file's git history and on ush in `~/m5-build/pkg272/out/`.

## Queued for the next kernel

Nothing queued. #1921 and #1930 merged and were dropped in v272-16; v272-17 dropped nothing. Still open upstream and carried here: #1173 (0001),
#1650 (0005), #1721 (0020); the HDMI patches 0017-0019 and 0021 (v272-18) and the 27.2 ANE pin 0016 are not upstream.
