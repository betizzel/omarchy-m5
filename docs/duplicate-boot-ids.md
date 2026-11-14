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

## To do in the installer

Write `/etc/fstab` with `PARTUUID=` at install time (or give each install fresh filesystem IDs). Not in release 3.
