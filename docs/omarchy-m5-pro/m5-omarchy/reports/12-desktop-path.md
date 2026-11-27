# 12 — Desktop path: Omarchy on aarch64 without a GPU driver

**Labels:** NATIVE / VM / REPORTED / HYPOTHESIS. Nothing here has been tried on the J714s.

**Sources** (AI instructions and licenses checked):
- **omacom/omarchy-mac-pkgs** @ `7e50e93`: MIT; AGENTS.md has engineering rules only.
- **omacom/omarchy**: MIT. Pinned runtime `81fd2d23` (from `omarchy-mac-pkgs/test/integration/runtime`), default branch `quattro` @ `50bb5db3`. AGENTS.md has agent task guides, no AI ban.
- **omacom/omarchy-pkgs**: MIT.
- **hyprwm/aquamarine**, issues: public discussion.
- **docs.mesa3d.org**.
- **AsahiLinux/docs** @ `5acb80f`.

## 1. Omarchy on aarch64 (ALARM)

**Plain aarch64 is a first-class Omarchy platform.**
- `omarchy-hw-platform` (quattro `50bb5db3`) names it: "x86, aarch64, aarch64-apple, aarch64-qualcomm, aarch64-n1x or aarch64-gb10".
- omacom's CI resolves a **generic `aarch64` platform** daily (`omarchy-mac-pkgs/tools/package-resolution/platforms/aarch64`):
  - repos: `[omarchy]` `https://pkgs.omarchy.org/edge/$arch` + ALARM `[core] [extra] [alarm] [aur]`;
  - `lists=(install/omarchy-base.packages install/omarchy-aarch64.packages)`, `packages=(omarchy omarchy-settings linux)`;
  - `forbidden_repos=('asahi*' omarchy-aarch64)`; Mac-only packages are forbidden.
- The released aarch64 pacman template (`omarchy/default/pacman/aarch64/pacman-stable.conf` @quattro) has `SigLevel = Required DatabaseOptional`, then `[omarchy] Server = https://pkgs.omarchy.org/stable/$arch`, then ALARM `[core] [extra] [alarm]` via `/etc/pacman.d/mirrorlist`.
- **Keys** (`omarchy/bin/omarchy-update-keyring`):
  - Omarchy key `40DFB630FF42BCFFB047046CF0134EE680CAC571` (`pacman-key --recv-keys … --keyserver keys.openpgp.org`, `--lsign-key`, then the `omarchy-keyring` package);
  - ALARM key `68B3537F39A313B3E574D06777193F152BDBE6A6` (already in our rootfs; same key we verified in 09).
- **Package sets** at the pinned runtime: `omarchy-aarch64.packages` = `zram-generator rtkit`. `omarchy-x86_64-only.packages` is empty (all lines comments). `omarchy-base.packages` has 162 entries, including `hyprland`, `quickshell`, `uwsm`, `sddm`, `plymouth`, `chromium`, `foot`, `libreoffice-fresh`, `docker`, `obsidian`, `gpu-screen-recorder`, `moonlight-qt`. Their resolution on aarch64 is **REPORTED** by omacom's daily CI.
- **What's Apple-specific** (`platforms/aarch64-apple` + `install/omarchy-aarch64-apple.packages`):
  - `omarchy-mac`, `omarchy-mac-boot`
  - `linux-aurora` (+headers), **`m1n1-aurora`**, `uboot-asahi`, `limine` + hooks
  - `asahi-alarm-keyring`, `asahi-bless`, `asahi-desktop-meta`, `asahi-fwextract`, `asahi-scripts`, `alsa-ucm-conf-asahi`
  - `avd-fw`, `libva-v4l2_request-avd`, `tiny-dfr`, `startup-disk`, `lzfse`
  - plus the `[asahi-alarm]` repo

  Everything else is plain Omarchy.

**(!) Blocker for "just install it": platform detection.** `omarchy-hw-platform` reads `/proc/device-tree/compatible`; `if [[ $token == "apple,"* ]] … echo aarch64-apple`. Its comment: "'apple,<model>' from Asahi's m1n1 on every Apple Silicon Mac".
- Our DT root is `apple,j714s apple,t6050 apple,arm-platform`, so a **booted** J714s is always `aarch64-apple`. The only override is an image manifest (`/var/lib/omarchy/image/target`, `generic-aarch64` → `aarch64`), and it's honoured **only while the root is not booted** (`if … [[ -e $manifest … ]] && ! booted`).
- `aarch64-apple` pulls `m1n1-aurora`. **Installing or running an m1n1 binary is forbidden for us (rule 7).** It also pulls `omarchy-mac-boot` (Limine/U-Boot/m1n1 deployment to the ESP) and `linux-aurora`, which conflicts with our kernel.
- **Renaming the root compatible is not an option:** our kernel checks `of_machine_is_compatible("apple,arm-platform")` (`drivers/cpuidle/cpuidle-apple.c:146`, `drivers/cpufreq/apple-soc-cpufreq.c:357`).

