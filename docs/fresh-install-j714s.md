# Fresh install of omarchy-j714s on the J714s

This is the procedure for installing the next J714s image (release 6) from scratch on TripleU613's
MacBook Pro 14" M5 Pro (J714s), as a brand-new user would. It was written on 2026-11-15 and
**run the same day**. What actually happened differs from the plan in one way: the owner asked for
a fully clean Mac, so after `fresh-cleanup.sh --delete` removed the logo Omarchy and the broken old
install, the disk-icon Omarchy, the dev ESP and the dev Linux root were removed too (each found by
partition UUID), macOS was made the startup disk (`bless --mount / --setBoot`) and given all the
space back (`diskutil apfs resizeContainer disk0s2 0`). So the installer had to shrink macOS, as for
a new user, and there is no cable-catcher recovery path any more. Result: installed, Finish setup
worked, first boot on v272-11; the speaker switch-over ran too early (fixed in j714s12). Details in
the README and release 6's notes. Note: over SSH without a terminal, the cleanup script's
startup-disk check gets no `sudo` and prints nothing; it worked when run in the owner's Terminal.

Words used here:
- **logo Omarchy**: the 27.2 install made with release 1 and updated by packages (Omarchy logo in
  the boot picker).
- **disk-icon Omarchy**: the old 27.3 stub (plain disk icon). The PC's catcher boots the dev Linux
  through it. This is the recovery lifeline.
- **pN**: Linux partition numbers on `nvme0n1` as of 2026-11-15. These numbers change when
  partitions are added or removed, so the steps go by partition UUID, not by number.

## 1. Scope

Remove:
- **p3–p6, the logo Omarchy** (stub, ESP, /boot, LUKS root).
- **p10–p12, the old upstream 27.3 install** (ESP, /boot, LUKS root; no stub of its own). Its boot
  files were overwritten on 2026-11-14 and it does not boot.

Keep:
- p1 iBoot system container, p2 macOS, p13 Recovery.
- **p7 old stub, p8 dev ESP, p9 dev Linux root.** These are how the Mac was recovered before.

Why remove p10–p12 too:
- Every Omarchy image writes the same filesystem IDs. p10 has the same FAT ID as the new ESP will
  have (`4F4D-5801`), and p11 has the same ext4 ID as the new /boot. This is the bug in
  [duplicate-boot-ids.md](duplicate-boot-ids.md). With p10–p12 gone, nothing on the disk shares an
  ID with the new install. The dev ESP (`85DC-1706`) and dev root (`9a2d0347-…`) have their own IDs.
- It is broken and holds nothing anyone needs.

Why keep p7–p9:
- If the fresh install loops, the owner picks the disk-icon Omarchy, the catcher boots the dev
  Linux, and the agent can read and fix the new install's ESP from there. That is how release 1's
  loop was found and fixed on 2026-11-13.
- macOS stays bootable either way, so removing p7–p9 would not brick the Mac. It would only lose
  the hands-free path, the dev Linux and its Touch ID enrolment. The 27.3 beta stub would be hard
  to recreate now that the Mac targets 27.2.

### 1.1 Will the installer refuse?

No, once p3–p6 are gone. Today it would refuse.

The app (upstream b1dade4, 67ae6a7, both in our tree) refuses when its welcome inspection finds a
"replace" candidate. `collect_existing_installs` in `Engine/overlay/src/omarchy_planner.py`
counts something as an existing install only when all of these hold:
- an APFS partition holds a stub whose volume label is `Omarchy`;
- the next three partitions are not free space;
- the first of those is a FAT ESP named `EFI - OMARC`;
- the other two are `Linux Filesystem`.

How each part of the disk fares:
- **p3–p6 match** (`EFI - OMARC` ESP, then two Linux partitions). Today the app would say "Omarchy
  is already installed".
- **p7–p9 cannot match.** The dev ESP p8 is named `OMARCHY`, not `EFI - OMARC`. After p10–p12 are
  deleted, the fourth slot is free space anyway.
- **p10–p12 have no stub** in front of them, so they never matched.

Release 1 installed on 2026-11-13 with p7–p12 all present and was not refused, which agrees with
this reading.

The refusal comes right after the welcome inspection, before any download or disk change. So
opening the app after the cleanup is a safe check (step 6.2).

### 1.2 Where the installer will put Omarchy

After the cleanup there are two free gaps:
- **Gap A**, between macOS and the old stub: 137.4 GB (exactly 128 GiB). This is where p3–p6 are now.
- **Gap B**, between the dev root and Recovery: 55.6 GB (p10–p12 plus about 0.2 MB of slack).

The image needs at least the stub (about 6 GB) + ESP 0.5 GB + /boot 2 GiB + root 32 GiB, about
43 GB, so both gaps qualify. `InstallerAllocationRecommendation` ranks free space above shrinking
macOS, and the larger free gap first. So **the app installs into gap A and does not shrink macOS**.
The new partitions should come out as p3–p6 again, with the old stub back at p7.

### 1.3 How this differs from a true first install, and the alternatives

What differs from a brand-new user's install:
1. **macOS is not shrunk.** A new user's install resizes the macOS container. Here the app takes
   free space. The resize code is upstream asahi/omarchy code. It probably ran on this Mac for
   release 1 (that stub starts exactly where macOS ends), but that is not recorded.
2. **There is a second stub** (disk-icon Omarchy) in the boot picker. A new user has only one.
3. Gap B stays empty.

Everything a release must prove still gets tested: download, stub creation, ESP/boot/root
writes, 1TR enrolment, first boot, disk password, first-boot setup and the hardware.

Alternatives:

