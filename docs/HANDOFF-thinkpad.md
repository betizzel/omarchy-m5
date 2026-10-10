# ThinkPad handoff: provision the 20 GB root (2026-10-09)

> For an agent on the Arch ThinkPad (T14) that drives the M5 over USB-C.
> The macOS half of the re-install is done (`docs/HANDOFF-mac.md`); this
> file carries everything the ThinkPad needs from it. You run the tether;
> the human types on the M5's keyboard. Background: `docs/HANDOFF.md`
> (project state) and `docs/bringup.md` ("Resizing or re-installing",
> steps 7–8).

## Where things stand

- From macOS on the M5, 2026-10-09: the stub, EFI and Linux root exist
  again (root now **20 GB**, was 256 GB). The stub is armed by
  `finish-install.sh` and blessed as the default boot volume.
- The **1TR ceremony** (power-hold → Omarchy → `step2.sh`) came next, done
  by the human right after this file was pushed. If it worked, an
  unattended power-on lands in m1n1. Step 1 checks that.
- The Linux root is **empty**: no filesystem. Nothing was backed up from
  the old root (accepted), so there is no `m5-pkglist.txt` or
  `m5-home.tgz` to restore.
- macOS is still **26.5 (25F71)**, the version the DT, runtime ADT and
  trackpad firmware were tuned on. Nothing to re-dump or re-extract.
- The installed stage-1 m1n1 was built on the Mac: pinned m1n1
  `4184923ffb2dff079b384d6a32cc02142aa14572` + `patches/m1n1/0001..0003`,
  `CHAINLOADING=0`, sha256
  `cf173749b6b873d39c5be9a72ab073cd3b5baa147efa24bf572b5fa80158b262`
  (not the ThinkPad prebuilt `e9d6122d…`; same sources, other toolchain).
  The chainloadable m1n1 in the tether bundle is unaffected.

## Disk facts

From `sudo gpt -r show /dev/disk0` and `diskutil` on the Mac; LBAs are
4096 bytes. Linux names partitions by GPT entry, so the root is
`nvme0n1p5`. macOS's `disk0sN` names did not follow the GPT entry in that
session (the root was `disk0s7`, the stub `disk0s5`), so ignore them.

| GPT | Linux | Contents | Start LBA | LBAs | Size |
|---|---|---|---|---|---|
| 1 | p1 | Apple_APFS_ISC | 6 | 140800 | 576.7 MB |
| 2 | p2 | macOS APFS container | 140806 | 236338432 | 968.0 GB |
| 3 | p3 | Omarchy stub, VGID `83F76F48-1DE4-4C8B-99C0-E9D48E59AF0D` | 236479238 | 1464843 | 6.0 GB |
| 4 | p4 | EFI, FAT32 `OMARCHY`, empty (the tethered flow does not use it) | 237944081 | 122070 | 500 MB |
| 5 | p5 | **Linux root**, unformatted, PARTUUID `31E075EA-6937-4A6A-BCE2-49AC5DE25062` | 238066151 | 4882812 | 20.0 GB |
| – | – | free (alignment slack) | 242948963 | 16588 | 68 MB |
| 6 | p6 | Apple_APFS_Recovery | 242965551 | 1310709 | 5.4 GB |

The root is GPT entry 5, the default of both `m5.root=` and
`provision-rootfs`, so no `PART=` and no BOOTARGS change.

## Ground rules

- The SSD holds the user's macOS. The only thing that writes to it is
  `provision-rootfs` on the M5, which refuses anything but `nvme0n1p5`
  with exactly the geometry above. No `dd`, `mkfs`, `sgdisk` or `parted`
  against `nvme0n1` from any shell.
- Anything typed on the M5's keyboard is the human's: give them the exact
  line.
- If the probe's GPT differs from the table, or a step errors out, stop
  and report.

## Step 0: ThinkPad preflight

```sh
cd ~/Work/omarchy-m5 && git pull --ff-only
sudo scripts/host-usbnet.sh          # once per ThinkPad boot
ls ~/tether/boot/                    # needs initramfs-provision.cpio
```

The 2026-10-01 `initramfs-provision.cpio` is still good: its root image is
2 GiB and grows to the partition on first boot, and the geometry is passed
on the command line, not baked in. Its root authorizes the `~/.ssh/*.pub`
of the machine that built the image. If it is missing, or was built
somewhere else, rebuild it (needs
`build/cache/ArchLinuxARM-aarch64-latest.tar.gz` and
`build/firmware/apple/tpmtfw-j714s.bin`, the latter from
`scripts/extract-tpmtfw.py` with the 26.5 IPSW):

