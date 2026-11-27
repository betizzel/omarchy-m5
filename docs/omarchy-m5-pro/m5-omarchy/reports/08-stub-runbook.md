# 08 — Stub partition step: audit and runbook

**Scripts:** betizzel/omarchy-m5 @ `15cd70c1`, `scripts/prep-stub.sh` (384 lines) and `scripts/finish-install.sh` (387 lines). Both carry `SPDX-License-Identifier: MIT`, so these two files are licensed even though the repo has no LICENSE (06C). Neither involves an asahi-installer *engine*: they re-implement its stub.py/step2 behaviour in plain shell + `diskutil`/`bless`/`python3`.

**Recovery path, verified by PM:** `work` sees the Mac in Port DFU (`irecovery`: Mac17,9 j714sap) with idevicerestore `ae8cfb4` + usbmuxd HEAD. That makes a DFU restore (erase) available as the last resort.

## 1. Audit

### `prep-stub.sh`: runs on macOS as root, **no m1n1 involvement**
| Lines | What it does | Notes for our Mac |
|---|---|---|
| 35–40 | Hard-coded `MACOS_PART=disk0s2`, stub `Omarchy` **6G**, EFI **500M**, Linux optional (`--linux-size`) | Our layout matches (s1 ISC, **s2 APFS 994.6 GB**, s3 Recovery). **It does not check the rest of disk0** (that it's internal, has exactly 3 partitions, etc.), so the pre-check in §2a does that |
| 57–59 | Refuses if `disk0s2` is missing or not `Apple_APFS` | — |
| 61–73 | Finds the macOS System volume in the container on `disk0s2`, its **VGID**, and requires `/System/Volumes/Preboot/<VGID>/restore` | Read-only |
| 75–101 | Finds the **Recovery-role volume inside the macOS container**, *mounts* it at `/tmp/recovery-mnt.*` (unmounted on exit), and requires `<VGID>/usr/standalone/firmware/arm64eBaseSystem.dmg` | A mount, not a write. It happens before the "Proceed?" prompt too |
| 103–110 | Prints free space in the container | Ours: ~715 GB |
| 116–160 | Plan: `need = stub + EFI + Linux + 64 MiB` (decimal G/M, so 6e9 + 5e8 + N + 64 MiB). Shrinks `disk0s2` by the shortfall, rounded down to 1 MiB, passing **bytes** to diskutil | With `--linux-size 20G`: need ≈ 26.567 GB, so new size ≈ 994.6 − 26.6 ≈ **968.0 GB** |
| 166–186 | `find_stub`: an `Apple_APFS` partition on disk0 other than disk0s2 with a volume named `Omarchy*` (re-runnable; it resumes) | Selects by type and name, never by number. ISC/Recovery are excluded by type |
| 188–207 | Prints the plan, then **`Proceed? [y/N]`**. Anything but `y` aborts | **This is the dry run**: answer `N` (nothing changed except the temporary Recovery mount) |
| 213–214 | (!) `diskutil apfs resizeContainer disk0s2 <NEW_SIZE>B` | Shrinks macOS. Works with FileVault on |
| 219–220 | (!) `diskutil addPartition disk0s2 apfs Omarchy 6G` | New container right after s2 |
| 233–298 | (!) Turns the default volume into Data (`changeVolumeRole … D`, rename `Omarchy - Data`), adds System (`-role S -groupWith Data`), Preboot (`-role B`) and Recovery (`-role R`), deletes stray no-role volumes, **requires exactly 4 volumes**, prints the **stub VGID** | — |
| 300–309 | (!) If no `EFI`/"Microsoft Basic" partition exists on disk0: `diskutil addPartition <stub> %EFI% %noformat% 500M`, then `newfs_msdos -F 32 -v OMARCHY /dev/r<efi>` | Ours has none, so it creates one. The `awk '$2=="EFI"'` match is simple; check the result in the post-check |
| 312–320 | (!) If `--linux-size`: `diskutil addPartition <efi> %Linux% %noformat% 20G` (unformatted) | — |
| 324–340 | (!) Stub Preboot: `ditto` the macOS **`restore` bundle** into `<stubVGID>/restore`, then copies **`AdminUserRecoveryInfo.plist`** and sets `schg` | This is what makes the stub's recoveryOS accept *our* admin/FileVault users |
| 342–356 | (!) Stub Recovery: copies the macOS **`arm64eBaseSystem.dmg`** (recoveryOS image) | — |
| 358–369 | (!) Stub System: copies `SystemVersion.plist`, `PlatformSupport.plist`, `bootcaches.plist`; sets ProductName "Omarchy Linux (stub)" | — |

- **Downloads:** **none**. Everything is cloned from this Mac's own install. So **the stub OS = this Mac's macOS 26.6.2 boot objects / mBoot-18000.161.10**, which suits this Mac by construction. betizzel's stub was 26.5 / 18000.120.36; the only difference is that ours is newer and matches our firmware.
- **What it leaves for later:** the bless, the install-media marker, the m1n1 boot object and the 1TR ceremony. Those are all in `finish-install.sh` + `step2.sh`.

### `finish-install.sh`: [owner-only] **owner step, because it embeds m1n1**
- 129–141: preflight. It needs an m1n1 image (`--m1n1 PATH`; it refuses a CHAINLOADING vendor build). It also re-checks the restore bundle, AdminUserRecoveryInfo and BaseSystem in the stub.
- 158–305: writes `Finish Installation.app` (launcher → Terminal → `step2.sh`, with VGID/Preboot substituted), then **`cp m1n1 → Resources/boot.bin`** [owner-only].
- 313–327: creates `Data/private/var/db/dslocal`; sets the APFS bootable flag via `fsctl(APFSIOC_VOL_BOOTABLE)`.
- 331–339: (!) **`bless --setBoot --device /dev/<stubSys> --user <admin>`**. This makes the stub the **global default boot volume**. `bless` will ask for the admin password.
- 343–360: hides `SystemVersion.plist` and writes `.IAPhysicalMedia` (AppName "Finish Installation.app"), so the picker boots the stub's *paired recoveryOS* and auto-launches the app.
- `--undo`: removes the app, re-shows `SystemVersion.plist`, disables the marker. **It does not re-bless macOS.**

### `step2.sh` (runs in the stub's 1TR)
1. Checks `bputil -d -v <VGID>` for `: Paired` and `one true recoveryOS`. If those are missing it re-blesses and shuts down.
2. (!) `bputil -nc -v <VGID>`: Permissive, stub only.
3. (!)[owner-only] `kmutil configure-boot -c boot.bin --raw --entry-point 2048 --lowest-virtual-address 0 -v <stubSys>`.
4. Renames `.IAPhysicalMedia` away, restores `SystemVersion.plist`, reboots.

**It does not run `csrutil disable` / `nvram boot-args=-v`.** That's the proxy backdoor, a separate owner step (§3).

### Assumptions that may not hold on our Mac
1. **`python3`** is used throughout. On macOS `/usr/bin/python3` is a shim that needs the Command Line Tools, and if they're missing it pops up an installer. → Pre-check. Installing the CLT is a change that needs approval.
2. **No disk0 layout guard** beyond "disk0s2 is APFS". → Our pre-check enforces the exact 3-partition layout.
3. Run over **SSH**: `prep-stub.sh` reads a `y/N` from the TTY and `bless --user` prompts for a password, so use `ssh -t`. Asahi's own installer refuses SSH-only sessions, but these scripts don't. [guess] `bless` may need a logged-in console session too; if it fails over SSH, the owner runs `finish-install.sh` at the console.
4. **FileVault on:** fine for resize and addPartition. The cloned `AdminUserRecoveryInfo.plist` carries the FileVault-capable admin users that 1TR will ask for.
5. Main macOS **SIP already disabled** (pre-existing): irrelevant to the scripts. We record its policy in §2a.
6. **Partition renumbering:** after the change the Recovery container becomes `disk0s6`. All later commands must identify partitions **by type, name and size**.

## 2. Runbook for the PM (over `ssh -t`, owner types credentials)

### (a) Read-only pre-checks: STOP on any mismatch
```sh
sw_vers                                   # expect ProductVersion 26.6.2
system_profiler SPHardwareDataType | grep -E 'Model Identifier|System Firmware|OS Loader'
                                          # expect Mac17,9, 18000.161.10 / 18000.161.10
diskutil list disk0                       # expect EXACTLY: s1 Apple_APFS_ISC 576.7MB, s2 Apple_APFS (disk3) 994.6GB,
                                          #                 s3 Apple_APFS_Recovery 5.4GB; no other partitions, no free space
diskutil info disk0 | grep -E 'Device Location|Solid State|Protocol'   # expect Internal, SSD, Apple Fabric
diskutil apfs list | grep -A3 'Container disk3' | grep -i free          # expect >= 27 GB free (we have ~715 GB)
fdesetup status                           # expect "FileVault is On."
csrutil status                            # record (PM: disabled, pre-existing)
sudo bputil -d                            # record main macOS LocalPolicy (Security mode etc.); owner types sudo pw
VGID=$(diskutil info / | awk -F': *' '/APFS Volume Group/{print $2}'); echo $VGID
ls -d /System/Volumes/Preboot/$VGID/restore            # must exist
xcode-select -p && python3 -c 'import plistlib; print("python ok")'   # must print a path + "python ok"
                                          # STOP if it offers to install Command Line Tools (that's a change)
git -C ~/omarchy-m5 rev-parse HEAD        # must be 15cd70c1fad65322b85be4de4362cbed816a11c1
shasum -a 256 ~/omarchy-m5/scripts/prep-stub.sh ~/omarchy-m5/scripts/finish-install.sh
                                          # expect ef36f4f4db73899b86bb4c7e6e13da6300b58f4c51da82fcbbff9faa37cb7253 prep-stub.sh
                                          #        f548b0af4862927635b4d93694cb52c336219e4afad31d51fe6fb5775a733105 finish-install.sh (as audited)
```
**Dry run** (mounts and unmounts the macOS Recovery volume; changes nothing else):
```sh
cd ~/omarchy-m5 && sudo scripts/prep-stub.sh --linux-size 20G      # answer N at "Proceed?"
```
Expect `macOS container free space: ~715 GB` and a Plan with:
- `resize disk0s2 (macOS container): 994.6 GB -> ~968.0 GB, macOS shrinks by ~26.6 GB`
- `addPartition disk0s2 apfs 'Omarchy' 6G`
- the EFI 500M and Linux 20G lines
- `clone restore bundle + recoveryOS + admin creds`

**STOP if** there's any `ERROR:`, the plan names anything other than disk0s2, or the shrink is ≠ ~26.6 GB.

### (b) Changes: (!) each needs owner approval
1. (!) `cd ~/omarchy-m5 && sudo scripts/prep-stub.sh --linux-size 20G` and answer **y**.
   - *Expect, in order:* `==> Resizing macOS container to <bytes> bytes` → `==> Creating stub APFS container (6G)` → `stub container: diskN (partition disk0s3)` → `==> Creating stub volumes` → `stub VGID: <UUID>` (record it) → `==> Creating EFI partition (500M)` + newfs_msdos output → `==> Creating Linux partition (20G)` → `Populating stub Preboot/Recovery/System` → `==> Done`.
   - **STOP on:** any `ERROR:`, `expected 4 stub volumes`, or a non-zero exit. The script is re-runnable and resumes an existing stub.
2. Post-check (read-only): `diskutil list disk0`. Expect:
   - s1 ISC 576.7 MB
   - s2 Apple_APFS ~968 GB
   - s3 Apple_APFS (Omarchy) 6.0 GB
   - s4 EFI OMARCHY 500 MB
   - s5 Linux Filesystem 20 GB
   - s6 Apple_APFS_Recovery 5.4 GB

   Also `diskutil apfs list` should show the Omarchy container with 4 volumes (Data, System, Preboot, Recovery). Then `sw_vers` and reboot into macOS once, to show macOS still boots. **STOP** if the layout differs.
3. [owner-only] Owner: build stage-1 m1n1 (`CHAINLOADING=0`, see 06B §3), copy it to the Mac as `~/m1n1-stage1.bin`, and at the console run:
   ```sh
   cd ~/omarchy-m5 && sudo scripts/finish-install.sh --m1n1 ~/m1n1-stage1.bin
   ```
   *Expect:* `machine-owner admin for bless: <user>`, `Writing Finish Installation.app`, `Installing m1n1 as …/boot.bin`, `APFS bootable flag: 1`, a `bless` password prompt, `Arming the install-media path`, `==> Done. VGID: <same UUID>`.

   (!) From now on the default boot volume is the stub.

## 3. The 1TR step (owner, at the Mac)

Credentials asked for: the **macOS admin user with FileVault access** (machine owner), name + password, several times.

1. `sudo shutdown -h now` and wait 15 s.
2. **Press and hold** power in one motion until "**Loading startup options…**". Tapping twice reaches the picker but *not* 1TR, and `step2.sh` refuses.
3. Startup Options shows the volumes and **Options**. Select **Omarchy** (shown as an install item because of `.IAPhysicalMedia`) → **Continue**.
4. The stub's paired recoveryOS boots. If it asks, select the admin user and enter the password (FileVault unlock / recovery auth).
5. **Finish Installation.app** opens Terminal running `step2.sh`. It prints `bputil -d` output and checks `Paired` + `one true recoveryOS`.
   - If it says "not the recoveryOS paired…", it re-blesses and shuts down; repeat from step 1.
   - If no Terminal appears: **Utilities → Terminal**, then run `"/Volumes/Omarchy/Finish Installation.app/Contents/Resources/step2.sh"`.
6. Press Enter → (!) `bputil -nc -v <VGID>`: **admin credentials (twice)**. This lowers the **stub only** to Permissive.
7. (!)[owner-only] `kmutil configure-boot … boot.bin …`: **admin credentials** again. This installs m1n1 as the stub's custom boot object.
8. "Installation complete. Press enter to reboot into m1n1." Press Enter. *Expect:* the m1n1 logo and log on the panel ([owner-only] the m1n1 log is read by the owner only).
9. **Proxy backdoor** (Asahi tethered-boot doc), a second 1TR session with the stub as default:
   1. Repeat steps 1–3, but this time choose **Options** (gear) → admin auth → **Utilities → Terminal**.
   2. (!) `csrutil disable && nvram boot-args=-v`. When asked, **select the Omarchy volume** and authenticate. SIP is stored in the stub's LocalPolicy only; `boot-args` is a global NVRAM variable (06B §1).
   3. Shut down.

## 4. Undo

**Back to macOS at any point:** hold power → pick **Macintosh HD**. Make it the default in System Settings → General → Startup Disk (owner, password), or with `sudo bless --mount / --setBoot --user <admin>`.

**Remove everything (b) created.** Use exact identifiers from a fresh `diskutil list disk0`, matched **by type, name and size**:
```sh
sudo ~/omarchy-m5/scripts/finish-install.sh --undo   # only if step (b)3 ran: removes app/markers (no m1n1 handling)
diskutil list disk0                                   # identify: Omarchy Apple_APFS 6 GB (disk0sZ), EFI OMARCHY (disk0sY), Linux Filesystem 20 GB (disk0sX)
sudo diskutil eraseVolume free free disk0sX           # Linux Filesystem
sudo diskutil eraseVolume free free disk0sY           # EFI
sudo diskutil apfs deleteContainer disk0sZ            # Omarchy stub (removes the stub OS and its volumes)
sudo diskutil apfs resizeContainer disk0s2 0          # macOS takes back all free space
sudo nvram -d boot-args                               # only if §3.9 ran
diskutil list disk0                                   # expect the original 3-partition layout again
```
- **Never** touch `Apple_APFS_ISC` or `Apple_APFS_Recovery`. This matches Asahi's "Deleting an installation" doc (asahi-docs @ `5acb80f`: `deleteContainer`, `eraseVolume free free`, `resizeContainer … 0`).
- If the resize reports a verify/repair failure, run `diskutil repairVolume disk0s2` from recoveryOS and retry.
- [guess] The stub's LocalPolicy (Permissive/SIP) is per-VGID and is no longer used once its OS is gone. Asahi's doc doesn't add a policy-cleanup step either.
- **Last resort:** DFU restore from `work` (idevicerestore `--erase --latest`, the left-back port, key combo; 06B §2/§7).
