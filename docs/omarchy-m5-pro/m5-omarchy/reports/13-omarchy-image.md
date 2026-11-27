# 13 — Omarchy userland baked into the rootfs (Stage B prep)

**Output:** `build/rootfs-omarchy.tar.zst`, **sha256 `f9be67814828f101ea990d072ff933d50811b2e6774e7ac3c655b59c2ac73079`**, 6,074,240,852 B (13 GB unpacked, 271,381 entries, **921 packages**). Built by `tools/rootfs/build-omarchy.sh` (reproducible; stages `extract repo settings runtime apply pack`) from `build/rootfs-alarm.tar.zst` `32f5b7ee…` (task 14 kernel). Not yet booted anywhere.

## How it's built (no root on ush)
- **No proot** (not in the Arch repos, AUR only). The rootless equivalent is used instead: `unshare --map-root-user --map-auto --mount --pid --fork`.
  - That gives uid 0 plus this user's subuid range (`/etc/subuid` 100000:65536, `newuidmap` has `cap_setuid=ep`), so files keep their real owners.
  - aarch64 binaries run through ush's registered `qemu-aarch64` binfmt (`F` flag, `/usr/bin/qemu-aarch64-static`).
  - No sudo and no binfmt changes.
- **The build never sees ush's hardware:**
  - `/sys` is an empty tmpfs carrying only the target's DMI identity (`product_name` Mac17,9, `sys_vendor` Apple Inc.) and an empty PCI bus.
  - `/proc/bus/pci` is hidden. Without that, `lspci` read ush's AMD GPU and Omarchy tried to install `vulkan-radeon`.
- **Recipe** follows omacom's image builder (MIT):
  1. `omarchy-settings` first;
  2. the root-owned manifest `/var/lib/omarchy/image/target` (`format=1`, `platform=generic-aarch64`);
  3. the runtime packages;
  4. `omarchy-apply-system --defer-provisioning --first-install`.
- **Pack:** zstd level 10 with `threads=0` (40 s on 24 cores, versus 30+ min single-threaded at -19). All builds now use `-j$(nproc)` / `zstd:threads=0`.

## Signatures (signed packages only)
- `SigLevel = Required DatabaseOptional` throughout.
- **ALARM key** `68B3537F39A313B3E574D06777193F152BDBE6A6` via `pacman-key --populate archlinuxarm`.
- **Omarchy key** `40DFB630FF42BCFFB047046CF0134EE680CAC571`: fetched from `keys.openpgp.org/vks/v1/by-fingerprint/…`, checked with `pacman-key --finger`, locally signed; then the `omarchy-keyring` package.
- **`omarchy-themes-intros-2026.10.14-1`** (a hard dependency of `omarchy`): the `[omarchy]` database carries no embedded `%PGPSIG%` for it, but the server's detached `.sig` verifies on the host. `GOODSIG F0134EE680CAC571 Omarchy <pkgs@omarchy.org>` / `VALIDSIG 40DFB630…C571`, EdDSA. The build checks that, then seeds the package + `.sig` into pacman's cache, and pacman verifies the detached signature itself. **Nothing unsigned was installed.**