```sh
scripts/mkrootfs-image.py            # -> build/rootfs/m5root.img.gz
scripts/mkinitramfs.py --rootfs-image build/rootfs/m5root.img.gz \
    --out build/initramfs-provision.cpio
cp build/initramfs-provision.cpio ~/tether/boot/
```

## Step 1: is the M5 in m1n1?

Cable on, power the M5 on without holding anything. Success: m1n1 on the
panel, and `/dev/m1n1` + `/dev/m1n1-sec` on the ThinkPad (no device: try
the M5's other USB-C ports; the gadget binds to one dwc3 port).

If it boots macOS or the picker instead, the ceremony did not finish. The
human redoes it: shut down, hold power until "Loading startup options…",
pick Omarchy, follow `step2.sh` (macOS admin is `bay`). No Terminal in
that recoveryOS: Utilities → Terminal, then
`"/Volumes/Omarchy/Finish Installation.app/Contents/Resources/step2.sh"`.
If the picker offers "reinstall", `.IAPhysicalMedia` is gone: boot macOS
(power-hold → Macintosh HD) and re-run
`sudo scripts/finish-install.sh --m1n1 ~/m1n1-stage1.bin` there
(`docs/HANDOFF-mac.md` Phase 4).

## Step 2: probe and provision

```sh
cd ~/tether
./chainload.sh
python3 hv/nvme-proxy-probe.py
```

The probe reads the GPT through m1n1 and writes nothing. It must list
p1–p6 as in the table and print:

```
rootfs p5: on the M5 run  provision-rootfs 238066151 4882812
```

Then boot the provisioning initramfs (a pyserial error when the proxy
vanishes at handoff is normal):

```sh
INITRAMFS=boot/initramfs-provision.cpio ./boot-linux.sh
```

p5 has no filesystem, so `/init` says `m5.root=/dev/nvme0n1p5 did not
mount; staying in initramfs` and stays in its shell. On the M5's keyboard:

```sh
provision-rootfs 238066151 4882812
```

Expect `partition ok: /dev/nvme0n1p5 18 GiB, start LBA(4K)=238066151`
(the guard compares sysfs start/size `1904529208`/`39062496` in 512-byte
units), `writing 2048 MiB to /dev/nvme0n1p5`, then `readback ok`. Then
`reboot -f`; the watchdog resets the M5 into m1n1 (or power-cycle).

## Step 3: first boot from the SSD

The same sequence as `boot-m5.sh`, which cannot run yet because it waits
for `ssh bay@`, and `bay` does not exist:

```sh
ssh-keygen -R 10.55.0.2                       # the new root has a new host key
./chainload.sh && python3 hv/nvme-proxy-probe.py && ./boot-linux.sh
ssh -t root@10.55.0.2 'useradd -m -G wheel bay && passwd bay &&
    echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/10-wheel-bringup'
ssh root@10.55.0.2 'install -d -m 700 -o bay -g bay /home/bay/.ssh &&
    install -m 600 -o bay -g bay /root/.ssh/authorized_keys /home/bay/.ssh/'
```

The last command matters this time: `bay`'s keys used to come back with
`m5-home.tgz`, and `boot-m5.sh` logs in as `bay` with keys only. The first
boot grows `/` to the partition (`df -h /` shows about 18G).

Packages are by hand (there is no list). pacman needs
`DisableSandboxFilesystem` unless the booted kernel has Landlock:

```sh
ssh root@10.55.0.2 "grep -q landlock /sys/kernel/security/lsm ||
    sed -i '/^\[options\]/a DisableSandboxFilesystem' /etc/pacman.conf"
ssh root@10.55.0.2 'pacman -Syu --noconfirm'
```

Then ask the user what to reinstall (Claude Code ran as `bay` before,
native installer). Twenty GB fills up fast: keep the pacman cache trimmed.
The bring-up defaults are still root/root on tty1 and passwordless sudo
for wheel; tighten both when the user is ready.

From here, `./boot-m5.sh` runs the whole cycle again.

## Step 4: write it down

Update `docs/HANDOFF.md` with the outcome (provisioning result, growfs
size, anything that broke) and push.

## For the record: Mac-side fixes in this round

`prep-stub.sh` had two bugs the 2026-09-21 run never hit. Its plan math
summed sizes in GiB but handed `diskutil` a bare `G`, which `diskutil`
reads as 10^9: for `--linux-size 20G` it would have shrunk macOS by
95.6 GB instead of 26.5 GB and stranded ~69 GB behind the root. And after
`resizeContainer`, storagekitd remounts the macOS Recovery volume under
`/Volumes`, while `diskutil mount -mountPoint` on an already-mounted volume
exits 0 without moving it, so the recoveryOS copy looked in an empty
directory. Both are fixed; a re-run also prints an honest "resume" plan
and merges the restore bundle with `ditto` instead of nesting it.
