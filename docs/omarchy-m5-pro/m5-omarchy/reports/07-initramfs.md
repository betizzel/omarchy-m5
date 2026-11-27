# 07 — First-boot initramfs + Option B loader

**Built:** `build/initramfs.cpio.gz` (first boot) and `build/initramfs-loader.cpio.gz` (+ kexec-tools). Both are produced by our own `tools/initramfs/build.sh` from verified Alpine v3.24 packages. Nothing touched the Mac.

| Artifact | Size | SHA-256 |
|---|---|---|
| `build/initramfs.cpio.gz` | 1,462,458 B (1.4 MiB) | `f1339ace39940d69bca992a48987b4d93f89b3eea640d67258d018f3d8fa25f1` |
| `build/initramfs-loader.cpio.gz` | 2,013,590 B (1.9 MiB) | `3efb0ba266244b34914e26bb877178a88a72158a133a975a104432edde6d7d12` |

Size budget: both are well under 2 MiB, about 1/8 of `Image.gz` (16 MB), so they add little to the USB chainload.

## Downloads (PM-approved; nothing was refused this time)

**Verification chain:**
1. `latest-releases.yaml` names the stable branch, **v3.24**.
2. `main` and `community` `APKINDEX.tar.gz` are verified against the RSA/SHA-1 signature in the index (`.SIGN.RSA.alpine-devel@lists.alpinelinux.org-616ae350.rsa.pub`, checked with `openssl dgst -sha1 -verify`).
3. The signing key was fetched from **two independent sources**: gitlab.alpinelinux.org `aports/main/alpine-keys` and github.com `alpinelinux/aports` mirror. They are byte-identical, sha256 `d11f6b21c61b4274e182eb888883a8ba8acdbf820dcc7a6d82a7d9fc2fd2836d`.
4. Each apk's control-stream SHA-1 matches its signed index entry (`C:Q1…`).
5. Each apk's **data stream** SHA-256 matches the `datahash` in its (now index-verified) `.PKGINFO`. Each apk must have exactly 3 gzip streams, and the index exactly 2. The index is parsed from the exact member the signature covers.

**Security fix (after an automated review):** the first version of `apk-verify.py` checked only step 4 (the data stream was unverified) and parsed the index from the last member rather than the signed one. Both are fixed; `build.sh` also refuses non-3-stream apks. All 9 packages re-verified through steps 1–5. Negative test: flipping one byte in zlib's data stream gives `DATAHASH MISMATCH` (exit 1). The images were rebuilt from the re-verified packages; their hashes changed only because cpio records file mtimes.

The tool is `tools/apk-verify.py` (ours: stdlib + openssl). Index sha256: main `8d542bbc…0500e`, community `09921dd9…d67e5`.

| URL | SHA-256 |
|---|---|
| https://dl-cdn.alpinelinux.org/alpine/v3.24/main/aarch64/busybox-static-1.37.0-r31.apk | `965777e06b94bf11981d5f4ecdfcd577879f4b0dda544294d1dd3f72b217bc75` |
| https://dl-cdn.alpinelinux.org/alpine/v3.24/main/aarch64/dropbear-2026.91-r0.apk | `83547e6936b7c90b1625514bd3497d5c7152fcdb66bcae3b68a8e51fdfe31090` |
| https://dl-cdn.alpinelinux.org/alpine/v3.24/main/aarch64/utmps-libs-0.1.3.3-r0.apk | `d6487b6f260728969191314f6706d4cc62527370e757ec3ac6f7fee8ed38cf88` |
| https://dl-cdn.alpinelinux.org/alpine/v3.24/main/aarch64/skalibs-libs-2.15.0.0-r0.apk | `7ea58fb512067402b519079fcce8a48381eb2b9c690341c4a017aa15f719c198` |
| https://dl-cdn.alpinelinux.org/alpine/v3.24/main/aarch64/musl-1.2.6-r3.apk | `2e17864102278d9049c3a56f1bceed9e8cf287065617e579325123443daed8a5` |
| https://dl-cdn.alpinelinux.org/alpine/v3.24/main/aarch64/zlib-1.3.2-r1.apk | `1f77a542ac6634761b9fe38d8bdca19b154071dcfa25432e73f2bc8a0740a33f` |
| https://dl-cdn.alpinelinux.org/alpine/v3.24/main/aarch64/xz-libs-5.8.4-r0.apk | `9be375832e747afe14f98e400e8b55d8f6fde25e41663090c81600628daab093` |
| https://dl-cdn.alpinelinux.org/alpine/v3.24/main/aarch64/zstd-libs-1.5.7-r2.apk | `2bb5136c89f5b0bbe1554c8915a3b520d5aa63ae2a51d4d821eb81698db5a818` |
| https://dl-cdn.alpinelinux.org/alpine/v3.24/community/aarch64/kexec-tools-2.0.32-r2.apk | `bd8b6951f862af1123972b521c355c655b7a2f40c2bf9cfe700edd590a101c94` |

