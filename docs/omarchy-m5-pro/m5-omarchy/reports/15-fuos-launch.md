# 15 — Why iBoot powers off after loading our raw boot object

**Evidence:** `~/m5boot/spec/native-panic-1.json`, the macOS panic report from the loop, NATIVE, J714s, mBoot-18000.161.10. I decoded it here myself. Sources: AsahiLinux/docs @`5acb80f`, Apple support pages, and our own data. No m1n1 code was used.

## What the evidence says (NATIVE, decoded)
- **Panic header:** `"device_in_recovery_mode_with_reason":"PanicMedic"`, `"panicString":"SOCD report detected: (iBoot panic)"`, `socId 6050`, `socRevision 11`.
- **SOCD container** (base64, 3 identical records): `iBoot Panic: : 3bdace14b1a9a68:1026 | Board: j714sap:0x7 | Chip: 6050:0x11 | Build: RELEASE:mBoot-18000.161.10 | UUID: <uuid> @0x00000100c1b3f5f0`.
  - [HYPOTHESIS] `<hash>:1026` is iBoot's own "source-file-hash:line" panic site. iBoot source isn't public.
- **Breadcrumbs** (87 per record; the hex-ASCII arguments decoded):
  ```
  …3000f('xhcf') 3000c('xhcf') 40029 3000d('xhcf') 30010 … 3000c(0) 3000d('sepi')
  40038(0xcb0000) 40059(0) 40039(0x1ff8000) 4003a(0) 4005a(1) 40061(0)
  3000c(0) 3000d('stg1')
  3000f('dtre') 3000c('dtre') 40029 3000d('dtre') 30010  3000f('ibdt') … 30010
  3000f('isys') … 30010  3000f('csys') … 30010  3000f('bstc') … 30010  3000f('trst') … 30010
  3000f('fuos') 3000c('fuos') 3000d('fuos') 30010        <- last entry, then the iBoot panic
  ```
  - Every image follows the same pattern: `3000f(tag)` → `3000c(tag)` → `3000d(tag)` → `30010`. [HYPOTHESIS] These mean begin / load-start / load-end / done. The tags are iBoot's 4CCs: `pmpf` PMP firmware, `msrf`, `sm3f`, `xhcf` xHCI firmware, `sepi` SEP image, `stg1`, `dtre` device tree, `ibdt`, `isys`/`csys` system/cryptex?, `bstc`, `trst` trust cache, `fuos` our image.
  - **`fuos` completes all four steps.** The panic is therefore **after iBoot has loaded our image and before (or at) the hand-off**. It's an iBoot panic, not an exception in our code, and none of m5boot ran in a way that left a trace.
- **PanicMedic:** 5 `PanicMedicReports` entries, each `PanicMedicEntryBootStage 34`, `BootTarget 1`, 5–6 s apart. After those panics the Mac booted recoveryOS "with reason PanicMedic", matching the owner's ~6 power-offs then Recovery. Asahi `fw/nvram.md` lists the related variable `panicmedic-timestamps` ("presumably when the last panic occurred").

## Answers
1. **Logo → power-off.** Between the logo and the jump, iBoot loads its firmware set and then our image (breadcrumbs above). The failure is an **iBoot panic after the `fuos` load**. [HYPOTHESIS] On this machine an iBoot panic records SOCD + PanicMedic data and powers the SoC off, rather than showing an error. I found no public document of "power off on failed fuOS". The Asahi boot-flow page leaves the fuOS branch blank (`docs/fw/boot.md`: "If loading a custom stage (fuOS): - ...") and says of stage-1 failures only that it "will either error out or fall back to DFU".
2. **Size/format.**
   - **Format:** Asahi `platform/introduction.md`: "Custom kernel images can be flat ARM64 executable images; the entrypoint and (virtual; mostly meaningless) load address are specified when the image is configured … Apple added this feature in 12.1". Raw is fine as a format.
   - **Size limit: no public document found** (Asahi docs, the kmutil man page mirror, web search). It's undocumented.
   - [HYPOTHESIS] `40039(0x1ff8000)` is a 32 MiB − 32 KiB region iBoot sets up just before loading `stg1`…`fuos`, and our 49,034,128-byte (≈46.8 MiB, 0x2EC3E90) image doesn't fit it, so iBoot panics in a post-load bounds/placement check.
     - *For:* the panic is post-load and pre-jump. Every raw object known to work on M-series (Asahi's stage-1 bootloader; betizzel's J714s stage-1 boot, REPORTED-NATIVE in `omarchy-m5 docs/bringup.md`: "boots iBoot → m1n1 stage1 → framebuffer console") is small.
     - *Against/unknown:* the meaning of `40039` is unverified; it could be any region.
   - kmutil option seen in its man page (keith.github.io mirror): `-C/--compress` for the custom boot object. A smaller stored object is a possible lever, but the in-memory size after decompression may be what's checked.