| Option | What it tests in addition | Risk |
| --- | --- | --- |
| **A. Recommended:** delete p3–p6 and p10–p12, keep p7–p9, leave the space free | – | macOS shrink not exercised |
| B. Also give gap A back to macOS | nothing: the app then installs into gap B (55.6 GB, a smaller root), still without shrinking macOS | worse layout |
| C. Delete only p3–p6, give gap A back to macOS, keep p10–p12 | the macOS shrink path and the j714s10 boot-mount workaround | duplicate ESP and /boot IDs on the disk again (the 2026-11-14 bug) |
| D. Delete p3–p12, give everything back to macOS | the exact new-user path | loses the catcher lifeline, the dev Linux and its Touch ID enrolment; if release 6 loops, recovery is macOS plus reinstall only |

To test the macOS shrink, do it as a separate later run (C or D), not in this one.

### 1.4 The app's own removal

The app has **Installation → Remove Omarchy…** (`OmarchyRemoval*.swift`). It finds the partitions
between macOS and Recovery and accepts exactly one stub followed by an ESP (≤ 1 GiB) and up to two
Linux partitions. It then checks files on that installation (the ESP's `m1n1/boot.bin`, the
installer log, the stub's boot object). It sets macOS as the startup disk, deletes the stub
container first, then erases the other partitions (`diskutil eraseVolume free none`), then grows
macOS (`diskutil apfs resizeContainer <macOS> 0`).

- **Today it refuses:** there are two stubs (p3 and p7) and too many partitions in the middle.
- **Danger after the cleanup:** the middle becomes p7, p8, p9: one stub, one ESP of 500 MB, one
  Linux partition. That passes the shape check, so the lifeline is what the menu would offer to
  remove. The file checks may still stop it, but don't find out. **Never open Remove Omarchy… or
  Return Space during or after this procedure.**
- It would also hand all the space back to macOS, which we don't want (1.2).

The manual removal below copies the engine's order and commands (`remove_existing_install` in
`omarchy_asahi.py`, `removeAndReturnSpace` in `OmarchyRemoval.swift`). It skips the
give-space-to-macOS step and keeps the old stub as the startup disk.

## 2. What exists today (read from Linux, 2026-11-15)

Logical block size 4096. Offsets and sizes are in bytes. The UUID column is the GPT partition
UUID, which macOS calls `DiskUUID` / "Disk / Partition UUID".

| p | Partition UUID | Offset | Size | What | Action |
| --- | --- | --- | --- | --- | --- |
| 1 | `81747D73-70F5-420F-92CB-5EEFAD5C0AF7` | | 576716800 | iBoot system container | keep |
| 2 | `6C240721-970B-4C09-A6DA-D0DC00EE56B7` | | 730603716608 | macOS APFS container | keep |
| 3 | `C3DB82BD-EF75-4060-911E-5C879C69AF51` | 731180457984 | 5999951872 | logo stub, APFS volume group `44EF390C-16A3-4083-9AB8-5A72E15CAE3A` | **delete** |
| 4 | `7196BCF0-8994-476A-A9EF-74D2847707F3` | 737180409856 | 524288000 | logo ESP, FAT `4F4D-5801`, "EFI - OMARC" | **delete** |
| 5 | `3FABFCD9-7651-44CA-8793-D1F255F808AE` | 737704697856 | 2147483648 | logo /boot, ext4 | **delete** |
| 6 | `AC4D63E2-5DFA-4DD8-B5B2-40D593CD12D4` | 739852181504 | 128767229952 | logo root, LUKS | **delete** |
| 7 | `32FB5A05-A8DB-4D56-BB12-27F8C48E2EF1` | 868619411456 | 5999996928 | old stub, group `A0D16C93-…` | keep (lifeline) |
| 8 | `C3D4EBAC-31D4-47B2-BE5B-11D16E2F8715` | 874619408384 | 499998720 | dev ESP, FAT `85DC-1706`, "OMARCHY", `m5local/` | keep (lifeline) |
| 9 | `0079041F-0A05-48C7-9554-04E1B95AEC99` | 875119407104 | 64425558016 | dev root, ext4 "omarchy" | keep (lifeline) |
| 10 | `595620DE-32DA-430B-8B2E-E1E0076BF045` | 939545067520 | 524288000 | old upstream ESP, FAT `4F4D-5801` (duplicate) | **delete** |
| 11 | `78842E13-D931-4764-A3FF-76DA0092F626` | 940069355520 | 2147483648 | old upstream /boot (duplicate ext4 ID) | **delete** |
| 12 | `9A1E651C-EBBF-4D9E-BED3-1D8E4EA01982` | 942216839168 | 52969865216 | old upstream root, LUKS | **delete** |
| 13 | `DFA55EC6-BDB6-4A33-9D30-EDA397E9C556` | 995186896896 | 5368664064 | Recovery | keep |

The dev Linux finds its root by PARTUUID (`m5-root-select` in its initrd) and its ESP by PARTUUID
in the loader, so renumbering doesn't break the lifeline. It already survived p5→p9 and p4→p8
when release 1 was installed.

## 3. Before you start

- [ ] Release 6 is published: app prerelease `omarchy-j714s-6`, image release
      `j714s-developer-image-omarchy-j714s-6`, `SHA256SUMS`. Fill in the real file names in step 7.
- [ ] Charger connected. The owner knows the macOS administrator password. FileVault means the owner
      unlocks macOS at the Mac.
- [ ] The PC's catcher is running: `tmux ls` shows `m5catch`, and the end of
      `~/m5/tools/logs/catch-loop.log` shows a recent "upstream boot up".
- [ ] Backups in section 4 are done and readable.
- [ ] The G9 test is batched into one trip (the monitor is in another room).

## 4. Backups (agent, from the logo Omarchy while it runs; read-only on the Mac)

Everything goes to the PC under `~/m5/backup/logo-install-2026-11-15/`. It contains the Wi-Fi
password and Bluetooth keys, so it never goes to GitHub.

