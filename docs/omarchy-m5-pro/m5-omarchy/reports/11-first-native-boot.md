# 11 — First native boot runbook (m5boot → our Linux on J714s)

This runbook prepares everything around m5boot. m5boot itself is written by the separate implementer session in `~/m5boot`. Results labels: **NATIVE**, **VM**, **REPORTED**. Nothing here has run yet.
- (!) = changes the Mac; needs explicit owner approval.
- = the owner clicks Run or types a password.

Assumed state (PM, 2026-11-04):
- The stub is created (08), and not yet armed.
- On the Mac: `~/omarchy-m5` @ `15cd70c1`, with `finish-install.sh` sha256 `f548b0af4862927635b4d93694cb52c336219e4afad31d51fe6fb5775a733105` (audited in 08).
- m5boot embeds `initramfs.cpio.gz` (`20eef155…`), `Image` (`d226395f…`) and the safe DTB (`23dabefb…`) (`~/m5boot/spec/inputs.md`).

## 1. Arming the stub with m5boot (over SSH)
**Pre-checks** (read-only, PM over `ssh macbook`). **STOP** if any check fails.
```sh
diskutil apfs list | grep -E 'Name:.*Omarchy'        # stub volumes present (Data/System/Preboot/Recovery)
shasum -a 256 ~/omarchy-m5/scripts/finish-install.sh # f548b0af…a733105
```
**Copy and verify** (on `work`). Set `M5BOOT` to the path the implementer reports:
```sh
M5BOOT=~/m5boot/build/m5boot.bin
sha256sum "$M5BOOT"                                    # record; must equal the implementer's published hash
scp "$M5BOOT" macbook:~/m5boot.bin
ssh macbook 'shasum -a 256 ~/m5boot.bin'               # must match
```
**(!) Arm the stub** (the owner types the sudo password, then the admin password for `bless`):
```sh
ssh -tt macbook 'cd ~/omarchy-m5 && sudo scripts/finish-install.sh --m1n1 ~/m5boot.bin'
```
- **Why this works with a non-m1n1 file** (08 / 10 §4):
  - `finish-install.sh` lines 129–135 check only that the file exists. The CHAINLOADING grep runs only for the vendor path.
  - Line 308 copies it to `Finish Installation.app/Contents/Resources/boot.bin`.
  - `step2.sh` lines 278–279 later run `kmutil configure-boot -c "$resources/boot.bin" --raw --entry-point 2048 --lowest-virtual-address 0 -v "$system_dir"`.
- **Expected output, in order:**
  1. `stub system volume: diskNsM (/Volumes/Omarchy)`, `stub VGID: <UUID>`
  2. `==> Remounting … read-write`
  3. `machine-owner admin for bless: <user> (candidates: …)`
  4. `==> Writing Finish Installation.app`
  5. `==> Installing m1n1 as …/boot.bin`, then an `ls -l` line showing m5boot's size. The "m1n1" wording is cosmetic.
  6. `==> Preparing Data volume + bootable flag`, `APFS bootable flag: 1`
  7. `==> Blessing the stub as the default boot volume` (password prompt)
  8. `==> Arming the install-media path`, a listing showing `.IAPhysicalMedia`
  9. `==> Done. VGID: <same UUID>`
- **Stop conditions:**
  - Any `ERROR:` line: e.g. `no System-role volume named 'Omarchy'`, `stub volume group is incomplete`, `restore bundle missing`, `bless failed - the ceremony cannot proceed`.
  - Any non-zero exit.
  - A `boot.bin` size that differs from `m5boot.bin`.
