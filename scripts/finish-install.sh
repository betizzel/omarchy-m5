#!/bin/bash
# SPDX-License-Identifier: MIT
#
# finish-install.sh — arm the stub created by prep-stub.sh so that picking
# "Omarchy" in the boot picker lands in *its* paired recoveryOS, running a
# "Finish Installation.app" that performs the 1TR ceremony for us.
#
# Why this is needed: a stub System volume that only carries
# SystemVersion.plist + bootcaches.plist looks like a normal (broken) OS to
# iBoot — the picker boots it as an OS, finds no LocalPolicy, and offers
# "reinstall". Apple's install-media marker `.IAPhysicalMedia` flips that:
# the picker boots the volume group's paired recoveryOS instead and
# auto-launches the app named in the plist. That is exactly how
# asahi-installer's step2 works (src/stub.py, src/step2/).
#
# This script replicates asahi-installer's post-stub state:
#   - Finish Installation.app  (launcher -> Terminal -> step2.sh)
#   - Resources/boot.bin       (m1n1, installed later by kmutil)
#   - Data volume private/var/db/dslocal
#   - APFS "volume is bootable" fsctl flag on the System volume
#   - bless --setBoot   (while SystemVersion.plist is still visible)
#   - then hide SystemVersion.plist + drop .IAPhysicalMedia
#
# Usage: sudo scripts/finish-install.sh [--m1n1 PATH] [--stub NAME]
#
# Idempotent: safe to re-run; it rebuilds the app and re-blesses.
# Reverse it with: sudo scripts/finish-install.sh --undo

set -euo pipefail

STUB_NAME="Omarchy"
DISTRO="Omarchy"
M1N1="vendor/m1n1/build/m1n1.bin"
UNDO=0

while [ $# -gt 0 ]; do
    case "$1" in
        --m1n1) M1N1="$2"; shift 2 ;;
        --stub) STUB_NAME="$2"; shift 2 ;;
        --undo) UNDO=1; shift ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
done

die() { echo "ERROR: $*" >&2; exit 1; }
step() { echo; echo "==> $*"; }

[ "$(id -u)" = 0 ] || die "run with sudo"

cd "$(dirname "$0")/.."

# --- locate the stub volume group ---------------------------------------

apfs_query() { diskutil apfs list -plist | python3 -c "$1" "$STUB_NAME"; }

