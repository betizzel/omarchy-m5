# 59 — Omarchy-for-M5-Pro installer: plan + dry-run skeleton

**Bottom line:**
- **This is one documented flow from stock macOS to an Omarchy desktop**, built only from pieces we already have plus betizzel's MIT stub scripts.
- **Three phases:**
  - (1) a scripted macOS phase (`tools/install/m5-omarchy-install.sh`), with dry-run and hash verification;
  - (2) the single 1TR step, done by the owner at the Mac;
  - (3) first boot.
- **No Asahi installer:** none of its code is used. Asahi's installer and upstream m1n1 are not used.
- **Status:** the skeleton runs `--dry-run` only and refuses anything else. Nothing on the Mac was touched.

## Pieces reused (and their licences / AI rules)
| Piece | Source | Licence / AI instructions | Role |
|---|---|---|---|
| `prep-stub.sh` `ef36f4f4…` | betizzel omarchy-m5 @15cd70c (`src/omarchy-m5`) | SPDX MIT header; no CLAUDE/AGENTS/GEMINI.md in the repo | Shrinks the macOS APFS container, then creates the 6 GB stub "Omarchy" (Data/System/Preboot/Recovery cloned from this Mac's own restore bundle, no IPSW download), the EFI partition and (`--linux-size`) the Linux partition. It picks partitions by type, not by disk0sN. |
| `finish-install.sh` `f548b0af…` | same | MIT | Arms the stub: installs our file as `Finish Installation.app/…/boot.bin` (audited in reports 08 and 11: it only checks that the file exists), blesses the stub, and writes `step2.sh` for 1TR. |
| m5boot **gz16** `7a2d134f…` (7,061,504 B) | `~/m5boot` | ours | The fuOS raw image. It patches the FDT, kexecs `m5next/` from the ESP if present, and otherwise boots its embedded default. |
| Omarchy rootfs `rootfs-omarchy.ext4(.zst)` `927400aa…` / `c35fd888…` | reports 13 and 27 | Omarchy's own image recipe (omacom builder, MIT); signed ALARM + Omarchy packages | `LABEL=omarchy`; first-boot online resize; SDDM autologin into Hyprland (uwsm) on simpledrm/llvmpipe |
| initramfs `m5.root=s5` + guard + ESP loggers | reports 27 and 34 | ours | Root = the single Linux-type partition of **exactly 120,000,000,000 B** with an ext4 `omarchy` label; the auto-reboot guard; `m5log/` |
| ESP drop-ins (`m5drop/`) | e.g. `tools/rootfs/m5drop-usbnet` (report 57) | ours | Copied into the rootfs at boot (SSH-over-USB, etc.) |

**What we take from Omarchy itself:** its installer logic (`omarchy-apply-system`, settings, packages) already runs **at image build time** (report 13: `--defer-provisioning --first-install`). The Mac never runs a package install, and user provisioning happens on Omarchy's own first boot. The installer copies the image; it doesn't rebuild it.

## Phase 1: from macOS (scripted, `--dry-run` first)
`tools/install/m5-omarchy-install.sh --dry-run --bundle DIR` prints each step. The real mode is a TODO and will need owner approval for steps 1–4.

0. **Preflight (read-only):**
   - checks: `hw.model` = Mac17,9; macOS version; `diskutil list` / `apfs list`; free space ≥ stub 6 GB + ESP 500 MB + Linux 120 GB;
   - spots an existing install (stub 'Omarchy', an EFI of 200–1100 MB, a Linux partition of exactly 120 GB), in which case it skips steps 1–2;
   - checks every artifact in the bundle against its **pinned sha256** and aborts on any mismatch.
1. (!) `sudo prep-stub.sh --linux-size 120000000000B`, then record STUB, EFI and LINUX by type and size.
2. (!) `sudo finish-install.sh --m1n1 m5boot-gz16.bin`, then check that the boot.bin size matches.
3. (!) **Rootfs to LINUX only:**
   - check `diskutil info` (Linux Filesystem, 120,000,000,000 B, 4096-B blocks);
   - decompress to a file first. macOS has no zstd, so the bundle ships a static zstd or a gzip variant (TODO);
   - `dd of=/dev/r$LINUX bs=4m`;
   - **read back and check**: the first 4,746,384 × 4 KiB blocks must hash to `927400aa…`.
4. (!) **ESP:** mount; `mkdir m5log m5drop`; unpack `m5drop.tar`; optionally an `m5next/` kernel set with its SHA256SUMS. **Never create `m5stay/`** (it disables the guard); unmount.

## Phase 2: the single 1TR step (owner, at the Mac; from report 11 §3)
1. `sudo shutdown -h now`; wait 15 s.
2. **Press and hold** power until "Loading startup options…". A double tap is not enough.
3. Select **Omarchy** → Continue. Pick the FileVault admin user and enter the password.
4. Terminal runs `step2.sh`. Its `bputil -d` output must show **Paired** and **one true recoveryOS**. If it doesn't, the script re-blesses and shuts down; start again at step 1.
5. `bputil -nc -v <VGID>`: credentials twice. This sets Permissive Security for the **stub only**; macOS keeps Full Security.
6. `kmutil configure-boot -c "/Volumes/Omarchy/Finish Installation.app/Contents/Resources/boot.bin" --raw --entry-point 2048 --lowest-virtual-address 0 -v /Volumes/Omarchy`: credentials.
7. Enter to reboot. The "m1n1" wording is cosmetic. **No `csrutil disable`, no boot-args.**

## Phase 3: first boot
- **Boot chain:** iBoot → m5boot gz16 → (`m5next/` or the default) Linux → initramfs `m5.root=s5` → switch_root → systemd → SDDM autologin → Omarchy/Hyprland.
- **First boot jobs:** the online resize to 120 GB; journal and dmesg written to ESP `m5log/`.
- **Failure:** the guard or the watchdog returns to macOS. macOS stays the default-recoverable OS through Startup Disk.
- **Today's limits:**
  - simpledrm/llvmpipe only (no GPU);
  - input only once MTP is solved; until then USB-ECM SSH (report 57) and, after t-hw1, the SMC read-only.
  - `maxcpus=1`.

## Undo
- **Before 1TR:** `finish-install.sh --undo`, then Startup Disk → Macintosh HD.
- **After:** delete the stub container, the EFI and the Linux partitions, then grow disk0s2 (betizzel `docs/bringup.md` "Resizing or re-installing"). macOS data is untouched throughout.

## Next (TODO, in order)
1. `tools/install/mkbundle.sh`: bundle the pinned artifacts plus `m5drop.tar` and a macOS-usable decompressor, with a MANIFEST.
2. The real mode for steps 1–4: explicit `--yes-i-have-owner-approval`, a re-check of partition type and size right before every `dd`, and abort on any mismatch.
3. Replace the 120 GB magic size with a GPT partition name or UUID in the initramfs, so other sizes work. This needs an initramfs change and VM proof.
4. VM test of phases 1 and 3: the macOS steps can't be emulated, but the dd/verify and ESP layout can be checked against a disk image in the report 27 VM.

Labels: design and skeleton (VM: dry-run on ush only); all Mac behaviour cited from reports 11, 19 and 27 (NATIVE/REPORTED there).

## Addendum 2026-11-05 (PM 12:36): fold in omacom/omarchy-mac-installer
**Source and provenance:**
- **Where it is:** `ush:~/m5-ref/omarchy-mac-installer`. PM says commit `0fe0d90`; the copy has no `.git`, so I couldn't verify that here.
- **License:** MIT (`LICENSE`, © David Heinemeier Hansson; `Engine/RestoreImage/LICENSE` and `image-builder/LICENSE` are separate).
- **Its AGENTS.md:** obeyed.
  - Owner authorization is required right before any helper registration, privileged step, disk or boot-policy change, or physical-device work.
  - Public builds keep unqualified boards fail-closed. Unqualified boards are allowed only in `OmarchyDeveloperBuild`.
  - `./test/all` must stay unprivileged.
- **Read:** only the app's own Swift, Python and scripts. **Not read:** `Engine/overlay/m1n1` and the m1n1 submodule.

**What it is:**
- **Engine:** a SwiftUI app driving the **pinned Asahi installer v0.9.2**, i.e. `AsahiLinux/asahi-installer` @`dffbb38e`, signed tag `e9cea671`, MIT. Our clone in `src/asahi-installer` has no CLAUDE/AGENTS/GEMINI.md.
- **Integration:** an Omarchy Python layer in `Engine/overlay/src` (planner, stage1, recovery, image, firmware).
- **Restore-image helper:** in Swift.
- **Its own 1TR script:** `omarchy_asahi.py` replaces asahi-installer's step2.sh, running bputil in the foreground and kmutil hidden with scripted answers.
- **Note on the earlier plan:** this supersedes report 59's "no Asahi installer" line. The PM now directs that the Asahi engine be reused through this app. The m1n1 *payload* stays unused, per CLAUDE.md rule 7.

**Reuse as-is (HYPOTHESIS until it is run on a Mac):**
- APFS resize and partition planning;
- stub OS creation through the restore-image helper (its own IPSW/restore path, instead of betizzel's local clone);
- ESP creation;
- the 1TR flow (`bputil -nc` + `kmutil configure-boot`);
- Recovery and removal (`OmarchyRemoval*`);
- owner prompts and dry-run/test fixtures.

**Change for the M5 Pro (fork or developer build only, so public builds stay fail-closed):**
1. **Device admission:**
   - `scripts/supported-models.json` gains `apple,j714s` under `developer` (not `supported`);
   - `omarchy_execution.UNSUPPORTED_DEVICES` keeps j614s and doesn't list j714s;
   - the engine's device and chip tables need a **T6050 / j714sap** entry (v0.9.2 has none; it refuses even the M3 Ultra j575d for the same reason).
2. **Boot object:** the engine's m1n1 stage-1 is replaced by **m5boot gz16** (`7a2d134f…`). The kmutil call shape is already the same as ours (`--raw --entry-point 2048 --lowest-virtual-address 0`, reports 11 and 19). The engine must not install an m1n1 stage 2, U-Boot or GRUB on the ESP.
3. **ESP payload:** our layout (`m5log/`, `m5drop/`, optional `m5next/`) replaces Asahi's stage-2 files. m5boot currently boots its embedded loop kernel and then kexecs `m5next/`. **The desktop kernel + DT + initramfs should be the default boot**, a small m5boot change for the m5boot session.
4. **Rootfs:** our `rootfs-omarchy.ext4` (report 27) goes in as the image payload, with Omarchy userland built by Omarchy's own recipe.
   - The engine sizes the Linux partition itself, so **the initramfs's "exactly 120,000,000,000 B" root rule has to go.**
   - The replacement is a GPT partition UUID or name written by the installer and passed as `m5.root=PARTUUID=…`.
   - That needs an initramfs change and a VM proof.
5. **Firmware step:** the engine's `omarchy_firmware` (Wi-Fi/BT extraction) is kept but optional. N1 isn't supported yet.

**Next concrete steps (none touch a Mac):**
- (a) Fork it, add j714s as a developer board, and stub the engine's T6050 device entry (read-only research into the v0.9.2 `devices` format first).
- (b) Make a boot-object swap patch with tests in `./test/all`.
- (c) Make the m5boot default-boot change (ask the m5boot session).
- (d) Make the PARTUUID root and prove it in the VM.
- (e) Remove the 120 GB rule from `tools/install/m5-omarchy-install.sh`, the skeleton, which stays as the fallback path.