```sh
B=~/m5/backup/logo-install-2026-11-15; mkdir -p "$B"
H=tripleu@10.168.168.116
K="-o UserKnownHostsFile=$HOME/m5/known_hosts-j714s"   # separate file; the host key changes with every install
read -rs PW                                            # the Mac's Linux sudo password; not stored

# Partition table: text (restorable with sfdisk) and the raw primary GPT (LBA 0-5)
ssh $K $H 'lsblk -b -o NAME,SIZE,FSTYPE,LABEL,UUID,PARTUUID,PARTLABEL,PARTTYPENAME /dev/nvme0n1' > "$B/lsblk.txt"
ssh $K $H 'sudo -S -p "" sfdisk -d /dev/nvme0n1' <<<"$PW" > "$B/gpt.sfdisk"
ssh $K $H 'sudo -S -p "" dd if=/dev/nvme0n1 bs=4096 count=6 status=none' <<<"$PW" > "$B/gpt-primary.bin"

# iBoot system container (holds every stub's boot policy) and the dev ESP (the lifeline's loader files)
ssh $K $H 'sudo -S -p "" dd if=/dev/disk/by-partuuid/81747d73-70f5-420f-92cb-5eefad5c0af7 bs=4M status=none' <<<"$PW" | zstd -T0 > "$B/p1-iboot-system-container.img.zst"
ssh $K $H 'sudo -S -p "" dd if=/dev/disk/by-partuuid/c3d4ebac-31d4-47b2-be5b-11d16e2f8715 bs=4M status=none' <<<"$PW" | zstd -T0 > "$B/p8-dev-esp.img.zst"

# Logo install: /boot and its ESP, the camera setfiles and light-sensor calibration (not owned by
# any package; the installer copied them from macOS), Wi-Fi, Bluetooth pairings, test files,
# Hyprland config incl. the G9 line, g9-test.sh
ssh $K $H 'sudo -S -p "" tar -C / -cpf - boot etc/fstab etc/modprobe.d var/lib/iwd var/lib/bluetooth var/lib/m5test usr/lib/firmware/apple home/tripleu/.config home/tripleu/g9-test.sh home/tripleu/g9-test.log' <<<"$PW" | zstd > "$B/logo-files.tar.zst"
unset PW

# Check
zstd -t "$B"/*.zst
zstd -dc "$B/p1-iboot-system-container.img.zst" | wc -c   # 576716800
zstd -dc "$B/p8-dev-esp.img.zst" | wc -c                  # 499998720
tar -tf "$B/logo-files.tar.zst" | grep -E 'monitors.lua|g9-test.sh|aop-als-cal.bin|vendorfw/manifest.txt'
grep -c nvme0n1p "$B/gpt.sfdisk"     # 13
```

Notes:
- The G9 line in `~/.config/hypr/monitors.lua` is
  `hl.monitor({ output = "HDMI-A-1", mode = "5120x1440@143.99", position = "auto", scale = 1 })`.
- The kernel packages in `~` (v272-7, v272-8, v272-11) are also in the releases. They are not
  needed.
- The camera setfiles, ALS calibration and `vendorfw/` come from macOS. The new installer collects
  them again; the backup is for comparison (section 9).
- Touch ID is enrolled on the dev Linux (p9, kept), not on the logo install (no `/var/lib/fprint`
  there).
- Nothing on macOS is changed except the partitions in section 2. A Time Machine backup of macOS
  is still the owner's call, as for any repartition.
- The dev root p9 is not touched. Older full backups are on ush (`~/m5-backup`).

## 5. Prove the lifeline and the default startup disk (recommended)

From the logo Omarchy: `sudo systemctl reboot`. A reboot goes to the default startup disk. That
should be the old stub, so the catcher boots the dev Linux within about 2 minutes. Check over SSH
that `uname -r` is the dev kernel, not `7.3.0-17.v272-11-ARCH`.

On 2026-11-15 the catcher had its fallback flag set: its last upstream boot "was not up" because
it checks `root@` SSH, which the logo install refuses. So the next catch boots the old daily
kernel (`loader-daily-dcp-bm.bin`, 7.3.0-j714s-sleep). That is still the dev Linux. The catcher
goes back to the upstream daily kernel on the catch after.

This proves the lifeline works today and that the old stub is the default. If the logo Omarchy
comes back instead, the default is the logo stub: fix that from macOS (6.4) before deleting
anything.

## 6. Remove p3–p6 and p10–p12 from macOS

The owner holds the power button at startup, picks **macOS** and unlocks it. Run the commands in
Terminal on the Mac, or let the agent run them over `ssh -t macbook` (Tailscale; needs the owner
logged in).

### 6.1 The script

Save this as `~/fresh-cleanup.sh` on the Mac. It is written for macOS's `/bin/bash` 3.2, `diskutil`
and `plutil`. It uses the same plist keys as the app (`DiskUUID`, `PartitionMapPartitionOffset`,
`Size`, `Content`, `VolumeName`, `APFSVolumeGroupID`).

How it works:
- It finds each partition by UUID, then checks offset and size before using the `disk0sN` name.
  This is the same identity check the app makes; slice numbers can shift after each deletion.
- Without `--delete` it changes nothing.
- With `--delete` it asks for `yes` before each deletion.

