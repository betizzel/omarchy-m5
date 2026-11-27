# 06B — First-boot procedure (J714s): one bootloader install, then Linux-side work

Nothing here has been run.
- (!) = changes the Mac; needs **owner approval** for each step.
- [owner-only] = **owner-only because of the m1n1 restriction** ([06-evidence §3](06-evidence.md): upstream `/CLAUDE.md` @ c9a03479 says "forbid any usage of AI or LLM tools whatsoever", and the forks inherit that requirement). It covers m1n1's code, binaries, tools, logs and traces. **Linux output after hand-off is not covered** (06-evidence §3, narrowed).

## 0. Strategy (minimise owner steps)
1. **m1n1 is a fixed bootloader the owner builds and installs once.** We never touch it again.
2. **First boot is tethered**, to prove our kernel and DT. The owner runs one `linux.py` command [owner-only].
3. **Everything after that happens inside Linux with our own code:**
   - PMP, cluster and PTD probes via our kernel module `tools/t6050-probe` (§3). No proxyclient probes.
   - Kernel and DT iteration via kexec from `/boot` (§4). It never touches m1n1.
   - We reach the Mac over **USB gadget Ethernet** to "work" (§5).

## 1. Why a stub OS + Permissive Security, and exactly what changes

**Why.**
- Each OS has its own **LocalPolicy**: "a new LocalPolicy for each", and a second OS requires "Creating a LocalPolicy for the second operating system" ([Apple, LocalPolicy contents](https://support.apple.com/guide/security/contents-a-localpolicy-file-mac-apple-silicon-secc745a0845/web)).
- iBoot runs a non-Apple payload only if that OS's policy is **Permissive**. `smb1` lets "objects such as a custom kernel collection" be Secure-Enclave signed, and **`coih`** is set "when they use the `kmutil configure-boot` command-line tool in 1TR"; iBoot then uses that payload "instead of the XNU kernel".
- Permissive "can be accessed only from command-line tools" ([Apple, Startup Disk security policy](https://support.apple.com/guide/security/startup-disk-security-policy-control-sec7d92dc49f/web)).
- Using a separate stub OS leaves the main macOS's own LocalPolicy unchanged. Asahi's installer does exactly this: asahi-installer @ `e93743d` (MIT, no AI files) `src/step2/step2.sh:107` `bputil -nc -v $VGID`, `:125` `kmutil configure-boot -c boot.bin --raw --entry-point 2048 --lowest-virtual-address 0 -v $system_dir`.

**Current Mac state** (PM, read-only):
- disk0: `s1` Apple_APFS_ISC 576.7 MB; `s2` Apple_APFS container `disk3` 994.6 GB (279.4 GB used, 715.2 GB unallocated *inside* the container); `s3` Apple_APFS_Recovery 5.4 GB. No free space outside the container.
- **FileVault on**, so 1TR and `bputil` ask for credentials.
- **SIP on main macOS already disabled** (pre-existing). Main macOS's security level is therefore *unknown to us*. **Owner read-only step:** `sudo bputil -d` and `csrutil status` in macOS. Record the result before any change.
- macOS 26.6.2.

**Sizes** (replacing the uncited "~40 GB"):

| Item | Size | Source |
|---|---|---|
| Asahi installer stub container | 2.5 GB | asahi-installer `src/main.py:11` `STUB_SIZE = align_down(psize("2.5GB"), PART_ALIGN)` |
| Asahi "UEFI environment only" | + EFI 500 MB | asahi-installer-data @ `06543833` `data/installer_data.json` |
| **betizzel's known-good J714s layout** (what we follow) | **6 GB stub + 500 MB EFI** (+ Linux root N) | omarchy-m5 `docs/bringup.md` @15cd70c1: "creates the 6 GB "Omarchy" stub … and makes a 500 MB EFI partition"; "`--linux-size N` takes N + 6.5 GB away from macOS" |

Plan: 6.5 GB + a 20 GB Linux root = **26.5 GB** taken from `disk0s2`. The Linux root is needed for §4/§5.

**Exact changes:**

| Change | Scope |
|---|---|
| (!) `disk0s2` shrunk by 26.5 GB; new APFS container "Omarchy" (Data/System/Preboot/Recovery); 500 MB FAT32 EFI; 20 GB Linux root partition | disk layout |
| (!) New LocalPolicy **for the stub only**, Permissive (`bputil -nc`) | stub only |
| (!)[owner-only] `coih` → m1n1 (`kmutil configure-boot`) | stub only |
| (!) SIP off for the stub (`csrutil disable`, stored in the LocalPolicy as `sip0`, "previously were stored in NVRAM") | stub only |
| (!) `nvram boot-args=-v` | **global NVRAM variable**. iBoot filters it per OS unless `sip3` ("won't enforce its built-in allow list for the boot-args NVRAM variable"). [guess] macOS may also boot verbose. Remove later with `nvram -d boot-args` |
| (!) Default startup volume → stub | global (picker / Startup Disk reverts it) |
| **Untouched** | main macOS volumes and *its* LocalPolicy; system recoveryOS; SEP; system firmware/NOR; FileVault state |

## 2. Equipment

- **Host "work"** (ThinkStation P3 Tiny Gen 2) is **sufficient**. Missing pieces, in owner-approval form:
  - `pyserial`, `construct` (user venv);
  - (!) host: `sudo pacman -S picocom`, the m1n1 udev rule (`1209:316d` → `/dev/m1n1`, `/dev/m1n1-sec`), `usermod -aG uucp $USER`;
  - `rustup target add aarch64-unknown-none-softfloat` (for [owner-only] m1n1).

  It already has bc, make, clang, lld, rustup, cargo, dtc and git.
- **Cable:** USB-C ↔ USB-C **data** cable, USB 3 recommended. Asahi tethered-boot: "any reasonable cable should work"; "You can also use a C to A cable". Not charge-only.
- **MacBook port:** a Thunderbolt port (Asahi). betizzel: "the gadget binds to one specific dwc3 port", so try each port and note which one works. The same port and cable carry the proxy and, later, gadget Ethernet. Put a charger on another port.
- **DFU recovery with the equipment we have.** Owner: no data to preserve, and a DFU *restore* (erase) is an acceptable last resort.
  - **Apple's supported path** needs another Mac with Apple Configurator or Finder ([Apple 108900](https://support.apple.com/en-us/108900)). Revive keeps data; restore erases. Whether a Mac is available is **unknown**.
  - **From Linux ("work"): yes, via idevicerestore.** It's not Apple-supported, but its upstream code explicitly supports Mac restores:
    - libimobiledevice/idevicerestore commit [`45145e9f`](https://github.com/libimobiledevice/idevicerestore/commit/45145e9fdc8458022c61a4b87bd029b866d5bcdc) (2026-06-25): "Add support for restoring macOS 27 IPSWs via DFU".
    - Commit [`5d9bd621`](https://github.com/libimobiledevice/idevicerestore/commit/5d9bd621eb60cab5303b72b4b35388fb515ffa87) detects Mac builds (`MacOSVariant`) and tells you to "use the correct USB port for this model, see https://support.apple.com/120694".
    - README: "On Linux, idevicerestore requires a properly installed usbmuxd". "By default, an update restore is performed which will preserve user data" (`idevicerestore --latest`). Erase is `idevicerestore --erase --latest`.
    - libirecovery knows the M5 Pro/Max MBP IDs (added 2026-07-15).
    - On Arch, `usbmuxd` is in `extra`; idevicerestore/libirecovery are **not** in the official repos (AUR or source build). (!) This is a host install on "work" and needs task permission.
    - [guess] The idevicerestore "update restore" is not identical to Apple's "revive" (firmware + recoveryOS only), but it also preserves data.
  - **Entering DFU without a second Mac:** the manual key combo works regardless of the host (Apple 108900):
    1. Hold power ~10 s until off.
    2. Press and release power, then immediately hold **left Control + left Option + right Shift + power** for ~10 s.
    3. Release all but power and keep holding up to 10 s more.

    The screen stays blank, and the host should see the device in DFU on USB.
  - **DFU port** ([Apple 120694](https://support.apple.com/en-us/120694), "How to identify the DFU port on Mac"):
    - For a 14" MacBook Pro with **M5 Pro** it's the catch-all rule: "**The leftmost USB-C port when you're facing the left side of the Mac**". That's the one nearest MagSafe, matching tuxvdmtool's "next to the MagSafe connector".
    - The 14" exception "with M4 or M5 chip (excluding Pro or Max versions)" (rightmost) doesn't apply to us.
    - theapplewiki's "front-left" claim is wrong for our model.
  - `tuxvdmtool` (remote DFU/serial over VDM) needs the host to be an Apple-silicon Mac running Linux, so it's not usable from "work".
  - **Conclusion:** a DFU **restore** is possible from "work" alone, using idevicerestore + usbmuxd (once installed with permission), the key combo, and the left-side leftmost USB-C port. A nearby Mac is still the officially supported, more reliable fallback.

## 2a. The cable as plugged now (PM, 2026-11-04)
The MacBook end is in the **left port next to MagSafe**, which macOS shows as `Port-USB-C@1`, `ConnectionActive=Yes`, `TransportsActive=(CC)`. The ThinkStation end is in a **front USB-C** port. The cable's data capability is unverified until m1n1 is in device mode.

- **Which port is Port 1 (OBSERVED-BY-US):** in our ADT (`reports/04-j714s-full.txt`), `hpm0` has `"port-number" = <01000000>` and `"port-location" = <"left-back">` (`usbc,sn201202x,spmi`). The others are `hpm1` = port 2 `"left-front"` and `hpm2` = port 3 `"right"`. So `Port-USB-C@1` is **left-back**, the port next to MagSafe.
- **(b) DFU: Port 1 is correct.** [Apple 120694](https://support.apple.com/en-us/120694): for the 14-inch MacBook Pro with M5 Pro (the "All other models" rule; the M4/M5 exception explicitly excludes Pro/Max), the DFU port is "The leftmost USB-C port when you're facing the left side of the Mac". Facing the left side, the rear is on your left, so that's left-back, i.e. Port 1. tuxvdmtool's README agrees ("the port next to the MagSafe connector on the 14" and 16" MacBook Pro").
- **(a) m1n1 USB proxy: probably, but not verifiable by us.**
  - Asahi's tethered-boot doc only requires "a Thunderbolt port on the target", and all three ports are Thunderbolt/USB4.
  - betizzel on J714s: "If proxyclient doesn't enumerate, try the other USB-C ports - the gadget binds to one specific dwc3 port" (`docs/bringup.md` @15cd70c1). Their DT maps `dwc3_0` = ADT `usb-drd0` = port 1 "hpm0 left-back" (`scripts/usb-gadget-net.sh`), but they don't say which port m1n1's gadget actually used.
  - Which port m1n1 enumerates on is m1n1 behaviour, which [owner-only] we can't check.
  - **Owner test:** keep Port 1 for the first attempt. If `/dev/m1n1` doesn't appear within the 5 s window, move the MacBook end to **left-front** (port 2), then **right** (port 3). Record which one works; Linux gadget networking (§5) uses the same port.
- **Host side:** any data-capable "work" USB-C (or USB-A with a C-to-A cable) port is fine. The front USB-C port is OK. If nothing enumerates on any MacBook port, try a known USB 3 data cable before suspecting software.

## 3. Owner-only steps: the shortest exact list

**On "work" (once):**
```sh
# [owner-only] m1n1: upstream 70757dc7 + betizzel patches (0001, 0005 need a 1-hunk hand merge; see 03A)
git clone --recursive https://github.com/AsahiLinux/m1n1.git ~/m1n1 && cd ~/m1n1 && git checkout 70757dc7
for p in 0001 0003 0004 0005; do git apply --3way ~/m5-omarchy/src/omarchy-m5/patches/m1n1/$p-*.patch; done
make CHAINLOADING=0 -j && cp build/m1n1.bin ~/m1n1-stage1.bin
# (!) host packages
sudo pacman -S picocom && sudo cp udev/80-m1n1.rules /etc/udev/rules.d/ && sudo udevadm control --reload && sudo usermod -aG uucp $USER
```

**On the Mac:**
1. Read-only: `sudo bputil -d; csrutil status; diskutil list disk0`. Save the output.
2. (!) Shrink macOS: `sudo diskutil apfs resizeContainer disk0s2 968.1GB` (994.6 − 26.5; diskutil uses powers of ten). Alternatively, `sudo ~/omarchy-m5/scripts/prep-stub.sh --linux-size 20G` does this exact-byte math, creates the stub and EFI, and prints the VGID.
3. (!)[owner-only] `sudo ~/omarchy-m5/scripts/finish-install.sh --m1n1 ~/m1n1-stage1.bin`
4. (!)[owner-only] Shut down, wait 15 s, **hold** power → "Options"/picker → **Omarchy**. In its Terminal (`step2.sh` or by hand):
   1. `bputil -nc` (FileVault/admin credentials twice).
   2. `kmutil configure-boot -c boot.bin --raw --entry-point 2048 --lowest-virtual-address 0 -v /Volumes/Omarchy`
   3. `csrutil disable && nvram boot-args=-v`
5. [owner-only] First tethered boot from "work" (Mac powered on, cable in):
   ```sh
   ~/m1n1/proxyclient/tools/linux.py ~/m5-omarchy/build/linux/arch/arm64/boot/Image.gz \
     ~/m5-omarchy/build/linux/arch/arm64/boot/dts/apple/t6050-j714s.dtb ~/m5-omarchy/build/initramfs.cpio.gz \
     -b "maxcpus=1 earlycon=efifb keep_bootcon console=tty0 loglevel=8 pd_ignore_unused clk_ignore_unused no_console_suspend nvme_apple.flush_interval=0"
   ```
6. (!)[owner-only] Once after step 5 works: install the untethered stage 2 (§4).

## 4. Untethered path

**Option A (Asahi's standard chain).** stage1 m1n1 → stage2 `m1n1/boot.bin` on the ESP → U-Boot → our kernel and DTB from `/boot`. Asahi: "Stage 2 is loaded from the EFI system partition at `m1n1/boot.bin`" (tethered-boot doc). Asahi builds stage2 by concatenation in asahi-scripts `update-m1n1` (MIT, no AI files): `cat "$M1N1" $DTBS >…; gzip -c "$U_BOOT" >>…; cat "$m1n1config" >>…`.
- **Blocker:** AsahiLinux/u-boot `asahi` and aurora-silicon/u-boot have `drivers/nvme/nvme_apple.c`, but I found no T6050/ANS2/SARTv4 support. Without it U-Boot can't read the ESP or `/boot` on this Mac.
- U-Boot is GPL with no AI files, so **porting T6050 NVMe to U-Boot is AI-allowed work** (from betizzel's Linux patches `0006`/`0007`, once they're licensed). That's our work item, not the owner's.

**Option B (recommended now: works with today's proven Linux).** stage2 on the ESP = m1n1 + `t6050-j714s.dtb` + a fixed **loader kernel** (our Image.gz) + initramfs, assembled once by the owner [owner-only]. The loader kernel:
1. mounts the Linux root on NVMe (NVMe already works in betizzel's stack);
2. brings up gadget Ethernet (§5);
3. on request, `kexec -l /boot/Image --dtb=<fdt> --command-line=… && kexec -e`.

The `<fdt>` is `/sys/firmware/fdt`, i.e. **the DT m1n1 already fixed up** (memory, framebuffer, reserved regions), optionally with our changes applied using `fdtoverlay`. That keeps m1n1's fixups without re-running m1n1. Kernel and DT iteration is then `scp` + kexec, **no owner step**.
- **Risks:** [guess] kexec on Apple silicon can fail if coprocessors (DCP, MTP) are left running. Single-core makes it simpler. This needs a test.
- Config has `CONFIG_KEXEC=y`, `CONFIG_KEXEC_FILE=y`; `kexec-tools` goes in the initramfs.
- How stage1 finds stage2 (the chainload config embedded at install) is m1n1 behaviour. The owner confirms it from Asahi's docs/installer when assembling [owner-only].

## 5. Network path to the Mac's Linux
- **Now: USB gadget Ethernet (CDC-EEM)** over the same cable. betizzel's initramfs `scripts/usb-gadget-net.sh` turns each DWC3 UDC into CDC-EEM, giving "subnet 10.55.<n>.0/24, host .1, M5 .2".
  - On "work": `scripts/host-usbnet.sh`, or `ip addr add 10.55.0.1/24 dev <usbX>`.
  - Then `ssh root@10.55.0.2`.
  - Config: `CONFIG_USB_CONFIGFS_EEM=y`, `CONFIG_USB_DWC3_DUAL_ROLE=y`.
  - "work" needs the `cdc_eem` module (stock Arch kernel).
- **Later: a USB-Ethernet dongle on the Mac** (`CONFIG_USB_RTL8152=m` is present). This needs **USB host mode** on T6050. betizzel's stack is gadget-only. edimoldovan has USB 2.0/3 host on J714c via Aurora PHY patches (`linux-aurora:t6050-j714c` `ae65f0d3a8`, `16b3737ba9`). That port is AI-allowed (GPL kernel) and is our follow-up.

## 6. First-boot expectations and failure modes
- **m1n1 stage 1:** logo and log on the panel at 3024×1964 (betizzel). The m1n1 log itself is [owner-only]; the owner reads it.
- **Proxy:** `/dev/m1n1` and `/dev/m1n1-sec` appear on "work". If not, try another Mac port.
- **`linux.py`:** `Starting CPU n … Failed!` ×14, which is expected ([#293](https://github.com/omacom/linux-aurora/issues/293#issuecomment-6614448292)).
- **Linux (AI-analysable from here on):**
  - `Booting Linux on physical CPU 0x…`, `Machine model: Apple MacBook Pro (14-inch, M5 Pro, 2026)`, a `simple-framebuffer` line, then DockChannel HID keyboard/trackpad enumeration.
  - **Success** = busybox `/ #` prompt, built-in keyboard typing, `nproc` = 1, `/proc/device-tree/compatible` = `apple,j714s`. Then `ssh root@10.55.0.2` from "work".
- **Failure modes:**
  - Hang in m1n1 USB init without `0005`.
  - No keyboard: MTP DAPF/DART.
  - Idle crash: WFI state loss.
  - Proxy-ABI mismatch.
  - An SError from a bad MMIO read (the probe module logs the address *before* each read, so the last dmesg line names it).
- **Probes from Linux** (after ssh works):
  ```sh
  insmod t6050_probe.ko groups=1    # controls
  insmod t6050_probe.ko groups=2    # PMGR PS: PMP/PMS_SRAM/MCPM/PCPM
  insmod t6050_probe.ko groups=4    # PMP DART / fw / PTD words
  insmod t6050_probe.ko groups=8    # PMP wrapper (may SError; run last, alone)
  ```
  Each load does single 32-bit reads, prints them and exits (no writes). Power-cycle after any hang.

## 7. Recovery
1. Hold power → **Macintosh HD**; then System Settings → General → Startup Disk. macOS was never modified.
2. Remove the stub:
   1. `diskutil list disk0`. Identify **by type and size**: the 6 GB "Omarchy" `Apple_APFS`, `EFI`, `Linux Filesystem`. **Never** touch `Apple_APFS_ISC` or `Apple_APFS_Recovery`.
   2. (!) `sudo diskutil eraseVolume free free disk0sX` (Linux, then EFI).
   3. (!) `sudo diskutil apfs deleteContainer disk0sZ` (stub).
   4. (!) `sudo diskutil apfs resizeContainer disk0s2 0`. If verification fails, run `diskutil repairVolume disk0s2` from recoveryOS.
   5. (!) `sudo nvram -d boot-args`.
3. **DFU** ([Apple 108900](https://support.apple.com/en-us/108900)): **revive** first (keeps data); **restore** erases.
   - With a Mac: Apple Configurator or Finder.
   - Without one, from "work": cable "work" ↔ the Mac's **leftmost left-side USB-C port** (Apple 120694), enter DFU with the key combo (§2), check that `lsusb` shows the Apple device, start `usbmuxd`, then run `idevicerestore --latest` (update, keeps data) or `idevicerestore --erase --latest` (restore). Both rebuild macOS and its recoveryOS.

## 8. Artifacts (built on ush, 2026-11-04, user-level)

**How they were built:** `tools/build-kernel.sh` with the owner-installed `bc`.
- Sources: AsahiLinux/linux `asahi-wip-7.2` @ `236788cd` + betizzel's 9 patches (omarchy-m5 @ `15cd70c1`, all `git apply` clean) + `dt/` overlay.
- Config: `defconfig asahi.config omarchy-bringup.config omarchy-storage-net.config omarchy-smc.config`, `ARCH=arm64 LLVM=1`, clang/lld 23.1.3. `CONFIG_RUST` is not set.
- Then `make modules`, and the probe module out-of-tree (`M=tools/t6050-probe`).

| Artifact | SHA-256 | Checks |
|---|---|---|
| `build/linux/arch/arm64/boot/Image.gz` (16,346,396 B) | `eaff9d70db41f7258fb501383049ad768ce64b641bf3af785e09d6b26a6ee555` | `file`: gzip → "Linux kernel ARM64 boot executable Image, little-endian, 16K pages". `vmlinux` reports "Linux version 7.2.2-g236788cd2602-dirty … (clang version 23.1.3, LLD 23.1.3) # SMP PREEMPT" |
| `build/linux/arch/arm64/boot/dts/apple/t6050-j714s.dtb` (72,219 B) | `25201b463eaf16daf40901dccb898507e2871fe49455c85be83fe64b6d2681ed` | `file`: DTB v17. `dtc -I dtb` round-trips with 0 warnings. `compatible = "apple,j714s", "apple,t6050", "apple,arm-platform"`, model "Apple MacBook Pro (14-inch, M5 Pro, 2026)" |
| `tools/t6050-probe/t6050_probe.ko` | `e44f9f5828005c9910ed2497270693a2cefbf2a352e7483756097a321a967483` | ELF aarch64 relocatable; vermagic `7.2.2-g236788cd2602-dirty SMP preempt mod_unload aarch64` matches the kernel |
| `build/linux/**/*.ko` | 1643 modules | `r8152.ko` present (for a later USB-Ethernet dongle) |

**Config sanity:** `CONFIG_ARCH_APPLE=y`, `NVME_APPLE=y`, `APPLE_SART=y`, `SPMI_APPLE=y`, `HID_DOCKCHANNEL=y`, `DRM_SIMPLEDRM=y`, `USB_CONFIGFS_EEM=y`, `USB_DWC3_DUAL_ROLE=y`, `KEXEC=y`, `KEXEC_FILE=y`, `DEVMEM=y`, `STRICT_DEVMEM=y` with `IO_STRICT_DEVMEM` off (unclaimed MMIO is readable), `MODULES=y`, `NR_CPUS=512`.

**Not built yet:**
- **initramfs.** betizzel's `mkinitramfs.py` downloads Alpine busybox; that's an external download and needs approval.
- **kexec-tools** for the loader initramfs (Option B).
- [owner-only] **m1n1** stage 1/2 (owner).

**License:** `Image.gz` includes betizzel's 8 unlicensed patches, so **local use only, no redistribution** (`06-licenses.md`).