**Proposed install (Stage B), on our ALARM root with our kernel.** This is a design, not tested.
1. **Network for pacman** (work-side (!) change, PM approval). `work` routes the Mac via the CDC-EEM link:
   ```sh
   sudo sysctl -w net.ipv4.ip_forward=1
   sudo nft add table ip m5nat
   sudo nft add chain ip m5nat post '{ type nat hook postrouting priority 100; }'
   sudo nft add rule ip m5nat post ip saddr 10.55.0.0/16 masquerade
   ```
   Then on the Mac: `ip route add default via 10.55.0.1` and a resolver in `/etc/resolv.conf`.
2. **Guards first** (on the Mac): add to `/etc/pacman.conf` `IgnorePkg` (we already have `linux-aarch64 linux-aarch64-headers`):
   `linux-aurora linux-aurora-headers m1n1-aurora uboot-asahi omarchy-mac omarchy-mac-boot asahi-* limine-mkinitcpio-hook`.
   Do **not** add `[asahi-alarm]`.
3. **Keys:**
   ```sh
   pacman-key --init
   pacman-key --populate archlinuxarm
   pacman-key --recv-keys 40DFB630FF42BCFFB047046CF0134EE680CAC571 --keyserver keys.openpgp.org
   pacman-key --finger 40DFB630FF42BCFFB047046CF0134EE680CAC571   # must print exactly this fingerprint
   pacman-key --lsign-key 40DFB630FF42BCFFB047046CF0134EE680CAC571
   ```
4. **Repo:** insert `[omarchy]` / `Server = https://pkgs.omarchy.org/stable/$arch` **before `[core]`**, as Omarchy's template does.
5. **Platform override (local, labelled):** make Omarchy see `aarch64` on this machine.
   - Preferred: a small local package `m5-omarchy-platform` that installs an override of `omarchy-hw-platform` and `omarchy-hw-aarch64-apple` (path to verify on-device after installing `omarchy`), protected with pacman `NoExtract` for those two files, so updates don't restore the Apple detection.
   - Alternative: ask omacom for an explicit generic opt-out (e.g. a root-owned `/etc/omarchy/platform`). the owner or the PM posts that; it's a good upstream request because their detector is the only thing that treats a non-m1n1 Mac boot as `aarch64-apple`.
6. `pacman -Syu omarchy omarchy-settings omarchy-keyring zram-generator rtkit` + the `omarchy-base.packages` list, then Omarchy's own first-run setup. The exact entry point on an existing Arch root still needs checking: Omarchy normally installs from its ISO/image builder.
   - Expect to skip or replace: `gpu-screen-recorder` (it needs a GPU encoder; it should install but fail at runtime), `moonlight-qt` (GPU decode), `docker` (fine, but heavy on 1 core).
   - `plymouth` (boot splash) is harmless on simpledrm.