```bash
#!/bin/bash
# fresh-cleanup.sh: remove the logo Omarchy (p3-p6) and the broken upstream install (p10-p12).
#   bash ~/fresh-cleanup.sh            dry run, changes nothing (asks for sudo to read the startup disk)
#   bash ~/fresh-cleanup.sh --delete   deletes, asking "yes" before each step; all 7 targets must be present
#   bash ~/fresh-cleanup.sh --resume   same, but allows targets that an earlier --delete already removed
set -u
DISK=disk0
LOGO_VG=44EF390C-16A3-4083-9AB8-5A72E15CAE3A
OLD_VG_PREFIX=A0D16C93
STUB="C3DB82BD-EF75-4060-911E-5C879C69AF51 731180457984 5999951872 logo-stub"
# Erased in this order (root, boot, ESP), like the engine.
PARTS="AC4D63E2-5DFA-4DD8-B5B2-40D593CD12D4 739852181504 128767229952 logo-root
3FABFCD9-7651-44CA-8793-D1F255F808AE 737704697856 2147483648 logo-boot
7196BCF0-8994-476A-A9EF-74D2847707F3 737180409856 524288000 logo-esp
9A1E651C-EBBF-4D9E-BED3-1D8E4EA01982 942216839168 52969865216 old-root
78842E13-D931-4764-A3FF-76DA0092F626 940069355520 2147483648 old-boot
595620DE-32DA-430B-8B2E-E1E0076BF045 939545067520 524288000 old-esp"
KEEP="81747D73-70F5-420F-92CB-5EEFAD5C0AF7 iboot-system-container
6C240721-970B-4C09-A6DA-D0DC00EE56B7 macos
32FB5A05-A8DB-4D56-BB12-27F8C48E2EF1 old-stub-LIFELINE
C3D4EBAC-31D4-47B2-BE5B-11D16E2F8715 dev-esp-LIFELINE
0079041F-0A05-48C7-9554-04E1B95AEC99 dev-root-LIFELINE
DFA55EC6-BDB6-4A33-9D30-EDA397E9C556 recovery"

T=$(mktemp -d)
pl()   { plutil -extract "$2" raw -o - "$1" 2>/dev/null; }
info() { diskutil info -plist "$1" > "$T/i.plist" 2>/dev/null && pl "$T/i.plist" "$2"; }
slices() {
  diskutil list -plist $DISK > "$T/l.plist" || return
  local i=0 id
  while id=$(pl "$T/l.plist" "AllDisksAndPartitions.0.Partitions.$i.DeviceIdentifier"); do
    echo "$id"; i=$((i+1)); done
}
by_uuid() {   # partition UUID -> disk0sN; empty if absent; DUP if more than one
  local s r= n=0
  for s in $(slices); do [ "$(info "$s" DiskUUID)" = "$1" ] && { r=$s; n=$((n+1)); }; done
  [ $n -le 1 ] && echo "$r" || echo DUP
}
container_of() {   # physical store disk0sN -> APFS container reference
  diskutil apfs list -plist > "$T/a.plist"; local i=0 ref
  while ref=$(pl "$T/a.plist" "Containers.$i.ContainerReference"); do
    [ "$(pl "$T/a.plist" "Containers.$i.PhysicalStores.0.DeviceIdentifier")" = "$1" ] && { echo "$ref"; return; }
    i=$((i+1)); done
}
groups_of() {   # volume group IDs of the volumes in container $1
  diskutil apfs list -plist > "$T/a.plist"; local i=0 ref j v
  while ref=$(pl "$T/a.plist" "Containers.$i.ContainerReference"); do
    if [ "$ref" = "$1" ]; then j=0
      while v=$(pl "$T/a.plist" "Containers.$i.Volumes.$j.DeviceIdentifier"); do
        info "$v" APFSVolumeGroupID; j=$((j+1)); done
    fi; i=$((i+1)); done
}
show() { printf '  %-9s %-14s offset %-13s size %-13s %-18s %s\n' "$1" "$2" \
  "$(info "$1" PartitionMapPartitionOffset)" "$(info "$1" Size)" "$(info "$1" Content)" "$(info "$1" VolumeName)"; }
same_place() { [ "$(info "$1" PartitionMapPartitionOffset)" = "$2" ] && [ "$(info "$1" Size)" = "$3" ]; }
confirm() { printf '%s\nType yes to go on: ' "$1"; read -r a </dev/tty; [ "$a" = yes ]; }
die() { echo "STOP: $*"; exit 1; }

check() {   # prints the plan; returns 1 if anything is off
  local bad=0 u off size name s c
  MISSING=0
  [ "$(info $DISK Content)" = GUID_partition_scheme ] && [ "$(info $DISK Internal)" = true ] || { echo "STOP: $DISK is not the internal GPT disk"; return 1; }
  echo "== Will DELETE"
  read -r u off size name <<<"$STUB"; s=$(by_uuid "$u")
  if [ -z "$s" ]; then echo "  $name: already gone"; MISSING=$((MISSING+1))
  elif [ "$s" = DUP ]; then echo "  $name: UUID found twice - STOP"; bad=1
  else
    show "$s" "$name"; same_place "$s" "$off" "$size" || { echo "    offset/size differ - STOP"; bad=1; }
    [ "$(info "$s" Content)" = Apple_APFS ] || { echo "    not Apple_APFS - STOP"; bad=1; }
    c=$(container_of "$s"); echo "    APFS container: ${c:-none}  groups: $(groups_of "$c" | sort -u | tr '\n' ' ')"
    groups_of "$c" | grep -qx "$LOGO_VG" || { echo "    volume group $LOGO_VG not in it - STOP"; bad=1; }
    groups_of "$c" | grep -q "^$OLD_VG_PREFIX" && { echo "    this is the OLD stub - STOP"; bad=1; }
  fi
  while read -r u off size name; do
    s=$(by_uuid "$u")
    if [ -z "$s" ]; then echo "  $name: already gone"; MISSING=$((MISSING+1))
    elif [ "$s" = DUP ]; then echo "  $name: UUID found twice - STOP"; bad=1
    else show "$s" "$name"; same_place "$s" "$off" "$size" || { echo "    offset/size differ - STOP"; bad=1; }; fi
  done <<<"$PARTS"
  echo "== Will KEEP"
  while read -r u name; do
    s=$(by_uuid "$u")
    case "$s" in ""|DUP) echo "  $name ($u): missing or duplicated - STOP"; bad=1;; *) show "$s" "$name";; esac
  done <<<"$KEEP"
  echo "== Startup disk"
  local b; b=$(sudo bless --getBoot 2>/dev/null)
  [ -n "$b" ] || { echo "  bless --getBoot printed nothing - STOP"; return 1; }
  echo "  $b  group $(info "$b" APFSVolumeGroupID)  name $(info "$b" VolumeName)"
  [ "$(info "$b" APFSVolumeGroupID)" = "$LOGO_VG" ] && { echo "  the startup disk is the logo stub - STOP (see 6.4)"; bad=1; }
  return $bad
}

diskutil list $DISK
check || die "the disk is not as expected; nothing was changed"
MODE=${1:-}
if [ "$MODE" != --delete ] && [ "$MODE" != --resume ]; then
  [ $MISSING -gt 0 ] && echo "NOTE: $MISSING target(s) are already gone. Use --resume only if an earlier --delete removed them."
  echo; echo "Dry run. Nothing was changed."; exit 0
fi
[ $MISSING -gt 0 ] && [ "$MODE" != --resume ] && die "$MISSING target(s) missing; refusing --delete (see --resume)"

# 1. The stub first: if diskutil refuses, the ESP and Linux partitions are still intact.
read -r u off size name <<<"$STUB"; s=$(by_uuid "$u")
if [ -n "$s" ]; then
  same_place "$s" "$off" "$size" || die "$name moved"
  c=$(container_of "$s"); groups_of "$c" | grep -qx "$LOGO_VG" || die "$name: wrong container"
  confirm "Delete APFS container $c (physical store $s, the logo Omarchy stub)?" || die "not confirmed"
  sudo diskutil apfs deleteContainer "$c" || die "deleteContainer failed"
  # Without a new name current macOS frees the store. Older macOS may leave an empty HFS partition.
  for x in $(slices); do
    if same_place "$x" "$off" "$size"; then
      case "$(info "$x" Content)" in
        Apple_HFS|Apple_HFSX) confirm "An empty $(info "$x" Content) partition $x was left where the stub was. Erase it to free space?" || die "not confirmed"
                              sudo diskutil eraseVolume free none "$x" || die "erase failed";;
        *) die "unexpected partition $x where the stub was";;
      esac
    fi
  done
fi
# 2. The ESP and Linux partitions, each found again by UUID right before it is erased.
while read -r u off size name; do
  s=$(by_uuid "$u"); [ -z "$s" ] && { echo "$name: already gone"; continue; }
  [ "$s" = DUP ] && die "$name found twice"
  same_place "$s" "$off" "$size" || die "$name moved"
  show "$s" "$name"
  confirm "Erase $s ($name) to free space?" || die "not confirmed"
  sudo diskutil eraseVolume free none "$s" || die "erase of $name failed"
done <<<"$PARTS"
echo; diskutil list $DISK; echo; check
```

