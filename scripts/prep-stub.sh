#!/bin/bash
# SPDX-License-Identifier: MIT
#
# prep-stub.sh — create the "stub macOS" APFS container that carries the
# Omarchy boot policy on this M5 Pro (J714s), populated entirely from
# on-disk assets (no IPSW download).
#
# What it does:
#   1. Shrinks the macOS APFS container (disk0s2) to make room.
#   2. Creates a 6 GB APFS container "Omarchy" with the volume group
#      shape iBoot expects: Data + System (grouped) + Preboot + Recovery.
#   3. Populates it by cloning this macOS install's restore bundle,
#      recoveryOS image (arm64eBaseSystem.dmg), and admin credentials
#      (AdminUserRecoveryInfo.plist) — the same files asahi-installer's
#      stub.py extracts from an IPSW.
#   4. Optionally creates the EFI system partition for m1n1/U-Boot.
#
# What it does NOT do (you do these next, see docs/bringup.md):
#   - bless the stub / set default boot
#   - the paired-1TR ceremony: bputil -nc + kmutil configure-boot
#
# Usage: sudo scripts/prep-stub.sh [--linux-size 200G] [--yes]
#   --linux-size N   also carve an N-sized raw partition for the Linux
#                    rootfs (default: skip; add later with addPartition)
#   --yes            skip the confirmation prompt
#
# Safety: never touches the iSC or the Apple_APFS_Recovery container. They
# are told apart by partition type, not by disk0sN: macOS renumbers
# partitions by disk position, so once the stub exists it can be disk0s3
# and the Recovery container disk0s6.
# Rollback / resize: docs/bringup.md "Resizing or re-installing".

set -euo pipefail

MACOS_PART=disk0s2          # the big APFS container partition
STUB_NAME="Omarchy"
STUB_SIZE="6G"   # M5 boot objects (~400M) + recoveryOS (~1.5G) exceed 2.5G
EFI_SIZE="500M"
LINUX_SIZE=""
ASSUME_YES=0

while [ $# -gt 0 ]; do
    case "$1" in
        --linux-size) LINUX_SIZE="$2"; shift 2 ;;
        --yes|-y)     ASSUME_YES=1; shift ;;
        *) echo "unknown arg: $1" >&2; exit 2 ;;
    esac
done

die() { echo "ERROR: $*" >&2; exit 1; }
step() { echo; echo "==> $*"; }

[ "$(id -u)" = 0 ] || die "run with sudo"

# --- sanity checks -------------------------------------------------------

diskutil info "$MACOS_PART" >/dev/null 2>&1 || die "$MACOS_PART not found"
diskutil info "$MACOS_PART" | grep -q "Apple_APFS" \
    || die "$MACOS_PART is not an APFS container partition"