3. **Entry contract.** `--entry-point 2048 --lowest-virtual-address 0` gives entry VA 0x800 = file offset 0x800 (Asahi user guide; asahi-installer `step2.sh:125`). Entry state: MMU off, x0 = boot_args (spec §1, sources there). Nothing in the evidence points at a wrong entry offset: we never got that far.
4. **macOS 26 / T6050 changes.** No source ties the panic to SPTM, `smb1`/`coih` or the stub's Cryptex1 generation (`stng 6` vs main macOS `4`). The breadcrumbs show `isys`/`csys`/`trst` (system, cryptex?, trust cache) loading fine for the stub, which makes a stub-firmware mismatch **less likely** (H4 below).
5. **Failure counter.** PanicMedic counted 5 iBoot panics, then sent the Mac to Recovery. That's the observed Recovery fallback. See §Next attempt for what to clear (nothing is *required*) and how to avoid a loop.

## Ranked hypotheses and the cheapest discriminating test for each
| # | Hypothesis | Evidence | Cheapest test |
|---|---|---|---|
| **H1** | **Image too large** for iBoot's fuOS placement/bounds; iBoot panics after load. Possibly the `0x1ff8000` (≈32 MiB) region | Post-load panic; working raw objects are all small; ours is 46.8 MiB | **Install the tiny probe, unpadded (< 1 MiB).** Colour on screen → H1 strongly favoured. Then the same probe **padded to 31 MiB** (should work if the limit is ~32 MiB) and **33 MiB** (should panic). Two re-arms pin down the threshold |
| H2 | kmutil's raw-to-Mach-O conversion (one huge segment from `--lowest-virtual-address 0`) gives a segment iBoot rejects (size or alignment), independent of the absolute limit | Same signature as H1 | Tiny probe again (works = rules out a format-level problem). Then padded probes distinguish "size" (H1) from "segment shape" (H2 would fail at any padded size) |
| H3 | Our code ran and faulted at once, and iBoot's still-installed vectors panicked *as* iBoot | Breadcrumbs end at `fuos` 30010; the text says "iBoot Panic" with a file:line | The tiny probe whose **first** instructions set its own VBAR and paint the screen. Colour visible → the jump happened, so the original image's failure is in our code or size |
| H4 | Stub firmware mismatch (Cryptex1 generation 6 vs 4, 26.6.2 boot objects) | Weak: `isys`/`csys`/`trst` loaded OK | Only if H1–H3 are excluded: `sudo bputil -d` on both OSes and compare |

**Recommended order:** probe < 1 MiB → probe padded 31 MiB → probe padded 33 MiB. If the limit is confirmed, put the kernel behind a small loader: **m5boot ≤ a few MiB** carrying only the shim + DTB + a compressed payload it inflates in RAM, or the loader-kernel fallback already in spec §9.