### 6.2 Run it

1. **Dry run:** `bash ~/fresh-cleanup.sh`. Read every line:
   - DELETE lists 7 partitions. Each offset and size in bytes matches the table in section 2,
     and none says "already gone". The stub line shows group `44EF390C-…` only.
   - KEEP lists 6 partitions, three of them marked LIFELINE.
   - The startup disk's group is the old stub's (`A0D16C93-…`), not `44EF390C-…`.
   - It ends with "Dry run. Nothing was changed."
   - Any STOP line: stop and report it.
2. **Delete:** `bash ~/fresh-cleanup.sh --delete`. Type `yes` seven times (eight if an empty HFS
   partition is left behind). `sudo` asks for the macOS password.
3. **Verify** (the script prints this itself; run it again any time with no argument):
   - every DELETE line says "already gone";
   - every KEEP line is present;
   - `diskutil list disk0` shows, in order: ISC, macOS container, **(free space) ~137.4 GB**, old
     stub container ~6.0 GB, EFI "OMARCHY" 500 MB, Linux ~64.4 GB, **(free space) ~55.6 GB**,
     Recovery;
   - `diskutil apfs listVolumeGroups | grep -i 44EF390C` prints nothing.
4. **Don't open the installer yet.** Its check is part of owner step 3 in section 7, with the
   release 6 app.

Don't give the freed space back to macOS. With gap A gone, the app would install into the smaller
gap B (1.2).

If a command fails halfway, run the dry run again. It shows what is already gone and what is left.
Then run `--resume`: it skips what is gone. Plain `--delete` refuses when any target is missing, so
a UUID that doesn't match can't leave a stub behind while its partitions get erased.

### 6.3 Boot policy and the boot picker after the deletion

- **No `bputil` and no `bless` are needed.** Deleting the stub container removes it from the boot
  picker. The app's own removal does the same (deleteContainer, then erase). Its leftover policy
  entry in the iBoot system container is not used.
- **Don't use Startup Security Utility.**
- **Boot picker afterwards:** macOS, the disk-icon Omarchy, Options.
- **Default startup disk:** unchanged, still the old stub.

### 6.4 Setting the old stub as the startup disk (from macOS only)

Use this before the cleanup if the dry run says the startup disk is the logo stub, or after the
install, to make the dev path the default again. Neither Linux has an NVRAM device, so this works
only from macOS.

```bash
# List every System volume with its volume group; pick the one whose group starts with A0D16C93.
T=$(mktemp -d); diskutil apfs list -plist > "$T/a.plist"; i=0
while plutil -extract Containers.$i raw -o - "$T/a.plist" >/dev/null 2>&1; do
  j=0
  while v=$(plutil -extract Containers.$i.Volumes.$j.DeviceIdentifier raw -o - "$T/a.plist" 2>/dev/null); do
    if [ "$(plutil -extract Containers.$i.Volumes.$j.Roles.0 raw -o - "$T/a.plist" 2>/dev/null)" = System ]; then
      diskutil info -plist "$v" > "$T/i.plist"
      echo "$v  $(plutil -extract APFSVolumeGroupID raw -o - "$T/i.plist")  $(plutil -extract VolumeName raw -o - "$T/i.plist")"
    fi; j=$((j+1)); done; i=$((i+1)); done
# Then, with the old stub's System volume (diskNs1 from the list above):
sudo bless --device /dev/diskNs1 --setBoot     # macOS asks for the owner's credentials
bless --getBoot                                # check: that same volume
```