SYS_VOL=$(apfs_query '
import plistlib, sys
d = plistlib.loads(sys.stdin.buffer.read())
for c in d["Containers"]:
    for v in c.get("Volumes", []):
        if "System" in v.get("Roles", []) and v.get("Name") == sys.argv[1]:
            print(v["DeviceIdentifier"])
')
[ -n "$SYS_VOL" ] || die "no System-role volume named '$STUB_NAME' (run prep-stub.sh first)"

read -r DATA_VOL PB_VOL REC_VOL <<<"$(apfs_query '
import plistlib, sys
d = plistlib.loads(sys.stdin.buffer.read())
out = {}
for c in d["Containers"]:
    names = [v.get("Name") for v in c.get("Volumes", [])
             if "System" in v.get("Roles", [])]
    if sys.argv[1] not in names:
        continue
    for v in c.get("Volumes", []):
        for r in ("Data", "Preboot", "Recovery"):
            if r in v.get("Roles", []):
                out[r] = v["DeviceIdentifier"]
print(out.get("Data", ""), out.get("Preboot", ""), out.get("Recovery", ""))
')"
[ -n "$DATA_VOL" ] && [ -n "$PB_VOL" ] && [ -n "$REC_VOL" ] \
    || die "stub volume group is incomplete (data=$DATA_VOL preboot=$PB_VOL recovery=$REC_VOL)"

VGID=$(diskutil info "$SYS_VOL" | awk -F': *' '/APFS Volume Group/{print $2}')
[ -n "$VGID" ] || die "could not read the stub VGID from $SYS_VOL"

mount_vol() {
    local dev="$1" mnt
    mnt=$(diskutil info "$dev" | awk -F': *' '/Mount Point/{print $2}')
    if [ -z "$mnt" ]; then
        diskutil mount "$dev" >/dev/null 2>&1 || die "could not mount $dev"
        mnt=$(diskutil info "$dev" | awk -F': *' '/Mount Point/{print $2}')
    fi
    [ -n "$mnt" ] || die "could not determine mount point for $dev"
    printf '%s' "$mnt"
}

SYS_MNT=$(mount_vol "$SYS_VOL")
DATA_MNT=$(mount_vol "$DATA_VOL")
PB_MNT=$(mount_vol "$PB_VOL")
REC_MNT=$(mount_vol "$REC_VOL")

echo "stub system volume: $SYS_VOL ($SYS_MNT)"
echo "stub VGID:          $VGID"

APP="$SYS_MNT/Finish Installation.app"
RES="$APP/Contents/Resources"
SV="$SYS_MNT/System/Library/CoreServices/SystemVersion.plist"
SV_DIS="$SYS_MNT/System/Library/CoreServices/SystemVersion-disabled.plist"
IAPM="$SYS_MNT/.IAPhysicalMedia"
IAPM_DIS="$SYS_MNT/IAPhysicalMedia-disabled.plist"

step "Remounting $SYS_MNT read-write"
mount -u -w "$SYS_MNT"

if [ "$UNDO" = 1 ]; then
    step "Reverting install-media state"
    if [ -e "$IAPM" ]; then mv -f "$IAPM" "$IAPM_DIS"; fi
    if [ -e "$SV_DIS" ]; then mv -f "$SV_DIS" "$SV"; fi
    rm -rf "$APP"
    echo "Reverted. The stub is a plain (non-bootable) OS volume again."
    exit 0
fi

# --- preflight -----------------------------------------------------------

[ -f "$M1N1" ] || die "m1n1 image not found at $M1N1 (run: make m1n1 CHAINLOADING=0)"
if [ -s vendor/m1n1/build/build_cfg.h ] && grep -q CHAINLOADING vendor/m1n1/build/build_cfg.h; then
    die "$M1N1 was built with CHAINLOADING=1; the installed stage-1 needs CHAINLOADING=0
     rebuild: CHAINLOADING=0 make m1n1"
fi
[ -d "$PB_MNT/$VGID/restore" ] \
    || die "restore bundle missing at $PB_MNT/$VGID/restore — re-run prep-stub.sh"
[ -f "$PB_MNT/$VGID/var/db/AdminUserRecoveryInfo.plist" ] \
    || die "AdminUserRecoveryInfo.plist missing in the stub Preboot — re-run prep-stub.sh"
[ -f "$REC_MNT/$VGID/usr/standalone/firmware/arm64eBaseSystem.dmg" ] \
    || die "arm64eBaseSystem.dmg missing in the stub Recovery — re-run prep-stub.sh"

# the recoveryOS authenticates against these users; bless wants one of them
ADMIN_USERS=$(python3 -c '
import plistlib, sys
print(" ".join(plistlib.load(open(sys.argv[1], "rb")).keys()))
' "$PB_MNT/$VGID/var/db/AdminUserRecoveryInfo.plist")
[ -n "$ADMIN_USERS" ] || die "no admin users in the stub AdminUserRecoveryInfo.plist"
ADMIN_USER="${SUDO_USER:-}"
case " $ADMIN_USERS " in
    *" $ADMIN_USER "*) ;;
    *) ADMIN_USER="${ADMIN_USERS%% *}" ;;
esac
echo "machine-owner admin for bless: $ADMIN_USER (candidates: $ADMIN_USERS)"

# --- Finish Installation.app --------------------------------------------

step "Writing Finish Installation.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$RES/en.lproj"

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDisplayName</key>
	<string>Finish Installation</string>
	<key>CFBundleExecutable</key>
	<string>step2_launcher.sh</string>
</dict>
</plist>
EOF

echo '"CFBundleDisplayName" = "Finish Installation";' > "$RES/en.lproj/InfoPlist.strings"