MACOS_SYS=$(diskutil apfs list -plist | python3 -c "
import plistlib,sys
d=plistlib.loads(sys.stdin.buffer.read())
for c in d['Containers']:
    stores=[p['DeviceIdentifier'] for p in c.get('PhysicalStores',[])]
    if 'disk0s2' not in stores: continue
    for v in c.get('Volumes',[]):
        if 'System' in v.get('Roles',[]): print(v['DeviceIdentifier'])
")
MACOS_VGID=$(diskutil info "$MACOS_SYS" 2>/dev/null | awk -F': *' '/APFS Volume Group/{print $2}')
[ -n "$MACOS_VGID" ] || die "could not determine macOS volume group ID"
PB=/System/Volumes/Preboot/$MACOS_VGID
[ -d "$PB/restore" ] || die "macOS restore bundle not found at $PB/restore"

REC_MNT=$(mktemp -d /tmp/recovery-mnt.XXXXXX)
# find the Recovery-role volume inside the macOS container (disk3),
# NOT the iSC (disk1) or Apple_APFS_Recovery (disk2) containers
REC_DEV=$(diskutil apfs list -plist 2>/dev/null | python3 -c "
import plistlib,sys
d=plistlib.loads(sys.stdin.buffer.read())
for c in d['Containers']:
    stores=[p['DeviceIdentifier'] for p in c.get('PhysicalStores',[])]
    if 'disk0s2' not in stores: continue
    for v in c.get('Volumes',[]):
        if 'Recovery' in v.get('Roles',[]):
            print(v['DeviceIdentifier']); sys.exit(0)
" 2>/dev/null || true)
[ -n "$REC_DEV" ] || die "could not find macOS Recovery volume"
# mount it; if it's already mounted somewhere, use that mount point
if ! diskutil mount -mountPoint "$REC_MNT" "$REC_DEV" >/dev/null 2>&1; then
    EXISTING=$(diskutil info "$REC_DEV" | awk -F': *' '/Mount Point/{print $2}')
    [ -n "$EXISTING" ] && [ "$EXISTING" != "Not mounted" ] \
        && REC_MNT="$EXISTING" \
        || die "could not mount $REC_DEV"
fi
trap 'diskutil unmount "$REC_DEV" >/dev/null 2>&1 || true' EXIT
[ -f "$REC_MNT/$MACOS_VGID/usr/standalone/firmware/arm64eBaseSystem.dmg" ] \
    || die "arm64eBaseSystem.dmg not found in Recovery volume ($REC_MNT)"

FREE_GB=$(diskutil info "$MACOS_PART" | awk '/Container Free Space/{print $(NF-1)}')
echo "macOS container free space: ${FREE_GB} GB"

# --- plan ----------------------------------------------------------------

# How much do we still need to shrink macOS by? Only the shortfall —
# free GPT space already sitting after disk0s2 counts toward the goal.
read -r NEW_SIZE NEED_GB <<<"$(python3 - "$LINUX_SIZE" "$STUB_SIZE" <<'EOF'
import sys, subprocess, re, plistlib

def gib(s):
    m = re.match(r'(\d+(?:\.\d+)?)([GgMm])', s)
    mult = 1024**3 if m.group(2).lower() == 'g' else 1024**2
    return int(float(m.group(1)) * mult)

info = subprocess.run(["diskutil","info","-plist","disk0s2"],
                      capture_output=True).stdout
d = plistlib.loads(info)
total = d["TotalSize"]

# free GPT space on disk0 (bytes) — space already reclaimed outside
# any partition
listing = subprocess.run(["diskutil","list","-plist","disk0"],
                         capture_output=True).stdout
dl = plistlib.loads(listing)
free_gpt = 0
for p in dl.get("AllDisksAndPartitions",[]):
    if p.get("DeviceIdentifier") != "disk0": continue
    for part in p.get("Partitions",[]):
        if part.get("Content") == "Free Space" or part.get("Type") == "Free Space":
            free_gpt += part.get("Size",0)
# also catch the "(free space)" pseudo-entry format
for p in dl.get("AllDisksAndPartitions",[]):
    if p.get("DeviceIdentifier") != "disk0": continue
    for part in p.get("Partitions",[]):
        if "free" in str(part.get("Content","")).lower() or \
           "free" in str(part.get("Type","")).lower():
            free_gpt += part.get("Size",0)

need = gib(sys.argv[2]) + int(0.5*1024**3)   # stub + EFI
if sys.argv[1]:
    need += gib(sys.argv[1])

shortfall = need - free_gpt
if shortfall <= 0:
    print("0", need // 1024**3)   # no resize needed
else:
    newsize = total - shortfall
    print(f"{newsize // 1024**3}G", need // 1024**3)
EOF
)"

echo
echo "Plan:"
if [ "$NEW_SIZE" = "0" ]; then
    echo "  - no resize needed ($NEED_GB GB already free after $MACOS_PART)"
else
    echo "  - resize $MACOS_PART (macOS container) -> $NEW_SIZE"
fi
echo "  - addPartition $MACOS_PART apfs '$STUB_NAME' $STUB_SIZE"
echo "    + volumes: Data, System (grouped), Preboot, Recovery"
echo "  - addPartition <stub> %EFI% %noformat% $EFI_SIZE + newfs_msdos"
[ -n "$LINUX_SIZE" ] && echo "  - addPartition <efi> %Linux% %noformat% $LINUX_SIZE"
echo "  - clone restore bundle + recoveryOS + admin creds into stub"
echo
if [ "$ASSUME_YES" != 1 ]; then
    read -r -p "Proceed? [y/N] " ans
    [ "$ans" = y ] || [ "$ans" = Y ] || { echo "aborted"; exit 1; }
fi

# --- partition -----------------------------------------------------------

# find the stub container: an Apple_APFS partition on disk0 (so never the
# iSC or Apple_APFS_Recovery) other than macOS, holding a "$STUB_NAME*"
# volume. Re-runnable: if a previous run already created it, we pick it up
# and continue.
find_stub() {
    diskutil apfs list -plist | python3 -c "
import plistlib, subprocess, sys
name, macos = sys.argv[1], sys.argv[2]
disk0 = plistlib.loads(subprocess.run(['diskutil', 'list', '-plist', 'disk0'],
                                      capture_output=True).stdout)
ptype = {p['DeviceIdentifier']: p.get('Content', '')
         for d in disk0.get('AllDisksAndPartitions', [])
         for p in d.get('Partitions', [])}
d = plistlib.loads(sys.stdin.buffer.read())
for c in d['Containers']:
    for ps in c.get('PhysicalStores', []):
        dev = ps['DeviceIdentifier']
        if dev == macos or ptype.get(dev) != 'Apple_APFS':
            continue
        if any(v.get('Name', '').startswith(name) for v in c.get('Volumes', [])):
            print(c['ContainerReference']); sys.exit(0)
" "$STUB_NAME" "$MACOS_PART"
}

STUB_CT=$(find_stub || true)
if [ -z "$STUB_CT" ]; then
    if [ "$NEW_SIZE" != "0" ]; then
        step "Resizing macOS container to $NEW_SIZE"
        diskutil apfs resizeContainer "$MACOS_PART" "$NEW_SIZE"
    else
        echo "no resize needed — using existing free space"
    fi

    step "Creating stub APFS container ($STUB_SIZE)"
    diskutil addPartition "$MACOS_PART" apfs "$STUB_NAME" "$STUB_SIZE"
    STUB_CT=$(find_stub)
else
    echo "stub container already exists: $STUB_CT (resuming)"
fi
[ -n "$STUB_CT" ] || die "could not find new stub container"
STUB_PART=$(diskutil apfs list "$STUB_CT" -plist | python3 -c "
import plistlib,sys
d=plistlib.loads(sys.stdin.buffer.read())
print(d['Containers'][0]['PhysicalStores'][0]['DeviceIdentifier'])
")
echo "stub container: $STUB_CT (partition $STUB_PART)"

step "Creating stub volumes"
# addPartition leaves a default no-role volume; repurpose it as Data
# (same as stub.py) rather than adding a second one. addVolume can
# spuriously fail on the auto-mount step; verify after each call.
vol_with_role() {
    diskutil apfs list "$STUB_CT" -plist | python3 -c "
import plistlib,sys
d=plistlib.loads(sys.stdin.buffer.read())
role='$1'
for c in d['Containers']:
    for v in c.get('Volumes',[]):
        if role in v.get('Roles',[]): print(v['DeviceIdentifier'])
"
}
vol_no_role() {
    diskutil apfs list "$STUB_CT" -plist | python3 -c "
import plistlib,sys
d=plistlib.loads(sys.stdin.buffer.read())
for c in d['Containers']:
    for v in c.get('Volumes',[]):
        if not v.get('Roles'): print(v['DeviceIdentifier'])
"
}

DATA_VOL=$(vol_with_role Data)
if [ -z "$DATA_VOL" ]; then
    DEFAULT_VOL=$(vol_no_role)
    if [ -n "$DEFAULT_VOL" ]; then
        diskutil apfs changeVolumeRole "$DEFAULT_VOL" D
        diskutil rename "$DEFAULT_VOL" "$STUB_NAME - Data" 2>/dev/null || true
    else
        diskutil apfs addVolume "$STUB_CT" apfs "$STUB_NAME" -role D 2>/dev/null || true
    fi
    DATA_VOL=$(vol_with_role Data)
fi
[ -n "$DATA_VOL" ] || die "Data volume was not created"

[ -n "$(vol_with_role System)" ] || \
    diskutil apfs addVolume "$STUB_CT" apfs "$STUB_NAME" -role S -groupWith "$DATA_VOL" 2>/dev/null || true
[ -n "$(vol_with_role Preboot)" ] || \
    diskutil apfs addVolume "$STUB_CT" apfs Preboot -role B 2>/dev/null || true
[ -n "$(vol_with_role Recovery)" ] || \
    diskutil apfs addVolume "$STUB_CT" apfs Recovery -role R 2>/dev/null || true

# delete any leftover no-role volumes (e.g. a second default vol)
for v in $(vol_no_role); do
    echo "deleting stray volume $v"
    diskutil apfs deleteVolume "$v"
done

N_VOLS=$(diskutil apfs list "$STUB_CT" -plist | python3 -c "
import plistlib,sys
d=plistlib.loads(sys.stdin.buffer.read())
print(len(d['Containers'][0]['Volumes']))
")
[ "$N_VOLS" = 4 ] || die "expected 4 stub volumes, got $N_VOLS"
SYS_VOL=$(diskutil apfs list "$STUB_CT" -plist | python3 -c "
import plistlib,sys
d=plistlib.loads(sys.stdin.buffer.read())
for c in d['Containers']:
    for v in c.get('Volumes',[]):
        if 'System' in v.get('Roles',[]): print(v['DeviceIdentifier'])
")
VGID=$(diskutil info "$SYS_VOL" | awk -F': *' '/APFS Volume Group/{print $2}')
[ -n "$VGID" ] || die "could not determine stub VGID"
echo "stub VGID: $VGID"

EFI_PART=$(diskutil list disk0 | awk '$2=="EFI" || /Microsoft Basic/{print $NF}' | tail -1)
if [ -z "$EFI_PART" ]; then
    step "Creating EFI partition ($EFI_SIZE)"
    diskutil addPartition "$STUB_PART" '%EFI%' '%noformat%' "$EFI_SIZE"
    EFI_PART=$(diskutil list disk0 | awk '$2=="EFI" || /Microsoft Basic/{print $NF}' | tail -1)
    newfs_msdos -F 32 -v OMARCHY "/dev/r${EFI_PART}"
else
    echo "EFI partition already exists: $EFI_PART"
fi
echo "EFI partition: $EFI_PART"


if [ -n "$LINUX_SIZE" ]; then
    LINUX_PART=$(diskutil list disk0 | awk '/Linux|Linux filesystem/{print $NF}' | tail -1)
    if [ -z "$LINUX_PART" ]; then
        step "Creating Linux partition ($LINUX_SIZE)"
        diskutil addPartition "$EFI_PART" '%Linux%' '%noformat%' "$LINUX_SIZE"
    else
        echo "Linux partition already exists: $LINUX_PART"
    fi
fi

# --- populate ------------------------------------------------------------

step "Populating stub Preboot"
PB_MNT=$(diskutil info "$(diskutil apfs list "$STUB_CT" -plist | python3 -c "
import plistlib,sys
d=plistlib.loads(sys.stdin.buffer.read())
for c in d['Containers']:
    for v in c.get('Volumes',[]):
        if 'Preboot' in v.get('Roles',[]): print(v['DeviceIdentifier'])
")" | awk -F': *' '/Mount Point/{print $2}')
mkdir -p "$PB_MNT/$VGID"
cp -R "$PB/restore" "$PB_MNT/$VGID/restore"
mkdir -p "$PB_MNT/$VGID/var/db"
# may already exist + schg-locked from a previous run
chflags noschg "$PB_MNT/$VGID/var/db/AdminUserRecoveryInfo.plist" 2>/dev/null || true
cp "$PB/var/db/AdminUserRecoveryInfo.plist" "$PB_MNT/$VGID/var/db/"
chflags schg "$PB_MNT/$VGID/var/db/AdminUserRecoveryInfo.plist"

step "Populating stub Recovery"
# the macOS Recovery volume may have been unmounted by the partition
# operations above — (re)mount it now, right before we need it
if [ ! -f "$REC_MNT/$MACOS_VGID/usr/standalone/firmware/arm64eBaseSystem.dmg" ]; then
    diskutil mount -mountPoint "$REC_MNT" "$REC_DEV" >/dev/null 2>&1 || {
        EXISTING=$(diskutil info "$REC_DEV" | awk -F': *' '/Mount Point/{print $2}')
        [ -n "$EXISTING" ] && [ "$EXISTING" != "Not mounted" ] && REC_MNT="$EXISTING"
    }
fi
[ -f "$REC_MNT/$MACOS_VGID/usr/standalone/firmware/arm64eBaseSystem.dmg" ] \
    || die "arm64eBaseSystem.dmg not found in Recovery volume ($REC_MNT)"
REC2_MNT=$(diskutil info "$(diskutil apfs list "$STUB_CT" -plist | python3 -c "
import plistlib,sys
d=plistlib.loads(sys.stdin.buffer.read())
for c in d['Containers']:
    for v in c.get('Volumes',[]):
        if 'Recovery' in v.get('Roles',[]): print(v['DeviceIdentifier'])
")" | awk -F': *' '/Mount Point/{print $2}')
mkdir -p "$REC2_MNT/$VGID/usr/standalone/firmware"
cp "$REC_MNT/$MACOS_VGID/usr/standalone/firmware/arm64eBaseSystem.dmg" \
   "$REC2_MNT/$VGID/usr/standalone/firmware/"

step "Populating stub System volume"
SYS_MNT=$(diskutil info "$SYS_VOL" | awk -F': *' '/Mount Point/{print $2}')
mkdir -p "$SYS_MNT/System/Library/CoreServices"
cp /System/Library/CoreServices/SystemVersion.plist "$SYS_MNT/System/Library/CoreServices/"
cp /System/Library/CoreServices/PlatformSupport.plist "$SYS_MNT/System/Library/CoreServices/" 2>/dev/null || true
cp "$PB/restore/usr/standalone/bootcaches.plist" "$SYS_MNT/usr/standalone/bootcaches.plist" 2>/dev/null || {
    mkdir -p "$SYS_MNT/usr/standalone"
    cp "$PB/restore/usr/standalone/bootcaches.plist" "$SYS_MNT/usr/standalone/"
}
# mark it as a stub so it's obvious in the boot picker
plutil -replace ProductName -string "Omarchy Linux (stub)" \
    "$SYS_MNT/System/Library/CoreServices/SystemVersion.plist" 2>/dev/null || true

step "Done"
cat <<EOF

Stub created. VGID: $VGID

Next steps (docs/bringup.md):
  1. Stage-1 m1n1, CHAINLOADING=0:  CHAINLOADING=0 scripts/build-m1n1.sh
  2. Arm the stub (writes Finish Installation.app with m1n1 as boot.bin,
     blesses the stub, drops .IAPhysicalMedia):
       sudo scripts/finish-install.sh [--m1n1 PATH]
  3. Shut down. Power on HOLDING the power button until
     "Loading startup options" (1TR). Pick '$STUB_NAME'; its recoveryOS
     runs step2.sh (bputil -nc + kmutil configure-boot for VGID $VGID).
EOF
