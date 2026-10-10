# Phase 1 bring-up guide — m1n1 → kernel → TTY on M5 Pro

The dev loop is tethered: an installed stage-1 m1n1 chainloads test builds
over USB, so kernel/DT iterations never touch boot policy. Partitioning and
`kmutil` happen once, up front; everything after is memory-only.

```sh
make setup    # brew llvm/lld/dtc/bc/bison/flex/openssl/make/gnu-sed
              # + rust aarch64-unknown-none-softfloat target
make fetch    # clone vendor/m1n1 (main) + vendor/linux (asahi-wip-7.2)
make m1n1     # CHAINLOADING=1 build -> vendor/m1n1/build/m1n1.bin
make dtbs     # overlay dt/ into the kernel tree, build t6050 DTBs only
make kernel   # full kernel (defconfig; KCONFIG=asahi_defconfig to override)
```

macOS quirks handled by the scripts: GNU Make/sed over the BSD versions
(kernel scripts use GNU sed syntax BSD sed silently passes through), and
`scripts/host-shim/` supplies the glibc headers macOS lacks (`elf.h` —
vendored musl copy — `byteswap.h`, `copy_file_range`, `O_LARGEFILE`).

## One-time on-device step (the risky part — do it once, carefully)

`scripts/prep-stub.sh` automates the mechanical half — run it with sudo:

```sh
sudo scripts/prep-stub.sh                  # stub + EFI only
sudo scripts/prep-stub.sh --linux-size 20G    # also carve the rootfs
```

It shrinks the macOS container, creates the 6 GB "Omarchy" stub
(Data+System+Preboot+Recovery volume group), clones this install's
restore bundle / `arm64eBaseSystem.dmg` / `AdminUserRecoveryInfo.plist`
into it (no IPSW download — everything is on-disk), and makes a 500 MB
EFI partition for m1n1. It prints the stub's VGID at the end. All in,
`--linux-size N` takes N + 6.5 GB away from macOS.

Then arm the stub so the picker hands control to *its* paired recoveryOS:

```sh
CHAINLOADING=0 make m1n1          # the installed stage-1 must not be a chainload build
sudo scripts/finish-install.sh    # asks for your macOS admin password (bless)
```

`finish-install.sh` reproduces the state asahi-installer leaves behind
(`src/stub.py` + `src/step2/`): it writes `Finish Installation.app` with
m1n1 as `Contents/Resources/boot.bin`, creates `private/var/db/dslocal` on
the Data volume, sets the APFS bootable fsctl on the System volume,
`bless --setBoot`es it, then hides `SystemVersion.plist` and drops
`.IAPhysicalMedia`.

That last marker is the whole trick: without it iBoot treats the stub as a
normal OS, finds no LocalPolicy, and the picker offers "reinstall". With
it the volume looks like install media, so the picker boots the volume
group's paired recoveryOS and auto-launches the app named in the plist.

Then, in one continuous motion:

1. Shut down fully, wait ~15 s.
2. Press and **hold** power until "Loading startup options..." (tapping
   twice reaches the picker but *not* 1TR — `step2.sh` will refuse).
3. Pick "Omarchy". Its recoveryOS opens a Terminal running `step2.sh`,
   which checks `bputil -d` for `: Paired` + `one true recoveryOS`, runs
   `bputil -nc` (credentials twice), then `kmutil configure-boot -c
   boot.bin --raw --entry-point 2048 --lowest-virtual-address 0`, and
   finally renames `.IAPhysicalMedia` away so the next boot goes straight
   to m1n1.
4. If no Terminal opens: Utilities → Terminal, then run
   `"/Volumes/Omarchy/Finish Installation.app/Contents/Resources/step2.sh"`.

Back out with `sudo scripts/finish-install.sh --undo`.

## Resizing or re-installing

The stub, the EFI partition and the Linux root sit together right behind
macOS (`disk0s2`), and an APFS container only grows into free space
directly after it. None of them can be resized in place: to give macOS
space back (or take more), delete all three, grow macOS, and install
again. That wipes the Arch root and the stub's boot policy, so the
ceremony above runs again.

1. Save what you want from the M5 (it is wiped), from the ThinkPad:

   ```sh
   ssh bay@10.55.0.2 'pacman -Qqen' > m5-pkglist.txt
   ssh bay@10.55.0.2 'sudo tar -C / -czpf - home/bay' > m5-home.tgz
   ```

2. In macOS, make it the default boot volume again **first**: System
   Settings → General → Startup Disk → Macintosh HD.