**Notes:**
- There's **no `dropbear-static`** in v3.24, so dropbear is dynamic and the image carries musl 1.2.6 plus `libutmps`/`libskarnet`/`libz`.
- kexec-tools is dynamic too (adds `liblzma`, `libzstd`), loader variant only.
- Licenses (upstream package metadata, not re-verified file by file): busybox GPL-2.0, dropbear MIT, musl MIT, kexec-tools GPL-2.0, zlib Zlib, xz-libs 0BSD/public domain, zstd BSD/GPL-2.0, utmps/skalibs ISC. **If the initramfs is redistributed, the GPL parts (busybox, kexec-tools) need the source offer** (add to `06-licenses.md`).

## Contents (ours: `tools/initramfs/`)
- **`/init`** (busybox sh):
  1. `busybox --install -s`; mounts proc, sysfs, devtmpfs, devpts, configfs.
  2. Prints `=== m5 initramfs ===`, `uname -a`, `nproc`, `/proc/device-tree/compatible` and the model.
  3. Starts `m5-gadget-net` and `m5-sshd` in the background.
  4. Runs `m5-loader` if the cmdline has `m5.loader=1`.
  5. `exec setsid cttyhack sh` on the console (tty0 with `console=tty0`).
- **`m5-gadget-net`** (our own reimplementation; betizzel's script was only used as a description of the approach). It waits up to 30 s for `/sys/class/udc`, then for each UDC *n* creates a configfs gadget with:
  - Linux Foundation VID/PID `1d6b:0104`
  - serial `m5pro-<n>`
  - one **CDC-EEM** function
  - binds it and sets `10.55.<n>.2/24` on the resulting netdev.

  Host side on "work": `ip addr add 10.55.<n>.1/24 dev <usbX>` (the `cdc_eem` host driver binds by class).
- **`m5-sshd`**: `dropbear -R -E -F -s -p 22`. Host keys are generated on first connection, password logins are disabled, and `/root/.ssh/authorized_keys` = `build/work.pub` (an ssh-ed25519 public key, 94 B). Login: `ssh root@10.55.<n>.2`.
- **`/lib/modules/t6050_probe.ko`**: our read-only probe (06, sha256 `e44f9f58…`). Run `insmod /lib/modules/t6050_probe.ko groups=N`.
- **`m5-loader`** (Option B, loader variant):
  1. Waits for the root device (arg → `m5.root=` → `/dev/nvme0n1p5`) and mounts it read-only.
  2. Takes `/boot/Image` (or `Image.gz`), the optional `/boot/initramfs.cpio.gz` and `/boot/cmdline`.
  3. DT = **`/sys/firmware/fdt`**, the one m1n1 fixed up. `/boot/m5.dtb` is used only if `/boot/USE_FILE_DTB` exists.
  4. `kexec -s -l …` (falls back to `kexec -l`), then `kexec -e`.

  If no root is found it says so and stays in the initramfs.
- `/etc/passwd` has root with `/bin/sh`. All files are root-owned via the kernel's `usr/gen_init_cpio` (no fakeroot), and `/dev/console` is created as `c 5 1`.

## Checks
- `cpio -t` (base): `bin/{busybox,m5-gadget-net,m5-loader,m5-sshd}`, `etc/{passwd,group,shells,dropbear}`, `init`, `lib/{ld-musl-aarch64.so.1,libc.musl-aarch64.so.1}`, `lib/modules/t6050_probe.ko`, `root/.ssh/authorized_keys` (0600), `usr/lib/{libskarnet,libutmps,libz}*`, `usr/sbin/dropbear`, `dev/console`, plus empty dirs.
- The loader variant adds `usr/sbin/kexec`, `usr/lib/liblzma*` and `usr/lib/libzstd*`.
- `file`:
  - `busybox`: "ELF 64-bit LSB pie executable, ARM aarch64 … **static-pie linked**".
  - `dropbear`, `kexec`: "ARM aarch64 … dynamically linked, interpreter /lib/ld-musl-aarch64.so.1". The interpreter and all `NEEDED` libraries are present.
  - **Not every binary is static** (dropbear and kexec can't be, from Alpine). The musl runtime is in the image.
- **QEMU `virt` smoke boot (VM): inconclusive.** Three attempts, each 45–60 s, with no console output at all:
  - `-M virt -cpu max`, using `Image.gz` and uncompressed `Image`;
  - `console=ttyAMA0`, then `earlycon=pl011,0x9000000`;
  - GICv3.

  [guess] This Apple-targeted config (16K pages, 52-bit VA, defconfig + asahi + bring-up fragments) hangs before earlycon under TCG. That says nothing about the initramfs or the J714s. I stopped there as the task allows; it wasn't quick.
- **Not tested anywhere yet:** gadget binding on real DWC3, the dropbear login, kexec on Apple silicon.

## How to use (for the first tethered boot, 06 §3 step 5)
Pass `build/initramfs.cpio.gz` as the third `linux.py` argument ([owner-only] owner). For the Option B stage 2, use `build/initramfs-loader.cpio.gz` with `m5.loader=1 m5.root=/dev/nvme0n1pN` on the cmdline.

Rebuild with `tools/initramfs/build.sh`. It reads `build/dl/alpine/pkgs`, `build/work.pub` and the probe `.ko`, and writes `build/initramfs.SHA256SUMS`.
