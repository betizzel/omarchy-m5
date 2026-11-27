# 03A — Recipe: single-core Linux on our J714s (tethered)

Not yet executed by us. Everything below comes from public sources, and I checked the patch apply status locally on 2026-11-04. (!) marks a step that **changes the MacBook's boot or security setup** (owner only, by hand, after PM approval).

## Which stack

| | **betizzel/omarchy-m5** (recommended) | edimoldovan (Aurora) |
|---|---|---|
| Board | **J714s**, same as ours (15-core bin) | J714c (M5 Max, 18 cores) |
| Loader | upstream `AsahiLinux/m1n1` + 6 patches | `edimoldovan/m1n1:t6050-aurora` (Aurora fork) |
| Kernel | `AsahiLinux/linux:asahi-wip-7.2` + 9 patches | `edimoldovan/linux-aurora:t6050-j714c` (Aurora 7.2.10) |
| Proven | single CPU, NVMe root (Arch), simplefb, kbd+trackpad, USB gadget net (as of 10-10) | single CPU, simplefb, kbd+trackpad (10-23); later NVMe, USB2/3 host, GPU firmware init |
| AI/RE provenance | used disassembly of Apple's SPTM (clean-room problem for Asahi) | commits co-authored by Claude (Asahi LLM ban) |

Use betizzel's stack because it has our board's DT and sits closest to upstream. edimoldovan's branches are reference material for NVMe, USB host and GPU on T6050.

**Pins**

| Item | Pin |
|---|---|
| omarchy-m5 | `15cd70c1fad65322b85be4de4362cbed816a11c1` (2026-10-11) |
| m1n1 | `AsahiLinux/m1n1` `70757dc7` (current main) |
| linux | `AsahiLinux/linux` `asahi-wip-7.2` = `236788cd2602a24c703fe7bdaddaf73ef77d2027` (unchanged since 2026-05-30) |
| edimoldovan reference | `linux-aurora@f76afe4297e3`, `m1n1@160b644c4759` |

Pin `fetch-sources.sh` with `M1N1_REF`/`LINUX_REF`. By default it tracks branch heads.