The stubs can all be called "Omarchy". Go by group, never by name or disk number.

### 6.5 Giving freed space back to macOS (not in this test)

Not part of this procedure (1.2). It is here for "give up" (section 10) or a later option C/D run.
macOS can only grow into free space directly after it. While p7–p9 stay, that means gap A only.
Gap B stays stranded behind the dev root.

```bash
# The macOS container's physical store, found by its partition UUID (p2)
for s in $(diskutil list -plist disk0 > /tmp/l.plist; i=0; while id=$(plutil -extract AllDisksAndPartitions.0.Partitions.$i.DeviceIdentifier raw -o - /tmp/l.plist 2>/dev/null); do echo $id; i=$((i+1)); done); do
  diskutil info -plist $s > /tmp/i.plist
  [ "$(plutil -extract DiskUUID raw -o - /tmp/i.plist)" = 6C240721-970B-4C09-A6DA-D0DC00EE56B7 ] && echo "macOS store: $s"
done
diskutil apfs resizeContainer <store> limits     # MaximumSize should be about 137.4 GB larger than now
sudo diskutil apfs resizeContainer <store> 0     # grow into all the free space after it
```

### 6.6 Check the lifeline again after the deletion

The partition table just changed. Before installing, prove the dev path still boots:
1. The agent makes sure the catcher runs (section 8).
2. Restart macOS. The default is still the old stub, so the catcher boots the dev Linux.
3. Over SSH: `uname -r` is the dev kernel, and `lsblk -o NAME,SIZE,PARTUUID /dev/nvme0n1` shows the
   the old stub, `c3d4ebac-…` and `0079041f-…`, then Recovery, and nothing else after macOS. macOS
   renumbered the GPT by offset when release 1 was installed, so expect p3, p4, p5 and Recovery p6
   now; the PARTUUIDs are what count.
4. This is the last point where the GPT backup can undo a wrong erase (`sfdisk` from here), because
   nothing new has been written to the freed space yet.
5. Then the owner holds the power button and picks macOS for section 7.

### 6.7 Installer leftovers from release 1 on macOS

Release 1's app ran on this Mac on 2026-11-13. Its helper and its records may still be there. List
them, change nothing:

```bash
ls -la "/Applications/Omarchy Installer.app" /Library/LaunchDaemons/org.omarchy.installer.helper.plist \
       /Library/PrivilegedHelperTools/ 2>&1 | grep -i -e omarchy -e 'No such'
sudo ls -la /var/db/org.omarchy.installer /var/db/org.omarchy.installer.aside 2>&1
defaults read "/Applications/Omarchy Installer.app/Contents/Info.plist" CFBundleVersion 2>&1
```

- Installing the release 6 package replaces the app in `/Applications`. The new app installs its own
  helper.
- `/var/db/org.omarchy.installer` holds the helper's install journals and any removal records. The
  app refuses to install while an unfinished removal record exists. Release 1's install finished,
  so its journal should not block. That is not proven.
- If the release 6 app reports a helper problem or an old record, stop and send the agent the
  message. Release 5's page removes the helper with
  `sudo launchctl bootout system/org.omarchy.installer.helper` and then deleting its plist. Do that
  only after the agent has saved a copy of `/var/db/org.omarchy.installer`.

## 7. Install release 6 (the owner's steps)

Before step 5 the agent stops the catcher (section 8). Fill in the real release 6 file names.

1. **Download.** From the `omarchy-j714s-6` release, get the online package
   `Omarchy-Installer-J714s-online-<version>.pkg` and `SHA256SUMS`. In Terminal:
   `cd ~/Downloads && grep ' Omarchy-Installer-J714s-online-<version>.pkg$' SHA256SUMS | shasum -a 256 -c`.
   It must print `OK`.
2. **Install the package.** Double-click it. If macOS blocks it: System Settings → Privacy &
   Security → **Open Anyway**, then open it again.
3. **Run Omarchy Installer.** It checks the Mac, then shows the plan.
   - First check it is release 6's app: Omarchy Installer → About shows the build number from the
     release page (or run
     `defaults read "/Applications/Omarchy Installer.app/Contents/Info.plist" CFBundleVersion`).
   - It must not say "Omarchy is already installed". If it does, stop and tell the agent. This
     check comes before any download or disk change.
   - The plan should use the free space (about 137 GB) and not shrink macOS. If it wants to shrink
     macOS, stop and tell the agent. Take the largest size it offers.
   - Tick the backup box, click **Install**, and type your macOS name and password.
   - Keep the Mac awake and on the charger. It downloads the image and Apple's 27.2 firmware, then
     writes the disk. Expect roughly 20 to 40 minutes.
4. **When it says the first stage is done:** shut down from the Apple menu. Wait 15 seconds.
5. **Finish setup in Recovery.**
   - Press and **hold** the power button until "Loading startup options" appears.
   - Pick the **Omarchy with the LOGO icon**, not the plain disk icon. Click Continue and sign in
     with your macOS account.
   - Omarchy's own **Finish setup** window opens. Click **Install**.
   - Wait. It can take **up to 30 minutes** with nothing moving. Don't power off.
   - Don't open Startup Security Utility.
   - When it says **Installation complete!**, click **Restart**.
6. **First boot.**
   - You see the Omarchy logo, then a pause of about 15 seconds (normal, every boot), then text.
   - It asks for a **disk password**. You choose it now. There is no recovery key: write it down.
   - Then Omarchy asks for your name and password.
   - Connect to Wi-Fi when it asks.
7. **Let the agent in.** Open a terminal (Super+Enter) and type:
   ```sh
   sudo systemctl enable --now sshd
   sudo ufw allow 22/tcp
   ip -4 addr show wlan0 | grep inet
   ```
   If the first line says the unit is not found, run `sudo pacman -S openssh` first. Tell the agent
   the address it shows.
8. **From now on** this new Omarchy starts by itself when you restart: the installer made it the
   startup disk. To reach macOS, hold the power button at startup and pick macOS.

