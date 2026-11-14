# J714s on the macOS 27.2 stub (one image line)

Kernel and Aura for the one J714s (14" MacBook Pro, M5 Pro, T6050) Omarchy image on Apple's
non-beta firmware 27.2: restore image `UniversalMac_27.2_26B123_Restore.ipsw` (sha256
`6613b34e...8534f`), J714s boot firmware `mBoot-20457.41.3`. Stage 1 is Aura as a padded Mach-O
boot object with no `__TEXT_BOOT_EXEC` (`kcbz` 0, so iBoot does not start SPTM), enrolled with
`kmutil configure-boot --compress` after `bputil -nc`; Linux runs at EL2 on every CPU inside the
128 MiB code-execute window, as aurora-silicon targets 27.2 (`docs/move-to-27.2.md`).

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
| 0001 | GPU InitData and firmware identity for 27.2 (26B123) and 27.3 (26C5035r), aurora-silicon/linux #1173 (open), resolved against the Graph refactor. The 26B123 fwid digest `2b4613c6...913f0fd9` was re-derived from the IPSW (below) | Rolando Trevino (rolotrealanis98) |
| 0002-0004 | Firmware 27 adaptive-sync parameter name; no panel brightness after a DCP crash; the full 27.3 IOMFB method table and swap record (only used on a 27.3 stub; 27.2 uses upstream's `dcp_methods_27_2`) | Rolando Trevino |
| 0005 | The K114/K116 27.2 (26B8125) G17S identity, #1650 (open) | Jens Axboe (via sithglan) |
| 0006 | ANE on 27.3; AVE builds selected by TEXT CRC on top of #1747 (27.2 and 27.3 share segment sizes) | this repo |
| 0007-0009 | Front camera: IMX958 setfile 2226_02, noise reduction gains, lens shading target and metering (omacom/linux-aurora #422) | Eduard Moldovan (edimoldovan) |
| 0010 | 2560x1440 added to #1835's J714s presets (config 6, the centre 1:1) | this repo, from edimoldovan's J714c preset |
| 0011-0013 | The camera light and its J714s pin (#422; J714s DT by this repo) | Eduard Moldovan; this repo |
| 0014 | VRR on the firmware 27 panel, `appledrm.fw27_panel_vrr` (j716s-next 8ab10100a4); the image turns it on (omarchy-aurora-firmware `aurora-m5-vrr.conf`) | Rolando Trevino |
| 0015 | ANE and AVE on 27.2 (26B123): layouts from the IPSW. ANE: 27.2 layout recognised, refused until its TEXT pin is known, and the refusal prints the digest. AVE: 26B123 admitted, probe only unless `apple_ave.ave_t6050_27_2_layout=1` | this repo |
| 0016 | The 27.2 ANE TEXT pin `b15dd8fb...c40e`, read from the first J714s 27.2 boot's refusal | this repo |
| 0017 | **J714s HDMI port** (DT): dcpext3 → the atc3 display crossbar → ATC3 as a fixed four-lane DP PHY → the on-board DP-to-HDMI converter; frees AOP pin 14 (HPD) from `t6050-max-atc2.dtsi`'s reserved range, atc3_dpxbar power domains. Tested on his J714s on 27.3 (HP E240c, 1920x1080@60: cold plug, hotplug, replug); not tried on 27.2. His `0010-linux-t6050-j714s-hdmi-dt.patch` at 267c7ea3cb gives a tree identical to this one | FatBoy721 (FatBoy721/omarchy-m5 898d8ad6cb), ported unchanged |
| 0018 | **HDMI v2 hold** (v272-5, replaces v1): while a T6050 fixed HDMI output connects (sink at boot, power-on, HPD edge) complete its flips locally for 8 s, so a present the DCP swallows during the monitor's wake HPD cycle can't time out the IOMFB queue and leave the DCP crashed. Per-DCP state, only `apple,t6050-dcpext` with an HDMI HPD GPIO; `appledrm.hdmi_hold_presents=0` turns it off. Tested on his J714s on 27.3 | FatBoy721 (`j714s-hdmi-upstream273` 267c7ea3cb, his 0012 v2), applied unchanged |
| 0019 | **HDMI IRQ_HPD** (v272-5, new): `dcp-hdmi.c`'s converter IRQ_HPD forwarder enabled for `apple,t6050-dcpext` as macOS does on the J714s (T6030 only before). Booted on his J714s on 27.3, no visible change on its own | FatBoy721 (267c7ea3cb, his 0013), applied unchanged |
| 0020 | **Dock displays** (v272-6, new): dcp-fabric gives T6050 DP IN 2 and 3 their own tunnel slots, so a Thunderbolt dock's third and fourth DP tunnels can be routed | Isaac-Duarte (aurora-silicon/linux #1921, 27f9349ab5f0), applied unchanged |
| 0021 | dt-bindings: `apple,tunnel-only` Type-C routes (no `mode-switch` needed) | Isaac-Duarte (#1921, 723d72539a93), unchanged |
| 0022 | dcp-fabric: tunnel-only routes (DP alt mode never lands on them, the pairing plan and `dcp_fabric_follow()` respect them, KUnit cases); their connectors are created in a second pass so DP-1..DP-4 keep their names and the new one is DP-5 | Isaac-Duarte (#1921, 7e34917fd867), unchanged |
| 0023 | J714s DT: dcpext1 gets a tunnel-only route to the right port's DP IN crossbar outputs (crossbar source 2) and hpm2 `endpoint@2`, so a dock on the right port can drive three displays as on macOS | Isaac-Duarte (#1921, head 4c6a7b451f34), unchanged |

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

Nothing queued. #1921 is in v272-6 at its head 4c6a7b451f34 while still open; re-take it when it
merges (drop 0020-0023 then) or if its head moves.