**Patch status (checked locally)**
- **Linux:** all 9 patches `git apply --check` clean on `236788cd`.
- **m1n1:** the published set doesn't apply to *any* single upstream commit.
  - `0003` and `0004` apply.
  - `0001` (kboot T6050) and `0005` (USB skip gen-4 SPMI PD) each have **one trivial conflict** on `70757dc7`. Keep upstream's new `tps6598x_foreach_hpm(..., true)` signature inside the `chip_id != T6050` guard. Take betizzel's `CTRR_M4_*_EL2` names.
  - `0002` targets the pre-2026-09-27 `src/hv.c` layout. `0006` lacks its base blob.
  - Both `0002` and `0006` are **hypervisor-only and not needed** for direct `linux.py` boots, so skip them.
  - Upstream merged SPMI gen-4 support (#626), so `0005` may no longer be needed. Test without it once, after the first good boot.

## 1. Host side (the machine cabled to the MacBook; Linux)

1. Install packages (Arch names):
   - `python python-pyserial python-construct picocom git make clang lld rustup dtc bc bison flex openssl cpio`
   - `aarch64-linux-gnu-gcc` (kernel cross-compile).
   - `rustup default stable && rustup target add aarch64-unknown-none-softfloat`.
   - The kernel's Rust needs `rust-src` and `bindgen` at the versions `make rustavailable` asks for.
2. (!) system-wide: `sudo cp vendor/m1n1/udev/80-m1n1.rules /etc/udev/rules.d/ && sudo udevadm control --reload && sudo usermod -aG uucp $USER` (`dialout` on Debian). Log out and back in.
3. Get the sources:
   ```sh
   git clone https://github.com/betizzel/omarchy-m5 && cd omarchy-m5 && git checkout 15cd70c1
   M1N1_REF=main LINUX_REF=asahi-wip-7.2 scripts/fetch-sources.sh
   git -C vendor/m1n1 checkout 70757dc7 && git -C vendor/m1n1 submodule update --init --recursive
   scripts/apply-patches.sh   # resolve the 2 conflicts above by hand; drop 0002/0006
   ```
4. Build:
   - Install image: `CHAINLOADING=0 scripts/build-m1n1.sh`, then copy `vendor/m1n1/build/m1n1.bin` to `m1n1-stage1.bin`.
   - Chainload image: `CHAINLOADING=1 scripts/build-m1n1.sh`, then copy to `build/m1n1-chain.bin`.
5. Kernel and DT:
   - `scripts/build-kernel.sh`. Its config is `defconfig asahi.config omarchy-bringup.config omarchy-storage-net.config omarchy-smc.config`, and it overlays `dt/` into the tree.
   - `make dtbs` builds `t6050-j714s.dtb`.
   - `make initramfs` builds the Alpine busybox initramfs.
6. `scripts/mktether.sh` produces `build/tether-bundle.tar.gz` (proxyclient, artifacts, `boot-linux.sh`, `chainload.sh`). Unpack it on the host.

**Check:** `vendor/m1n1/build/m1n1.bin` exists, `Image.gz` and `t6050-j714s.dtb` are built, and `./proxyclient/tools/shell.py --help` runs.

## 2. MacBook side (owner, by hand)

Make a backup first. FileVault is fine for macOS; the stub is separate.

1. Copy `m1n1-stage1.bin` and the omarchy-m5 checkout to the Mac.
2. (!) **Partition:** `sudo scripts/prep-stub.sh` (or `--linux-size 20G` to also carve the Linux root).
   - This shrinks the macOS container and creates the 6 GB "Omarchy" APFS stub (Data/System/Preboot/Recovery) plus a 500 MB EFI partition.
   - It clones *this* install's restore bundle, so the stub gets **26.6.2 / mBoot-18000.161.10**. betizzel tested on 26.5 / 18000.120.36.
   - It prints the stub VGID; write it down.
3. (!) `sudo scripts/finish-install.sh --m1n1 ~/m1n1-stage1.bin`.
   - Writes `Finish Installation.app` with `boot.bin`, blesses the stub, and drops `.IAPhysicalMedia`.
   - It asks for the macOS admin password.
4. (!) **1TR ceremony** (one continuous sequence):
   1. Shut down and wait 15 s.
   2. **Hold** power until "Loading startup options…". Tapping isn't enough; that reaches the picker, not 1TR.
   3. Pick **Omarchy**. Its recoveryOS auto-opens Terminal running `step2.sh`. If it doesn't, use Utilities → Terminal and run `"/Volumes/Omarchy/Finish Installation.app/Contents/Resources/step2.sh"`.
   4. `step2.sh` checks `bputil -d` for `Paired` and `one true recoveryOS`.
   5. (!) It runs `bputil -nc` (credentials asked twice). This sets Permissive Security **on the stub only**.
   6. (!) It runs `kmutil configure-boot -c boot.bin --raw --entry-point 2048 --lowest-virtual-address 0`.
   7. It renames `.IAPhysicalMedia` away.
5. (!) Proxy backdoor, in the stub's 1TR: `csrutil disable && nvram boot-args=-v`. Pick the Omarchy volume when asked.
6. **Check:** reboot. You should see the m1n1 logo and log on the native 3024×1964 panel. (!) `nvram boot-volume` now points at the stub, so a plain power-on goes to m1n1. To get macOS: hold power → picker → Macintosh HD, which stays at Full Security.

## 3. Tethered boots (memory only, never writes the Mac)

1. Plug USB-C from the host into the MacBook. If it doesn't enumerate, **try each port**; the gadget binds to one specific dwc3.
2. On the host: `proxyclient/tools/picocom-sec.sh` (console). Power on the Mac; within 5 s the open TTY puts m1n1 into proxy mode.
3. Check `proxyclient/tools/shell.py` prompts, then exit.
4. Optional, to iterate on m1n1 only: `./chainload.sh` (runs `chainload.py -r boot/m1n1-chain.bin`).
5. Boot Linux: `./boot-linux.sh`. This is `linux.py Image.gz t6050-j714s.dtb initramfs -b "$BOOTARGS"`, and the argument order matters. The default bootargs are:
   `maxcpus=1 earlycon=efifb keep_bootcon console=tty0 loglevel=8 pd_ignore_unused clk_ignore_unused no_console_suspend nvme_apple.flush_interval=0`
   - Add `m5.root=/dev/nvme0n1p5` only after a root partition exists.
   - Add the M4+ WFI workaround: the `idle=` param, or rely on m1n1's auto-disable.

## 4. Expected results and known failures

| Step | Success looks like | Known failure |
|---|---|---|
| m1n1 stage 1 | Logo plus log on the panel | Picker offers "reinstall": `.IAPhysicalMedia` is missing |
| proxy | `/dev/m1n1`, `/dev/m1n1-sec` appear | Wrong USB-C port; host user not in the tty group |
| `linux.py` | `Starting CPU n … Failed!` ×14 (~1.4 s, expected), then the kernel on the framebuffer | Hang without patch `0005` (SPMI gen-4 PD probe); proxy-ABI mismatch, so chainload the matching m1n1 first |
| kernel | Busybox prompt on tty0, built-in keyboard works, NVMe visible | No input: MTP DAPF/DART (edimoldovan's J714c notes: filter entry 0 = PMGR window); crash in idle: WFI loses state; no secondary CPUs: **expected** (see 03-pmp.md) |
| root on NVMe | `provision-rootfs` from the initramfs, then root on `nvme0n1p5` | follow betizzel's `docs/bringup.md` §Resizing step 7 |

**Unverified for us:** the 26.6.2 firmware versus betizzel's 26.5. The MTP and ANS firmware could differ.

## 5. Disagreements between betizzel and edimoldovan
- **Why secondary cores don't start.** betizzel (10-10) blames SPTM-mediated reset and wants an XNU shim. edimoldovan (11-03) withdrew his own SPTM theory: under a raw loader `GXF_CONFIG_EL1=0`, so SPTM isn't active, and he puts the cause in the **PMP**. I lean towards edimoldovan; details are in 03-pmp.
- **Loader and kernel:** upstream plus patches (betizzel) versus the Aurora forks (edimoldovan).
- **Loader duties:** edimoldovan's loader programs the MTP DAPF entry 0 and keeps the MTP DART in translate mode. betizzel's `0001` covers kboot DAPF differently. Agreed: ADT `reg` + `0x2_0000_0000` = MMIO, the UART is at `0x505200000`, and `maxcpus=1`.

## 6. Rollback to stock
1. In macOS: System Settings → General → Startup Disk → Macintosh HD.
2. `diskutil list disk0`. Identify partitions **by type and size**, not number: the 6 GB `Apple_APFS` "Omarchy" container, the `EFI` partition, and the `Linux Filesystem` partition. **Never** touch `Apple_APFS_ISC` (first) or `Apple_APFS_Recovery` (last).
3. (!) Delete them, re-listing between each command:
   - `sudo diskutil eraseVolume free free disk0sX` (Linux, then EFI)
   - `sudo diskutil apfs deleteContainer disk0sZ` (stub)
   - `sudo diskutil apfs resizeContainer disk0s2 0`

   If the resize fails verification, run `diskutil repairVolume disk0s2` from recoveryOS.
4. The stub's LocalPolicy (Permissive) goes away with its container. macOS was never downgraded. Clear `boot-args` from macOS's own recovery only if it was set there; step 2.5 above set it in the stub's 1TR.
5. **Last resort:** DFU revive from a cabled Mac (see 01).

Alternatively, `sudo scripts/finish-install.sh --undo` reverses the bless/app step only.