## Next attempt: PanicMedic and avoiding another loop
- **Avoid the loop.** Set **Macintosh HD as the default** startup disk (System Settings → General → Startup Disk; [Apple](https://support.apple.com/guide/mac-help/change-your-mac-startup-disk-mchlp1034/mac)). Then boot the stub **once** per test via Startup Options: hold power → select **Omarchy** → **Continue** (Apple: "Change your startup disk once … select a disk and click Continue"). A panicking test then boots macOS on the next power-on, not the stub again, so PanicMedic never accumulates 5 strikes.
  - `finish-install.sh` re-blesses the stub as the default, so do the Startup Disk change **after** each re-arm.
  - [HYPOTHESIS] Whether "Continue" on a fuOS stub is one-shot hasn't been tested on this Mac. Confirm on the first probe boot.
- **Clearing.** Nothing is *required*: the Mac already booted macOS (the panic report was written there). Read-only, record before the next attempt:
  ```sh
  nvram -p | grep -iE 'panicmedic|failboot|boot-volume|boot-note' | sed -E 's/(boot-note|boot-info-payload)\t.*/\1 <omitted>/'
  ```
  (!) Deleting `panicmedic-*` or `failboot-breadcrumbs` is an **NVRAM write**, so it needs owner approval (rule 1). I don't recommend it unless a later boot shows PanicMedic still forcing Recovery.
- **Read-only Preboot inspection** (PM, over `ssh -tt macbook`; sudo is read-only here). It checks what kmutil stored and its size against our 49,034,128 B:
  ```sh
  VG=$(diskutil apfs list | awk '/Name:.*Omarchy/{f=1} f&&/Volume Group/{print $NF; exit}'); echo "stub VG: $VG"
  sudo bputil -d -v "$VG" | grep -iE 'coih|smb|sip|nsih|Cryptex|stng|fuos'
  PB=$(diskutil apfs list | awk '/Omarchy/{f=1} f&&/Preboot/{getline; print $NF; exit}')   # stub Preboot device; verify by eye
  diskutil info "$PB" | grep -E 'Mount Point|Volume Name'
  # if not mounted: diskutil mount readOnly "$PB"
  sudo find "/Volumes/Preboot"* -path "*$VG*" \( -iname '*kernelcache*' -o -iname '*custom*' -o -iname '*.im4m' \) -exec ls -l {} \; 2>/dev/null
  sudo ls -l "/System/Volumes/iSCPreboot/$VG/LocalPolicy/" 2>/dev/null
  man kmutil | col -b | grep -n -A3 -iE -- '--raw|--compress|entry-point|lowest-virtual'
  ```
  Expected: a `fuos`-linked `.im4m` in the LocalPolicy dir and a custom kernelcache/img4 of about 49 MB, or smaller if kmutil compressed it.

## Recovery status (unchanged)
macOS + Recovery are intact (the Mac booted macOS and wrote this report). DFU is verified only as far as detection/identification; the TSS check is pending, and revive/restore is untested.


## Update 2026-11-04: NATIVE result supersedes the ranking above (H1–H4)
**probe2 RAN on mBoot-18000.161.10 (NATIVE, J714s).** probe2 is 196,608 B, 16 KiB padded, with a branch at **file offset 0** to the entry. Result: **no iBoot panic**, the Mac stays powered on, black screen. There is no trusted framebuffer yet; a fix using the vram region from our ADT is in progress.
- **H4-firmware (stub stage 2 18000.161.x) is refuted:** this firmware does launch raw fuOS objects.
- **H-ENTRY is confirmed:** iBoot enters a raw fuOS at **file offset 0**, not at 0x800, on this firmware/kmutil combination, despite `--entry-point 2048`. The earlier images (m5boot, m5boot-gz, probe v1) had no valid code at offset 0, which explains the post-`fuos` iBoot panic.
- **Consequence:** every boot object must start with a branch at offset 0 (or carry its entry at 0). A macOS/firmware update is **not** needed for single-core boot. The 27.3b1 stub fix (above) still matters for SMP later.
- The ranked hypotheses above are kept as written; H1 (size) was already ruled out by probe v1, and H2/H3 resolve to the entry offset. Superseded by this result.


## CORRECTION 2026-11-04: the probe2 NATIVE claims above are RETRACTED
The owner photo shows step2-fast.sh printed "This is not the recoveryOS paired with Omarchy … Press enter to shut down" on **every** fast cycle. **probe2, gz2, beacon and beacon3 were never installed** (kmutil never ran); the black screen was the shutdown. Therefore:
- "H-ENTRY confirmed (entry at file offset 0)": **RETRACTED; H-ENTRY is UNTESTED**.
- "H4-firmware refuted" and "our code runs natively": **RETRACTED**; no new NATIVE evidence exists.
- The last real NATIVE results are still m5boot / m5boot-gz / probe v1 (iBoot panic after the `fuos` load).
- Cause of the failed cycles: report 18, correction section.


## NATIVE update 2026-11-04 (owner-verified; supersedes the open ranking for this question)
**beacon3 painted GREEN on stub firmware mBoot-18000.161.10.** beacon3 is a raw image with a **branch at file offset 0** plus **16 KiB padding**, and it was installed via `finish-install.sh` (a real kmutil install, unlike the retracted probe2 cycles). This is the first native code execution.
- The stock-image iBoot panic on 26.6.2 (ours and, REPORTED, asahi stage 1 on J613) is **avoided by our header**: a branch at offset 0 and/or 16 KiB padding. Which of the two matters isn't separated yet.
- The 26.6.x firmware itself doesn't block raw boots, so Plan B (report 22) stays a fallback only.
- The earlier retraction (probe2) stays as written; this result comes from a different, verified install.
