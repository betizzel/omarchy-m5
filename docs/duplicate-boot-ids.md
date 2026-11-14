# Two Omarchy installs on one disk share boot partition IDs

Found 2026-11-14 on the J714s (release 1 installed next to an older Omarchy install, then updated to release 3 by pacman).

## What goes wrong

- Every installer image carries the same filesystem IDs: ESP `4F4D-5801`, `/boot` `4f4d5801-424f-4f54-8000-000000000001`.
- `/etc/fstab` mounts `/boot` and `/boot/efi` by those IDs.
- With a second Omarchy install on the same disk, either pair can win at boot. On the J714s one boot mounted the new install's partitions, the next one the old install's.
- A kernel update then writes the kernel, the `limine.conf` entry and `m1n1/boot-ctxr.bin` onto the other install's partitions. The new install keeps starting its previous kernel, and the other install's boot files are overwritten.

A Mac with a single Omarchy install is not affected.

## Check

```
findmnt -no SOURCE /boot /boot/efi
lsblk -o NAME,FSTYPE,UUID,PARTUUID
```

Both mounts must sit right before the root partition of the running system.

## Fix on an installed system

Mount by partition ID (unique per partition) instead, then put the boot files back:

```
sudo cp /etc/fstab /etc/fstab.bak-fsuuid
# replace the two UUID= entries for /boot and /boot/efi with PARTUUID=<id from lsblk>
sudo systemctl daemon-reload
sudo umount /boot/efi /boot && sudo mount /boot && sudo mount /boot/efi
sudo pacman -U linux-aurora-*.pkg.tar.zst m1n1-aurora-*.pkg.tar.zst   # the release's own package files
```

Do not use `pacman -S` for this: the public `omarchy` repository carries the generic kernel and loader, not the J714s builds.

Then `grep "Kernel version" /boot/efi/limine.conf` must show the installed kernel.

## Fixed from release 4

`omarchy-aurora-firmware` j714s10 (in [omarchy-j714s 4](https://github.com/betizzel/omarchy-m5/releases/tag/omarchy-j714s-4)) adds a systemd generator, `aurora-boot-mounts-generator`. At boot it reads the ESP m1n1 booted from (`/proc/device-tree/chosen/asahi,efi-system-partition`), takes the ext4 `OMARCHY_BOOT` partition right after it, and mounts both by `PARTUUID`. Its units take precedence over the ones made from `/etc/fstab`. If anything does not match, it writes nothing and `/etc/fstab` stays in charge.

Installed systems get it with the package (`sudo pacman -U` the j714s10 package from the release's inputs bundle); it takes effect at the next boot. If the boot files already went to the other install's partitions, put them back first as above.

Tried on the J714s: generator dry run, `systemctl daemon-reload`, unmount/mount cycle; each gave the right partitions. Not yet tried across a restart.

Still open: the installer writes the same filesystem IDs into every install. Writing `/etc/fstab` with `PARTUUID=` (or giving each install fresh filesystem IDs) would remove the cause.
