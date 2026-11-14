# aurora-silicon base on the 27.3 beta 1 stub (J714s)

Work toward running aurora-silicon's `integration/aurora` kernel and the Aura bootloader on
TripleU613's J714s while it stays on the macOS 27.3 beta 1 stub (26C5035r,
mBoot-20457.60.65.0.1), with the GPU and the internal display handed over as our own kernel and
m1n1 do today.

Status (2026-11-11): **builds, not yet boot-tested.** Do not ship. The first staging attempt
broke the dev Linux root (a `lib/` modules tarball extracted at `/` replaced the `/lib -> usr/lib`
symlink); `~/m5/tools/rescue-lib-bm.bin` repairs it on the next boot and `stage-up273.sh` stages
under `/usr` instead.

| Patch | Applies to | What |
| --- | --- | --- |
| `0001-linux-integration-aurora-pr1173-rolo-27.3-dcp.patch` | aurora-silicon/linux `integration/aurora` at e661192638a3 (image -8, not booted; 3766943238bd for -7, 8679514f4dff for -6, 2b4523cb6592 for -5, unchanged bytes) | Four commits. #1173 (GPU 27.2/27.3 InitData layouts and firmware identity; Rolando Trevino), resolved against upstream's `Graph` refactor: each build gets its own `Graph` (`M5_GRAPH_26B123`, `M5_GRAPH_26C5035`), `hw_offset()` and the board graph are kept, and the J813 keeps its board graph. Then three of rolotrealanis98's commits from his `j716s-next` (bf857188d0): 450cfbf77385 (the firmware 27 adaptive sync parameter's name), e25c83799018 (no panel brightness after a DCP crash) and 26b9f266cb2d (the full 27.3 IOMFB method table and the 27.3 swap record on top of upstream's merged #1174, whose own 20-entry table refuses a 27.3 DCP; the refusal check stays and passes). His J716s-only DT, config and audio commits are left out. His table and swap conversion are identical to the first #1174 (290b7de9f129 + 0cdf8957541b) that images -1 to -4 carried; the difference is that the EDR words are not sent on a 27.3 swap. One conflict with #1674 in `dcp_swap_submit()`: a swap is EDR-prepared only if it shows a surface and is not 27.3. Images -2 to -4 used the first #1174 on f1b79c4beaef and f8581cbaa87f. |
| `0002-aura-t6050-27.3-gpu-dcp-handoff.patch` | aurora-silicon Aura main d35655304e (image -6: after 1.0.0b12, with #184 MTE tag storage and #196); images -1 to -5 used 1.0.0b11 (main dbf088e151; #173 M5 Pro boot path, #180 DART; first written on 1669cad0) | Aura knows 27.2 and 27.3 beta 1; its T6050 GPU handoff admits the 27.0, 27.2 and 27.3 beta 1 GPU builds (digests and boot-filled ranges from #1173); its T6050 DCP handoff accepts 27.3 beta 1, takes the DCP image the ADT names and publishes `apple,firmware-compat <27 3 0>` (what #1174 keys its 27.3 table by). Only the firmware gate, image check and compat key are changed; our m1n1's notch rows and display-default handling (m1n1-installer 0006/0007) are not ported, so the full 3024x1964 panel is unverified. |
| `0003-aura-notch-default-and-m5-max-27.3-gpu.patch` | after 0002 | The notch rows by default on M5 (T6050/T6051): without a config line Aura keeps iBoot's full framebuffer and sets `/chosen/asahi,show-notch = "1"`; `chosen.asahi,show-notch=0` opts out. And joshuaswarren's M5 Max 27.3 GPU digest (aurora-silicon/aura #172, the upstream equivalent for the Max of 0002's G17S entries) as one more entry in 0002's build table, so there is a single digest check. |
| `0004-linux-t6050-ane-ave-27.3-firmware.patch` | after 0001 | The T6050 Neural Engine and video encoder on the macOS 27.3 firmware, beside 27.0. Each driver gets a table of admitted builds, and the segment layout the loader hands off selects the build. ANE (`ane_fw_platform`): 27.0 TEXT 0xc0000 and DATA 0x2ac000 at DVA 0x100000c0000; 27.3 TEXT 0xec000 and DATA 0x280000 at 0x100000ec000, each with its own TEXT sha256 pin (27.3: `11557586...66dc6066`). AVE (`ave_t6050`): 27.0 TEXT 0x154000 with CRC 87279429; 27.3 (26C5035r) TEXT 0x158000 with CRC c25b4ddb; DATA is 0x134000 in both. The 27.3 encoder has no qualified command layout, so it probes without one and encoding is refused. `apple-ave.ave_t6050_try_26a428=1` drives it with the 27.0 layout for testing by hand. The H17 ANE backend also sizes its IPC from the firmware's boot request instead of a fixed 64 KiB/0xc441: 27.3 asks for 0x10441 bytes, as the H16 backend already handles. `ane_t6021.boot_stages=N` (default 5) holds the bind's bring-up after N stages, so the rest can be stepped from `firmware_stage`. The recipe ships it as `t6050-ane-ave-27.3.patch` (pkgrel 3). Since image -5, the 27.3 build takes 26A428's command layout by default: H.264 encodes (two boots, below). HEVC on 27.3 stayed refused unless `apple-ave.ave_t6050_27_3_hevc=1`. `ave_t6050_try_26a428` is gone. Since image -6, HEVC on 27.3 is on by default too (a second boot encoded cleanly); `apple_ave.ave_t6050_27_3_hevc=0` refuses it. |
| `0005-linux-t6050-isp-j714s-camera-27.3.patch` | after 0004 | The front camera's image quality on T6050, from edimoldovan's J714c camera (omacom/linux-aurora #422), on top of aurora-silicon's own T6050 ISP driver (#1252/#1253, Erik Bourget) and J714s camera DT (#1306), which `integration/aurora` already has. Three of Eduard Moldovan's driver commits, unchanged apart from the hardware table: IMX958 setfile `isp_2226_02XX.dat` instead of 2224_01 (38993598aa9a), the noise-reduction radial gains computed from the setfile's lens-shading table (162531436bd8), and the lens-shading target 84% plus the face-detection scene metering (cb9cbb2b470f). His camera light (5a3e9d8a5f0b, 04606609e94c): the driver drives the light pin to its on level before every stream, refuses to stream unless it reads back, and feeds the eic ISP watchdog only while the light is on. On the J714s the pin is in the eic's own GPIO block (`cil` at 0x2dc000234, config 0x474002, active high). And his J714c presets on the J714s: 1920x1080 and 2560x1440 in firmware configuration 6, 1280x720 in configuration 7, centre crops (from e8233e1bbe91/8916070002f4). |
| `0006-aura-t6050-isp-27.3-j714s-camera.patch` | Aura, after 0002 + 0003 | The camera hand-off on 27.3. Aura's T6050 camera hand-off (`dt_set_t6050_isp`) admitted only macOS 27.0. Jens Axboe's board table from aura #188 (9ece8137fa, K116s on 27.2, ported by Thomas Glanzmann), plus a J714s row for 27.3 beta 1: its ADT isp0 keeps sensor type 0x74 and the same two segments (TEXT 0xc1c000 at phys 0x100010cc000, DATA 0x13d0000 at 0x100026a4000). A board may have one row per firmware. |
| `0007-aura-t6050-pcie-storage-auto-pm.patch` | Aura, after 0006 | Aura's T6050 GP PCIe bring-up compares the storage registers before and after each stage and stops on a change. The storage-side domain APCIE_SYS_ST0 runs under auto power management and gates itself while storage is idle (`0x1f0003ff -> 0x1000030f`: PS_AUTO and the actual state go 0xf -> 0, target and auto-enable unchanged). After stage F that stop left port 0, the N1 Wi-Fi, down; after the shared stages A or S it refuses the whole hand-off (`kboot: refusing T6050 handoff`, "No valid payload found"), which looks like an early hang until the watchdog. 0007 lets a domain with AUTO_ENABLE set before and after move PS_AUTO; target, auto-enable and the ANS/NVMe checks still stop it. See the image -6 section. |
| `0008-linux-drm-apple-fw27-panel-vrr.patch` | after 0001, 0004, 0005 | rolotrealanis98's j716s-next 8ab10100a4 "drm/apple: Offer VRR on the firmware 27 panel and apply VRR_ENABLED" (Rolando Trevino; his rebase onto integration/aurora 34a447be), unchanged. The firmware 27 ProMotion panel reports its adaptive-sync range fields as zero, so the parser now reads them as 24-120 Hz, the connector says `vrr_capable`, and a plain page flip that changes `VRR_ENABLED` selects the current mode again with adaptive sync at 24 Hz (`minRR = 0x180000`) or off; a swap that does not complete within a second turns it off for good. Opt-in: `appledrm.fw27_panel_vrr=1`. His J716s DT, config and audio commits are left out. Image -7. |
| `0009-linux-drm-apple-softdep-t6050-combo-phy.patch` | after 0008 | **In the recipe since pkgrel 10 (image -8); the patched kernel is not booted yet.** The same softdep as a modprobe.d line on up273-8 made all four external DCPs bind and DRM offer DP-1..DP-4. appledrm also soft-depends on `atc-t6050-dp`, the T6050 combo PHY module, as it already does on the display crossbar. Without it, appledrm can probe dcpext0/dcpext2 before their route PHYs exist, after the deferred-probe timer, and they give up with -110. See "External displays on 27.3". |
| `0010-linux-t6050-j714s-hdmi-dt.patch` | after 0001-0009 (DT only) | **Works on FatBoy721's J714s (27.3), with 0011, 0012 and 0013:** HP E240c at 1920x1080@60, cold plug at boot, hotplug and replug. dcpext3 -> atc3 display crossbar (source 6 = 2 * ufp-endpoint 3, as macOS's AppleT8142ATCDPXBAR) -> ATC3 as a fixed DP PHY (`apple,t6050-dp-phy`; no usb-drd3 in the ADT) -> the on-board DP-to-HDMI converter. HPD on AOP GPIO 14 (freed from t6050-max-atc2.dtsi's reserved range), converter power on SMC pcIO 1/2 (the J775d encoding), and atc3_dpxbar gets its usb-aon/common power domains (without them the Mac resets at boot). |
| `0011-aura-t6050-fixed-dp-phy-tunables.patch` | Aura, after 0007 | **Booted on FatBoy721's J714s (HDMI works with 0010/0012).** `t6050_setup_atc()` also fills an `apple,t6050-dp-phy` node: no usb-drdN pairing, only the first nine lists (axi2af, fabric, common-cfg, lioa, lane RX clock/EQ, auspll), each still checked against its ADT bank. Without it the HDMI PHY probes with no tunables. Builds on d35655304e + 0002/0003/0006/0007. FatBoy721 |
| `0012-linux-drm-apple-t6050-hdmi-hold-presents.patch` | after 0001-0009 | **Works on FatBoy721's J714s.** A monitor waking from standby drops HDMI HPD ~2 s after the first mode set and raises it again; DCP swallows the presents sent while its controller is down, and the unwatched dropped present times out the IOMFB queue and marks the DCP crashed until the next boot. While a T6050 fixed HDMI output connects (sink at boot, power-on, HPD), its flips complete locally for 8 s, so the reconnect works. Per-DCP state, only `apple,t6050-dcpext` with an HDMI HPD GPIO; `appledrm.hdmi_hold_presents=0` turns it off. |
| `0013-linux-drm-apple-t6050-hdmi-irq-hpd.patch` | after 0012 | **Booted on FatBoy721's J714s.** Enables `dcp-hdmi.c`'s converter IRQ_HPD forwarder (T6030 only before) for `apple,t6050-dcpext`, as macOS does on the J714s ("handleIrqHpdEvent dispatching IRQ_HPD"). No visible change on its own. |

Kernel: `0001` is on `integration/aurora` f8581cbaa87f since image -4 (f1b79c4beaef before), cross-built on ush, which the image's kernel recipe (`installer/recipes/linux-aurora-upstream`) builds. The f8581cba tree is `~/m5-build/up273-4/src` on ush, branch `up-274` (0001, 0004 and 0005 as three commits). The f1b79c4b branch was `build/linux-up` `up-273c` (merges 0929f4f5c93b, 8a0eb8647062, fix e0516e36058b). Aura branch: `~/m5/work/up/aura-isp` `up-273-image-main-isp` (0002 + 0003 + 0006 + 0007 on main d35655304e, image -6; the uncommitted test watchdog and payload retry in its working tree are for RAM tests only). `up-273-image-b11-isp` was images -3 to -5 (on main dbf088e1). Packaged by `installer/recipes/m1n1-aurora-upstream`.

Still to check on the Mac: GPU firmware up, DCP modeset 3024x1964@120 with the notch rows,
Wi-Fi (`CONFIG_APPLE_CENTAURI_T6050=m`), trackpad, NVMe.

## Boot test on TripleU613's J714s (27.3 beta 1 stub, 2026-11-11)

Aura (0002, test watchdog) chainloaded from the stage-1 m1n1 proxy, kernel `7.3.0-j714s-up+` (0001):

- GPU: `GPU firmware build: 26C5035r for T6050 G17S` (the 27.3 firmware); Vulkan `Apple M5 Pro (G17S B1)`, Borealis.
- Internal display: DCP handed over, `eDP-1` 3024x1890 at 120 Hz (`set_digital_out_mode ... 120`); notch rows not shown yet (m1n1 0007's default is not in Aura yet). External DCPs and `DP-1`..`DP-4` registered.
- Wi-Fi (N1) up, trackpad (`Touch MT ready`), NVMe, USB (a device enumerates, Type-C ports 0/1), SEP firmware reserved by Aura, USB4 router (acio) present, AOP sensors.
- Notch rows: with `chosen.asahi,show-notch=1` in Aura's config the panel runs 3024x1964 at 120 Hz.
- Sound: with `CONFIG_SND_SOC_APPLE_T8152_AOP_AUDIO=m` (off in our config) the `AppleJ714` card (speakers, headphone jack) and `AppleJ714HPAI` (microphones) come up; the speakers stay locked until speakerguardd (shipped in the image) takes them, not tried on the dev Linux.

## Packaged kernel boot test (2026-11-12, RAM, Aura 1.0.0b11)

linux-aurora 7.3.0.aurora17.up273-2 (f1b79c4b + this 0001) from RAM via Aura b11 with the test watchdog: GPU 26C5035r, DCP `eDP-1` 3024x1964 at 120 Hz on apple-drm (the notch rows), Hyprland running, Wi-Fi up. The up273-1 build with the updated #1174 had no DCP (simpledrm only). Not working on 27.3 yet: the ANE (the kernel pins the 27.0 TEXT digest and the preloaded TEXT reads as zeros) and the AVE encoder ("unexpected firmware segment sizes").

## ANE and AVE on 27.3 (0004, 2026-11-12)

iBoot 20457.60.65 (27.3 beta 1) preloads both firmwares, and Aura #169/#171 hand them over intact. On the dev Linux, the reserved ANE TEXT/DATA and AVE TEXT/DATA read back through `/dev/mem` (mmap) as real firmware: RTKit 3514.60.8, AppleAVE2FW. Aura's `aurora,ave-text-crc32`/`aurora,ave-data-crc32` (c25b4ddb/f4e9dda8) match. The all-zero "preloaded TEXT sha256" in the up273-2 log is not the memory. `ane_fw_handoff_present()` hashes TEXT only after the layout check passes, so on the 27.3 layout it printed its zero-initialised buffer. Apple moved 0x2c000 bytes from DATA into TEXT; the span still ends at 0x36c000, so the heap tail, pool and IPC DVAs are unchanged. The AVE TEXT grew by 0x4000, so its build is new.

Upstream (aurora-silicon/linux, aura, 2026-11-12) has no 27.3 ANE/AVE work; #1595/#1597 and aura #169/#171 are 27.0 only.

RAM boot test of up273-3 (f1b79c4b + 0001 + 0004, `7.3.0-17.up273-3-ARCH`, built on ush with rustc 1.98.0 and clang 23.1.3, config identical to up273-2's) through Aura b11 (`loader-up273b-b11-bm.bin`), 2026-11-12 02:29. Aura was chainloaded at 02:30:03, but the Mac was not back on Wi-Fi within 5 minutes. No new m1n1 proxy appeared either, so the 170 s test watchdog did not reset it before Linux took the watchdog over. No kernel log was captured. At the time this was put down to the first real start of the 27.3 ANE firmware, but that was wrong: the boot had no Wi-Fi. PCIe port 0, the N1 Wi-Fi chip, was not adopted from the loader, and m5.deadman reset the Mac after 300 s (see the camera section below). The ANE was not the cause. The up273-2 Image/dtb from `m5local/up273b` are kept at `/root/up273b-backup-up273-2` on p5.

**Open risk: Wi-Fi port 0 not adopted.** On this base, PCIe port 0 (the N1) is sometimes not picked up from the loader. The boot then has no Wi-Fi, and the dev setup's deadman resets the Mac after 300 s. In the dev root's journal, 2 of the last 25 boots lack it (the 02:30 up273-3 boot and one camera test 3 boot); the repeat boots were fine. Not understood yet. The deadman is the dev test loaders' `m5.deadman=300`; an installed image's command line has none, so it would stay up without Wi-Fi until the next boot.

Starting the ANE by hand (2026-11-12). The 02:30 boot was reset at 02:36:13, and the catcher brought the daily kernel back. Before its real cause (Wi-Fi port 0, above) was found, the ANE was isolated. With `module_blacklist=ane_t6021,ane` (`loader-up273b-noane-bm.bin`), up273-3 boots: AVE `firmware build 26C5035 (TEXT 0x158000 CRC c25b4ddb, DATA 0x134000)`, probe only, `/dev/video0` apple-ave, DCP 3024x1964@120, Hyprland, Wi-Fi. `loader-up273b-anestep-bm.bin` has `modprobe.blacklist=ane_t6021,ane` instead, which leaves `modprobe` by hand possible. With it, `/root/anestep.sh` on p5 loads `ane_t6021 boot_stages=0` and steps probe, map, boot, startup and program from `firmware_stage`, syncing `/var/log/anestep.log` after every step. Probe and map passed. Boot reached READY and then returned -EPROTO (no hang; the ANE never hung): scratch1 (the IPC size minus one) read 0x10440 where the backend required 0xc440. Every other request cell matched (8 channels, heap 0xf00000, mode 0). With the IPC sized from the request (the whole 0x14000 window up to the heap, 0x10441 in the init block), all five stages pass: `H17 ANE: READY; IPC 0x10441 bytes requested`, startup, `H17 accel node ready (ABI 3...)`, `/dev/accel/accel0`. No inference workload was run: the dev Linux has no ANE program.

Full RAM boot with the fix (`loader-up273b-b11-bm.bin`, no blacklist, 2026-11-12 02:47). The ANE comes up at bind on its own: `H17 ANE: loader hand-off verified (27.3 build, TEXT sha256 115575864d4c8d02d48d83077170e7e16079aaf70dadd608c71910ac66dc6066)`, `READY; IPC 0x10441 bytes requested`, `up at boot, accel node ready`, `/dev/accel/accel0`. AVE: `firmware build 26C5035 ... probe only`, `/dev/video0`. GPU `27.3 (26C5035r), G17S`; DCP `eDP-1` 3024x1964 at 120 Hz; Hyprland; Wi-Fi associated. No SError/Oops. Still open: an ANE inference run (no workload on the dev Linux) and qualifying the AVE 27.3 command layout (`apple-ave.ave_t6050_try_26a428=1` plus an encode). The p5 modules of `7.3.0-17.up273-3-ARCH` carry this fixed `ane_t6021.ko`; the first build's module is kept at `/root/ane_t6021-up273-3-orig.ko`.

## Front camera on 27.3 (0005, 0006, 2026-11-12)

The J714s camera is an IMX958, the same sensor as edimoldovan's J714c. Most of what his PRs carry is already in our base. All 27 commits of omacom/linux-aurora #421 (aurora-silicon's ISP driver) are in `integration/aurora` f1b79c4b: 22 by patch-id, and the other 5 under the same subjects, which he adjusted for conflicts. aurora-silicon has its own T6050 support (#1252/#1253/#1254), and #1306 enables it on the J714s. #1306 was tested on a J714s on 27.0: 90/90 frames at 1920x1080, 30 fps. On 27.3 the node stayed `disabled`, because Aura's camera hand-off refused any firmware other than 27.0. His static reserved-memory DT for the J714c is not used: the firmware's physical addresses differ per board (J714c TEXT 0x10001224000, J714s 0x100010cc000), and Aura publishes them from the ADT.

RAM tests on TripleU613's J714s (Aura b11 + 0002/0003/0006 with the test watchdog, `loader-up273b-isp-bm.bin`; `loader-up273b-isp-noisp-bm.bin` also blacklists `apple_isp`):

- **Test 1:** up273-3 kernel unchanged, `modprobe.blacklist=apple_isp`.
  - Aura: `isp@580000000` `okay`, `apple,platform-id` 0x74, text/data reserved at the ADT addresses, 32 MiB main memory.
  - `modprobe apple-isp`: `/dev/video2` "FaceTime HD Camera" (1920x1080 NV12).
  - 30 real frames: auto exposure ramps the luma mean from 16 to 88, no two consecutive frames are identical, 29.9-30.0 fps.
  - Sensor tuning: `isp_2224_01XX.dat` (the driver asks for exactly this file, so the sensor is 0x958). The image has heavy grain and a colour cast.
- **Test 2:** kernel `7.3.0-17.up273cam-1-ARCH` (f1b79c4b + 0001 + 0004 + 0005's driver commits, built on ush in `~/m5-build/up273-cam`).
  - `apple-isp` binds at boot.
  - 60 frames at 30.3 fps with `isp_2226_02XX.dat`.
  - Flat-wall noise (mean neighbour difference in the luma) 2.0, against 8.8 with 2224_01.
- **Test 3:** the same kernel plus 0005's J714s presets (dtb only).
  - `--list-formats-ext` offers 1920x1080, 1280x720 and 2560x1440.
  - Each streams 60 NV12 frames at 30.1-30.6 fps.
  - Frames show the full, centred field of view.

In each test the GPU (27.3, G17S), DCP `eDP-1` 3024x1964, Hyprland and Wi-Fi were up while streaming. The ANE (`/dev/accel/accel0`) was checked in test 3 only, and the kernel log had no SError or Oops in tests 2 and 3. Test 1 ended in a kernel crash after the captures. It came from a raw `/dev/mem` read of the gpio0 register at 0x29c000234 (see test 4), not from the camera. One test 3 boot had no Wi-Fi: PCIe port 0, the N1 Wi-Fi chip, was not adopted from the loader, and m5.deadman reset the Mac after 300 s. The repeat boot was fine. The same failure also happened once under the original b11 loader: the up273-3 boot of 02:30 EST that this README first put down to the ANE had no port 0 either. In the dev root's journal, 2 of the last 25 boots lack it. This is an open risk (see the ANE section).

Setfiles: Apple firmware, not in this repo. They are extracted with installer #208's `omarchy_isp.extract()`, unmodified, from macOS 27.3 (26C5035r) `/usr/sbin/appleh16camerad` on the Mac's own System volume. On the dev root (p5) they are in `/usr/lib/firmware/apple`: `isp_1925_03XX.dat`, `isp_2224_01XX.dat` and `isp_2226_02XX.dat` (0x7000 each for the IMX958 files). The local 26.6.2 IPSW has AEA-encrypted system images. The camera streams without a setfile (`streaming without sensor tuning`), but badly.

- **Test 4:** kernel `7.3.0-17.up273cam-2-ARCH`, all of 0005, including edimoldovan's camera light.
  - aurora-silicon's driver only fed the eic ISP watchdog. edimoldovan found that on the J714c the light stays off unless the driver drives it.
  - The light pin is ADT eic `cil-gpio-offset` 141, config 0x474002. The offset is in the eic's own GPIO block (eic `mmio-gpio` 0x2dc000000, as edimoldovan has it), not the AP's gpio0 (0x29c000000).
  - Any read of 0x29c000234 brings the Mac down: a `/dev/mem` read during test 1, and the first try of this test, whose driver read it at probe. Neither left a trace in the synced log, and the watchdog and catcher recovered both.
  - With `cil` at 0x2dc000234, the driver binds at boot. Before every stream the pin reads back at its on level (the driver refuses to stream otherwise).
  - 1920x1080 and 2560x1440 stream at 30.2-30.6 fps. GPU, eDP 3024x1964, Wi-Fi and the ANE are up, with no SError or Oops.
  - Nobody looked at the light itself. The read-back is the evidence.
  - With `camera_light` set for every T6050, as in #422, a T6050 board whose DT has no `cil` (J716c, K116s in this tree) no longer probes its camera. This doesn't matter for the J714s-only image.

Open:
- Lid sleep with the camera was not tried. The 2226_02 setfile, the radial gains, the 84% lens-shading target and the scene metering apply to every T6050 (as in #422). They are verified on the J714c and J714s only.

Dev Mac state: p4 `m5local/up273b` now holds up273cam-2 (Image.gz and the dtb with `cil`), not up273-3. up273-3's files are in `/root/up273b-backup-up273-3` on p5. Modules for `7.3.0-17.up273cam-1-ARCH` and `-2-ARCH` are in p5's `/usr/lib/modules`. The setfiles are in p5's `/usr/lib/firmware/apple`. A patched apfs-fuse (read-only, keybag errors ignored), used to read macOS, is in `/root/build`.

What the image needs:
- `linux-aurora-upstream`: add `0005` after `t6050-ane-ave-27.3.patch` and bump pkgrel. `CONFIG_VIDEO_APPLE_ISP=m` is already set.
- `m1n1-aurora-upstream`: apply `0006` after 0002 + 0003. Regenerate `aura-up273-image.patch` and its sha256, and bump pkgrel.
- Setfiles on an installed system: omacom/omarchy-mac-installer #208 (cffff8b5ed2c, edimoldovan) adds the IMX958 2224_01 and 2226_02 entries to the installer's `omarchy_isp.py`. It applies on c07e54c, the base of our installer patches. The installer's firmware collection then extracts them from macOS's `appleh16camerad` into the vendor firmware it installs. The driver requests `apple/isp_2226_02XX.dat` (2224_01 on T6040/T8142) from the firmware search path. Check on the first installed image that the file lands where the kernel finds it.

Done in image [upstream-2026.11.12-3](https://github.com/betizzel/omarchy-m5/releases/tag/j714s-developer-image-upstream-2026.11.12-3): linux-aurora up273-4 (0005), m1n1-aurora up273-2 (0006) and #208 in `installer/patches-upstream-27.3` (0002, with 0003 re-pinning the engine it changes). Where the setfile lands:
- The kernel (`fw_path`) searches `/lib/firmware/vendor` and then `/lib/firmware`. `apple-isp` asks for `apple/isp_2226_02XX.dat` when a stream starts, not at probe.
- If `vendorfw/firmware.tar` on the image's ESP holds `apple/isp_2226_02XX.dat`, the image's `omarchy-vendor-firmware.service` (enabled; it checks for `/boot/efi/vendorfw/firmware.tar`) extracts it into `/lib/firmware`, which is `/usr/lib/firmware/apple/isp_2226_02XX.dat`. A `firmware.cpio` copy also goes to `/lib/firmware/vendor/apple/` from the initramfs.
- The installer engine doesn't put it there. It applies `omarchy_isp`'s extended registry only on the MacBook Neo (`_neo_peripheral_collectors`, j700ap). Every other Mac gets upstream's collector, which scans `appleh13camerad` only and knows no IMX958.
- Since 7fd19f1, `tools/camera-setfiles/save-camera-setfiles.py` (#208's extractor, IMX958 only) saves the files on macOS 27.3. `tools/install-image/install-from-linux.sh` packs any `apple/isp_*.dat` in its firmware folder into `vendorfw/firmware.tar`. Otherwise copy the file to `/usr/lib/firmware/apple/` by hand.

## Re-pin to integration/aurora f8581cba (image -4, 2026-11-12)

What upstream merged for the M5 after f1b79c4b: panel EDR on firmware 27 (#1659), the platform-profile class without ACPI (#1655) and its first user, CLPC platform profiles after macOS's power modes (#1656), CLPC holding fabric 2 for GPU work (#1657), T6050 ProRes (#1586), paired-display VRR (#1613), external HDR hints and formats on firmware 27 (#1614, #1640, #1641), and media DART power domains (#1673). #1521 (the T6050 AOP booted through its setup port) is not new: it merged before f1b79c4b and has been in every upstream image.

- **0001:** one conflict, in `dcp_swap_submit()` (`iomfb_template.c`). Upstream now stamps the external HDR hints (#1614) and prepares the panel EDR fields (#1659) on `present_v27` before the push; #1174 converts that record to the 27.3 wire layout. Both are kept, and the conversion runs last. The new swap fields (`bl_flags` 0x358, `bl_limit` 0x376, `edr_scale` 0x37e, `edr_headroom` 0x3e6) lie between the 27.3 layout's second and third gaps, so the conversion moves them 0x60 bytes further. Nobody has checked whether 27.3 keeps them there. Every swap submit, including the paired-display path (#1613), goes through `iomfb_v27_swap_wire()`, and upstream added no new method IDs that the 27.3 table would lack. The rest of 0001 applies unchanged; the patch bytes are identical on 44ff52a2 and f8581cba.
- **0004, 0005:** apply unchanged with `patch -Np1` (0005 in order after 0004). `patch -Np1` of the three on the f8581cba tarball gives exactly the tree that was built and tested.
- **Config:** the recipe config plus `CONFIG_ACPI_PLATFORM_PROFILE=y`, which `APPLE_CLPC` now selects. Upstream's new `asahi.config` lines are not taken: the DP855 panel bus, TMP103, and the boot-chain lockdown (`APPLE_AURORA_BOOT_SECURITY_LOCKDOWN`, `SECURITY_LOCKDOWN_LSM_EARLY`), which could refuse this package's unsigned modules on a boot it judges secure (not tried).
- **Device tree** (J714s, against up273cam-2): ProRes and its DART are enabled, the `scodec` and `fab7-soc` power states are on (`fab7-soc` firmware-owned), and the CLPC points at the SMC. The SEP node stays `disabled` (#1325, which enables it, merged after f8581cba).
- **Aura** stays 1.0.0b11 + 0002/0003/0006. 1.0.0b12 (ea20cedb) has nothing for the T6050: the Neo's encoder 0, M4 Pro EL2/hibernation, the J604 AOP and J813 `arm64.nomte`. Its PMP boot-argument change touches every chip and has not been tried on a J714s.

RAM test of `7.3.0-17.up273-5-ARCH` (built on ush, the source of linux-aurora up273-5), 2026-11-12 07:27 EST. It booted through `loader-up273b-isp-bm.bin` (Aura b11 + 0002/0003/0006, test watchdog), from p4 `m5local/up273b`, with modules on p5. It came back in 1.5 minutes, Wi-Fi on the first try.

| Item | Result |
| --- | --- |
| Kernel | `uname -r` 7.3.0-17.up273-5-ARCH |
| GPU | `GPU firmware: 27.3 (26C5035r), G17S` |
| Internal display | DCP `eDP-1` 3024x1964 at 120.00 Hz (Hyprland's `hyprctl monitors`) |
| Hyprland | running |
| Wi-Fi | associated, 10.168.168.116 |
| ANE | `H17 ANE: READY; IPC 0x10441 bytes requested`, `up at boot`, `/dev/accel/accel0` |
| AVE | `firmware build 26C5035 ... probe only`, `/dev/video0` |
| Camera | `/dev/video2`, 10 NV12 frames at 1920x1080, all different, auto exposure ramps the luma mean from 16 to 99 |
| Panel brightness (#1659) | `apple-panel-bl` swept 250 → 1000 → 300: the DCP ramps it (`brightness_changed`), no errors |
| Platform profile (#1655, #1656) | `/sys/class/platform-profile/platform-profile-0`: `apple-clpc`, `low-power balanced performance`, `balanced` |
| ProRes (#1586) | binds its DART, then `no apple/prores-t6050-init.bin and no built-in rows, engine not used` |
| AOP (#1521) | Same as up273cam-2: `apple_aop` RTKit up, `aop-sensors-las` (lid angle reads 130) and `aop-sensors-als` (present but off: `no ALS calibration named in the device tree; the sensor stays off`). Sound cards `AppleJ714` (Primary, Secondary, Speaker Sense) and `AppleJ714HPAI` (Microphone Array). speakersafetyd and speakerguardd inactive, so the speakers stay held |
| SEP / Touch ID (#1587) | no probe: the J714s `sep` node is `disabled` in this tree; only the `sep-firmware` reserved memory from Aura. The fingerprint sensor enumerates on SPI (`spi0.0`, `mesa-fingerprint`), but no driver in this kernel binds it |
| Errors | no SError, Oops, WARNING or call trace |

Not tested on 27.3: external displays (VRR, the HDR hints and formats), EDR with HDR content.

**AVE encoding on 27.3 works with the 27.0 command layout.** `apple-ave` reloaded with `ave_t6050_try_26a428=1` on the same boot:
- ffmpeg's `h264_v4l2m2m` is refused at session setup (-EOPNOTSUPP). That is the driver's own limit for the 26A428 layout, not the firmware: that layout takes 30 fps H.264 with B-frames, baseline or intra only (`ave-sess.c`). `v4l2-ctl` with Main and `video_b_frames=0` gets the same -95, which matches how ffmpeg sets up the encoder.
- `v4l2-ctl` with the driver defaults (Main, 3 B-frames, 30 fps), NV12 1920x1080 `testsrc2`: 30 frames give a 528 KB H.264 stream. ffprobe reads 30 frames, Main, 1920x1080; ffmpeg decodes it with no errors; luma PSNR against the source frames is 40.8-44.5 dB.
- 300 frames (the input looped) give 5.0 MB; all 300 decode with no errors. The kernel log has no DART fault, timeout or error.
- GStreamer `videotestsrc ! v4l2h264enc` (60 frames, 1920x1080 NV12, 30 fps) picks Baseline: a 1.0 MB stream, all 60 frames decode with no errors.
- HEVC (`pixelformat=HEVC`): session setup fails with -95. The driver refuses HEVC for this layout (`ave-sess.c`: no slice-header slot is known), as on 27.0.
- So the 27.3 firmware (26C5035, TEXT CRC c25b4ddb) speaks 26A428's H.264 command layout. The proposal is to admit it by default (for H.264) in the next 0004, after a second encode on another boot. Image -4 keeps the default probe-only, which is what was RAM-tested.

Dev Mac state: p4 `m5local/up273b` now holds up273-5 (Image.gz, dtb; the initrd is unchanged and carries no modules). up273cam-2's files are in `/root/up273b-backup-up273cam-2` on p5. Modules for `7.3.0-17.up273-5-ARCH` are in p5's `/usr/lib/modules`, and the test logs and the 30-frame stream are in `/var/lib/m5test`.

## Re-pin to integration/aurora 2b4523cb (image -5, 2026-11-12)

What upstream merged for the M5 after f8581cba:
- the T6050 CPU PMU (#1628)
- AVE HEVC on the 26A428 layout (#1638)
- the MTE guard: keep MTE off without reserved tag storage (#1639)
- T6050 JPEG encode, with the J714s engines enabled (#1675)
- brcmf WoWLAN for macOS-style sleep (#1679)
- DP audio across system sleep (#1681)
- the J714s MagSafe 3 PD controller (#1686)
- firmware 27 panel presents with no surface (#1674)
- the remaining DART power domains (#1676)
- rolotrealanis98's #1174, the partial-27.3 version (61a1fd086170 + bf43e8cefdf3)

**Correction:** the J714s Secure Enclave (#1325, 18d276c76c61, merged 2026-11-09) was already in f8581cba, so images -4 and before had it. The SEP node ships `disabled` on purpose: `apple_sep` enables it and its DART with a device-tree changeset when the module loads, and it has no module alias. On -4 nobody loaded it.

- **0001:** see the table. The earlier variant of this re-pin (fdde6bb) reverted upstream's #1174 merge and re-applied the first #1174. Following the coordinator, it was replaced by rolotrealanis98's commits on the merged #1174. Only DCP modules differ between the two builds; both were RAM-tested.
- **0004:** the AVE default change above. 0004 and 0005 apply unchanged on top.
- `patch -Np1` of 0001, 0004 and 0005 on the 2b4523cb tarball gives exactly the tree that was built (ush, `~/m5-build/up273-5/src`, branch `up-275r`).
- **Config:** unchanged; `olddefconfig` gives the same `.config` as up273-5.
- **Device tree** (J714s, against up273-5): the PMU, the MagSafe PD controller (`usb-pd@8`, `apple,no-liquid-detection`), both JPEG engines and their DARTs enabled, plus DART power domains.
- **Aura** stays 1.0.0b11 + 0002/0003/0006. Main since b12 has one T6050-relevant change, #184: reserve the MTE tag store (2 GiB at the top of RAM on a 64 GiB J714s), or boot with `arm64.nomte`. Kernel #1639 covers the b11 case: on these boots `/proc/cpuinfo` shows no `mte`. #184 is for -6.

### RAM tests of `7.3.0-17.up273-6-ARCH` (2026-11-12)

Booted through `loader-up273b-isp-bm.bin` (Aura b11 + 0002/0003/0006, test watchdog), from p4 `m5local/up273b`, with modules on p5.

| Item | Result |
| --- | --- |
| Kernel | `uname -r` 7.3.0-17.up273-6-ARCH (both builds) |
| GPU | `GPU firmware: 27.3 (26C5035r), G17S` |
| Internal display | DCP `eDP-1` 3024x1964 at 120.00 Hz (`hyprctl monitors`), with both the first #1174 and rolotrealanis98's commits |
| Hyprland | running |
| Wi-Fi | associated on the good boots |
| ANE | `READY; IPC 0x10441 bytes requested`, `up at boot`, `/dev/accel/accel0` |
| AVE | `firmware build 26C5035 ...`, now a full encoder (`/dev/video2`; the JPEG engines take video0/1) |
| Camera | `/dev/video3`, 10 NV12 frames at 1920x1080, all different, luma 16 → 108 (first build) and 18 → 138 (second) |
| PMU (#1628) | `hw perfevents: enabled with apple_t6050_pmu PMU driver, 10 counters` |
| JPEG (#1675) | `apple-jpeg ... JPEG encoder, HWREV 0x110010`, two engines |
| MTE (#1639) | no `mte` in `/proc/cpuinfo` (Aura b11 reserves no tag store) |
| Errors | no SError, Oops, WARNING or call trace |

**AVE, second H.264 encode (first boot of the first build, no module parameter):**
- `v4l2-ctl`, Main with 3 B-frames, 30 fps, NV12 1920x1080 `testsrc2`: 30 frames, 528 KB, ffprobe reads 30 Main frames; ffmpeg decodes them cleanly; luma PSNR 40.8-44.5 dB.
- 300 frames (looped input): 5.0 MB, all 300 decode.
- GStreamer `v4l2h264enc`: Baseline, 60 frames, all decode.
- No DART fault or timeout.
- This repeats -4's result (`7.3.0-17.up273-5`) on another boot and kernel, so 0004 now admits 27.3 for H.264 by default. On the rolotrealanis98 build, Main (30 frames) and GStreamer Baseline (60 frames) encoded and decoded cleanly again.

**AVE HEVC on 27.3 (rolotrealanis98 build):**
- Without the parameter, HEVC session setup gets -95, as intended.
- `apple_ave` reloaded with `ave_t6050_27_3_hevc=1` before any session. HEVC, 3 B-frames, 30 fps, NV12 1920x1080: 30 frames, 543 KB, ffprobe reads 30 Main frames, ffmpeg decodes them cleanly, luma PSNR 42.8-46.3 dB.
- So #1638's 26A428 slice-header path works on the 27.3 firmware. It stays off by default in -5 (one sample).
- `apple_ave` cannot be reloaded once its firmware has started (`firmware data is not in its boot state`), so the parameter has to be set before the first session.

**Secure Enclave and Touch ID on 27.3** (first build; `modprobe apple_sep xart_writes=0 provision_keybag=0`, read-only):
- Aura b11 already publishes what the SEP needs on 27.3: `memory-region` (`sepfw`), `local-policy-manifest` and `iboot-manifest` on `sep@502600000`.
- The driver picks `SEP platform profile: T6050/J714s` (warm attach). It resolves the xART `.gl` extent (170 slots, 11 live records, writes disabled) and reports `ready in 1433 ms: 12 endpoints (cntl sbio scrd sse hdcp xars sks xarm hibe pnon skdl stac), key store open`. It registers the hwrng and the `trusted` key type, and creates `/dev/sep-bio` and `/dev/sep-key`.
- upstream's `tools/aurora-sep/aurora-sep status`: 14 pass. keybag `unknown`, matching `blocked` (xART writes off).
- The fingerprint sensor binds when `/dev/sep-bio` is opened (upstream's `sensor-present`): `apple-mesa spi0.0: sep sensor: bound, 8000000 Hz, mode 2`, `sbio: communication initialization accepted`. Activation then stops at `Touch ID: no persisted identity keybag exists`.
- Enrol/verify was not tried. It needs the identity keybag, which `provision_keybag=1` creates by writing the xART store macOS shares, and a finger on the sensor. Upstream's userspace for it (`tools/aurora-sep`: `aurora-sep`, `aurora-touchid-setup`, the fprintd config, the Arch `aurora-sep` package) exists, but the image doesn't ship it.
- The host-state file the driver created (`/var/lib/aurora-sep-host-state.bin`) was moved to `/var/lib/m5test`.

**Boots and the open risks:**
- Six test boots of up273-6. The 2b4523cb base adds a new risk: hangs early.
- Clean: three boots (from up273-5 twice, from up273-6 itself once), each up in about 1.5 minutes.
- No Wi-Fi: one boot (rebooted from up273-6 after the SEP test). PCIe port 0 was not adopted, and the deadman reset it after 300 s. This is the known port 0 risk.
- **Early hang:** two boots, both rebooted from the dev Mac's daily kernel (`7.3.0-j714s-sleep`). No journal; the loader's 170 s watchdog reset the Mac. up273-5 rebooted from the same daily state came up normally, and so did up273-6 from up273-5 right after. So the hang follows the kernel that ran before, not the boot count. Not understood. An installed image's own reboots look like the clean case (one self-reboot tested). A cold boot from macOS or power-on has not been tried. An installed image has no watchdog, so such a hang would need a power cycle.

Dev Mac state:
- p4 `m5local/up273b` holds up273-6 (Image.gz and dtb; the same Image.gz for both builds).
- up273-5's files are in `/root/up273b-backup-up273-5` on p5.
- Modules for `7.3.0-17.up273-6-ARCH` (the rolotrealanis98 build) are in p5's `/usr/lib/modules`.
- Logs, the streams, the SEP status and `aurora-sep`/`sensor-present` are in `/var/lib/m5test`.

## Re-pin to integration/aurora 8679514f and Aura main (image -6, 2026-11-12)

What upstream merged after 2b4523cb: the H16 ANE recovering from a hung request (#1706), brcmfmac resetting the dongle before freeing host buffers on remove (#1707), the m2m engines' video nodes from video10 so the camera keeps video0 (#1708), the ProRes DART's SMMU window dropped on T8112/T602x (#1709), and T8142 s2idle (#1527).
- **0001, 0004, 0005** apply unchanged, without offsets. `patch -Np1` of the three on the 8679514f tarball gives exactly the tree built on ush (`~/m5-build/up273-7/src`) and RAM-tested as `7.3.0-17.up273-7-ARCH`. Config unchanged; the J714s dtb is byte-identical to up273-6's.
- **0004:** HEVC on the 27.3 AVE firmware is on by default (below).
- **Aura:** main d35655304e (after 1.0.0b12) with 0002/0003/0006 regenerated (only hashes and offsets changed: `git range-diff` shows all five commits identical) and the new 0007.
- **Video nodes (#1708):** the camera is `/dev/video0`; JPEG, AVE and AVD take video10-13, and AVE and AVD swap places between boots. Find AVE by name (`apple-ave`).

### The early hang and the missing Wi-Fi: one cause, in Aura (0007)

**Missing Wi-Fi.** With Aura's stage-2 log ring saved on every test boot (below), a boot without Wi-Fi showed:

```
SMC: /arm-io/apcie0/pci-bridge0 function-reset gP13 released: 0
pcie-t6050: port 0 link Gen1 x1
pcie-t6050: port 0 endpoint 106b:1900
pcie-t6050: storage after F: 0x419600048 0x0000006c -> 0x0000004d
pcie-t6050: storage after F: 0x419608114 0x00028801 -> 0x00208a01
pcie-t6050: storage after F: 0x280900150 0x1f0003ff -> 0x1000030f
pcie-t6050: STOP: storage changed after F
pcie-t6050: port 0 left down
```

The N1 link was up and the endpoint answered. Aura then refused the port, because a storage power-state register changed. 0x280900150 is the PMGR state of APCIE_SYS_ST0, the storage side's PCIe system domain. It runs under auto power management (AUTO_ENABLE, bit 28), and its hardware had gated it: PS_AUTO (bits 27:24) and the actual state (7:4) went 0xf -> 0, while target and auto-enable stayed. Aura's check allows only the actual state and the was-gated flags (0x3f0) to move. The ANS and NVMe registers that follow it were fine. The Linux side matches: on such a boot the DT has no `pci@0,0`, so Linux never sees port 0.

**Early hang.** The same check also runs after the shared stages A and S. A stop there makes `pcie_t6050_init()` return -1. kboot then refuses the T6050 hand-off (`kboot: refusing T6050 handoff after the apcie0 port 2 bring-up stopped`), `payload_run()` fails, Aura prints "No valid payload found", and it waits in its own USB proxy, which the dev PC's cable cannot reach, until the loader's 170 s watchdog. Linux never starts, so there is no journal.
- The timing fits every hang seen: reset 170 s after the loader armed the watchdog. A hung kernel that had taken the watchdog over would have reached the 240 s `watchdog.open_timeout`, or a lockup panic.
- During one hang (13:00 EST) the panel showed "No valid payload found".
- No Aura log of a hung boot survived: nothing in DRAM does (below). The trigger was caught on boots that 0007 let through instead: in 2 of 6 later boots the "before" reference caught APCIE_SYS_ST0 gated (`0x1000030f`) and stage A found it awake (`0x1f0003ff`), the same auto-PM movement the other way round. Without 0007 that is `STOP: storage changed after A`, a refused hand-off and "No valid payload found".

**0007** lets a storage domain with AUTO_ENABLE set before and after also move PS_AUTO. Measurements, all RAM test boots straight after the dev Mac's daily kernel (`7.3.0-j714s-sleep`), which is when the hangs were seen:

| Aura | Kernel | Boots | Hung (watchdog) | No Wi-Fi |
| --- | --- | --- | --- | --- |
| b11 + 0002/0003/0006 | up273-6-dbg (pstore, lockup detectors) | 4 | 1 | 0 |
| main + 0002/0003/0006 | up273-7 | 9 | 2 (one showed "No valid payload found") | 1 |
| main + 0002/0003/0006 + **0007** (test build retries a failed payload) | up273-7, HEVC default | **8** | **0** | **0** |
| the same, a second run while the image built | up273-7, HEVC default | **6** | **0** | **0** |

- With 0007, two of the eight rings show exactly the APCIE_SYS_ST0 change after F, now `allowed`, with `port 0 up`. Before 0007 those two boots would have had no Wi-Fi.
- In the second run, two of the six rings show APCIE_SYS_ST0 moving after A and S (`0x1000030f -> 0x1f0003ff`, `allowed`). Before 0007 both boots would have hung. The test build's payload retry never fired in the 14 boots (`TEST: payload failed` in none).
- Before the fix, the same day: 3 hangs in 13 from-daily boots (plus 2 of 2 in image -5's round), and 2 no-Wi-Fi boots, one of them from a test kernel.
- Not explained: why the hangs were only seen after the daily kernel, while a missing Wi-Fi also followed a test kernel. A random self-gate doesn't predict that. Nothing in the rings of good boots differs by predecessor.
- **Status for -6:** both observed and fixed: 14 of 14 from-daily boots with 0007 came up with Wi-Fi, 4 of them through the self-gate that would have cost Wi-Fi (2) or the boot (2).

**What did not work for capturing a hung boot** (worth knowing for the next one):
- On this Mac nothing in DRAM survives a reset through iBoot:
  - A ramoops region (test dtb), in RAM or in the ADT's `/pram` (0x105D98D8000, the 1.5 MiB XNU panic region), was empty on the next boot, even after a clean reboot of a test kernel into itself.
  - Aura's 16 KiB log ring at the top of RAM read as zeros from the next stage-1 catch.
  - So did the previous boot's kernel Image, at the address its ring had named.
- Reading `/pram` from the stage-1 m1n1 proxy faults it: its MMU maps RAM only to 0x105ca600000. That was the "kernel panic" seen on the Mac's screen at 12:27. The catcher no longer touches memory above stage 1's top.
- What worked: the test initrd installs a runtime-only systemd unit (in `/run`, nothing on disk) that copies the `aura_stage2.log` phram MTD to `/var/lib/m5test/aura-log/<boot id>-<release>.log` on every test boot that reaches the root, including boots without Wi-Fi.

### MTE (#184)

Aura main reserves the MTE tag store: `TagOffset_EL2 = 0x800001059a600000`, 0x1059a600000..0x105ca600000 (768 MiB, 1/32 of 24 GiB), and RAM ends at its base. Linux reserves `mte-tag-storage@1059a600000` (no-map), and all 15 CPUs report `mte` in `/proc/cpuinfo`. No MTE workload was run.

### AVE HEVC, second boot

Boot with `apple_ave.ave_t6050_27_3_hevc=1` on the command line, so it was set before the first session (the module cannot be reloaded once its firmware runs). HEVC with the driver defaults (Main, 3 B-frames, 30 fps), NV12 1920x1080 `testsrc2`:
- 30 frames, 543 KB: ffprobe reads 30 Main frames (21 B, 7 P, 2 I), ffmpeg decodes them cleanly, luma PSNR 41.9 (40.5-45.4) dB.
- 300 frames (looped input), 5.0 MB: all decode.
- No DART fault or timeout.

That is two clean boots (this and -5's), so 0004 makes HEVC the default. On the final kernel (HEVC by default, no parameter), HEVC 30 frames and H.264 30 frames both decode cleanly (PSNR 41.7 and 40.8 dB).

### Final RAM test of the -6 stack

The eighth 0007 boot ran Aura main + 0002/0003/0006/0007 (test watchdog) and `7.3.0-17.up273-7-ARCH` with HEVC on by default, without extra parameters:

| Item | Result |
| --- | --- |
| Kernel | 7.3.0-17.up273-7-ARCH, up in about 90 s on all 14 boots |
| GPU | `GPU firmware: 27.3 (26C5035r), G17S` |
| Internal display | `eDP-1` 3024x1964 at 120.00 Hz (`hyprctl monitors`), Hyprland |
| Wi-Fi | associated on all 14 |
| ANE | `/dev/accel/accel0` |
| AVE | H.264 and HEVC encode, decode clean |
| Camera | `/dev/video0`, 10 NV12 frames at 1920x1080 |
| MTE | on (above) |
| Errors | no SError, Oops, WARNING or call trace |

The packaged Aura is built from the same source minus the test watchdog and the payload retry (test-only), and its kernel from the same tree.

### Touch ID userspace

The image ships `aurora-sep` (aurora-silicon/linux `tools/aurora-sep` at 8679514f) and `libfprint-aurora` (libfprint 1.94.100 with aurora-sep-userspace 2ea454e0's aurora driver, sep-bio interface 5); recipes in `installer/recipes/aurora-sep-upstream` and `installer/recipes/libfprint-aurora`. Read-only until the owner opts in: `options apple_sep xart_writes=0 provision_keybag=0` in `/usr/lib/modprobe.d`, the loader no longer forces writes, fprintd doesn't load the driver, and no unit is enabled. Nothing was loaded, provisioned or enrolled on TripleU613's Mac for this image. The owner's procedure is `installer/recipes/aurora-sep-upstream/README.md` (installed as `/usr/share/doc/aurora-sep/README.omarchy-m5.md`). Keybag creation and enrolment are untried on a J714s on 27.3.

### Dev Mac state

- p4 `m5local/up273b`: up273-7's Image.gz (HEVC-default build) and dtb (identical to up273-6's), and the test initrd with the Aura-log unit.
- Backups on p5: up273-6 in `/root/up273b-backup-up273-6`, and the `-dbg` set in `/root/up273b-backup-up273-6-dbg`.
- Modules on p5:
  - `7.3.0-17.up273-7-ARCH`: the HEVC-default build.
  - `7.3.0-17.up273-6-ARCH-dbg`.
  - The first up273-7 build's modules are in `/root/modules-up273-7-hevcoff`.
- Rings, streams and logs: `/var/lib/m5test/aura-log`, `/var/lib/m5test/pstore`, `/var/lib/m5test/up273-7-*`.
- The catcher is back to plain `~/m5/tools/catch-loop.sh loader-daily-dcp-bm.bin`, and the Mac is on its daily kernel.
- For the libfprint-aurora build, `libgusb`, `glib2-devel`, `gobject-introspection`, `gtk-doc` and `umockdev` were installed on p5. The package builds are in `/home/tripleu/m5-work` (`up6/`, `aura-up/`, `linux-aurora-up/`).
- Not booted as packaged: the linux-aurora and m1n1-aurora packages themselves (their sources were). The read-only branch of aurora-sep's loader has not run on a Mac.

## Re-pin to integration/aurora 3766943238bd and panel VRR (image -7, 2026-11-12)

Image: [`j714s-developer-image-upstream-2026.11.12-7`](https://github.com/betizzel/omarchy-m5/releases/tag/j714s-developer-image-upstream-2026.11.12-7) (prerelease). Built by CI run [43303056006](https://github.com/betizzel/omarchy-m5/actions/runs/43303056006) from inputs [`installer-build-inputs-j714s-947e002931eb`](https://github.com/betizzel/omarchy-m5/releases/tag/installer-build-inputs-j714s-947e002931eb), set `j714s-dev-runtime-f42a2e2eb85c`. Update check run [43306248588](https://github.com/betizzel/omarchy-m5/actions/runs/43306248588): pacman exited 0, and linux-aurora up273-8 and m1n1-aurora up273-3 were kept over the channel's versions.

What upstream merged after 8679514f:
- DjDeveloperr's SPMI generation 4 fault queue (#1713). On the J714s, both SPMI controllers drain 8 queued faults at probe (`apple-spmi ...: fault 0x6a100f00 (1 so far)`); nothing after.
- MTE: no asynchronous tag checking without FEAT_MTE_ASYNC (#1695).
- ATC: say which condition stops the host for a sleep (#1701).
- T8140 fixes (#1700, #1715).

No other T6050 or J714s work was merged into `integration/aurora` or Aura main (still d35655304e) since -6. Still open upstream, so not in -7: #1601 (T6050 GPU mailboxes by polling), #1618 (Clock PM masked on adopted T6050 endpoints), #1699 (T6050 USB DARTs across sleep).
- **0001, 0004** apply unchanged. **0005**: its two J714s DT hunks moved by 8 lines; only those two hunk headers changed.
- **0008 (new):** rolotrealanis98's panel VRR, see the table.
- `patch -Np1` of 0001, 0004, 0005 and 0008 on the 3766943238bd tarball gives exactly the tree built on ush (`~/m5-build/up273-8/src`, branch `up-278`). Config unchanged. The J714s dtb differs from up273-7's because of upstream DT changes.
- **Aura:** unchanged from -6 (m1n1-aurora 1.6.1.aurora24.up273-3).

### The -6 packages, booted as packaged

-6's packages had never been booted themselves, so these boots used the packages from the -6 inputs bundle (`installer-build-inputs-j714s-218219a5e83d`, package hashes as in its manifest):
- **Kernel.** linux-aurora 7.3.0.aurora17.up273-7. Its `vmlinuz` is a raw Image (sha256 `cbeef90d...`). It went onto p4 `m5local/up273b` gzip'd as `Image.gz` (decompressed bytes identical), with the package's `dtbs/t6050-j714s.dtb` (byte-identical to the ush build's). The package's module tree went to p5, and the ush-built tree with the same release name was moved aside. `/proc/version` shows the package's build stamp: clang 23.1.4, `Thu, 12 Nov 2026 18:43:09 +0000`.
- **Aura.** The stage 2 an installed image runs is the first part of `m1n1/boot.bin`, which `update-m1n1` writes as `cat m1n1.bin dtbs; gzip u-boot`. So m1n1-aurora's `/usr/lib/asahi-boot/m1n1.bin` (the `ESP_STAGE2=1` build, 3997696 bytes, sha256 `2de10833...`) is that Aura, separable byte for byte. The RAM loader was this file plus the usual config tail (`boot=` p4 `m5local/up273b`, the bootargs, `chosen.asahi,show-notch=1`) in place of the dtbs and U-Boot. `aura-raw.bin` is the stage 1 flavour and was not used.

| Boot | Aura | Kernel | Result |
| --- | --- | --- | --- |
| 1 | -6 test loader (0007, test watchdog) | packaged up273-7 | full pass |
| 2, 3 | **packaged m1n1.bin** (`asahi,m1n1-stage2-version` 1.0.0b12-gd3565530-dirty) | packaged up273-7 | full pass |

- "Full pass" means: GPU 26C5035r; eDP-1 3024x1964 at 120 Hz under Hyprland; Wi-Fi; `/dev/accel/accel0`; AVE H.264 and HEVC, 30 frames each, decoding cleanly; camera `/dev/video0`, 10 distinct frames at 1080p; MTE on 15 CPUs; no SError, Oops or WARNING.
- On boot 3, the packaged Aura's 0007 path fired: `storage after F: allowed`, then `port 0 up`.
- Image -7's own `m1n1/boot.bin` (CI run 43303056006) starts with exactly this `m1n1.bin`: its first 3997696 bytes match it byte for byte.
- **The packaged-Aura boots had no watchdog.** Packaged Aura calls `wdt_disable()` at its start, which drops the 170 s the proxy arms. Its own boot watchdog only arms on `wdt-version` 2, and T6050 is 3. So only two such boots were run; the stability runs below use the test loader.

### Panel VRR (0008) on the J714s eDP

Booted with `appledrm.fw27_panel_vrr=1` in the loader's bootargs:
- **The panel offers VRR.** The eDP connector's `vrr_capable` is 1, Hyprland shows `vrrCapable: yes`, and the mode set logs `vrr:1`. Without the parameter, `vrr_capable` is 0 and nothing changes.
- **Hyprland enables it.** `hyprctl eval 'hl.config({ misc = { vrr = 1 } })'` gives `vrr: true` and `VRR_ENABLED 1: selecting "3024x1964" ... again`. The firmware logs `IOMFBParameter_adaptive_sync Req minRR = 0x180000` (24 Hz). `vrr = 0` sends `minRR = 0x0`. The mode stays 3024x1964@120 throughout.
- **What swap timing does and doesn't show.** The DCP's `iomfb_swap_complete` tracepoint, with mpv paced at 48 fps full screen, gives steady 20.8 ms swaps with VRR on. 120 fps content gives 8.3-8.4 ms.
  - A control boot **without** the parameter (`vrr_capable` 0, Hyprland `vrr: false`) gives the same steady 20.8 ms. So does `iomfb_vrr_timestamps` (`enabled=0`, firmware timestamps 20.8 ms apart).
  - So neither tracepoint shows when the panel scans out, and they cannot prove the panel refreshes at the content's rate.
  - Some samples, in either state, showed 12.5/16.7/25/29.1 ms swap intervals. They did not follow the VRR state. They were mostly the first sample after mpv started, so they say more about the client than the panel. An earlier reading of them as "VRR off does not restore a fixed rate" is withdrawn.
  - Established: the panel offers VRR, Hyprland enables it, the firmware takes `minRR` 24 Hz on and 0 off, and it stays stable. Not yet measured: the panel's actual refresh (needs a scanout-side timestamp or a camera on the panel).
- **Stable:** in 7 boots with the parameter on (a 2-minute 48 fps run on the first, 48 fps with off/on toggles on each; each boot's kernel journal checked afterwards), there was no `adaptive swap timed out`, no retraining and no error. Hyprland stayed at 120.00 Hz. The packaged up273-8 boot with the parameter is clean too.
- **Image -7 ships it opt-in**, as written: add `appledrm.fw27_panel_vrr=1` to the kernel command line, then turn on Hyprland's `misc.vrr`.

### RAM tests of `7.3.0-17.up273-8-ARCH`

Booted through the -6 loader template (Aura main + 0002/0003/0006/0007, test watchdog; `loader-up273-8-bm.bin`, and `loader-up273-8-vrr-bm.bin` with the VRR parameter), every boot from the dev Mac's daily kernel:

| Item | Result |
| --- | --- |
| Boots | 8 of 8 up in 84-91 s: one without the VRR parameter, then seven with it (one VRR session, six stability boots in a row) |
| GPU | `GPU firmware build: 26C5035r for T6050 G17S` |
| Internal display | `eDP-1` 3024x1964 at 120.00 Hz, Hyprland |
| Wi-Fi | associated on all 8. Aura's 0007 path (`storage after ...: allowed`) fired on 5 of the 8, and on the packaged boot |
| ANE | `/dev/accel/accel0` |
| AVE | H.264 and HEVC, 30 frames each, decode clean on all 8 |
| Camera | `/dev/video0`, 10 distinct NV12 frames at 1920x1080 on all 8 |
| MTE | 15 CPUs |
| Errors | no SError, Oops, WARNING or call trace |

Then the **up273-8 package itself** (linux-aurora 7.3.0.aurora17.up273-8, the one in image -7; `/proc/version` clang 23.1.4, `20:23:47 +0000`), with its Image (gzip'd), dtb and module tree, through `loader-up273-8-vrr-bm.bin`. It gave the same full pass, with `vrr_capable` 1. A later control boot of the same package without the parameter also passed (9 up273-8 boots in all).

### Dev Mac state

- p4 `m5local/up273b` holds the packaged up273-8 Image.gz and dtb, with the same test initrd. The ush build's files are in `/root/up273b-ush-up273-8`, and its modules in `/root/modules-up273-8-ush`.
- Backups on p5:
  - `/root/up273b-backup-up273-7`: the ush up273-7 Image.gz, dtb and initrd.
  - `/root/up273b-pkg-up273-7`: the packaged up273-7 Image.gz.
- Modules on p5:
  - `7.3.0-17.up273-8-ARCH`: the packaged tree.
  - `7.3.0-17.up273-7-ARCH`, now the packaged tree; the ush-built one is in `/root/modules-up273-7-ush`.
- Logs: `/var/lib/m5test/up273-8/<tag>` (pass lists, dmesg, VRR timings) and `/var/lib/m5test/aura-log`.
- The Mac was left on the packaged up273-8 (a test boot, the no-VRR control); the catcher is back on `catch-loop.sh loader-daily-dcp-bm.bin` for the next reboot.
- Also on p5: `/root/pkg-up273-7-old` (the -6 linux-aurora packages), `/root/Image-pkg-up273-7.gz`. The `linux-aurora-up` build tree's old src, pkg and 8679514f tarball were deleted, and the up273-8 package was built there.
- Test loaders in `~/m5/tools`: `loader-up273-7pkgk-bm.bin`, `loader-up273-7pkgaura-bm.bin`, `loader-up273-8-bm.bin`, `loader-up273-8-vrr-bm.bin`.

## Re-pin to integration/aurora e661192638a3 (2026-11-12): built, not booted

`linux-aurora-upstream` pkgrel 9 (`7.3.0-17.up273-9-ARCH`) on `integration/aurora` e661192638a3, 90 commits after 3766943238bd. Image -8 ships it with 0009 added, as pkgrel 10 (next section). Nothing from e661192638a3 has been booted on the Mac.

New in it for the J714s and T6050:
- erikwb's `DMA_ATTR_NO_BOUNCE` (#1608) and `GEM_USERPTR` (#1609).
- joshuaswarren's T6050 GPU mailboxes by polling (#1601), and its quick-poll follow-up (a23755c12ee9).
- The SEP trusted-accessory service (stac/sse/pnon, #1720) and the K116s SEP profile.
- brcmfmac kept in D0 across s2idle (#1722).
- The DCPEXT crossbar output parked for s2idle (#1723).
- The DP audio domain powered for a link held at resume (#1735).

Already in -7's 3766943238bd: #1679 (WoWLAN), #1707, #1713, and the external display PRs #1515, #1600, #1614, #1640 and #1641. The rest of the range is other machines: T8132/J604 DP alt mode, T6041/J575c, T8142, the J614s dcpext2 routes, Centauri Wi-Fi, and K114c.

- **0001, 0004, 0005, 0008 apply unchanged** (`patch -Np1`, offsets only; 0005's ISP hunks move 5 lines after Jens Axboe's "Report the detected camera"). Their sha256 in the recipe are unchanged.
  - Upstream's only `iomfb_v27.c` change is CoreAnalytics logging at debug level (#1726). There are no new IOMFB methods or swap fields, so 0001's 27.3 table still covers everything.
- **Build.** Cross-built on ush, `~/m5-build/up273-9`; `src` is the `up-279` worktree of `linux-up`, same `build.sh` as up273-8.
  - `BUILD-OK`. 41 warnings, the same count as up273-8.
  - Config identical to the recipe's `config` and to up273-8's.
  - `patch -Np1` of the four patches on the e661192638a3 tarball (sha256 `93226922...`) gives exactly the built tree.
  - The PKGBUILD's `check()` test passes (35 tests). All dtbs the package installs are built.
  - `t6050-j714s.dtb` is byte-identical to up273-8's.
  - Image.gz sha256 `c627e7bd...`, modules in `mods.tgz`.
- **Aura:** unchanged (d35655304e + 0002/0003/0006/0007). Aura main is now addd0bfc. What it added since is the J614s dcpext2 hand-off, the T8132 AVE hand-off, the T8142/T8152 GPU firmware, and 27.2 firmware support. None of it touches T6050.
- Not done yet: the `installer/patches-upstream-27.3` pin, the image, and a RAM test.

## External displays on 27.3: why dcpext0/dcpext2 time out, and HDMI (offline, 2026-11-12)

The test (up273-8, 22:48): HDMI plugged in, no hotplug. `2b2e00000.dcp` and `302e00000.dcp` print `deferred probe timeout, ignoring dependency` and `external display processor unusable (probe failed: -110)` at 61.67 s; `392e00000` and `306e00000` come up.

File:line references below are in the up273-9 tree (e661192638a3 + patches, DCP code unchanged from 3766943238bd), the J714sAP 27.3 ADT dump (`~/m5/private/postupdate-27.3-20261108/04-j714s-full-27.3.txt`) and Aura main.

### Two separate problems

**1. dcpext0 and dcpext2: a module load-order race with the T6050 combo PHY.** *Confidence: the mechanism is high; which of the four suppliers lost the race (most likely the PHY, see below) still needs RAM-test step 1.*

- **Only the engines with Type-C routes fail.**
  - dcpext0 (`2b2e00000`, `t6050-dieX.dtsi:152`) and dcpext2 (`302e00000`, `t6050-peripherals.dtsi:2839`) have `typec-routes`: route@1 to the left-front port through `<&atc1_phy 6>` and `<&atc1_dpxbar 0>`, and dcpext2's route@0 through `<&atc2_phy 6>` and `<&atc2_xbar 0>` (`t6050-j714s-display.dtsi:17-104`; dcpext0's route@0 is disabled in `t6050-max-atc2.dtsi:74-86`).
  - dcpext1 and dcpext3 have no routes.
- **The -110 path.** A T6050 dcpext is "failsafe" (`dcp.c:5977`). `dcp_platform_probe()` (`dcp.c:6954`) first needs `dcp_ext_route_suppliers()` (`dcp.c:6850`: `of_phy_get` and `mux_control_get` on each route), then `dcp_ext_bind_suppliers()` (`dcp.c:6904`: the PIODMA DART and the mailbox). On -EPROBE_DEFER it asks `driver_deferred_probe_check_state()`. Once the deferred-probe timer has expired, that returns -ETIMEDOUT on the very first deferral (`drivers/base/dd.c:292-294`), and `dcp_ext_give_up(..., "probe")` (`dcp.c:7011`) prints the line seen.
- **Why the timer had expired.**
  - The timer is 10 s (`CONFIG_DRIVER_DEFERRED_PROBE_TIMEOUT=10`), restarted by each driver registration.
  - The test initrd loads these modules from p5's root, and systemd on the root starts at about 60 s.
  - In the saved log of an earlier up273 boot, the internal DCP `48ae00000` and dcpext1 also first appear at 62.048 s, between dcpext0's and dcpext2's timeout lines: appledrm itself was only loaded at about 62 s. So the dcpexts did not wait a minute; their first probe deferred and was final.
- **Why a route supplier was not there yet.**
  - `appledrm.ko` already soft-depends on the crossbar: `MODULE_SOFTDEP("pre: mux-apple-display-crossbar macsmc-power")` (`apple_drv.c:2118-2126`). Its comment describes exactly this failure for the crossbar ("a DCP probe that waits past the deferred probe timeout ... gives up its routes").
  - On T6050 the routes' PHYs come from a different module, `atc-t6050-dp.ko` (`drivers/phy/apple/atc-t6050-dp.c`, which binds `apple,t6050-combo-phy`). appledrm has no hard dependency on it (`modules.dep`: appledrm needs apple-pmp, dcp-fabric-core, snd, typec, thunderbolt) and no softdep.
  - So udev loads the PHY module and appledrm in parallel. If appledrm probes a dcpext before `atc1_phy`/`atc2_phy` have registered their PHY provider, the route lookup defers, and the expired timer makes that final.
  - USB on those ports still comes up afterwards, because dwc3 keeps deferring normally.
- **What it is not.**
  - **Not Aura's dcpext hand-off.** In the static dtb all four dcpext nodes, their mailboxes and DARTs are `disabled`. Aura's `t6050_ext_one()` (aura `src/kboot_display_handoff.c:3567-3688`) is the only thing that enables them, and all four probed. So Aura handed all four over on 27.3 (0002 makes it accept the 27.3 DCP image for dcpext too).
  - **Not the DART or mailbox.** dcpext1 and dcpext3 pass the same `dcp_ext_bind_suppliers()` check.
  - **Not a static DT problem.** A supplier walk over `t6050-j714s.dtb` finds all four route suppliers `okay`, with `okay` power domains and parents.
  - **Probably not Aura's PHY tunables**, though only partly checked. `t6050_setup_atc()` (`src/kboot_atc.c:1184`) exports by compatible for ports 1-5. Every ADT name it reads is in the 27.3 ADT for atc-phy1 and atc-phy2. The banks it checks against `reg[]` match for reg[40..43], reg[0] and usb-drdN reg[3]. Not checked: the core sub-banks, and that usb-drdN's `atc-phy-parent` equals the PHY's phandle.
- **aura #166** (petrskuta, merged in Aura main, f0adc275) hands over the J614s's dcpext2 firmware memory on T6041 (`t6041_exts`). That is the T6041 path, where Linux needs carve-outs filled; T6050's dcpexts are adopted running and already handed over. It does not apply here.
- **The earlier "the panel waits a minute" note is withdrawn.** Here appledrm itself loaded late, so the panel was not held up by the dcpexts. On an installed image whose initramfs loads appledrm in the first seconds, the race may or may not show.

**2. HDMI is not described in the J714s device tree.** No hotplug is possible even with every dcpext up. *Confidence: high.*

- **The ADT has the HDMI path.**
  - `atc3-dpphy`: `port-type` 6, the same as `port-hdmi0`; `dp-switch-dfp-endpoint` 3 on `display-crossbar0`; `dpxbar-parent` = `atc3-dpxbar@8B24C000`; `dp2hdmi-gpio-parent` = `dp2hdmi-gpio0`. ADT lines 7421-7437.
  - `dp2hdmi-gpio0` (lines 9511-9525):
    - `function-hdmi_hpd` is aop-gpio0 pin 14.
    - `function-hdmi_pwr_en` is SMC pcIO (0x800000, 0xf0000).
    - `function-dp2hdmi_pwr_en` is pcIO (0x0, 0x1a0000).
    - These are the same templates as J716s (`t6050-j716s.dts:178-180`) and J775d (`t6050-j775d.dts:352-357`).
  - The `parade,DP855` on spi4 (line 3605) is the panel TCON, not the HDMI converter.
- **The DT has none of it.**
  - `t6050-j714s.dts:306-312` disables `atc3_phy` and its mailbox ("ATC3's USB chain ... stay off").
  - `atc3_dpxbar` (`t6050-peripherals.dtsi:1660`) stays disabled.
  - No dcpext has `apple,connector-type = "HDMI-A"`, `hdmi-hpd-gpios` or a `dp-phy`/`dp-xbar`.
  - `smc_pcio` drives only `sd_pwr_en` (`t6050-j714s.dts:291-292`).
- **Nobody upstream has T6050 HDMI output.**
  - DjDeveloperr's #1515 was validated on a J714s with a USB-C display (left-front) and a Thunderbolt dock (right), not HDMI.
  - J775d's HDMI description (die 1's LPDPTX) is marked "No output yet" (`t6050-j775d.dts:676-680`).
  - No open PR or branch covers J714s/J716s HDMI. erikwb's `ewb/j716c-public-*` branches are USB4/Type-C.
- **The PHY driver has a fixed-bridge mode, but no board uses it.**
  - `atc-t6050-dp.c` also binds `apple,t6050-dp-phy` (DjDeveloperr's d1ccc586855d, in `apple,combo-phy.yaml`): no Type-C, no PHY firmware, three domains, `of_phy_simple_xlate`.
  - For ATC3 as a fixed HDMI PHY, it needs:
    - its core `reg` sized to 0x2c400 (`atc-t6050-dp.c:888`; the die0 node has 0x2c000);
    - the nine non-Type-C tunables (`:972-981`), which Aura's `t6050_setup_atc()` fills only for `apple,t6050-combo-phy`. They would have to come from the ADT statically, or Aura's export would have to cover the DP compatible.

### 0009 (in the recipe since pkgrel 10, image -8)

`0009-linux-drm-apple-softdep-t6050-combo-phy.patch`: appledrm's softdep becomes `pre: mux-apple-display-crossbar atc-t6050-dp macsmc-power`, the same fix upstream already made for the crossbar.
- One line; applies on the up273-9 tree after 0001/0004/0005/0008.
- Compiled on ush: `apple_drv.o`'s modinfo carries the new softdep.
- Step 2 below (the softdep as `/etc/modprobe.d/m5-appledrm-dpphy.conf` on up273-8) passed: all four external DCPs bound, no -110, and DRM offered DP-1..DP-4. No monitor plugged in yet.
- The kernel with 0009 compiled in (`7.3.0-17.up273-10-ARCH`) is not booted yet.
- mkinitcpio also follows `MODULE_SOFTDEP`, so on an installed image the PHY module would go into the initramfs with appledrm.

### RAM test for the next free slot

1. **Without any change (up273-8 or up273-9).** After boot, run:
   ```
   for d in 2ab000000.phy 383000000.phy 2ab24c000.mux 38324c000.mux; do
     printf '%s -> %s\n' $d "$(readlink /sys/bus/platform/devices/$d/driver)"; done
   dmesg | grep -nE 'apple-dcp|atc-t6050|t6050-dp-phy|2ab000000|383000000|24c000|systemd\[1\]: Started'
   ```
   - All four bound after boot, with appledrm's first line before the PHY's bind, means it is the race (expected).
   - A supplier that is still unbound points to a real probe failure. Its dmesg line names it (`missing or invalid apple,tunable-*`, `cannot attach ... domain`, `cannot power crossbar controls`). Then also keep Aura's `FDT: T6050 ATCn tunables copied|unavailable` lines.
2. **The no-code workaround.** In the loader bootargs, either:
   - `/etc/modprobe.d/` on p5: `softdep appledrm pre: atc-t6050-dp`; or
   - `deferred_probe_timeout=120`.
   
   dcpext0 and dcpext2 should then probe. Look for no -110, and `apple-drm display-subsystem: bound` without "unusable".
3. **Then 0009 itself** (kernel `7.3.0-17.up273-10-ARCH` = up273-9 + 0009), with no modprobe.d line.
4. **Display test:** a USB-C display on the left-front port and on the right port. HDMI will stay dark until problem 2 is done.

### Proposal

- **Problem 1:** step 2 passed, so 0009 went into the recipe for image -8 (pkgrel 10). Still to do: RAM-test up273-10 (step 3), plug in a USB-C display (step 4), then send 0009 upstream as a one-line PR next to the crossbar softdep.
- **Problem 2:** a DT port onto the existing, but unused, `apple,t6050-dp-phy` mode. It is not a new driver, but it is untested on any board, so it waits for someone upstream, unless the user wants us to try it. The pieces, in the J614s HDMI layout (petrskuta's #1585, `t6040-j614s-extdisp-hdmi.dtsi`):
  - **The PHY:** `atc3_phy` as `apple,t6050-dp-phy` with the 0x2c400 core and the ADT's ATC3 tunables, and three domains (usb-aon, common, wrapper).
  - **The crossbar:** `atc3_dpxbar` on with `power-domains = <&ps_atc3_usb_aon>, <&ps_atc3_common>`.
  - **The engine:** dcpext1 (no routes), with:
    - `apple,connector-type = "HDMI-A"`
    - `phys = <&atc3_phy>` named `dp-phy`
    - `mux-controls = <&atc3_dpxbar 0>` named `dp-xbar`
    - `mux-index = <2>` (2 × ufp 1 + port 0)
    - `apple,dptx-phy = <3>`, `apple,dptx-die = <0>`
    - `hdmi-hpd-gpios = <&pinctrl_aop 14 GPIO_ACTIVE_HIGH>`
    - `hdmi-pwren-gpios = <&smc_pcio 1 GPIO_ACTIVE_HIGH>`, `dp2hdmi-pwren-gpios = <&smc_pcio 2 GPIO_ACTIVE_HIGH>`
  - **The SMC outputs:** `smc_pcio` `apple,output-commands` = `<0x0019000000000000 0x000f000000800000 0x001a000000000000>`.
  - **The DCP side is generic** (`dcp.c:6630-6766`: HPD IRQ, converter power, `dp-xbar` select). Whether the firmware 27 dcpext drives an HDMI DPTX port is untested anywhere.

## 0009 in the recipe: up273-10 and image -8 (2026-11-12)

Image: [`j714s-developer-image-upstream-2026.11.13-8`](https://github.com/betizzel/omarchy-m5/releases/tag/j714s-developer-image-upstream-2026.11.13-8) (prerelease). Built by CI run [43341262146](https://github.com/betizzel/omarchy-m5/actions/runs/43341262146) (head ef44aff) from inputs [`installer-build-inputs-j714s-4fc7743353dc`](https://github.com/betizzel/omarchy-m5/releases/tag/installer-build-inputs-j714s-4fc7743353dc), set `j714s-dev-runtime-60d0be7e4391`. Update check run [43344092181](https://github.com/betizzel/omarchy-m5/actions/runs/43344092181): pacman exited 0, and linux-aurora up273-10 and m1n1-aurora up273-3 were kept over the channel's versions.

- **Kernel:** `linux-aurora-upstream` pkgrel 10, `7.3.0-17.up273-10-ARCH`: e661192638a3 + 0001/0004/0005/0008 + **0009** (the recipe's `drm-apple-softdep-t6050-combo-phy.patch`, recipe at 152b6ef). pkgrel 9 (`up273-9`) stays the name of the tree without 0009.
- **Why 0009 went in before its own boot:** the same softdep as `/etc/modprobe.d/m5-appledrm-dpphy.conf` on the dev Linux (up273-8) made all four external DCPs bind, with no -110, and DRM offered DP-1..DP-4. No monitor plugged in yet.
- **Package**, built on the Mac (`~/m5-work/linux-aurora-up`, makepkg): `linux-aurora-7.3.0.aurora17.up273-10-aarch64.pkg.tar.zst`, sha256 `8df8da52...`. `modinfo appledrm` softdep is `pre: mux-apple-display-crossbar atc-t6050-dp macsmc-power`. `atc-t6050-dp` declares no firmware.
- **Image -8's initramfs** (the UKI's `.initrd`) has neither `appledrm` nor `atc-t6050-dp`; both load from the root, as in the dev Linux test. The softdep makes `modprobe appledrm` load the PHY module first. 41 compiler warnings, as in up273-9.
- **Cross-build on ush**, for the RAM test: `~/m5-build/up273-10` (`src` is worktree `up-2710` of `linux-up`). `BUILD-OK`. `patch -Np1` of the five patches on the e661192638a3 tarball gives exactly that tree. `t6050-j714s.dtb` is byte-identical to up273-9's. Image.gz sha256 `5538e302...`, modules `mods.tgz` (`32ccbf6c...`).
- **Not booted:** neither the package nor the ush build. The RAM test (steps 3 and 4 above) is next.
- **Aura** and the other packages are unchanged from -7.

### Wi-Fi and Bluetooth on an installed image: `vendorfw/firmware.cpio`

The -7 image installed with `tools/install-image/install-from-linux.sh` had no Wi-Fi or Bluetooth.
- **Why:** the N1 drivers (`apple_centauri_t6050`, `btcentauri_t6050`) are not in the image's initramfs; udev loads them from the root right after the switch. Their firmware is only there in time through `omarchy-mac-boot`'s initrd units (`omarchy-vendorfw-initrd.sh`, `omarchy-vendorfw.sh`). These unpack `vendorfw/firmware.cpio` from the ESP and mount it on the new root's `/lib/firmware/vendor` before the switch. The script wrote only `firmware.tar`.
  - The late root service `omarchy-vendor-firmware.service` does extract `firmware.tar` into `/lib/firmware`, but then reloads only `brcmfmac` and `hci_bcm4377`. Neither the upstream kernel nor our stable kernel (`apple_centauri`, `btcentauri`) uses those for the N1, so the late path never retries the N1.
- **The image path has no gap.** The image zip carries no `vendorfw` (it is per machine). Its `installer_data.json` asks for `copy_firmware: true` on the EFI partition. The installer engine's `asahi_firmware.core.FWPackage` then writes `firmware.tar`, `firmware.cpio` (the same files under `vendorfw/`, plus `vendorfw/.vendorfw.manifest`) and `manifest.txt`. It also collects the N1 FTAB (`omarchy_centauri`). The engine's recovery stager requires all three files. The stable image gets its firmware the same way.
- **The fix**, 7de632b: `install-from-linux.sh` now writes `firmware.cpio` in the FWPackage layout. The installed -7 got it by hand, and then Wi-Fi connected (78aa416).
- **Left as is:** the late service's reload list, which belongs to omacom's `omarchy-mac-boot`. Adding the N1 modules to it is untested: reloading a PCIe driver at runtime is a risk of its own.