## Channel and package decisions (PM: prefer signed stable)
- **`[omarchy]` = stable** (`https://pkgs.omarchy.org/stable/$arch`). Runtime: `omarchy 4.0.6-1`, `omarchy-settings 4.0.6-1`.
- **Hyprland stack from signed ALARM `extra`**, not `[omarchy]`. Stable's `hyprland-0.56.2-7` needs `libaquamarine.so=14` and `libhyprgraphics.so=4`, but ALARM ships aquamarine 0.16.0 and hyprgraphics 0.6.0, so it can't be resolved. Installed instead:
  - `hyprland 0.57.1-1` (contains hyprwm/Hyprland#16343, the software-render detection that omarchy-pkgs #649 backports; v0.57.1 is 159 commits ahead of the merge);
  - `aquamarine 0.16.0-1`, `uwsm 0.27.1-1`, `sddm 0.21.0-7`, `quickshell 0.3.2.r7`.

  `hyprland` is pinned via `IgnorePkg`. `omarchy` depends on an unversioned `hyprland`, so this satisfies it.
- **Package lists** come from the installed runtime (`/usr/share/omarchy/install/omarchy-base.packages`; 4.0.6 has no `omarchy-aarch64.packages`). 147 wanted, 144 installed from them.
  - **Not available on aarch64, skipped:** `dotnet-runtime`.
  - **Substituted:** `nvim` → `neovim 0.12.6` (ALARM's name).
  - **Added:** `sudo` (Omarchy's setup scripts call it; the ALARM base has none).
- **Our kernel stays:**
  - `/boot/Image` sha256 `9c377f51…` = the task 14 build.
  - Modules `7.2.2-g236788cd2602-dirty`.
  - ALARM's own `linux-aarch64 7.1.6-1` is still installed from the base but is pinned and unused. Its mkinitcpio hook errors in the chroot are harmless.
- **m1n1 check:** `pacman -Q | grep -iE "m1n1|aurora|asahi"` gives **nothing**. Only firmware/headers names contain `linux-`. The guard is in the final `IgnorePkg`:
  `linux-aarch64 linux-aarch64-headers linux linux-headers linux-aurora linux-aurora-headers m1n1 m1n1-aurora m1n1-neo aura uboot-asahi omarchy-mac omarchy-mac-boot omarchy-apple-boot asahi-* limine-mkinitcpio-hook hyprland`.
- **Platform:** stable 4.0.6 predates `omarchy-hw-platform`, so there's no device-tree platform detection to defeat. Its "apple" scripts are Intel-Mac-only (T2 via PCI `106b:1801/2`, SPI keyboards via old DMI names) and can't match. The manifest is kept for later runtimes.
  - (!) A future `omarchy` upgrade to a runtime **with** `omarchy-hw-platform` will report `aarch64-apple` on this device tree (report 12). The `IgnorePkg` guards still block every boot package. A local platform override is needed before that upgrade.

## Omarchy 4.0.6 problems found and how each was handled
| Problem | Handling |
|---|---|
| `install/config/*.sh` call `sudo` | `sudo` added |
| `snapper.sh` needs btrfs + `snapper` (our root is ext4, booted by m5boot, no Limine) | ran with the script's own `OMARCHY_SNAPPER_CONFIGURE_TEST=1` (writes the config, no `snapper create-config`). Snapshots don't apply on ext4 |
| `firewall.sh`: ufw → iptables-nft needs netfilter netlink, which **qemu-user doesn't emulate** (an own netns didn't help) | build-time bind-mount of a recorder over `/usr/bin/ufw` (the image's ufw is untouched). The 6 commands (`default deny incoming`, `default allow outgoing`, `allow 53317/udp`, `allow 53317/tcp`, 2× `allow-docker-dns`) are in `/var/lib/m5/ufw-replay`. **`m5-ufw-replay.service`** replays them natively on first boot, before `ufw.service`. ufw-docker's `after.rules` block was written; `ENABLED=yes` and `ufw.service` are enabled |
| `omarchy-apply-hardware` sources `install/helpers/image-target.sh`, **which stable 4.0.6 doesn't ship**, so deferral silently fails and every hardware step runs at build time | hardware hidden (above): every hardware step ran, found nothing, and changed nothing. Hardware setup is **not** queued for the Mac's first boot. None of 4.0.6's hardware steps cover Apple silicon anyway |
| Hardware scripts read DMI under `bash -e` and fail on a DMI-less (device-tree) machine (`fix-spi-keyboard.sh`). This would also fail natively on the J714s | the build gets the target's true DMI identity; every regex targets Intel Macs, so none match |
| `post-install/pacman.sh` copies **x86 templates**: `core/extra/multilib` + mirror `stable-mirror.omarchy.org`, dropping `[alarm]` and our guards | final `/etc/pacman.conf` written at pack: Omarchy's `[options]` + `[omarchy]` stable + ALARM `core/extra/alarm/aur` + guards. `/etc/pacman.d/mirrorlist` restored from the verified ALARM tarball (`mirror.archlinuxarm.org`). (!) **Running `omarchy-update`/post-install again on the Mac will re-break pacman.** Use `pacman -Syu` until this is fixed upstream or overridden |
| pacman sandbox (Landlock) unsupported under qemu; `CheckSpace` can't find the mount table in the chroot | build-only `DisableSandbox` + `#CheckSpace`, both **restored** at pack |

## Display / GPU
- No Apple GPU drivers. Mesa `26.2.6` with `kms_swrast_dri.so` / `swrast_dri.so` (llvmpipe) for simpledrm.
- Omarchy's Hyprland config sets NVIDIA env only when `omarchy-hw-nvidia` detects NVIDIA.
- SDDM: `DisplayServer=wayland`, `CompositorCommand=start-hyprland -- --config /usr/share/sddm/hyprland.lua`. **The greeter is itself Hyprland**, so the aquamarine #425 single-core spin risk (report 12) applies at the login screen too.
- Omarchy 4.0.6's Lua configs target its Hyprland 0.56.2; we run ALARM's **0.57.1**. Config compatibility is **unverified**. It's the first thing to check in Stage B (`hyprctl` errors / the log).

## State of the image at first boot, and what's left
- **Default target is `multi-user.target`** (Stage A: console + SSH; tty1 root autologin; `m5-gadget-net`, sshd with `work.pub`). SDDM is enabled as `display-manager.service`, but it doesn't start until `systemctl set-default graphical.target`.
- **No user account.** Omarchy's first-boot owner setup (`omarchy-provision-owner.service`: asks for the user on tty1 before SDDM) ships **unarmed** in this image. For Stage B, either:
  1. arm Omarchy's own flow: `install -D -m644 /usr/share/omarchy/install/provisioning/omarchy-provision-owner.service /etc/systemd/system/` → `systemctl enable omarchy-provision-owner` → `mkdir -p /var/lib/omarchy/provisioning && touch /var/lib/omarchy/provisioning/pending` → remove `/etc/systemd/system/getty@tty1.service.d/autologin.conf` → `systemctl set-default graphical.target`, reboot; the owner types a user/password on the Mac; or
  2. create the user over SSH (`useradd -m -G wheel …`) and run `omarchy-provision-first-run` as that user.
- **First boot runs automatically:**
  - `m5-firstboot` (pacman-key init/populate, `pacman -U` kexec-tools);
  - `m5-ufw-replay`;
  - `m5-gadget-net`; sshd.

  Then `pacman -Sy` is needed (the `alarm`/`aur` databases are new in the final config), with network via `work` NAT (report 12 §1).
- **Install path is unchanged** (09/11): `zstd -dc build/rootfs-omarchy.tar.zst | ssh root@10.55.0.2 'sh /bin/install-rootfs.sh --yes'`. It's about 6 GB over the USB 2 gadget, so expect minutes. 120 GB partition, 13 GB used.
- (!) The pacman keyring's local master key was generated at build time. Fine for this single-machine image; don't reuse the image for other machines.