**If it loops** (logo, then off, again and again, or stuck on the logo for more than 5 minutes):
1. Hold the power button about 10 seconds until the Mac is off.
2. **Tell the agent first and wait for "go".** The agent restarts the catcher.
3. Press and hold the power button until "Loading startup options" appears. Pick the **plain disk
   icon Omarchy**.
4. Nothing else to do. The PC boots the dev Linux on the Mac in about 2 minutes, and the agent
   works from there.

macOS is always one boot-picker choice away. The installer does not change macOS's own security
setting.

## 8. The catcher during the install (agent)

The logo stub was enrolled by release 1 with a Stage 1 USB proxy window of 0. Release 2's engine
and later (patches-j714s 0008) enrol a **15 s window** ("every boot pauses about 15 seconds"). That
window is new on this Mac.

`bmboot.sh` takes the first `/dev/m1n1` that appears. If Aura's window enumerates on the PC cable,
the running catcher would grab the new install's first boot and chainload the dev Linux into it.
Aura's proxy was not reachable on the cable after a chainload (2026-11-12), but Aura as Stage 1
from iBoot has not been tried.

So:
- **Before the owner clicks Restart in Finish setup** (owner step 5), stop the catcher. Watch the
  cable passively instead:
  `m5catch` was started with the script as the session's command, with no shell under it. So stop
  it by killing the session, then check that nothing else waits on `/dev/m1n1`. Other agents' test
  loops do too.
  ```sh
  tmux kill-session -t m5catch
  pkill -f 'catch-loop|bmboot|chainload.py|test-once'
  pgrep -af 'catch-loop|bmboot|chainload|test-once'       # must print nothing
  tmux new -d -s m5watch 'while :; do if [ -e /dev/m1n1 ]; then date; lsusb -d 1209:316d; sleep 20; fi; sleep 0.2; done >> ~/m5/tools/logs/aura-window.log 2>&1'
  ```
  `aura-window.log` then answers the open question: does the new install's 15 s window appear on
  the cable?
- **If the install loops**, or whenever the owner is about to pick the disk-icon Omarchy, start the
  catcher again first, then say "go":
  ```sh
  tmux kill-session -t m5watch 2>/dev/null
  tmux has-session -t m5catch 2>/dev/null || tmux new-session -d -s m5catch 'cd ~/m5/tools && ./catch-loop-up.sh'
  pgrep -af catch-loop-up                                  # must show the loop
  ```
- **After the install the default startup disk is the new install** (the app runs
  `bless --setBoot` with the new stub, in macOS and again in Recovery). A Linux reboot of the new
  install comes back to the new install. The catcher is only needed for the boot picker's
  disk-icon choice.
- Also, once the new install is the default, any `reboot` or watchdog reset on the dev path
  (including `test-once-wdt.sh` and `bmboot-wdt.sh` fallbacks) lands in the new install, not back
  in the catcher. Hands-free RAM tests need the old stub as the default again (6.4).
- If the watcher shows the window does reach the cable, the catcher must learn to tell the old stub
  from Aura before it runs during new-install boots.

## 9. After first boot: agent checklist over SSH

```sh
H=tripleu@<address>; K="-o UserKnownHostsFile=$HOME/m5/known_hosts-j714s"
ssh-keygen -f ~/m5/known_hosts-j714s -R 10.168.168.116 2>/dev/null   # new host key
ssh-copy-id $K $H                                                    # the owner's new password, once
```

| Check | Command | Expect |
| --- | --- | --- |
| Kernel | `uname -r` | `7.3.0-17.v272-11-ARCH` (or what release 6 ships) |
| Clean boot | `systemd-analyze; systemctl --failed; journalctl -b -p err --no-pager \| head -50` | no failed units; boot ~25–40 s |
| Own partitions | `cat /proc/device-tree/chosen/asahi,efi-system-partition; findmnt -no SOURCE,TARGET /boot /boot/efi; lsblk -o NAME,UUID,PARTUUID /dev/nvme0n1` | `/boot/efi` is the partition whose PARTUUID the device tree names (the new ESP); `/boot` is the ext4 partition right after it; both are in the new install (expected p4/p5), not p8 |
| No duplicate IDs | `lsblk -no UUID /dev/nvme0n1 \| grep . \| sort \| uniq -d` | prints nothing |
| Layout | `lsblk -b -o NAME,SIZE,FSTYPE,PARTUUID /dev/nvme0n1` | new stub/ESP/boot/root in gap A; p7–p9 unchanged PARTUUIDs; ~55.6 GB free before Recovery |
| AOP and sound | `lsmod \| grep -w aop; cat /proc/asound/cards` | `aop` loaded; `AppleJ714`, `AppleJ714HPAI` |
| Speakers | `systemctl is-active speakerguardd-v2; sudo aurora-speaker-upgrade status; speakerguardd-gate explain` | active, v2 owns the speakers. This is a fresh run of v2's checks on this Mac. Loud playback waits for the low-level test in the recipe README |
| Speaker sense | pause all audio, then `scripts/speaker-sense-test.sh` from this repo (about 45 s, a faint 2.5 kHz tone and two short stutters; it asks first) | `RESULT: shift 0 everywhere`, every fault status 0. Any other shift means speakerguardd v2 is reading another amplifier's voltage and current (kernels before v272-26) |
| Firewall | `systemctl is-active ufw; sudo ufw status` | active; 22/tcp allowed |
| ANE, camera | `ls -l /dev/accel/accel0 /dev/video0` | both present |
| Camera setfiles, ALS | `ls -l /usr/lib/firmware/apple/aop-als-cal.bin /usr/lib/firmware/apple/isp_*.dat; sha256sum` and compare with `usr/lib/firmware/apple/` in the backup; `sudo ls /boot/efi/vendorfw` | files present and the same as the logo install's. Release 5 marks the installer's collection of these as untested, so this is a real check |
| Wi-Fi | `iwctl station wlan0 show` | connected |
| Bluetooth | `bluetoothctl show \| grep Powered; lsmod \| grep -E '^(rfcomm\|pkcs8_key_parser)'` | Powered: yes; both modules loaded |
| uclamp | `sysctl kernel.sched_util_clamp_min_rt_default` | 0 |
| Fans | `h=$(dirname $(grep -l macsmc_hwmon /sys/class/hwmon/*/name)); echo 3000 \| sudo tee $h/fan1_target; sleep 8; cat $h/fan1_input; echo 0 \| sudo tee $h/fan1_target` | about 3000 rpm, then back to firmware control |
| Fast-die | `ls /sys/firmware/devicetree/base/soc@200000000/performance-controller@*/apple,fast-die-effort` | three files (clusters 210e, 211e, 212e) |
| Boot files | `sudo sha256sum /boot/efi/m1n1/boot-ctxr.bin; stat -c %s /boot/efi/m1n1/boot-ctxr.bin` | matches the image release's record; under 11 MB |
| Logs for the issue | `journalctl -b --no-pager > first-boot-journal.txt; sudo dmesg > first-boot-dmesg.txt`, then copy to the PC | saved under `~/m5/work/fresh-6/` |

