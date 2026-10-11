# Dual-Boot Partitioning & Installation Mechanics on Apple Silicon
### Research for `omarchy-m5` - how a second OS gets onto an M5 Pro MacBook Pro without removing macOS

**Author:** Devin (research session `de25fc5c33784d018573ac11d7402a7a`, spawned from `omarchy-m5` parent session)
**Date:** 2026-09-21 · All sources dated inline. "Verified" = read in primary source (installer source code, official docs); "inferred" = reasoned from those sources.

---

## 1. Executive summary

- **There is no Boot Camp on Apple Silicon.** Multi-boot is native: each "OS" is an APFS volume group (System+Data) inside an APFS container partition, plus paired `Preboot` and `Recovery` volumes. A third-party OS becomes bootable by *impersonating the shape of a macOS install*: the Asahi installer creates a 2.5 GB "stub macOS" container and registers the m1n1 bootloader as that OS's **custom kernel** via Apple's own `bputil`/`kmutil` boot-policy machinery. Linux itself lives on ordinary GPT partitions behind the stub.
- **The security ceremony is unavoidable and per-OS.** Setting a volume group's boot policy (`bputil -nc`, "Permissive Security") and installing the custom boot object (`kmutil configure-boot`) can only run from the recoveryOS *paired to that OS* in **1TR** ("one true recoveryOS" - the power-button-hold boot path), authenticated by admin credentials copied into the stub's Preboot. This is why every Asahi install needs its own stub, and why the install is a two-stage dance across a reboot.
- **Support gate is a hardcoded table.** `asahi-installer` whitelists chips/devices in `CHIP_MIN_VER`/`DEVICES` (src/main.py) plus a table of Apple firmware packages (`IPSW_VERSIONS`). As of tag **v0.9.2 (2026-09-14, "Do not require expert for M3")** the installer covers M1, M2, and - just enabled this month - M3 families. **M4 and M5 are absent.** MBP M5 Pro (announced 2026-03-03, ships macOS Tahoe 26.x) cannot pass the gates: its chip/board IDs aren't in the tables and no IPSW/OTA asset with a matching BuildIdentity is listed. Root cause upstream: m1n1/kernel bring-up for M4/M5 is early-stage and Apple's silicon changes broke Asahi's existing reverse-engineering tools (Sven Peter, 39C3, Dec 2025).
- **Omarchy M's native installer is real and already shipping RC builds** - but it is a SwiftUI macOS app + privileged helper that *embeds a pinned, signed Asahi installer engine* (asahi-installer v0.9.2 + Python overlay, rebuilt reproducibly). It does not reimplement partitioning, so it inherits Asahi's device gates wholesale, plus its own signed-catalog model allowlist that currently fail-closes on `apple,j614s` (M4 Pro) and anything newer.
- **Recommended path for omarchy-m5 today:** there is no safe install path onto bare M5 Pro metal yet. Partitioning plans should target the proven layout (2.5 GB stub + ~500 MB ESP + boot + root) and treat the real work as m1n1/kernel bring-up; when that lands, the mechanical install layer is already solved and scriptable.

---

## 2. Apple Silicon boot & security model (why a stub exists at all)

Verified from Asahi docs and installer source.

