# Task 09 — Root filesystem for the 120 GB Linux partition + post-boot plan (no Mac changes)

Status (PM, locally verified 2026-11-04): Mac partitioned via prep-stub.sh (--linux-size 120G): macOS 868 GB, Omarchy stub 6 GB (4 volumes), EFI 500 MB FAT32, **Linux Filesystem 120 GB (unformatted)**, Recovery untouched. macOS reboots fine. Next is the owner's m1n1 build + finish-install + 1TR, then the first tethered boot with our Image.gz + DTB + initramfs.cpio.gz.

Build on ush (AI-allowed: no m1n1):
1. **Arch Linux ARM aarch64 rootfs** for the 120 GB partition. Our kernel is 16K-page; check whether stock ALARM userspace is fine with 16K pages (it should be; note jemalloc/16K issues if any). Include our kernel modules (`make modules_install INSTALL_MOD_PATH=…`), `/boot/Image.gz` + DTB, openssh with work.pub authorized for root, systemd-networkd config for the CDC-EEM gadget (10.55.n.2/24; gadget setup as a systemd unit reusing our initramfs `m5-gadget-net` logic), the probe module, and kexec-tools. Verify every download (ALARM signing keys / pacman signatures). Output: `build/rootfs-alarm.tar.zst` + SHA-256.
2. **Install procedure from the first-boot initramfs** (runs on the Mac over `ssh root@10.55.n.2`, AI-driven once Linux is up): identify the 120 GB `Linux Filesystem` partition **by GPT type + size** (never by number), `mkfs.ext4` (or btrfs), untar the rootfs, set fstab by PARTUUID. Script it as `tools/install-rootfs.sh` with hard guards (refuse if the size or type mismatches, refuse any Apple_APFS/EFI partition).
3. **Option B loader readiness:** what exactly the owner must assemble for stage 2 (m1n1 + DTB + loader Image + initramfs-loader) and the m1n1 chainload config, as a minimal [owner-only] owner command list; everything after that (kernel/DT iteration via kexec) is ours.
4. **Next experiment list once Linux is up:** ordered probes with our module (groups 1→8) and what each result would mean for the PMP hypothesis.
End with `DONE 09`.
