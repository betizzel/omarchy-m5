# Mac handoff: re-install the Omarchy boot partitions (2026-10-09)

> ✅ **Completed 2026‑10‑09 — historical task‑handoff, kept for the record.**
> Current project state is in [`HANDOFF.md`](HANDOFF.md).

> For an agent running in macOS on the M5 Pro itself. You do the macOS
> half: disk survey, stage-1 m1n1, `prep-stub.sh`, `finish-install.sh`.
> The human does the 1TR ceremony at the keyboard. The ThinkPad then
> writes the Linux root over USB. Background: `docs/HANDOFF.md` (project
> state) and `docs/bringup.md` ("One-time on-device step", "Resizing or
> re-installing").

**Done 2026-10-09.** Stub VGID `83F76F48-1DE4-4C8B-99C0-E9D48E59AF0D`,
root = GPT entry 5 (20 GB). Next: `docs/HANDOFF-thinkpad.md`.

## Situation

- The user **already deleted** the old Omarchy stub, EFI and Linux root
  (6 GB / 500 MB / 256 GB) to give macOS room for local AI models. The Arch
  install on the SSD and the stub's boot policy (old VGID
  `B931CA67-AA4F-465B-B80D-B24814488E27`) are gone. Nothing was backed up
  from the Linux side; that is accepted.