## 2. Hyprland with no GPU driver (simpledrm + llvmpipe)
- **REPORTED: it works on Apple silicon today.**
  - omacom's installer README: "M3 Macs run with software rendering (llvmpipe) until their GPU driver lands".
  - omarchy-pkgs [#649](https://github.com/omacom/omarchy-pkgs/pull/649) (merged 2026-09-27) backports hyprwm/Hyprland#16343 so Hyprland "decides whether it is software rendering from the GL renderer (llvmpipe/softpipe) rather than the DRM driver name … Display-only KMS devices such as simpledrm paired with llvmpipe were previously missed". Test plan: "M3 Air (simpledrm + llvmpipe, implicit sync): desktop renders correctly".
  - Their runtime comparison ([comment](https://github.com/omacom/omarchy-pkgs/pull/649#issuecomment-5852377750)): "The approximately 15 FPS baseline was an operator estimate, not a benchmark". Before the backport the operator "observed tearing, incomplete rendering, and cursor trails".
  - Aquamarine still logs DRM-renderer errors, and omacom says "we have not established that they have no performance impact".
- **Mechanism:** aquamarine needs GBM/EGL; Mesa's `kms_swrast` gives GBM on simpledrm backed by llvmpipe. This is REPORTED in community notes (e.g. omacom/omarchy-iso [#176](https://github.com/omacom/omarchy-iso/pull/176)). Not verified by us.
- **Known hazard, critical on 1 core:** hyprwm/aquamarine [#425](https://github.com/hyprwm/aquamarine/issues/425) (open). When the only DRM device is simpledrm, `eglQueryDeviceStringEXT` returns `EGL_BAD_PARAMETER` and the renderer init is "re-attempted on every subsequent commit, burning CPU" ("Hyprland process pegs ~6.8 CPU cores steady-state", 3.9 GiB of logs in 100 h).
  - One comment reports it fixed with aquamarine 0.15.1 for a render-node case (Raspberry Pi 5). Others still see it on simpledrm-only VMs with 0.15.0/0.15.1.
  - **On a single core this alone could make the desktop unusable.** The first Stage B test is to measure Hyprland's idle CPU and log growth.
- **Resolution:** simpledrm can't modeset, so we render at the iBoot mode (3024×1964 on J714s; H8 in the m5boot spec). Hyprland's `scale` changes layout, not the render buffer, so the fill cost is fixed.
- **Expected performance [HYPOTHESIS]:**
  - The M3 Air (8 cores) gets ~15 FPS (estimate).
  - One J714s core, which has to run llvmpipe *and* the apps, will be much lower, likely single-digit FPS on full redraws.
  - Typing in a terminal redraws small regions, so it's probably tolerable. Scrolling, animations and browsers will be poor.
  - Mitigations: disable blur, shadows and animations, use `misc:vfr = true`, and keep compositor effects off.
- **Minimum for "usable"** (proposed, the owner decides later): log in (sddm or autologin), a terminal (foot), and opening a browser with page loads/scrolling at a tolerable rate. With one core, *terminal* is likely met and *browser* likely not.

## 3. Why SMP matters
- [SRC] Mesa: llvmpipe "is multithreaded to take advantage of multiple CPU cores (up to 32 at this time)" ([docs](https://docs.mesa3d.org/drivers/llvmpipe.html)).
- J714s has **15 cores** (5 M + 5 M + 5 P; OBSERVED in 02). Today only cpu0 (an M core) runs (`maxcpus=1`). Secondaries are blocked by the T6050 PMP issue (03/05).
- [HYPOTHESIS] Rasterization is the fill-bound part, so SMP gives llvmpipe roughly an order of magnitude more throughput. It also frees the compositor from competing with apps on one core. That's the gap between "terminal only" and "a browser is usable". It would put us at or above the M3 Air's ~15 FPS REPORTED baseline.
- No public numbers for llvmpipe scaling vs cores were found. Measuring it is easy once SMP works: run `glmark2-es2-wayland` with `LP_NUM_THREADS=1..N`.

## 4. Daily-use essentials under the safety rules
| Item | Status | Basis |
|---|---|---|
| Keyboard/trackpad | In the safe kernel (DockChannel MTP, `HID_DOCKCHANNEL=y`). Expected to work | REPORTED native on J714s (betizzel) / J714c |
| Display brightness | **Fixed at the iBoot level** | Asahi `hw/soc/smc.md`: the SMC handles "the LCD backlight and lid switch". Our ADT has `dcp-brightness-node` (OBSERVED), so DCP is involved. SMC and DCP are both banned, so no control. [HYPOTHESIS] stays as iBoot set it |
| Keyboard backlight | Unknown mechanism on J714s; not attempted | — |
| Battery / charging status | **None** (SMC) | smc.md: SMC = "battery status". Banned |
| Lid switch | None (SMC) | smc.md |
| Suspend | **Disable**: `systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target`. Leave lid handling alone (no lid events without SMC anyway) | No working suspend path; avoid untested state |
| Audio | **Off** (owner rule) | safe kernel |
| Wi-Fi/BT | **None.** Apple N1, no driver | 02 dump: `centauri-*`, PCI 106b:1901–1903 |
| Networking | **Now:** CDC-EEM gadget to `work`, with `work` NATing (§1 step 1). **Later:** a USB-Ethernet dongle (`r8152.ko` built) once **USB host mode** works on T6050. Our DT is gadget-only; edimoldovan has USB 2/3 host on J714c via Aurora PHY patches (REPORTED, GPL, portable) | 09/11 |
| Fans/thermals | SMC-managed, banned, so firmware default control | — |
| Storage | NVMe (ANS2 + SART) in the safe kernel | REPORTED native on J714s |

## 5. Staged plan
| Stage | Contents | "Usable" means | Blockers |
|---|---|---|---|
| **A** Console + SSH (first native boot) | m5boot → safe kernel → initramfs; SSH over CDC-EEM; ALARM installed to the 120 GB partition; kexec loader | Owner sees a shell; we can SSH and iterate | m5boot (implementer), arming + 1TR (11) |
| **B** Omarchy userland, 1 core, simpledrm + llvmpipe | §1 install with the platform override and Apple-package guards; Hyprland with effects off; Wi-Fi absent, net via `work` | Login + terminal + editor responsive. Browser *opens* but is slow | Platform override; aquamarine #425 spin on 1 core; network via `work` |
| **C** SMP | T6050 PMP start → secondary cores (`maxcpus` removed) | Browser usable (tolerable scrolling/video), comparable to Omarchy-on-M3-llvmpipe (~15 FPS REPORTED or better) | PMP (03/04/05 probes → start); also USB host for Ethernet |
| **D** GPU | G17S driver + Mesa M5 path (Aurora work is the closest, REPORTED: firmware init on J714c, jobs stall on PMP-gated power) | Full Omarchy experience | PMP (the GPU power domain), the DCP driver for brightness and modes, plus SMC (owner rule review) for battery/backlight |

[HYPOTHESIS] **Stage C is the first stage likely to meet a "usable desktop" bar.** Stage B demonstrates Omarchy natively, but the single core caps it. The owner confirms the bar later.

Stage D also needs the owner to revisit the SMC/DCP bans: brightness, battery and lid all depend on them.