cat > "$APP/Contents/MacOS/step2_launcher.sh" <<'EOF'
#!/bin/sh
exec /System/Applications/Utilities/Terminal.app/Contents/MacOS/Terminal "${0%/*}/../Resources/step2.sh"
EOF
chmod 755 "$APP/Contents/MacOS/step2_launcher.sh"

cat > "$RES/step2.sh" <<'EOF'
#!/bin/sh
# SPDX-License-Identifier: MIT
# Runs inside the stub's *paired* recoveryOS, in 1TR.

DISTRO="##DISTRO##"
VGID="##VGID##"
PREBOOT="##PREBOOT##"

self="$0"
case "$self" in
    */*) cd "${self%/*}" || exit 1 ;;
esac
resources="$(pwd)"
system_dir="$(cd ../../../ && pwd)"
os_name="${system_dir##*/}"

printf '\033[2J\033[H'
echo "$DISTRO installer (second step)"
echo
echo "VGID:          $VGID"
echo "System volume: $system_dir"
echo

fail_shell() {
    echo
    echo "$1"
    echo "Dropping to a shell. Fix it, then re-run: $resources/step2.sh"
    exec sh
}

retry() {   # retry <description> <cmd...>
    desc="$1"; shift
    while ! "$@"; do
        echo
        echo "$desc failed. Did you mistype your password?"
        echo "Press enter to retry, or type 's' + enter for a shell."
        read ans
        [ "$ans" = s ] && exec sh
    done
}

bputil -d -v "$VGID" > /tmp/bp.txt 2>&1 || true
cat /tmp/bp.txt

if ! grep -q ': Paired' /tmp/bp.txt; then
    echo
    echo "This is not the recoveryOS paired with $os_name."
    echo "The final step only works from the recoveryOS that belongs to the"
    echo "OS being installed. Re-blessing and shutting down so you can pick"
    echo "'$os_name' again from the boot picker."
    echo
    echo "Press enter to continue."
    read _
    while ! bless --setBoot --mount "$system_dir"; do
        echo "bless failed. Press enter to try again."
        read _
    done
    echo "Shutting down. Wait 10s, then press and HOLD power until"
    echo "'Loading startup options...', and pick '$os_name'."
    read _
    shutdown -h now
    exit 1
fi

if ! grep -q 'one true recoveryOS' /tmp/bp.txt; then
    echo
    echo "Not in One True RecoveryOS (1TR) mode — you must press and HOLD"
    echo "the power button in one continuous motion from a full power-off."
    echo "Tapping power twice reaches the picker but NOT 1TR."
    echo
    echo "Press enter to shut down and retry."
    read _
    shutdown -h now
    exit 1
fi

echo
echo "Lowering the security level of the $DISTRO install only."
echo "macOS keeps its own (unchanged) security level."
echo "You will be asked for your macOS admin credentials twice."
echo
echo "Press enter to continue."
read _

retry "bputil" bputil -nc -v "$VGID"

if [ -e "/System/Volumes/iSCPreboot/$VGID/boot" ]; then
    # external volume: kmutil looks for AdminUserRecoveryInfo.plist in the
    # wrong place; mirror it into iSCPreboot.
    diskutil mount "$PREBOOT" || true
    preboot="$(diskutil info "$PREBOOT" | sed -n 's, *Mount Point: *,,p')"
    [ -n "$preboot" ] && cp -R "$preboot/$VGID/var" "/System/Volumes/iSCPreboot/$VGID/"
fi

retry "kmutil" kmutil configure-boot -c "$resources/boot.bin" --raw \
    --entry-point 2048 --lowest-virtual-address 0 -v "$system_dir"

echo
echo "Wrapping up..."
mount -u -w "$system_dir" || fail_shell "could not remount $system_dir read-write"

# switch future boots off the install-media path and back to a real OS
# entry — from here iBoot loads the m1n1 we just installed.
cs="$system_dir/System/Library/CoreServices"
if [ -e "$system_dir/.IAPhysicalMedia" ]; then
    mv "$system_dir/.IAPhysicalMedia" "$system_dir/IAPhysicalMedia-disabled.plist"
