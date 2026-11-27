> Moved from the top-level README on 2026-11-11 (the README is now the short version). Detailed status, history and the bring-up story are kept here as they were.

## Images so far (moved from the README on 2026-11-14)

There is one image line now: `omarchy-j714s N`, installed from macOS with Omarchy Installer on
Apple's 27.2 firmware. The newest is on the [README](../README.md). The older ones, newest first:

| Image | What it was | Why it was replaced |
| --- | --- | --- |
| `omarchy-j714s 8` | kernel v272-12: lid sleep (s2idle), the shared M5 boot guard (j714s13), engine `d33f2cef00c4` | replaced by 9 for kernel v272-17 (DP audio on docks), video decode by default (j714s14), the Hyprland EDID guard and Aura 0008 |
| `omarchy-j714s 7` | 6 plus the boot guard (#11, firmware j714s12) and the speaker switch-over waiting for the speaker card | replaced by 8 for lid sleep (kernel v272-12) and the shared M5 boot guard (j714s13) |
| `omarchy-j714s 6` | kernel v272-11 (fans, thermal limit, Bluetooth RFCOMM, dock fixes) and hyprland-m5 0.57.2-3; the first from-scratch install | replaced by 7 for the boot guard (#11) and the speaker switch-over timing |
| `omarchy-j714s 5` | kernel v272-7: HDMI 4K and USB-C DP on the left port | replaced by 6 for fans, thermal limit, Bluetooth RFCOMM, dock fixes |
| `omarchy-j714s 4` | 3 plus the boot-mount fix for two installs on one disk (firmware j714s10) | HDMI 4K stayed blank and `ufw` failed: kernel v272-7 in 5 |
| `omarchy-j714s 3` | 2 plus built-in sound on 27.2 (Jens Axboe's AOP fix), AOP loaded at boot | a second Omarchy install on the disk could take its kernel updates: fixed in 4 |
| `omarchy-j714s 2` | 1 plus the 27.2 Neural Engine pin, FatBoy721's HDMI v1, speakerguardd v2 | no built-in sound on 27.2: fixed in 3 |
| `omarchy-j714s 1` | first 27.2 image with the Mac installer | boot loop after install (Aura stage 2 handed U-Boot a powered-off disk, [`install-failure-2026-11-13.md`](install-failure-2026-11-13.md)): fixed in 2 |
| `j714s-developer-image-upstream-2026.11.1x-N` | aurora-silicon's kernel and Aura on the 27.3 beta firmware; camera, Neural Engine, video encode, Touch ID first worked here | the maintainers target 27.2, not the beta ([`move-to-27.2.md`](move-to-27.2.md)) |
| `j714s-developer-image-2026.11.11-7` ("stable") | the original line on the 27.3 beta stub, installed from a Linux PC ([`bringup.md`](bringup.md)) | replaced by the Mac installer line |

### Reports from other owners on the 27.3 line

From FatBoy721 ([#6](https://github.com/betizzel/omarchy-m5/issues/6)), on his J714s machines with
the 27.3 beta stub:

- **Touch ID works on a second J714s** with the `aurora-sep-upstream` and `libfprint-aurora` recipes
  as written: enrolment, verify, verify again after a reboot, and `sudo` and the lock screen
  unlocked by fingerprint (password still works as the fallback). That makes two J714s machines
  on 27.3. Not tried on 27.2 yet.
- **An old m1n1 Stage 1 in front of an Aura Stage 2 hangs on the logo.** Our U-Boot runs the ANS
  handshake again when the controller isn't already enabled and `/chosen/asahi,nvme-adopt` is
  not set, and the firmware accepts that handshake only once per boot. His one-line fix: add `chosen.asahi,nvme-adopt=live-rtkit-v1` to
  the end of `m1n1/boot.bin`. The 27.2 images are fresh installs with Aura as Stage 1, so they
  don't use that combination. Release 1's boot loop, under Aura's own Stage 1, was a different
  hand-off problem, fixed by aura #213 from release 2 on
  ([`install-failure-2026-11-13.md`](install-failure-2026-11-13.md)).

The rest of this file is older still and is kept as it was.

# omarchy-m5

Bringing [Omarchy](https://omarchy.org) - Arch Linux ARM + Hyprland - to the
**M5 Pro MacBook Pro**: Apple **T6050 "Sotra"**, Mac17,9 / J714s, dual-booted
beside macOS, Asahi-style.

This is frontier J714s bring-up, built on
[m1n1](https://github.com/AsahiLinux/m1n1) and
[linux-asahi](https://github.com/AsahiLinux/linux). A Linux ThinkPad drives the
Mac over USB-C. The installed raw m1n1 boots Linux on **all 15 cores** now that
the Omarchy stub carries Apple's fixed firmware (macOS 27.3 beta 1 or later).
A pinned [Aura](https://github.com/aurora-silicon/aura) Mach-O Stage 1 is also
packaged as an alternative; it has not been tested on hardware.

A separate, pinned [Aurora Linux](https://github.com/aurora-silicon/linux)
kernel now drives the **internal display through DCP**, including a readable
console, brightness control and display off/on. This is a kernel alternative,
not the Aura bootloader trial; it uses the existing raw-m1n1 boot path.

> **N1 Wi-Fi/Bluetooth, T6050 PHYs and the installer image's kernel/loader**
> are an isolated extra flavor: [`docs/installer-stones.md`](installer-stones.md)
> (`make kernel-aurora-installer`, `make m1n1-installer`). Merged with this repo's GPU
> kernel as `make kernel-aurora-n1` (GPU bins from the ADT with `t6050-j714s-gpu-adt`). This Mac's variant,
> `make kernel-aurora-gpu-n1-simpledrm`, now
> [runs Wi-Fi and Bluetooth](#n1-wi-fi-and-bluetooth-isolated-j714s).
> Full J714s status/evidence history: [`docs/omarchy-m5-pro/`](omarchy-m5-pro/README.md).

> **Reviewing this?** Start with **[`FOR-AURORA.md`](../FOR-AURORA.md)** - the three
> things worth your time, and what to skip.

## Try it: Omarchy on an M5 Pro (developer image, for the brave)

There is now a full **Omarchy 4.5.0 image** for the J714s, built in CI from
this repo:
[**`j714s-developer-image-2026.11.11`**](https://github.com/betizzel/omarchy-m5/releases/tag/j714s-developer-image-2026.11.11).
The previous build (2026.11.10) was installed onto TripleU613's J714s and
booted through the normal chain (m1n1 → U-Boot → Limine → EFI Linux) into
Omarchy, with Wi-Fi and trackpad. 2026.11.11 adds one change: the GPU takes
its own chip's voltage bins, so the image is meant for any J714s.

**What you get:** the merged kernel (`linux-aurora 7.3.0.aurora16.j714s3-4`,
this repo's `patches/linux-aurora` + `patches/linux-aurora-n1`) on **15
cores**, NVMe, keyboard and trackpad (with the J714c AFE reset, so it comes up
every boot), **N1 Wi-Fi and Bluetooth**, **speakers, headphone jack and
microphones** (speaker volume capped at -30 dB), the GPU with Vulkan (see the
GPU caveat below), the panel on simpledrm, and Omarchy's normal first-boot setup.

Much of this is other people's working code, gathered here: the J716s audio
setup (rolotrealanis98/m5pro-linux), the J714c trackpad reset and J714 speaker
profile and graphs (edimoldovan), the T6050 kernel base (rolotrealanis98) and
N1/GPU work (betizzel, TripleU613). See the credits in
[`docs/installer-stones.md`](installer-stones.md).

**Be honest with yourself before trying:**

- **One unit tested, installed by hand.** The image was written from Linux on
  the Mac (below), not through the Omarchy Mac app from macOS; that path is next.
- **J714s only** (MacBook Pro 14-inch, M5 Pro), with the **macOS 27.3 beta 1
  stub firmware** (`mBoot-20457.60.65.0.1`) the bring-up needs for all cores.
- **GPU bins come from your chip** (new in 2026.11.11). m1n1 passes the
  voltage bins macOS's device tree holds for your GPU, and the kernel checks
  them against the M5 Pro profile; if they look wrong it refuses to start the
  GPU (no acceleration, the rest runs). Checked on one unit so far: its bins
  came out identical to the hand-measured table. A second unit's boot log line
  `J714s GPU voltage bins from the ADT (...)` is the result we want next.
- The internal-display DCP driver works but is off by default (simpledrm);
  the USB-C gadget network does not always come up.

**How it was installed (you need this repo's bring-up first):** a J714s that
already boots Linux the [`docs/bringup.md`](bringup.md) way (stub +
stage-1 m1n1), and about **35 GiB of free disk space** (we shrank the existing
Linux ext4 to make room; macOS can shrink its APFS container instead).

```sh
# on a PC: download and check the image (two parts: GitHub's 2 GiB limit)
gh release download j714s-developer-image-2026.11.11 -R betizzel/omarchy-m5
cat omarchy-2026.11.11-*.zip.part0 omarchy-2026.11.11-*.zip.part1 \
  > omarchy-2026.11.11-aarch64-apple-silicon-mac-edge-os-package.zip
sha256sum -c SHA256SUMS --ignore-missing

# on the Mac's Linux, as root: write EFI/Boot/Root into free space
tools/install-image/install-from-linux.sh omarchy-2026.11.11-*.zip /usr/lib/firmware
```

The script prints the line that boots the image (the new ESP's
`m1n1/boot.bin` plus `chosen.asahi,efi-system-partition=<uuid>`). Try it once
from RAM with [`tools/m5-remote/bmboot.sh`](../tools/m5-remote/README.md) before
making it your stage 1's default. The first boot sets up the system, then asks
for your user name and password on screen.

How the image is built: [`installer/README.md`](../installer/README.md) (patches
on omacom/omarchy-mac-installer, the signed build inputs, and the manual
[`installer-image`](../.github/workflows/installer-image.yml) workflow).
Bring-up notes and credits: [`docs/installer-stones.md`](installer-stones.md).

## Status - verified on hardware

Unless noted, this table describes the default `vendor/linux` kernel.
The experimental Aurora/DCP path and its limits are described below.

| Area | State |
| --- | --- |
| Boot chain | yes iBoot → m1n1 → Linux kernel, **all 15 cores** (stub firmware ≥ mBoot-20457.60) |
| Root filesystem | yes Arch on the **internal SSD** (`nvme0n1p5`), dual-boot, macOS preserved |
| Storage | yes NVMe (ANS2 + NVMMU + SARTv4) |
| Console / display | yes simpledrm fallback (`eDP-1`); experimental Aurora DCP (`eDP-2`) with brightness and display off/on. Patched Hyprland 0.57.1 works on DCP at 3024x1890 / 120 Hz, software-rendered (no GPU) |
| Input | yes built-in keyboard **and** trackpad (DockChannel MTP + `tpmtfw`) |
| Keyboard backlight | yes `fpwm0` + pwm-leds (`/sys/class/leds/kbd_backlight`) |
| CPU frequency | yes all three clusters on schedutil; P cores measured 1307 MHz before, about 4.22 GHz after |
| CPU idle | yes WFI on all 15 cores, no `idle=nop` (patches 0012 + 0013): idle draws 5.6 W in total (SoC 1.6 W) against 15.3 W with `idle=nop` |
| SMC | yes hwmon (both fans, temperatures, power rails); lid opens wake the Mac from sleep; RTC registers |
| Networking | yes USB-C gadget (CDC EEM) - host reaches the Mac over the cable |
| m1n1 on upstream `main` | yes USB enumeration unblocked on T6050 (`patches/m1n1/0005`) |
| **SMP - secondary CPUs** | yes 15/15 online (2026-11-06): stub rebuilt from macOS 27.3 beta 1 (`scripts/refresh-stub-firmware.sh`), kernel patches 0009 + 0010 |
| Sleep (s2idle) | yes On the default kernel, `systemctl suspend` or closing the lid sleeps, and opening the lid wakes it (patch 0011 fixes a resume SError in the debug UART). With cpuidle registered (patch 0013) the tick and timekeeping stop during sleep. The default simpledrm path leaves the panel lit |
| Battery / charger | Verified on Aurora: battery telemetry, charging/discharging and charger notifications. Still disabled on the default fallback kernel |
| Wi-Fi / Bluetooth (N1) | Works in the isolated `aurora-gpu-n1` profile (2026-11-09): WPA3 association on 2.4 and 5 GHz, DHCP, DNS and HTTPS; drivers load and the saved network rejoins by themselves at boot; Bluetooth controller up with classic and LE discovery. Pairing, HID, audio, suspend and sustained load are not qualified. Not in the default kernel |
| GPU | Native GL/compute and Vulkan-backed Zink checks pass on this J714s. Isolated Zink/Borealis Hyprland renders on simpledrm at 3024x1890 / 60 Hz in short automatic checks. Native Gallium desktop rendering is defective; GPU+DCP and sustained-load qualification remain open |

Today the machine boots Arch from the internal SSD on **all 15 cores**; the
kernel is staged over the USB tether (`boot-m5.sh`). Apple fixed the
single-core raw-boot-object bug in macOS 27.3 beta 1, but the fix only reaches
Linux once the Omarchy stub is rebuilt from that macOS: the stub supplies its
own stage-2 firmware.

## SMP: fixed by Apple's firmware

On stub firmware cloned from macOS 26.5, every secondary failed to start
([probe log](research/probe-logs/t6050-cpu-impl-0100-2026-11-04-j714s.log)).
Apple fixed "only a single core is available when you boot Linux ... from a
custom raw boot object" on M5 Pro/Max/Ultra in macOS 27.3 beta 1 (26C5035r).
The stage-2 firmware that loads m1n1 comes from the Omarchy stub's own restore
bundle, so after updating macOS the stub has to be rebuilt:
[`docs/bringup.md` -> Stub firmware refresh](bringup.md#stub-firmware-refresh-all-cores).
With `mBoot-20457.60.65.0.1` the unchanged installed m1n1 starts 14/14
secondaries.

Linux also needs patch 0009 with `arm64.nowfxt` (cores lose state in WFIT; a
kernel without the override panics in `__delay` on CPU1), patch 0012 (WFI
loses x0-x30 and FP/SIMD on every core except the boot CPU, so the idle path
saves them; `idle=nop` is gone) and patch 0010 (the ANS firmware can take
about 3 s to answer RTKit on an all-core boot). The October SPTM attribution
does not explain the failure: the fix is in mBoot, with m1n1 unchanged.
[`docs/smp-t6050-findings.md`](smp-t6050-findings.md) keeps the
measurements of the broken firmware, with that history labeled.

## Internal DCP display (experimental Aurora kernel)

`make kernel-aurora` builds Linux 7.3 from pinned Aurora commit
`5b0f106acdd71de11400464adfeb8c87a83b20b0` plus
[`patches/linux-aurora/`](../patches/linux-aurora/). The default `make kernel`
and its artifacts stay separate. Package it with
`KERNEL_FLAVOR=aurora scripts/mktether.sh`; see the
[build and fallback instructions](bringup.md#aurora-kernel-with-internal-dcp-experimental).

Verified on J714s with stub firmware **mBoot-20457.60.65.0.1**:
all 15 CPUs, internal SSD root, USB networking, trackpad motion and clicks,
DCP framebuffer console, brightness changes and display off/on.
The console needed both fbdev damage
submission and ARGB pixels: this firmware treats the fourth XRGB byte as
alpha, so otherwise valid console text was invisible.

SMC power samples on this DCP boot averaged **9.09 W at brightness
setting 300**, versus **5.55 W with the display blanked**, with keyboard
backlight still at 200/255 (15 samples each). These are awake measurements,
not sleep power; the earlier simpledrm brightness was not controlled.

This does **not** provide GPU acceleration. A basic software-rendered
Hyprland desktop and native Wayland terminals are now verified on DCP at
3024x1890, 120 Hz, using the
[alpha-only scanout fix](../patches/hyprland/0001-output-support-alpha-only-scanout.patch).
Unpatched Hyprland 0.57.1 assumes XRGB during mode tests and crashes on this
alpha-only primary plane; the fix selects an advertised format and permits
ARGB/ABGR. The user config and packaged compositor are unchanged; the tested
build is a local override described in the
[runbook](bringup.md#aurora-kernel-with-internal-dcp-experimental).
Lid suspend/resume still needs qualification on DCP. Keep the default kernel
as the tested fallback; do not infer sleep or GPU support from the desktop.

## M5 Pro GPU trial (isolated J714s)

The isolated GPU trial now performs real rendering on this J714s. Two boots of
`7.3.0-g929e67a1da3e` passed native GL/compute and Vulkan-backed Zink smoke
checks, plus all 14 indexed-rendering cases in each mode, with no new kernel
messages during the tests. The GPU reports **Apple M5 Pro (G17S B1), 16 enabled
cores**. This is short functional coverage, not Vulkan conformance or general
application/thermal qualification.

The working profile uses **simpledrm, with Linux DCP disabled**. It combines
Aurora Linux PR #1173, Mesa PR #194 and the minimal m1n1 GPU handoff, retaining
**this Mac's own voltage bins**, not the other J714s's draft voltage profile.
`make kernel-aurora-gpu-simpledrm` and `make m1n1-gpu-simpledrm` use private
build trees; `scripts/build-mesa-gpu.sh` packages Mesa and its Vulkan loader
under `/opt`, without replacing system graphics libraries.

The [GPU desktop launch path](bringup.md#accelerated-hyprland-zink-on-simpledrm)
now uses **Zink/Borealis**, with a private Aquamarine render-node allocator
fix. Captured Kitty text/colours and a short active-update timing sample
worked near the panel's 60 Hz rate, with no new kernel messages. This is real
M5 GPU rendering, not a software fallback. Native Gallium could start the
desktop but produced black Kitty content and poor responsiveness, so it is
not the desktop default. The user's config and system graphics packages are
unchanged. On a GPU kernel the distro's Mesa has no driver for the GPU node and
plain `start-hyprland` aborts at startup, so `scripts/start-hyprland.sh` is
installed as the default `start-hyprland` and `hyprland`: it runs
`start-hyprland-gpu` when that node exists.

Both original recovery bundles and the installed boot object are unchanged.
The corrected trial loader also passed a live watchdog-preservation check.
Final physical-input/latency confirmation for the Zink session is pending.
The [GPU runbook](bringup.md#gpu-trial-isolated-j714s) records the source
pins, calibration guard and remaining limits. **GPU + DCP is not yet qualified.**

The [standalone milestone](bringup.md#standalone-no-second-machine---one-1tr-ceremony-per-image)
packaged that same kernel/DT/initramfs behind a native loader that checks this
Mac's calibration and prepares NVMe without the host probe. Its real payload
parser and boot routine were exercised from RAM: SSD-root Linux, all 15 CPUs
and both GPU smoke modes passed. **Do not enroll that image.** The N1 image of
the same shape and size boot-looped when it was enrolled (below); a RAM run
does not show what iBoot does with the object.

Omarchy itself is **not installed yet**. The
[package preflight](bringup.md#omarchy-installation-preflight-not-installed)
found stock Btrfs/boot assumptions and network/firewall changes that would put
this ext4/custom-boot setup's SSH recovery path at risk if applied unattended.

## N1 Wi-Fi and Bluetooth (isolated J714s)

The N1 now runs on this J714s. On tethered boots of `7.3.0-gc1fabe3c06f9`
Linux powered and trained the N1's PCIe link itself, loaded Apple's firmware
and registered `wlan0` and `hci0`. Wi-Fi joined a WPA2/WPA3 network from
`nmtui` with an ordinary passphrase (SAE, management-frame protection), took a
DHCP lease and carried ping, DNS, HTTPS and a 25 MB download. After a reboot
udev loaded both drivers and NetworkManager rejoined the network, on 5 GHz,
with nothing typed. Bluetooth answered a classic inquiry and, with LE built
in, found 48 LE devices in ten seconds. CPUs, SSD, the GPU hand-off, battery
and SMC behaved as in the GPU trial, and the kernel logged no Oops, WARN or
SError.

The profile adds two things to the GPU/simpledrm one. `patches/linux-aurora-n1/`
carries TripleU613's merge of the installer kernel's N1 work (Centauri drivers
and kernel-owned PCIe train by rolotrealanis98) plus the five patches that
merge needed on this tree. `patches/m1n1-gpu/0004` gives this repo's GPU
loader a device-tree-only N1 hand-off: it copies the PCIe tunables and the
control function's identity from the boot ADT and enables the port, does no
PCIe MMIO, and leaves the N1 off if anything is missing. The firmware is
assembled locally from Apple's public restore image by `scripts/mk-n1-ftab.py`
and is not redistributed.

A self-contained
[native image](bringup.md#native-n1-image-proven-from-ram-boot-loops-when-enrolled)
of the same kernel, tree and loader ran its own payload parser, calibration
guard, NVMe preparation and hand-off from RAM and reached the same running
system. **Enrolled on 2026-11-09, it boot-looped**, and so did a 1.2 MB loader
with a `chainload=` line appended: a few restarts, then recoveryOS, and nothing
of either ever appeared on the cable. Size alone does not explain both
failures. Both had data appended and neither size was a multiple of 16 KiB;
[the raw objects compared in the runbook](bringup.md#raw-image-alignment-evidence-and-current-workaround)
that booted were aligned. The plain, aligned replacement now boots natively
on this Mac; alignment versus the appended tail has not been isolated.
The saved boot object was put back with `enroll.sh rollback` both
times.

A native boot is therefore
[two stages](bringup.md#native-boot-in-two-stages), and stage 1 is a plain
image: a 1.2 MB m1n1 with its target compiled in reads the GPU/N1 loader from
the EFI partition, and that loader reads the kernel, device tree and initramfs
from a file there. Chainloaded from the cable with nothing else sent, the whole
chain booted this system, and with either file missing the stage concerned
fell back to its USB proxy, from which the tether flow still works. **The owner
enrolled the plain stage 1 on 2026-11-09 and it booted successfully.** Live SSH
confirmed both loader versions, Linux `7.3.0-gc1fabe3c06f9`, all 15 CPUs and the
existing SSD root, with no host-supplied boot images. An unplugged cold boot
remains to be confirmed. The first native boot exposed an N1 probe-order race:
Bluetooth's temporarily assigned driver pointer caused shared IPC startup to
abort with `-16`. Patch 0007 synchronizes sibling acquisition with probing.
**Native `7.3.0-g76b01c3f2e1c` now reconnects Wi-Fi and starts Bluetooth
automatically**; Wi-Fi SSH, ICMP and HTTPS passed, with `hci0` powered and no
matches for the selected kernel warning/Oops/SError checks. The enrolled
loader is unchanged. A small unit in the root image clears
[iBoot's boot counter](bringup.md#iboots-boot-counter), which otherwise
adds up with every restart made without the cable.

This is short functional coverage. Bluetooth pairing, HID and audio with a
real device, suspend and sustained load are open. The
[N1 runbook](bringup.md#n1-wi-fi-and-bluetooth-isolated-j714s) has the
build, the bring-up failures and their fixes, and the remaining limits.

## Aura Mach-O Stage 1 (optional, untested on hardware)

`make aura-test` packages a pinned Aura v1.0.0b4 Mach-O Stage 1 with our
kernel/DT and a RAM-only diagnostic image. SMP no longer depends on it. See
[`docs/bringup.md` -> Aura Mach-O diagnostic trial](bringup.md#aura-mach-o-diagnostic-trial-j714s)
for preflight, approval, testing and rollback.

## Repo map

- **[`docs/`]()** - everything written down; **[`docs/README.md`](README.md)**
  indexes it (current state, SMP RE, build guide, Phase-0 research).
- `dt/` - the T6050 device trees, authored from **this machine's real ADT**
  (`scripts/adt2pmgr.py`), not guessed.
- `patches/m1n1/`, `patches/linux/` - the default bootloader and kernel changes;
  `patches/linux-aurora/` - the separate pinned Aurora/DCP port.
- `scripts/` - the dev harness (build / install / tether) and
  `scripts/probes/` (the hardware RE tooling).
- `configs/` - kernel configs · `tools/` - tiny on-device C helpers ·
  `Makefile` - `make setup fetch m1n1 dtbs kernel`.

## Build & dev loop

See **[`docs/bringup.md`](bringup.md)**. Short version:

```sh
make setup fetch m1n1 dtbs kernel   # toolchain, vendor clones, m1n1, DTBs, kernel
```

The original on-device install (partitioning + `kmutil`) is in
`docs/bringup.md` -> *"One-time on-device step"*. After a macOS update, rebuild
only the stub (`scripts/refresh-stub-firmware.sh`); do not repeat the
installation. Kernel uploads are memory-only, but the normal tether workflow
subsequently boots the SSD root filesystem.

## Credits & upstreams

Built on the Asahi Linux project and the omarchy-mac / Aurora Silicon ecosystem.
The hardware reverse-engineering here is interoperability work on the author's
own Mac.

- [m1n1](https://github.com/AsahiLinux/m1n1) ·
  [linux-asahi](https://github.com/AsahiLinux/linux) ·
  [Asahi feature support](https://asahilinux.org/docs/platform/feature-support/)
- [omarchy-mac](https://github.com/omacom/omarchy-mac) ·
  [Aurora Silicon](https://github.com/aurora-silicon)
- [rolotrealanis98/m5pro-linux](https://github.com/rolotrealanis98/m5pro-linux) -
  found that the 27.3 beta 1 SMP fix needs a rebuilt stub, and the RTKit timeout.
- [edimoldovan/linux-aurora](https://github.com/edimoldovan/linux-aurora) - J714c
  platform work ported here (P-cluster DVFS, eDP connector, keyboard backlight,
  T6050 fan keys).
- [antiapplefox/m5-linux](https://github.com/antiapplefox/m5-linux) - the SPTM
  static-RE / XNU-shim track behind the earlier SMP investigation.

## License

[MIT](../LICENSE) for this repo's original scripts and docs. Patches under
`patches/` follow the project they apply to and keep its SPDX identifiers: the
Linux patches are GPL-2.0, device trees (there and under `dt/`) are
GPL-2.0+ OR MIT, and the m1n1 patches are MIT. Where a file carries an SPDX
line, that line decides. Contributions are accepted on the same terms. No Apple
firmware is redistributed here - the extraction scripts re-derive everything
from a locally-downloaded IPSW.
