# 09 — Rootfs for the 120 GB partition, installer, loader readiness, probe plan

## 1. `build/rootfs-alarm.tar.zst`
**sha256 `f859bd8d77dd693b8c148ae130997c24c98a45b814486a5b9a762186727e7065`**, 589 MB (2.2 GB unpacked). Built by `tools/rootfs/build.sh` (user-level; one fakeroot state keeps every file root-owned).

**Base: Arch Linux ARM aarch64 "latest" tarball.**
- `ArchLinuxARM-aarch64-latest.tar.gz`: 829,367,415 B, sha256 `42a4eeaa038994ffd31fa173256ef2f0ef511358eeb41b9ea1f8626391b9b319`; MD5 matches the published `.md5`.
- **GPG:** `GOODSIG`, `VALIDSIG 68B3537F39A313B3E574D06777193F152BDBE6A6` (Arch Linux ARM Build System), signed 2026-08-05.
- **Key provenance:** fetched over HTTPS from keyserver.ubuntu.com. Its fingerprint matches the one on `https://archlinuxarm.org/about/package-signing`. The `.sig` fetched from `os.archlinuxarm.org` and from the `fl.us` mirror are byte-identical.
- (!) `https://os.archlinuxarm.org` currently fails TLS (certificate name mismatch), so the tarball came over **HTTP via the mirror redirect**. Integrity rests on the GPG signature.
- **kexec-tools** `2.0.32-1` (`kexec-tools-2.0.32-1-aarch64.pkg.tar.xz`, sha256 `3ad703c3…577c8`, which matches `extra.db`'s `%SHA256SUM%`). GPG `VALIDSIG` by the same key. It ships in `/root/pkgs/` and is **installed by pacman on first boot**, so the pacman DB stays consistent.

**Our additions:**
- `/usr/lib/modules/7.2.2-g236788cd2602-dirty/` (our 1643 modules, stripped).
- `/boot/Image.gz`, `/boot/Image` (uncompressed, for kexec), `/boot/m5.dtb` (= `t6050-j714s.dtb`).
- `/boot/cmdline`: `maxcpus=1 earlycon=efifb keep_bootcon console=tty0 loglevel=7 pd_ignore_unused clk_ignore_unused nvme_apple.flush_interval=0 root=PARTUUID=@PARTUUID@ rw rootwait`. The installer fills in the PARTUUID.
- `/etc/pacman.conf` has **`IgnorePkg = linux-aarch64 linux-aarch64-headers`**. ALARM's own kernel package owns `/boot/Image*`, so without this a `pacman -Syu` would overwrite ours. ALARM's 7.1.6 modules dir and `initramfs-linux.img` are left in place, unused.
- `/root/.ssh/authorized_keys` = `build/work.pub` (0600); sshd as shipped by ALARM (openssh 10.4p1), key-only for root.
- **Default ALARM credentials removed:** `root:root` and `alarm:alarm` are locked (`!` in `/etc/shadow`). Console access is via **tty1 autologin as root** (`getty@tty1` drop-in), physical access only.
- `m5-gadget-net.service`: oneshot, enabled. It runs `/usr/local/bin/m5-gadget-net`, the same logic as the initramfs (CDC-EEM on every UDC, `10.55.<n>.2/24`). No systemd-networkd `.network` file claims the gadget netdevs, so the script's static address isn't fought over.
- `m5-firstboot.service`: runs once, only while `/var/lib/m5/firstboot-pending` exists. It does `pacman-key --init`, `pacman-key --populate archlinuxarm`, `pacman -U /root/pkgs/*`, then removes the flag.
- `/usr/local/lib/m5/t6050_probe.ko`; hostname `m5-j714s`.

**16K pages:**
- Our scan (`tools/rootfs/elf-align-check.py`) of **1672 aarch64 EXEC/DYN ELF files** found **0 with PT_LOAD alignment < 16 KiB**. Asahi's broken-software page names misaligned ELF segments as the usual 16K failure.
- **jemalloc is not installed** in the base. Asahi lists jemalloc as "Fixed since 5.3.1" if it's ever pulled in.
- glibc `2.43`, systemd `261.2`.
- [guess] Fine for 16K. Software outside the base (browsers, hardened_malloc, Waydroid) is covered by Asahi's list.

**Known limitation:** file capabilities (`security.capability` xattrs, e.g. on `ping`) may not survive fakeroot repack + busybox tar extract. Fix after boot with `pacman -S iputils` (or `setcap`).

## 2. Install procedure (on the Mac, from the first-boot initramfs, AI-driven over ssh)
The first-boot initramfs now also carries `sfdisk` (util-linux 2.42.3), `mkfs.ext4`/`e2fsck` (e2fsprogs 1.47.4) and `/bin/install-rootfs.sh`. All of these are from Alpine v3.24, and the 12 new apks were verified through the signed index + control checksum + data `datahash` chain. Every binary's `NEEDED` libraries are present.

| Image | Size | sha256 |
|---|---|---|
| `build/initramfs.cpio.gz` | 2,368,720 B | `20eef15588801b43dc75f4dbd570ccebf9d84632ffc753019767318c55db002f` |
| `build/initramfs-loader.cpio.gz` | 2,920,588 B | `f11e0a88cdd42053e921c41c285154b70d03dcd85357928099e38ec28389efa1` |

These supersede the 07 hashes.

**`tools/install-rootfs.sh` guards** (any failure exits before writing anything):
1. The target disk (default `/dev/nvme0n1`) is a GPT block device.
2. It carries Apple **ISC** (`69646961-…`), **APFS** (`7C3457EF-…`) and **Recovery** (`52637672-…`) types, so it's the Mac's internal disk.
3. **Exactly one** partition of type Linux filesystem `<uuid>`.
4. Its size is within **119.5–120.5 GB** (sector size read from `sfdisk -d`; Apple NVMe uses 4096).
5. Its type is not APFS/ISC/Recovery/EFI.
6. It isn't mounted.
7. It has no existing filesystem (busybox `blkid`) unless `--force`.
8. An interactive `YES` confirmation unless `--yes`.

It then runs `mkfs.ext4 -L m5root`, untars the rootfs from stdin, checks for `/etc/os-release`, writes `/etc/fstab` with **`PARTUUID=<uuid> / ext4 rw,relatime 0 1`**, fills the PARTUUID into `/boot/cmdline`, and unmounts.

**Tested on ush** against sparse GPT images (512-byte sectors, our real layout):

| Image | Result |
|---|---|
| good layout | dry run passes |
| no Apple partitions | REFUSING: lacks Apple partition type |
| two Linux partitions | REFUSING: need exactly one, found 2 |
| 10 GB Linux | REFUSING: size outside range |

Not tested: the existing-FS guard, and the real 4096-byte-sector NVMe.

**Commands from `work`:**
```sh
ssh root@10.55.0.2 sh /bin/install-rootfs.sh --dry-run          # guards only; prints target, size, PARTUUID
zstd -dc build/rootfs-alarm.tar.zst | ssh root@10.55.0.2 'sh /bin/install-rootfs.sh --yes'
ssh root@10.55.0.2 'm5-loader /dev/nvme0n1pN'                    # kexec into the installed system (loader initramfs)
```
- The tar is decompressed on `work`, because busybox tar has no zstd and Alpine's zstd binary would pull in libstdc++.
- After kexec into ALARM: `ssh root@10.55.0.2`. On first boot, `m5-firstboot` installs kexec-tools (it needs no network).
- Note: `/boot/cmdline` keeps `maxcpus=1`.

## 3. Option B loader readiness ([owner-only] owner part)
**Superseded in direction by task 10** (our own boot object instead of m1n1). For the record, the m1n1-based stage 2 needs the owner to:
1. [owner-only] Build the m1n1 stage 2 and assemble the payload: m1n1 + `t6050-j714s.dtb` + `Image.gz` + `initramfs-loader.cpio.gz` + a `chosen.bootargs=… m5.loader=1 m5.root=/dev/nvme0n1pN` line.
2. [owner-only] Configure stage 1 to chainload it from the ESP (`m1n1/boot.bin`).

Both steps are m1n1 tooling and formats, so they're owner-only (06-evidence §3). Everything after that (kernel/DT iteration via `/boot` + kexec, probes) is ours.

## 4. Experiment list once Linux is up (our module, read-only, one group per `insmod`)
Order: **1 → 2 → 4 → 8**. Reboot after any hang. The module logs each address before reading it, so the last dmesg line names the culprit.

| Step | Reads | Result → meaning for the PMP hypothesis |
|---|---|---|
| G1 controls | MTP `+0x44`, MTP reg[1], dart-mtp | **Values** → reads from Linux work. A **fault** means our method is wrong; stop and fix it before interpreting anything else |
| G2 PMGR PS | PMS, **PMP**, **PMS_SRAM**, MCPM0/1, PCPM (`0x2_8060_0100/0128/0130/0090/0098/00a0`) | PMP **and** PMS_SRAM "on" → the gates aren't the problem, so B5 (access lock) gains. **PMS_SRAM off** → supports "a missing gate makes the PMP wrapper fault" (05 alternative 3); the next experiment would be a gate-on *write* (needs PM approval). The MCPM/PCPM state shows whether secondary cluster power is requested or held |
| G4 PMP DART / fw / PTD | dart-pmp0 +0, firmware region +0, **PMP-STATUS** `0x2_8424_0010`, SOC-DEV-PS-REQ/ACK | Firmware non-zero + STATUS 0 → loaded but not running, as edimoldovan saw on J714c. **STATUS non-zero** → the PMP *is* running under our boot, which weakens "nobody starts PMP" |
| G8 PMP wrapper | mailbox `+0x8110`, reg[1], wrapper `+0`, **`+0x44`** | All fault → block gated or locked (combine with G2). Mailbox OK but `+0x44` faults → a selective lock on CPU control. **`+0x44` reads fine** → J714s differs from J714c, and the next step is a PMP start attempt (pmp.rs-style; needs approval) |

The aura-derived addresses (G2/G4) are used under the owner's research-only decision (06-evidence).