- **`bless --setBoot --user` over SSH: [HYPOTHESIS].**
  - No source says whether `bless` needs a GUI/console session on Apple silicon.
  - Third-party copies of the bless man page describe `--user` (owner username to authorize boot policy changes) and `--stdinpass` (read the password from stdin) ([bless.8 mirror](https://rust-digger.code-maven.com/src/gen-completions-0.6.0/tests/resources/man/expected/bless.json), [Apple bless.8](https://opensource.apple.com/source/bless/bless-166/bless.8.auto.html)).
  - Apple: changing startup security needs an admin who is a volume owner ([Apple deployment guide](https://support.apple.com/en-asia/guide/deployment/dep24dbdcf9e/web)).
  - With `ssh -tt` there is a TTY for the password prompt.
  - **Console alternative** if `bless failed` over SSH. The owner, at the Mac, opens **Terminal.app** and runs exactly:
    ```sh
    cd ~/omarchy-m5 && sudo scripts/finish-install.sh --m1n1 ~/m5boot.bin
    ```
    The script is idempotent and re-runs safely.
- **Undo before 1TR:** `sudo scripts/finish-install.sh --undo`, then System Settings → Startup Disk → Macintosh HD.

## 2. TSS signing check (read-only; the owner puts the Mac in DFU)
**Purpose:** prove that Apple's signing server will personalize this IPSW for this Mac. That's a precondition for a DFU restore from `work`.

**What `-t` does** (idevicerestore @ `ae8cfb4`, `src/idevicerestore.c`):
- Usage: "`-t, --shsh  Fetch TSS record and save to .shsh file, then exit`".
- Code: `case 't': client->flags |= FLAG_SHSHONLY`. The OS-image extraction is skipped (`if (needs_os_extraction && !(client->flags & FLAG_SHSHONLY))`). Stashbag handling only runs in `MODE_NORMAL`.
- After `get_tss_response()` it writes `<cache|.>/shsh/<ECID>-<ProductType>-<version>.shsh` (gzip), logs `SHSH saved to '…'`, and **`return 0`, before any restore step**.
- It **does** send a TSS request (with the device ECID and nonce) to Apple's signing server; that's the network call it exists for.

**Steps:**
1. **Owner, DFU entry** ([Apple 108900](https://support.apple.com/en-us/108900); port per [Apple 120694](https://support.apple.com/en-us/120694)):
   1. Cable `work`'s **USB 2.0 port** (the one that already showed Port DFU) to the Mac's **left-side, leftmost (rear) USB-C port**, next to MagSafe.
   2. Hold power ~10 s until the Mac is off.
   3. Press and release power, then immediately hold **left Control + left Option + right Shift + power** for ~10 s.
   4. Release all but power, and keep holding up to 10 s.
   5. The screen stays black.
2. **On `work`**, check detection (read-only):
   ```sh
   LD_LIBRARY_PATH=~/.local/dfu/lib ~/.local/dfu/bin/irecovery -q    # expect PRODUCT: Mac17,9, MODEL: j714sap, MODE: (Port) DFU
   ```
3. **usbmuxd** (root, foreground in its own terminal; `sudo` drops `LD_LIBRARY_PATH`, so pass it through `env`):
   ```sh
   sudo env LD_LIBRARY_PATH=$HOME/.local/dfu/lib $HOME/.local/dfu/sbin/usbmuxd -f -v
   ```
   Adjust `sbin/` → `bin/` to wherever the HEAD build installed it. In DFU, idevicerestore talks to the device through libirecovery; usbmuxd is needed for later restore-mode stages. Running it is harmless.
4. **TSS fetch:**
   ```sh
   mkdir -p ~/m5-recovery/cache
   LD_LIBRARY_PATH=~/.local/dfu/lib ~/.local/dfu/bin/idevicerestore -t -C ~/m5-recovery/cache \
       ~/m5-recovery/UniversalMac_26.6.2_25G83_Restore.ipsw
   ```
   **Success** = a line `SHSH saved to '…/cache/shsh/<ECID>-Mac17,9-26.6.2.shsh'` and exit 0. **Do not add `-e`, `-l`, `-y` or `-z`.**

   (!) Don't paste or commit the `.shsh` or its ECID-bearing filename (rule 6: identifiers).
5. Leave DFU: hold power ~10 s, then press power to boot normally.

**Status wording:**
- The DFU path is verified as far as **device detection/identification** (PM).
- After this step: **TSS signing verified**. Revive/restore stays **untested**.

## 3. 1TR ceremony for m5boot (owner, at the Mac)
Credentials: the **macOS admin user with FileVault access** (volume owner), name + password, several times.
1. `sudo shutdown -h now`, then wait 15 s.
2. **Press and hold** power in one motion until "**Loading startup options…**". Tapping twice gives the picker but not 1TR, and `step2.sh` refuses.
3. Select **Omarchy** (shown as an install item) → **Continue**. If asked, pick the admin user and enter the password.
4. Terminal opens running `step2.sh`. It prints `bputil -d` output; it must show `Paired` and `one true recoveryOS`.
   - If it says it isn't the paired recoveryOS: it re-blesses and shuts down. Repeat from step 1.
   - If no Terminal appears: **Utilities → Terminal**, then `"/Volumes/Omarchy/Finish Installation.app/Contents/Resources/step2.sh"`.
5. Enter → (!) `bputil -nc -v <VGID>`: credentials **twice**. This sets Permissive Security for the **stub only**.
6. (!) `kmutil configure-boot -c …/boot.bin --raw --entry-point 2048 --lowest-virtual-address 0 -v /Volumes/Omarchy`: credentials. **`boot.bin` is now m5boot**, and its hash goes into the stub's LocalPolicy `coih` ([Apple, LocalPolicy contents](https://support.apple.com/guide/security/contents-a-localpolicy-file-mac-apple-silicon-secc745a0845/web): "when they use the `kmutil configure-boot` command-line tool in 1TR").
7. "Installation complete. Press enter to reboot into m1n1." Press Enter (the wording is cosmetic). The Mac reboots into m5boot.
8. **Not needed:** `csrutil disable && nvram boot-args=-v`. That was the m1n1 USB-proxy backdoor, and m5boot has no proxy. Skipped as the conservative choice: fewer security changes.

## 4. First native boot observation
**Cable:** the same cable as DFU, `work` **USB 2.0 port** ↔ Mac **left-rear USB-C** (port 1, `hpm0` "left-back" in our ADT, 06B §2a). Our initramfs binds a CDC-EEM gadget on **every** UDC, so any port with a working DWC3 should appear. If nothing appears, move the Mac end to left-front, then right.

**What the owner sees on screen:**
1. m5boot's framebuffer step lines. The exact text comes from the implementer; per the spec, it starts by printing x0 / CurrentEL / SCTLR / PC, the pointer classification, the memory window and carveouts, the WDT value, a colour test pattern, and "jumping to Linux".
2. Then Linux on the framebuffer:
   - `Booting Linux on physical CPU 0x…`
   - `Linux version 7.2.2-g236788cd2602-dirty …`
   - `Machine model: Apple MacBook Pro (14-inch, M5 Pro, 2026)`
   - a `simple-framebuffer` / simpledrm line
   - DockChannel HID keyboard/trackpad lines
   - `=== m5 initramfs ===` with `nproc: 1`, `compatible: apple,j714s apple,t6050 apple,arm-platform`, `model: …`
   - `m5-gadget-net: udc=<x> netdev=usb0 me=10.55.0.2 host=10.55.0.1`
   - a busybox shell on tty0. The built-in keyboard should type.

**What `work` sees:**
- `lsusb` shows `1d6b:0104 Linux Foundation Multifunction Composite Gadget` (serial `m5pro-0`).
- `dmesg` shows `cdc_eem … usb0: register 'cdc_eem'` (the module is in the stock Omarchy kernel: `cdc_eem.ko.zst`, alias `ic02isc0Cip07`).
- Then:
  ```sh
  tools/host-usbnet.sh          # finds 1d6b:0104 serial m5pro-<n>, sets 10.55.<n>.1/24 (sudo), pings .2
  ssh root@10.55.0.2            # work.pub is authorized; dropbear generates host keys on first connect
  ```

**Failure triage:**

| Symptom | Most likely cause | Next action |
|---|---|---|
| Black screen, no m5boot text at all | H1 (raw entry state differs), H8 (fb not live or wrong format), H9 (size limit), or m5boot crashes before the console | Hold power → Macintosh HD. Implementer builds the minimal "console + test pattern only" object (spec §9) and re-arms (§1 + §3) |
| m5boot stops at step N | Read the last printed step: pointer classification (H4), BOOT_LINE_LENGTH (H3), ADT walk, carveouts (H5/H6), FDT patching, relocation | **Photo of the screen** → implementer. No retries that change anything else |
| Linux starts, then panics | Early mm/reserved-memory (wrong `/memory` or a missing carveout), the DT, idle/WFI | Photo of the panic. The `earlycon=efifb` output shows how far it got. Kernel/DT fix on our side, then re-arm |
| Linux reaches the shell but there's no USB gadget on `work` | Wrong Mac port, a USB 2-only cable issue, DWC3 not in device role, or UDC absent | On the Mac keyboard: `ls /sys/class/udc; dmesg \| grep -i dwc3`. Try the other ports. Check `lsusb` on `work` |
| Gadget appears but no ping | host-usbnet didn't match (serial), NetworkManager grabbed it, or the Mac side IP wasn't set | `ip -br a` on both ends; on the Mac, `m5-gadget-net` output on the console |
| Hang anywhere | — | Hold power → Startup Options → Macintosh HD (macOS's own LocalPolicy, untouched) |

## 5. After SSH works (AI-driven from here; NATIVE results)
```sh
# 1. installer guards only
ssh root@10.55.0.2 sh /bin/install-rootfs.sh --dry-run
#    expect: target /dev/nvme0n1pN size ~120000000000 B PARTUUID <uuid> (sector size 4096); "dry run, all guards passed"
# 2. (!) format + install the 120 GB Linux partition (owner approval: destructive to that partition only)
zstd -dc build/rootfs-alarm.tar.zst | ssh root@10.55.0.2 'sh /bin/install-rootfs.sh --yes'
#    rootfs sha256: see `~/m5boot/spec/inputs.md` (updated in task 14); expect "install-rootfs: done"
# 3. probes, read-only, one group per load, in order (09 §4)
for g in 1 2 4; do ssh root@10.55.0.2 "insmod /lib/modules/t6050_probe.ko groups=$g; dmesg | grep t6050_probe | tail -12"; done
ssh root@10.55.0.2 "insmod /lib/modules/t6050_probe.ko groups=8; dmesg | grep t6050_probe | tail -6"   # last: may SError
```
After any hang: power-cycle (the machine boots m5boot again), then continue with the next group.

**Switching to kernel iteration (loader initramfs + kexec):**
1. Implementer rebuilds m5boot with **`initramfs-loader.cpio.gz`** (`f11e0a88…`) and bootargs `… m5.loader=1 m5.root=/dev/nvme0n1pN`.
2. (!)Re-arm once: §1 + §3, a new `kmutil` hash.
3. From then on each boot does m5boot → loader initramfs → `m5-loader`, which kexecs `/boot/Image` on the installed root with `--dtb=/sys/firmware/fdt` (the DT m5boot patched).
4. Iterating on kernel/DT = `scp` a new `Image` (and optionally `m5.dtb` + `touch /boot/USE_FILE_DTB`) to `root@10.55.0.2:/boot/`, then reboot. **No owner step, no re-arm.**
   - Caveat [HYPOTHESIS]: kexec on Apple silicon is untested here.
   - If kexec fails, the loader stays in the initramfs (it says so), and SSH remains available.