fi
if [ -e "$cs/SystemVersion-disabled.plist" ]; then
    mv -f "$cs/SystemVersion-disabled.plist" "$cs/SystemVersion.plist"
fi

echo
echo "Installation complete. Press enter to reboot into m1n1."
read _
reboot
EOF

sed -i '' \
    -e "s|##DISTRO##|$DISTRO|" \
    -e "s|##VGID##|$VGID|" \
    -e "s|##PREBOOT##|$PB_VOL|" \
    "$RES/step2.sh"
chmod 755 "$RES/step2.sh"

step "Installing m1n1 as $RES/boot.bin"
cp "$M1N1" "$RES/boot.bin"
ls -l "$RES/boot.bin"

# --- volume housekeeping asahi-installer also does -----------------------

step "Preparing Data volume + bootable flag"
mkdir -p "$DATA_MNT/private/var/db/dslocal"
python3 - "$SYS_MNT" <<'EOF'
import sys
from ctypes import CDLL, c_char_p, c_int, c_uint, c_ulong, POINTER, byref, get_errno
libc = CDLL("libSystem.B.dylib", use_errno=True)
libc.fsctl.restype = c_int
libc.fsctl.argtypes = (c_char_p, c_ulong, POINTER(c_int), c_uint)
APFSIOC_VOL_BOOTABLE = 0xc0044a57  # _IOWR('J', 'W', int32_t)
cmd = c_int(1)                     # 1 = set bootable, -1 = clear, 0 = query
if libc.fsctl(sys.argv[1].encode(), APFSIOC_VOL_BOOTABLE, byref(cmd), 0) == -1:
    raise SystemExit(f"fsctl APFSIOC_VOL_BOOTABLE failed: errno {get_errno()}")
cmd = c_int(0)
libc.fsctl(sys.argv[1].encode(), APFSIOC_VOL_BOOTABLE, byref(cmd), 0)
print(f"APFS bootable flag: {cmd.value}")
EOF

# --- bless (SystemVersion.plist must still be visible here) --------------

step "Blessing the stub as the default boot volume"
# bless inspects a *normal* OS volume: SystemVersion.plist visible, no
# install-media marker. We flip both back on after it succeeds.
if [ ! -e "$SV" ]; then
    [ -e "$SV_DIS" ] || die "SystemVersion.plist missing from the stub — re-run prep-stub.sh"
    mv -f "$SV_DIS" "$SV"
fi
if [ -e "$IAPM" ]; then mv -f "$IAPM" "$IAPM_DIS"; fi
bless --setBoot --device "/dev/$SYS_VOL" --user "$ADMIN_USER" \
    || die "bless failed — the ceremony cannot proceed"

# --- arm the install-media path -----------------------------------------

step "Arming the install-media path"
mv -f "$SV" "$SV_DIS"
cat > "$IAPM" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>AppName</key>
	<string>Finish Installation.app</string>
	<key>ProductBuildVersion</key>
	<string>00A191</string>
	<key>ProductVersion</key>
	<string>12.1</string>
</dict>
</plist>
EOF
rm -f "$IAPM_DIS"

echo
echo "Stub System volume now looks like install media:"
ls -la "$SYS_MNT"

cat <<EOF

==> Done. VGID: $VGID

Next (on-device, one continuous motion):
  1. sudo shutdown -h now      # full power off, wait ~15 s
  2. Press and HOLD the power button until "Loading startup options..."
     (tapping twice gets you the picker but NOT 1TR — it will refuse)
  3. Pick "$STUB_NAME"
  4. It boots the stub's paired recoveryOS and opens a Terminal running
     Finish Installation.app -> step2.sh, which verifies Paired + 1TR,
     runs 'bputil -nc' (macOS admin creds, twice), then
     'kmutil configure-boot' with m1n1, and finally disables the
     install-media marker so the next boot goes straight to m1n1.

If no Terminal opens: Utilities -> Terminal, then run
  "/Volumes/$STUB_NAME/Finish Installation.app/Contents/Resources/step2.sh"

To back this out entirely: sudo scripts/finish-install.sh --undo
EOF