Boot chain (https://asahilinux.org/docs/fw/boot/, https://asahilinux.org/docs/alt/boot-process-guide/):

```
SecureROM → LLB/iBoot1 (NOR) → iBoot2 (per-OS, in Preboot) → OS kernel
                    for Linux:  iBoot2 → m1n1 stage1 → m1n1 stage2 → U-Boot → GRUB → Linux
```

Key platform facts:

- Internal NVMe is GPT-partitioned. Two APFS containers are sacred: the **first** partition (`Apple_APFS_ISC`, iBoot System Container) and the **last** (`Apple_APFS_Recovery`, System Recovery / 1TR home). Deleting the recovery partition kills macOS updates and can force a DFU restore. All third-party work happens *between* them. ([Partitioning Cheatsheet](https://asahilinux.org/docs/sw/partitioning-cheatsheet/), accessed 2026-09-21)
- An "OS" to the platform = an **APFS volume group** (`System` + `Data`) in an APFS container, accompanied by `Preboot` (per-OS boot objects incl. iBoot2, boot policies) and `Recovery` (that OS's own recoveryOS image) volumes. Each volume group has a **VGID** and a per-OS **LocalPolicy** signed by the SEP.
- **Pairing:** boot policy/security for a VGID may only be modified from a recoveryOS that reports `OS Pairing Status: Paired` for that VGID - i.e., booted from the Recovery volume belonging to *that* OS - and only in **1TR** mode (hold power button through boot; the ordinary recovery boot or "tap then hold" path doesn't count). `bputil -d -v <vgid>` reports both (`Current OS environment: one true recoveryOS`, `: Paired`). Verified in `src/step2/step2.sh` + [Eclectic Light on bputil](https://eclecticlight.co/2024/04/01/checking-bootable-systems-using-bputil-on-apple-silicon/) (2024-04-01).
- **Permissive Security** (`bputil -n…`): per-OS policy level telling iBoot to accept locally SEP-signed *custom boot objects* - Apple's official escape hatch for "arbitrary fully untrusted operating system kernel[s]". Secure boot verification still runs end-to-end; macOS's own policy is unaffected (per-OS policies by design). Side effect documented by Apple: while booted into a fuOS, "some decryption keys become unavailable" - i.e., Linux can't unlock FileVault data. ([Apple Platform Security](https://support.apple.com/guide/security/startup-disk-security-policy-control-sec7d92dc49f/web))
- **`kmutil configure-boot -c <bin> --raw --entry-point 2048 --lowest-virtual-address 0 -v <system volume>`** registers a raw binary (m1n1 stage1) as the OS's custom kernel/boot object, generating a machine-specific signed boot collection (`kernelcache.custom.<hash>` under Preboot). This is the actual mechanism that makes Linux bootable - it is Apple's own dual-boot facility, not an exploit.
- `bless --setBoot` sets default boot; the boot picker (1TR startup options) shows every bootable volume group, which is how users pick macOS vs Linux at power-on.

Why the stub is a separate container rather than volumes inside macOS's container: deliberate choice - "makes it less error-prone and easier to delete" (Asahi partitioning cheatsheet). Linux can't live in APFS anyway (no stable/mainline APFS write support), so Linux gets real GPT partitions; the stub is purely a boot-policy vehicle. Asahi calls the triple - stub APFS container + dedicated ESP + OS partitions - a "virtual UEFI environment"; each installed OS gets its own ESP (a bespoke `asahi,efi-system-partition` /chosen property tells m1n1/U-Boot which ESP is paired to this OS).

---

## 3. Mechanical walkthrough: what the installer actually does

Verified end-to-end from `asahi-installer` source @ v0.9.2 (`dffbb38`, 2026-09-14) - `src/main.py`, `src/diskutil.py`, `src/stub.py`, `src/osinstall.py`, `src/step2/step2.sh`.

### Stage 0 - bootstrap (`curl https://alx.sh | sh`)
- Thin shell script: refuses non-macOS, requires macOS ≥13.5 (probed via curl feature), downloads `installer-<ver>.tar.gz` + `installer_data.json` from the distro's endpoints (Fedora: `cdn.asahilinux.org`; ALARM: `asahi-alarm.org`), extracts to `/tmp/asahi-install`, re-execs as `sudo ./install.sh` under `caffeinate`. Downstreams rebrand via env vars (`INSTALLER_BASE`, `INSTALLER_DATA`, `REPO_BASE`, `REPORT_TAG`).

### Stage 1 - macOS-side install (Python, runs as root in normal macOS)
1. **Device/host gating:** reads chip-id, board-id, device class, firmware versions from IORegistry; `bputil -d` for boot mode. Hard fails ("This device is not supported yet!") if `chip_id`/`device_class` aren't in `CHIP_MIN_VER`/`DEVICES`. Requires a macOS install with ≥1 admin "machine owner"; the logged-in console user must be an admin (SSH-only sessions rejected). macOS ≥13.5 (≥12.3 expert).
2. **Menu:** inspect partitions via `diskutil ... -plist`; options: `r` resize an APFS container, `f` install into free space, `p` repair incomplete install, `m` upgrade m1n1, `v` rebuild vendor firmware, `7` fix macOS 27 boot-picker compatibility, expert-only: `d` external disk, `w` wipe disk.
3. **Resize:** `diskutil apfs resizeContainer <part> <newsize>`, with floor = max(used + 38 GB headroom for OS containers, diskutil's own `resizeContainer … limits` minimum). Warns about Time Machine snapshot / pending-upgrade overhead (>16 GB overhead triggers the `alx.sh/tmcleanup` warning). The screen may freeze - normal.
4. **Stub creation:** `diskutil addPartition <after> apfs <OS name> 2.5GB` → inside the new container, `diskutil apfs addVolume` creates `Data`+`System` (a volume group), `Preboot`, `Recovery`.
5. **Stub population from Apple firmware package** (`stub.py`): downloads the chosen IPSW (or OTA asset - used for the 14.8.3/M3 path), picks the `BuildIdentity` matching this board/chip/`macOS Customer`/`Erase` variant, then extracts into the stub: `bootcaches.plist`, `PlatformSupport.plist`, `SystemVersion.plist` (marked "(stub)"), `BootabilityBundle`, firmware manifests + kernelcache `.im4p`s into Preboot's restore bundle, and `arm64eBaseSystem.dmg` into the Recovery volume - this *is* the paired recoveryOS for the new OS. Copies `AdminUserRecoveryInfo.plist` from the user's macOS Preboot into the stub's Preboot (that's how the paired recovery authenticates you later), `schg`-locks it, installs `Finish Installation.app` + `step2.sh`, `.IAPhysicalMedia`, sets `fsctl` bootable. Firmware blobs (Wi-Fi, Bluetooth, multitouch, ISP, kernel-attached, ALS) are collected into a `vendorfw` package for the Linux side.
6. **OS partitions:** per `installer_data.json` os-list entry, `diskutil addPartition` raw GPT partitions; EFI partition formatted `newfs_msdos -F 32 -I <fixed volume-id>`; partition images (`root.img` etc.) dd'd straight to `/dev/r<part>`; `expand: true` partition takes the user's chosen size minus stub.
7. **Boot object:** stage-1 `m1n1.bin` + appended vars (`chosen.asahi,efi-system-partition=<ESP PARTUUID>`, `chainload=<ESP PARTUUID>;m1n1/boot.bin`) written as `boot.bin` into the stub's `Finish Installation.app` resources.
8. **Hand-off:** `bless --setBoot --device /dev/<stub system volume>` with your macOS admin credentials → stub becomes default boot → shutdown. (If run from an *unpaired* recoveryOS, it first calls `bputil -g -v <vgid>` to set Reduced Security; if run inside the paired 1TR already, it runs step2 immediately.)

### Stage 2 - paired 1TR ("Finish Installation")
User powers on holding the button → "Loading startup options" (1TR) → picks the new OS volume → boots into its paired recoveryOS → `Finish Installation.app` → `step2.sh`:
- Verifies `bputil -d` shows `: Paired` **and** `one true recoveryOS`; if not, re-`bless`es and makes you retry.
- `bputil -nc -v <VGID>` → sets **Permissive Security + custom kernel** on the stub VGID (authenticate with the macOS admin credentials).
- `kmutil configure-boot -c boot.bin --raw --entry-point 2048 --lowest-virtual-address 0 -v <system_dir>` → registers m1n1 stage1 as the custom kernel.
- Restores `SystemVersion.plist`/media plist, reboots → machine now boots: iBoot2 → m1n1 stage1 → chainloads ESP's `m1n1/boot.bin` (m1n2 stage2 + DTBs + U-Boot) → UEFI → GRUB/BOOTAA64 → Linux.

Failure mode note (verified in step2.sh): wrong recoveryOS → "not paired" errors; boot loop/"needs reinstall" → shut down, power-hold, retry; worst case documented escape is the double-tap-hold trick into System Recovery; catastrophic recovery breakage → DFU revive from another Mac or `idevicerestore`.

### The resulting layout (Fedora Remix reference install)
| GPT slot | Type | Size | Contents |
|---|---|---|---|
| 1 | `Apple_APFS_ISC` | - | Apple's iBoot system container (untouched) |
| 2 | APFS [Macintosh HD] | shrunk by resize | real macOS |
| 3 | APFS [Asahi Linux] | 2.5 GB | stub macOS (m1n1 stage1 + paired recoveryOS) |
| 4 | EFI | 500 MB | m1n1 stage2 + DTBs + U-Boot + GRUB core + vendorfw |
| 5 | Linux | 1 GB boot (Fedora) / - | Fedora: separate `/boot` |
| 6 | Linux | rest | root filesystem |
| last | `Apple_APFS_Recovery` | - | System Recovery/1TR (untouched) |

ALARM/Omarchy variants collapse boot+root into one Linux partition (see §6).

---

## 4. Installer support matrix & what blocks a new SoC

### Current support (verified, 2026-09-21)
| Family | Installer | Notes |
|---|---|---|
| M1 / M1 Pro/Max/Ultra | ✅ shipped (macOS ≥11.0-12.3 min) | Full support; regression platform for Omarchy MX (14" M1 Pro, `apple,j314s`) |
| M2 / M2 Pro/Max/Ultra | ✅ shipped (≥12.4-13.4) | Full support incl. Mac Pro |
| M3 family | ✅ just enabled - tag v0.9.2 (2026-09-14), min macOS **14.8.3**, dedicated OTA-asset firmware path | Kernel feature support still partial: GPU/display WIP, sleep broken (framebuffer limits), HDMI out WIP. Feature page still marks "Installer: WIP" - docs lag the tag |
| M4 family | ❌ `Installer: no`, everything TBA | Early bring-up only (NVMe/PCIe "signs of life"); Apple's changes broke Asahi's RE tooling (39C3, Dec 2025) |
| M5 / M5 Pro / M5 Max | ❌ not even in tables; no feature page exists | MacBook Pro M5 Pro/Max announced 2026-03-03 ("Fusion Architecture" dual-die, ships macOS 26.x Tahoe, N1 Wi-Fi 7 chip, TB5) |

### What technically blocks adding a new SoC (all verified in source)
1. **Device table:** `CHIP_MIN_VER` (chip_id → min macOS) and `DEVICES` (device_class e.g. `j514sap` → min macOS, expert flag) in `src/main.py`. M4/M5 IDs absent → hard exit before any disk work.
2. **Firmware source:** `IPSW_VERSIONS` - a curated list of Apple restore packages (12.3/12.3.1/13.5 full IPSWs; 14.8.3 as an OTA asset zip restricted via `devices=[...M3 ids]`). Each entry carries `min_macos`/`min_iboot`/`min_sfr` floors checked against live system firmware. For M5 Pro you'd need a ≥26.x asset whose BuildManifest contains a `BuildIdentity` matching the new `ApBoardID`/`ApChipID`/`DeviceClass` - the stub is literally synthesized from that package.
3. **Per-OS `supported_fw` filter** in `installer_data.json` (Fedora/ALARM currently `["12.3","12.3.1","13.5","14.8.3"]`; Omarchy `["13.5","14.8.3"]`) - must include the new firmware baseline.
4. **m1n1 stage1 must run on the chip** (chainloading build; new iBoot/ADT/SEP behavior each gen) and the kernel needs devicetree+drivers. This is the actual long pole - the installer plumbing is trivial next to it. M4/M5 "broke the existing Asahi reverse engineering tools" per 39C3 talk (Phoronix, ~2025-12-31); AppleInsider (2026-08-29) reports M4 WIP + "an early M5 version also created" internally.

---

## 5. Omarchy M native installer (Marcelo Alcantara)

**Announced:** [Introducing Omarchy M](https://omarchy.org/news/2026/09/introducing-omarchy-m/), DHH, 2026-09-11: "You download an app on macOS, it fetches the signed Omarchy release, carves out the partitions, and boots you into Omarchy alongside your existing macOS. No USB stick, no incantations."

**What exists today** (verified in repo [`maralcbr/omarchy-mx-mac`](https://github.com/maralcbr/omarchy-mx-mac), HEAD 2026-09-21; download page [maralcbr.github.io/omarchy-mx-mac](https://maralcbr.github.io/omarchy-mx-mac/)):

- `apps/omarchy-apple-installer/`: a **SwiftPM/SwiftUI macOS app** + root privileged helper (`com.omarchy.mx.installer.helper`, XPC), Developer-ID-signed and notarized (signing OU `T2C384FJBD`).
- It **embeds the Asahi installer as a pinned "engine"**: `Engine/source-lock.json` pins asahi-installer **v0.9.2** (signature-verified tag, commit `dffbb38`), m1n1 `06a4601a`, asahi-installer-data `42648e71`, plus exact hashed build inputs (Python 3.13.9 pkg, libffi, cacert) and a downstream patch + `omarchy_*.py` overlay producing a reproducible `installer-v0.9.2-omarchy.17.tar.gz`.
- Flow mirrors Asahi mechanically (overlay `omarchy_stage1.py`): journaled stage-1 with checkpoints `apfs-target-prepared` → `stub-and-esp-installed` → `recovery-handoff-prepared` → `awaiting_recovery`, then the same **user-completes-1TR** handoff ("follow the app's Recovery instructions" on the download page). Underneath it calls the Asahi internals: `resizeContainer`, `addPartition`, `StubInstaller`, `bless`. There is also a `Replace` flow and in-app removal (`OmarchyRemoval.swift` → `diskutil apfs deleteContainer` + partition deletion).
- **Trust model on top:** ed25519 trust root → signed per-channel **support catalog** (`catalog.signed.json` from downloads.aicodelabs.com.au, channels `stable`/`rc`) → exact size+SHA-256 of the OS payload → device **model allowlist**; host check `MacHostInspection.swift` hard-rejects `apple,j614s` (M4 Pro MBP) and anything not in the catalog. Current RC image `os-v4.0.3-mac.1.20260913`; payload ≈3.4 GB zip with EFI (500 MB, vol-id `0x4f4d5801`), `boot.img` (2 GB), `root.img` (32 GB, expands).
- **Maturity:** past "alpha" (Sept 7-12 demo posts; ~5-min M1/M2 install video amplified by DHH). Repo docs record real hardware qualification: 2026-08-27 matrix - stage-1 + 1TR completed on the M1 Pro canary into Omarchy's initramfs (a root-selector bug failed Switch Root then; since fixed - download page now says end-to-end physical install confirmed on an M2 Max; RC as of 2026-09-13). Regression host: M1 Pro (`j314s`); M2 Max also physically tested. README: tested on M1, M2, **and M3**.

**Does it generalize to new SoCs?** Structurally yes - the catalog + pinned-engine model means enabling a new SoC = upstream Asahi engine support + a new model entry in the signed catalog + qualification evidence. But it adds *no* independent capability: no M4/M5 until the Asahi engine supports them (their own gate keeps `j614s` fail-closed "until official support and physical qualification both exist" - `docs/apple-silicon-m4-integration-matrix.md`). For omarchy-m5 this is the obvious upstream to track rather than to fork.

---

## 6. asahi-alarm.org path (the current M1/M2 Omarchy route)

Verified: `installer-bootstrap.sh` (fetched 2026-09-21) is the **same Asahi installer**, just pointing `INSTALLER_DATA`/`REPO_BASE` at asahi-alarm.org (`REPORT_TAG=alarm-prod`, installer version currently v0.9.2 - same tag as upstream). Its `installer_data.json` os-list: *Asahi Alarm Minimal* (ext4), *Minimal (BTRFS: @ + @home)*, *Desktop* (Calamares picks KDE/GNOME/XFCE/MATE/LXQt/**Hyprland** at first boot) - EFI 500 MB + single expandable Linux root (min ~2.06 GB), `supported_fw` = 12.3-14.8.3.

So partitioning-wise it is identical to §3: same stub/1TR/kmutil mechanics; only the OS payload differs. Omarchy then lands on top via script - two actively maintained variants:
- [`omarchy-mac/omarchy-mac`](https://github.com/omarchy-mac/omarchy-mac) (`quattro` branch): `bin/omarchy-mac-setup` one-shot → btrfs migrate + optional **LUKS2** in-place (`cryptsetup reencrypt`), snapper `@factory` snapshot. Requires ≥50 GB free (100 GB recommended), M1/M2.
- [`maralcbr/omarchy-mx-mac`](https://github.com/maralcbr/omarchy-mx-mac): `install-omarchy-mx-mac.sh` → verifies signed release metadata (immutable channel/manifest/checksums) then installs Omarchy 4 over the Asahi Arch Minimal base - same flow the app automates.

The older manual path (basecamp/omarchy Discussion #155, 2025-07-13): same bootstrap, then hand-edit upstream Omarchy install.sh (`set -e` off) to skip non-aarch64 packages - now obsolete.

---

## 7. Manual / "unsafe" paths for unsupported hardware (incl. an M5 Pro dev path)

What exists and what it costs:

- **Historical pre-installer path (early 2021, M1):** the Asahi [Developer Quickstart](https://asahilinux.org/docs/platform/dev-quickstart/) documents the manual layout used before the installer existed: `diskutil apfs resizeContainer disk0s2 200GB` → `diskutil addPartition disk0s2 APFS Linux 80GB` → install a **full second macOS** into it (needed 80 GB then; the 2.5 GB stub came later), → FAT32 `/boot` + root partitions → 1TR + `bputil`/`kmutil`. That is the proven ancestor of today's flow - and the template for doing it by hand.
- **m1n1-as-custom-kernel by hand** ([m1n1 User Guide](https://asahilinux.org/docs/sw/m1n1-user-guide/)): create/prepare an APFS OS volume (stub-shaped), copy `AdminUserRecoveryInfo.plist`, boot paired 1TR, then `kmutil configure-boot -c m1n1-stage1.bin --raw --entry-point 2048 --lowest-virtual-address 0 -v <OS volume>`. m1n1 even ships `scripts/kmutil.py` - a host-side webserver you `sh <(curl …)` from 1TR to configure-boot a fetched binary. This skips the *installer*, but **not** the security ceremony: you still need a stub volume group, paired recoveryOS, 1TR, and Permissive policy.
- **Tethered/dev boot:** the Fedora os-list has an expert-only "Tethered boot (m1n1, for development)" entry, and m1n1's proxy mode (USB device on the TB ports → `proxyclient`/`run_guest.py`, chainload via `chainload.py`) is exactly how Asahi devs bring up new silicon - a 7-second kernel test cycle without touching boot policy per iteration, once an initial fuOS m1n1 is in place.
- **What a real M5 Pro path would take** (inferred from source + project history): (a) add chip_id + device classes to a forked installer, (b) add a macOS 26.x IPSW/OTA asset containing the M5 Pro BuildIdentity, (c) build m1n1 that survives the new SoC (the hard part - M4/M5 broke existing RE/hv tooling), (d) ≥ stage-1-only: for pure TTY/dev you could stop at m1n1 + proxy and skip U-Boot/GRUB entirely. The *partitioning* part of the problem is already fully solved machinery; nothing about the disk layout itself is SoC-specific.
- **Risks of going manual on unsupported metal:** wrong-recoveryOS → `not paired` kmutil/bputil failures; broken LocalPolicy/pairing → boot loop into "macOS needs to be reinstalled"; killing `Apple_APFS_Recovery` or the iBoot container → unbootable, DFU revive (needs second Mac or idevicerestore); Apple tooling dislikes out-of-order GPT entries created by Linux-side edits (fix order in fdisk expert mode). The polished installer exists precisely to keep you inside the safe subset - it has no partition-deletion code at all.
- Caveat verified in docs: chainloading only works for ESP on **internal** NVMe; external-drive boots rely on a stub on the external disk and are the expert path.

---

## 8. Recommended disk layout for `omarchy-m5`

Assuming eventual upstream M5 support (or a dev stub while bring-up happens):

```
disk0s1  Apple_APFS_ISC                      (untouched)
disk0s2  APFS [Macintosh HD]  - resize, keep ≥38 GB free headroom (installer enforces)
disk0s3  APFS [Omarchy]       2.5 GB  stub macOS (paired recoveryOS + m1n1 stage1)
disk0s4  EFI                  500 MB  m1n1 stage2 + DTBs + U-Boot (+ GRUB core) + vendorfw
disk0s5  Linux [boot]         1-2 GB  optional; Omarchy app uses 2 GB boot.img; Fedora uses 1 GB
disk0s6  Linux [root]         rest    btrfs (@, @home, @log) - LUKS2 if encrypted
disk0s7  Apple_APFS_Recovery               (untouched, last)
```

Sizing notes: stub is fixed 2.5 GB (install-time constant `STUB_SIZE`); ESP ~500 MB (never encrypted - it must stay readable by m1n1/GRUB); Omarchy-MX image wants ≥~37 GB root and expands to whatever you grant; give macOS ≥30-38 GB free for updates (installer floor is 38 GB for OS containers, relaxed on 128 GB SKUs).

**Encryption:** FileVault (macOS side) is per-volume APFS-level, fully compatible - resize works on FileVaulted containers; the stub is unencrypted by design; while running Linux the SEP withholds keys so macOS data is unreachable (feature, not bug). Linux side: LUKS2 on the root partition, applied post-install (omarchy `omarchy-system-btrfs-migrate --encrypt` does in-place `cryptsetup reencrypt`; GRUB's prefix must live on the unencrypted vfat ESP/boot - their docs note why). Note that under Permissive Security, `boot-args` is user-modifiable (m1n1 docs) - treat the boot path as untrusted for threat-model purposes; LUKS passphrase is still required at every Linux boot.

**Rollback/uninstall:** set default boot back to macOS (System Settings or Option at boot picker), then delete the stub APFS container + EFI + Linux partitions (`diskutil apfs deleteContainer` + `deletePartition`; the Omarchy app already automates this). Never touch slots 1 or last. macOS grows back into free space via `diskutil apfs resizeContainer disk0s2 0`. Everything outside the three/four created partitions is untouched.

---

## 9. Risk table

| Risk | Likelihood | Severity | Mitigation / note |
|---|---|---|---|
| Trying the Asahi/Omarchy installer on M5 Pro today | certain failure | none (fails closed before disk changes) | device table gate → "not supported yet"; safest possible refusal |
| APFS resize fails / freezes | medium | low-medium | pre-existing APFS corruption or TM snapshots/pending updates are the usual causes; First Aid in recoveryOS; `tmutil` snapshot cleanup; "may appear to freeze - normal" |
| Selecting wrong recovery in 1TR step | medium (user error) | low | step2 detects `: Paired`/`1TR`, re-blesses and retries; worst case reboot loop, not data loss |
| Deleting `Apple_APFS_Recovery` / iBoot container | low | critical | → unbootable, DFU restore (other Mac or `idevicerestore`); cheatsheet warning; only possible via manual partition surgery, never via the installer |
| Breaking LocalPolicy/pairing with manual `bputil`/`kmutil` | medium on manual path | high | Eclectic Light: bputil misuse is the classic DFU-restore trigger; paired-1TR requirement enforced by SEP |
| macOS 27 boot-picker hiding stub | n/a - handled | low | installer action `7` re-applies `fsctl` bootable flag (code-verified; new macOS version sensitivity - watch every major macOS upgrade) |
| macOS upgrade breaking Linux boot | low-medium | medium | macOS updates can drop/replace boot policy bits → keep internal macOS install for repairs (Asahi FAQ); m1n1 upgrade path (`m` action) exists |
| Unencrypted boot chain tampering | - | medium | Permissive policy + writable boot-args = boot path untrusted; LUKS still protects root data |
| Manual M5 dev path (forked installer + hand kmutil) | n/a | high | can desync stub/recoveryOS pairing on an unsupported chip; DFU risk; keep on canary hardware, expect no upstream support |

---

## 10. Sources (all accessed 2026-09-21)

Primary code:
- `AsahiLinux/asahi-installer` @ `dffbb38` (tag v0.9.2, 2026-09-14 "Do not require expert for M3"): `src/main.py`, `src/diskutil.py`, `src/stub.py`, `src/osinstall.py`, `src/osenum.py`, `src/system.py`, `src/m1n1.py`, `src/step2/step2.sh`, `scripts/bootstrap-prod.sh`. https://github.com/AsahiLinux/asahi-installer
- `asahi-installer-data` prod `installer_data.json` (os-list, Fedora Remix 44 images, supported_fw). https://github.com/AsahiLinux/asahi-installer-data
- `asahi-alarm.org/installer-bootstrap.sh` + `installer_data.json` (live, 2026-09-21; installer ver v0.9.2, REPORT_TAG alarm-prod).
- `maralcbr/omarchy-mx-mac` @ HEAD 2026-09-21 (`3d88b31`): `apps/omarchy-apple-installer/` (Swift app, `Engine/source-lock.json`, `omarchy_*.py` overlay, `Release/release.json`), `docs/apple-silicon-m4-integration-matrix.md` (2026-08-27). https://github.com/maralcbr/omarchy-mx-mac
- `omarchy-mac/omarchy-mac` `quattro` README + `docs/btrfs.md` (LUKS2/btrfs/ESP constraints). https://github.com/omarchy-mac/omarchy-mac

Docs:
- Asahi docs: Partitioning Cheatsheet, FAQ, m1n1 User Guide, Apple Silicon Boot Flow, Asahi Boot Process, Open OS Platform Interoperability, Dev Quickstart, M3/M4 feature-support pages. https://asahilinux.org/docs/
- Fedora Asahi Remix page (device support: "All M1 and M2 series"). https://asahilinux.org/fedora/
- Apple Platform Security - startup disk security policy / Permissive Security. https://support.apple.com/guide/security/startup-disk-security-policy-control-sec7d92dc49f/web
- OpenBSD 7.8 `INSTALL.arm64` - Apple Silicon section (piggybacks on Asahi "UEFI environment only"). https://cdn.openbsd.org/pub/OpenBSD/7.8/arm64/INSTALL.arm64
- Eclectic Light Co on `bputil`/LocalPolicy (2024-04-01, 2024-09-09, 2022-11-21).

Announcements/press:
- Omarchy: "Introducing Omarchy M" - DHH, 2026-09-11. https://omarchy.org/news/2026/09/introducing-omarchy-m/
- Omarchy MX Mac download/RC notes (image `os-v4.0.3-mac.1.20260913`; M2 Max end-to-end install). https://maralcbr.github.io/omarchy-mx-mac/
- Omarchy Central: "Omarchy on Apple Silicon: M1/M2 Install in About Five Minutes Hits Alpha" - 2026-09-12. https://omarchycentral.com/news/omarchy-apple-silicon-m1-m2-alpha-install-dhh/
- tbreak: "Omarchy M: Linux on Apple Silicon Macs" - 2026-09-12. https://tbreak.com/omarchy-m-apple-silicon-linux/
- Apple Newsroom: M5 Pro/Max debut - 2026-03-03. https://www.apple.com/newsroom/2026/03/apple-debuts-m5-pro-and-m5-max-to-supercharge-the-most-demanding-pro-workflows/
- AppleInsider: "Asahi Linux nears M3 support release, M4 and M5 are on the way" - 2026-08-29. https://appleinsider.com/articles/26/08/29/asahi-linux-nears-m3-support-release-m4-and-m5-are-on-the-way
- Phoronix: "Asahi Linux … Apple M3/M4/M5 Bring-Up Still Ongoing" (39C3, Sven Peter) - ~2025-12-30. https://www.phoronix.com/news/Asahi-Linux-EOY-2025-CCC
- webpronews M3-support summary - 2026-09-08. https://www.webpronews.com/asahi-linux-brings-m3-macs-to-linux-but-gpu-and-sleep-remain-out-of-reach/
- Asahi "Passing the torch" (project priorities; new-hw deprioritized behind upstreaming/CI) - 2025-02-01. https://asahilinux.org/2025/02/passing-the-torch/
- Kaizen Musings M1 Max walkthrough - 2026-08-22. https://kaizenmusings.com/post/installing-omarchy-quattro-m1-max/
- basecamp/omarchy Discussion #155 (manual pre-MX path) - 2025-07-13. https://github.com/basecamp/omarchy/discussions/155

### Confidence notes
- **Verified (read in source):** every installer mechanic, size, command, gate, and flow in §2-§6; Omarchy app architecture incl. pinned engine, signed catalog, device fail-close on `j614s`; ALARM bootstrap = upstream installer; OpenBSD piggyback path.
- **Verified (official docs):** boot chain, 1TR/pairing requirement, security levels, recoveryOS-per-OS, FileVault-key withholding under fuOS.
- **Inferred:** exact M5 Pro chip-id/device-class (not yet public in installer tables - likely t8xxx/t6xxx successors and `j7xx` boards, but unverified); that an M5 Pro stub needs a macOS 26.x OTA/IPSW asset (strong inference - it's the only firmware source mechanism); timeline for upstream M4/M5 enablement ("a while" per 39C3 talk).
- **Watch items:** asahi-installer tags after v0.9.2 (M3 shipped this month - M4 could come faster than expected); Omarchy catalog `models[]` additions; whether macOS 27 changes bootability handling further (installer already has one fix for it).