- **Target:** the same three partitions again, root now **20 GB** (the
  user's choice): `--linux-size 20G` takes 26.5 GB from macOS in total.
- **Unknown, find out in phase 1:** whether macOS was grown back over the
  freed space, whether the startup disk was switched back to macOS, and the
  current `disk0sN` numbering.
- The same scripts completed this end to end on 2026-09-21. Since then
  `prep-stub.sh` finds the stub by partition type and volume name instead of
  by number (the old lookup could match the system Recovery container), and
  `finish-install.sh --m1n1` takes an image built elsewhere.

## Ground rules

- **Never touch the first partition (`Apple_APFS_ISC`) or the last
  (`Apple_APFS_Recovery`).** Breaking Recovery means a DFU restore from
  another machine. Identify partitions by type, size and volume names from
  `diskutil list`, never by `disk0sN`: macOS renumbers them by disk
  position, and they can change after any partition operation.
- Do not use Disk Utility.app. `diskutil` only.
- Read-only commands are fine to run. For every `sudo`, `diskutil` write,
  or `bless`, show the exact command, wait for the user's yes, and let them
  run it if it needs their password.
- If anything does not match what this file expects (extra partitions, a
  plan you did not predict, a script error), stop and report. Do not
  improvise disk operations.
- Leave `/System/Volumes/iSCPreboot` alone. The old VGID's leftover policy
  there is harmless.

## Machine facts

- MacBook Pro 14", M5 Pro: Mac17,9 / J714sAP, SoC T6050, 48 GB RAM, 1 TB.
- The bring-up (DT, runtime ADT, trackpad firmware) was tuned under macOS
  **26.5**. macOS VGID was `863345B8-7FEC-4FD2-996D-187D72EC9A66`.
- Repo: `git@github.com:betizzel/omarchy-m5` (private). Work from an
  up-to-date checkout: `git pull --ff-only`.

## Phase 1: survey (read-only)

```sh
sw_vers
diskutil list disk0
diskutil apfs list
diskutil apfs list | grep -E 'Capacity (Ceiling|Not Allocated)'
bless --getBoot
fdesetup status
```

Expected after a clean delete: `Apple_APFS_ISC`, the macOS `Apple_APFS`
container, possibly a `(free space)` row right after it, then
`Apple_APFS_Recovery` last. No `EFI`, no `Linux Filesystem`, no second
`Apple_APFS` container with `Omarchy` volumes.

Act on what you find:

- **Leftover** `EFI`, `Linux Filesystem`, or a 6 GB `Apple_APFS` holding
  `Omarchy*` volumes: list them for the user, then delete them as in
  `docs/bringup.md` step 4 (`diskutil eraseVolume free free disk0sN`,
  `diskutil apfs deleteContainer disk0sN`). This matters because
  `prep-stub.sh` reuses any EFI partition it finds.
- **Free space after the macOS container:** have the user run
  `sudo diskutil apfs resizeContainer disk0s2 0` first. Otherwise
  `prep-stub.sh` shrinks macOS again and the old space stays unallocated.
  If it fails with `Storage system verify or repair failed`, run
  `diskutil repairVolume disk0s2` from recoveryOS and retry.
- **`bless --getBoot`** should point at the macOS volume. If it does not,
  have the user set System Settings → General → Startup Disk → Macintosh HD.
- **Free space in macOS** must cover 26.5 GB with room to spare. Keep at
  least ~40 GB free afterwards for macOS updates.
- **`sw_vers` is not 26.5:** not a blocker. Tell the user, because the
  stub copies *this* macOS's boot objects. After the first boot, the
  ThinkPad should re-dump the runtime ADT (`./dump-adt.sh`) and re-extract
  the trackpad firmware for this version
  (`scripts/extract-tpmtfw.py --ipsw <URL>`).

## Phase 2: stage-1 m1n1 (`CHAINLOADING=0`)

The image that `kmutil` installs must be a non-chainloading build.

**A. Prebuilt (preferred):** the user copies the ThinkPad build
`~/Work/omarchy-m5/build/m1n1-stage1.bin` to `~/m1n1-stage1.bin` on the
Mac. Check `shasum -a 256 ~/m1n1-stage1.bin` =
`e9d6122dcff433a56c9fdc85369caf0fee7d745a2a886f03bc343fc1fc217a1e`.

**B. Build here.** The patches are against m1n1
`4184923ffb2dff079b384d6a32cc02142aa14572`, so pin it. Do not use
`make fetch`: it follows m1n1 `main`, and it also clones a 1.5 GB kernel
that this phase does not need.

```sh
make setup                                    # once: brew llvm/lld/make…, rustup target
[ -d vendor/m1n1/.git ] || git clone --recursive https://github.com/AsahiLinux/m1n1.git vendor/m1n1
git -C vendor/m1n1 status --short             # dirty? `git -C vendor/m1n1 stash`, never discard
git -C vendor/m1n1 fetch origin
git -C vendor/m1n1 checkout 4184923ffb2dff079b384d6a32cc02142aa14572
git -C vendor/m1n1 submodule update --init --recursive
scripts/apply-patches.sh                      # patches/m1n1/0001..0003 (linux skipped if absent)
CHAINLOADING=0 scripts/build-m1n1.sh          # GNU make >= 4.3 required; the script checks
cp vendor/m1n1/build/m1n1.bin ~/m1n1-stage1.bin
```

`vendor/m1n1/build/build_cfg.h` must not contain `#define CHAINLOADING`.
A local build's sha256 will not match the prebuilt one. The embedded build
tag and the toolchain differ, and that is expected. These exact steps were
dry-run on the ThinkPad from a fresh clone: all three patches apply cleanly
and the sources match the tree the prebuilt came from.

## Phase 3: partitions and stub

```sh
sudo scripts/prep-stub.sh --linux-size 20G
```

Before answering `Proceed?`, check the printed plan. Its first line should
read `994.6 GB -> 968.0 GB, macOS shrinks by 26.6 GB` (give or take, if
macOS was not fully grown back), followed by the 6 GB `Omarchy` container,
the 500 MB EFI and the 20 GB Linux partition. Stop if it plans anything else.
The script is resumable: a re-run picks up a half-made stub.

Verify afterwards:

- `diskutil list disk0`: macOS, a 6 GB `Apple_APFS`, `EFI` (~500 MB),
  `Linux Filesystem` (~20 GB), then `Apple_APFS_Recovery` still last.
- `diskutil apfs list`: the stub has exactly 4 volumes
  (`Omarchy - Data`, `Omarchy`, `Preboot`, `Recovery`).
- Record the **stub VGID** that the script printed.

## Phase 4: arm the stub

```sh
sudo scripts/finish-install.sh --m1n1 ~/m1n1-stage1.bin
```

It asks for the admin password (for `bless`). Success ends with
`==> Done. VGID: …`, and the stub System volume listing shows
`.IAPhysicalMedia` and `Finish Installation.app`. If the picker later
offers "reinstall", `.IAPhysicalMedia` is missing: re-run this script.

## Phase 5: report, then the ceremony (the human)

Before the user shuts down, write `~/omarchy-reinstall-report.txt` with:
`sw_vers`, `diskutil list disk0`, the stub VGID,
`sudo gpt -r show /dev/disk0` (the Linux partition's start and size), and
the stage-1 sha256. Tell the user to paste it to the ThinkPad session.

Then give the user these steps. Your session ends at the shutdown.

1. Shut down fully and wait ~15 s.
2. Press and **hold** power until "Loading startup options…". Tapping
   twice reaches the picker but not 1TR, and `step2.sh` refuses then.
3. Pick **Omarchy**. Its recoveryOS opens a Terminal running `step2.sh`.
   It checks `Paired` + `one true recoveryOS`, runs `bputil -nc` and
   `kmutil configure-boot`, and asks for macOS admin credentials for
   each. Press Enter at the end to reboot.
4. If no Terminal opens: Utilities → Terminal, then
   `"/Volumes/Omarchy/Finish Installation.app/Contents/Resources/step2.sh"`.

`step2.sh` handles the two common failures itself. "Not the paired
recoveryOS" re-blesses and shuts down; "not 1TR" shuts down. Either way,
retry from step 2.

**Success:** the M5 boots into m1n1 (framebuffer, then waits for the USB
proxy). From now on an unattended power-on goes to m1n1. macOS is
power-hold → picker → Macintosh HD.

## After the Mac: the ThinkPad

With the M5 sitting in m1n1 and the USB-C cable to the ThinkPad, follow
`docs/bringup.md` "Resizing or re-installing" steps 7–8 from `~/tether`:
`./chainload.sh`, then `python3 hv/nvme-proxy-probe.py` (it prints the
exact `provision-rootfs` line), then boot the provisioning initramfs and
run that line on the M5's keyboard. The first SSD boot only knows `root`,
so recreate `bay`. There is no `m5-home.tgz`/`m5-pkglist.txt` this time,
so skip those two restore commands and reinstall packages by hand.