3. `diskutil list disk0`, and find the three by type and size, never by
   number (macOS renumbers `disk0sN` by disk position): the 6 GB
   `Apple_APFS` container with the `Omarchy` volumes, the `EFI` partition,
   and the `Linux Filesystem` partition. **Never** touch the first
   (`Apple_APFS_ISC`) or the last (`Apple_APFS_Recovery`) partition.
4. Delete them, re-running `diskutil list disk0` between commands, then
   give macOS all of the free space:

   ```sh
   sudo diskutil eraseVolume free free disk0sX     # Linux Filesystem
   sudo diskutil eraseVolume free free disk0sY     # EFI
   sudo diskutil apfs deleteContainer disk0sZ      # the 6 GB Omarchy stub
   sudo diskutil apfs resizeContainer disk0s2 0    # macOS takes the free space
   ```

   Grow macOS before re-installing: `prep-stub.sh` then shrinks it by
   exactly what it needs instead of leaving the old space unallocated. If
   the resize says `Storage system verify or repair failed`, run
   `diskutil repairVolume disk0s2` from recoveryOS and retry (Asahi's
   [partitioning cheatsheet](https://asahilinux.org/docs/sw/partitioning-cheatsheet/)
   covers this and the delete commands).
5. Build the stage-1 m1n1 (`CHAINLOADING=0 scripts/build-m1n1.sh`, on the
   ThinkPad or the Mac) and copy `vendor/m1n1/build/m1n1.bin` to the Mac as
   `~/m1n1-stage1.bin`.
6. On the Mac, in an up-to-date checkout:

   ```sh
   sudo scripts/prep-stub.sh --linux-size 20G
   sudo scripts/finish-install.sh --m1n1 ~/m1n1-stage1.bin
   ```

   then the power-hold → "Omarchy" → `step2.sh` ceremony above. Afterwards
   an unattended power-on lands in m1n1 again.
7. Provision the root, from the ThinkPad's tether directory with the M5
   in m1n1:

   ```sh
   ./chainload.sh
   python3 hv/nvme-proxy-probe.py      # prints the provision-rootfs line
   INITRAMFS=boot/initramfs-provision.cpio ./boot-linux.sh
   ```

   The new partition has no filesystem, so `/init` stays in its shell. On
   the M5's keyboard, type the `provision-rootfs START COUNT` line the probe
   printed, then `reboot -f` (the watchdog resets the M5 into m1n1; or
   power-cycle).
8. First boot from the SSD. The image only knows root (with the ThinkPad's
   `~/.ssh/*.pub` from when it was built) and `boot-m5.sh` waits for `bay`,
   so boot by hand once, then recreate `bay` and restore:

   ```sh
   ssh-keygen -R 10.55.0.2                    # the new root has a new host key
   ./chainload.sh && ./boot-linux.sh          # first boot grows / to the partition
   ssh -t root@10.55.0.2 'useradd -m -G wheel bay && passwd bay &&
       echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/10-wheel-bringup'
   ssh root@10.55.0.2 'pacman -Syu --needed --noconfirm -' < m5-pkglist.txt
   ssh root@10.55.0.2 'tar -C / -xzpf -' < m5-home.tgz
   ```

   From then on `./boot-m5.sh` does the whole cycle again.

## Status: boot policy is DONE (2026-09-21)

The ceremony completed on the M5 Pro. `bputil -nc` set Permissive (3rd
party kexts permitted, CTRR disabled, boot-args filtering disabled),
`kmutil configure-boot` registered m1n1 as the stub's custom boot object,
and the machine now boots iBoot → m1n1 stage1 → framebuffer console at
native 3024x1964 with DARTs initialized. `nvram boot-volume` points at the
stub VGID, so an unattended power-on lands in m1n1, **not** macOS; get
macOS back with power-hold → picker → Macintosh HD (still Full Security).

## Dev loop

Two loops. The tethered one is the real one; the standalone one exists
because the target and the build host are the same laptop when no second
machine is around.

### Tethered — the normal loop (Arch ThinkPad over USB-C)

The M5 is the target, so the proxyclient has to live on the other
machine. `scripts/mktether.sh` packs everything it needs — proxyclient,
kernel, DT, initramfs, a chainloadable m1n1, the udev rule and runners:

```sh
make initramfs
CHAINLOADING=1 scripts/build-m1n1.sh && cp vendor/m1n1/build/m1n1.bin build/m1n1-chain.bin
CHAINLOADING=0 scripts/build-m1n1.sh     # restore the installed-image config
scripts/mktether.sh                      # -> build/tether-bundle.tar.gz
scp build/tether-bundle.tar.gz thinkpad:
```

On the host (once): `pacman -S python-pyserial python-construct`,
`cp 80-m1n1.rules /etc/udev/rules.d/`, `udevadm control --reload`,
`usermod -aG uucp $USER`. The rule matches the gadget (1209:316d) and
creates `/dev/m1n1` (proxy) and `/dev/m1n1-sec` (m1n1's own console).
Then:

```sh
./boot-linux.sh                                  # kernel + dt + initramfs
BOOTARGS="maxcpus=1 initcall_debug" ./boot-linux.sh
./chainload.sh                                   # iterate on m1n1 itself
```

Note the upstream tools take **positional** arguments
(`linux.py <Image.gz> <dtb> [initramfs] -b "<cmdline>"`); the runners in
the bundle wrap that. Iterations are memory-only — the installed boot
object is never rewritten, and a bad boot just needs a power-cycle.

Expect `Starting CPU n … Failed!` for every secondary: SMP is broken on
T6050 and m1n1 gives each core 100 ms before moving on (~1.4 s total,
not fatal). That is why the cmdline pins `maxcpus=1`.

If proxyclient doesn't enumerate, try the other USB-C ports — the gadget
binds to one specific dwc3 port.

### Standalone (no second machine — one 1TR ceremony per image)

m1n1 parses everything appended after its own image as a payload chain
(`src/payload.c`), so the kernel, DT, initramfs and cmdline ship inside
the boot object itself:

```sh
make initramfs   # Alpine aarch64 busybox+musl, repacked as newc cpio (no root)
make payload     # m1n1 | chosen.bootargs=… | Image.gz | dtb | initramfs.cpio.gz
sudo scripts/finish-install.sh --m1n1 build/m1n1-payload.bin
# then repeat the power-hold → picker → "Omarchy" ceremony
```

`mkpayload.sh` re-walks the assembled file with the same magics m1n1 uses
and fails if the chain doesn't parse, so a bad `cat` never reaches the
ceremony. Use this for milestone boots; it costs a ceremony per kernel, so
it is not an iteration loop.

Kernel cmdline for first boots: `maxcpus=1` (SMP is broken — secondaries
never execute the reset vector), plus the M4+ WFI workaround (`idle=` param
from linux-next, or m1n1 PR #672's auto-disable).

Console: `console=tty0` on m1n1's framebuffer handed over as simplefb is
the only console needing no cable. dockchannel-UART (m1n1 secondary
channel) and serial0 (0x505200000, Samsung UART) both need the debug cable.

## DT state (populated from the real J714s ADT)

`dt/t6050-pmgr.dtsi` is generated, not hand-written:

1. Extract the ADT: `devicetree.img4` lives in the booted OS's Preboot at
   `usr/standalone/firmware/devicetree.img4`. Strip the IM4P header and
   LZFSE-decompress the `bvx2` payload (macOS `libcompression` handles it).
2. `scripts/adt2pmgr.py adt.bin > dt/t6050-pmgr.dtsi` — a fixed fork of
   m1n1's `pmgr_adt2dt.py` (upstream crashes on T6050's die-level parent
   IDs 219/325/609, which have no device entry).

Verified on J714s (macOS 26.5): 405 power domains across 6 PMGR blocks;
real IRQs/npins for uart/i2c/spi/gpio/wdt/dockchannel; CPU topology
15 cores (5+5+5, binned — cpu5/cpu11/cpu17 disabled in the board DTS).
Remaining TODO(adt) markers: AIC event region, PMU FIQ affinities,
pinmux tables, which SPI bus carries keyboard/trackpad.

Note: ADT `reg` values sit 0x2_0000_0000 below the MMIO address on this
SoC (uart0 ADT 0x305200000 → MMIO 0x505200000, matching m1n1's
EARLY_UART_BASE). Apply the same offset when converting new nodes.

## Success metric

Reproducible boot to getty: single core, on-device display (simplefb) or
dockchannel console, NVMe rootfs optional for the first milestone.

## References

- `docs/PLAN.md` — phase plan
- `docs/research/kernel-boot-m5.md` — blockers (SMP, WFI, NVMe fwabi)
- `docs/research/dualboot-partitioning.md` — stub/1TR/kmutil mechanics
- qspqww/m1n1 `t6050-j716c-bringup` — real-hardware M5 Pro/Max notes
  (findings.md, bringup/t6050-j716c/LINUX_PC_BRINGUP_GUIDE.md)
- ImAtomiskk/asahim5 — t8142 (base M5) DT + ADT dump, closest public
  reference for what a hand-authored M5-gen DT looks like