Don't install other kernels or packages by hand during this test. The point is to test the image as
shipped.

### 9.1 External display (one trip to the G9)

The session must be awake: a locked session with its displays off looks exactly like a dead
output (2026-11-14). Copy `g9-test.sh` from the backup to the new install, and make it wake the
session before every mode switch:

```sh
tar -xOf ~/m5/backup/logo-install-2026-11-15/logo-files.tar.zst home/tripleu/g9-test.sh | ssh $K $H 'cat > ~/g9-test.sh; chmod +x ~/g9-test.sh'
ssh $K $H 'sed -i "s|^try() { # output mode\$|&\n  omarchy-system-wake >/dev/null 2>\&1|" ~/g9-test.sh'
ssh $K $H 'export OMARCHY_PATH=$HOME/.local/share/omarchy PATH=$HOME/.local/share/omarchy/bin:$PATH
  export XDG_RUNTIME_DIR=/run/user/$(id -u) HYPRLAND_INSTANCE_SIGNATURE=$(ls -t /run/user/$(id -u)/hypr | head -1)
  omarchy-system-wake; hyprctl monitors all | grep -E "^Monitor|availableModes"'
```

Then, with the owner at the G9:
1. HDMI first. Run
   `ssh $K $H 'export OMARCHY_PATH=$HOME/.local/share/omarchy PATH=$HOME/.local/share/omarchy/bin:$PATH; ~/g9-test.sh 10'`.
   The owner notes which numbered TEST screens show a picture. The log is `~/g9-test.log`.
2. Then USB-C DisplayPort on the **left non-DFU port**. Replug it if it isn't detected. Run the
   same command again.

If the owner wants it, put the G9 line from 4 back into `~/.config/hypr/monitors.lua`.

## 10. Rollback

- **After the deletion there is no way back to the logo Omarchy.** Its stub, its boot policy and
  its root are gone. The way back is reinstalling (release 5 or 6). The GPT backup in section 4 is
  for undoing a wrong erase (`sfdisk` from the dev Linux, before anything new is written there),
  not for restoring the logo install.
- **The app fails before Recovery:** read its log, then rerun it. If it left partitions behind,
  remove them with a copy of the script holding their UUIDs (from `diskutil list` and
  `diskutil info`). Don't use the app's Remove Omarchy… (1.4).
- **The install loops after Finish setup:** the "If it loops" steps (section 7), then from the dev
  Linux read and fix the new ESP. This is the release 1 method: check `m1n1/boot-ctxr.bin` and the
  Stage 1 config. See [install-failure-2026-11-13.md](install-failure-2026-11-13.md). Fix it in
  RAM or on the new ESP only. Never write to p8 or p9: on 2026-11-11 a test file on the dev ESP
  cost the dev Linux its Wi-Fi and the owner several power cycles.
- **Give up on release 6:** boot macOS, delete the new install's four partitions the same way
  (new UUIDs), and install release 5. To hand gap A back to macOS instead, see 6.5.
- **macOS** is never modified apart from losing the partitions listed here. The owner can always
  pick it in the boot picker.

## 11. Never

- Never open **Remove Omarchy…** or **Return Space** in the app (1.4).
- Never use Startup Security Utility.
- Never run `diskutil` on a disk number taken from notes or from an earlier boot. Find it by UUID
  first, every time.
- Never touch p7, p8 or p9, the catcher's loaders or `m5local/` on p8.
- Never give the freed space to macOS during this test (1.2).
- Never enrol Touch ID on the new install until the shared-store question below is settled.

## 12. Open questions

1. Does the new install's 15 s Aura Stage 1 window appear on the PC cable (section 8)? The watcher
   log answers it. If it does, the catcher must tell the stubs apart before it can stay on during
   new-install boots.
2. Release 6 specifics: file names, kernel (v272-11 assumed), and whether the engine and Recovery
   app (and so the 15 s window and `--compress`) are unchanged from release 5.
3. On this macOS version, does `apfs deleteContainer` free the stub partition, or leave an empty
   HFS partition? The script handles both.
4. Touch ID: the enrolment from the dev Linux lives in the Secure Enclave store that macOS shares.
   Is a second enrolment from the new install safe? Read the aurora-sep recipe README before
   anyone enrols there.
5. The macOS shrink path stays untested by this run (1.3). Should a later run do option C or D?
6. Gap B (55.6 GB) stays free. Leave it, or use it later for a second test install?
7. Does release 1's finished journal in `/var/db/org.omarchy.installer`, or its old helper, get in
   the way of the release 6 app (6.7)?
8. After the test, should the old stub be the default again (6.4) for hands-free dev work, or should
   the new install stay the default as for a normal user?
