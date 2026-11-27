# Install on a J714s

It runs on a Mac, not from a Linux PC. You need:

- A **MacBook Pro 14-inch, M5 Pro** (J714s). Not M5 Max, not the 16-inch, not yet.
- **macOS 27.2 or newer** on it, FileVault on, an administrator account.
- About **35 GB free** on the Mac's disk, the charger, and about an hour.

Steps (the [release page](https://github.com/betizzel/omarchy-m5/releases/tag/omarchy-j714s-11) has every detail):

1. **Download** the installer package from the release (online: small; offline: the `.partN`
   files joined) and check it against `SHA256SUMS`.
2. **Install and run** Omarchy Installer. It shrinks macOS, adds a new startup disk (Apple's 27.2
   firmware, downloaded from Apple) and writes Omarchy.
3. **Finish setup in Recovery:** shut down, hold the power button, pick the **Omarchy with the
   logo icon**, sign in, click **Install** in Omarchy's own "Finish setup" window and wait (up to
   30 minutes). Don't use Startup Security Utility.
4. **Restart.** First boot asks for a disk password, then your name and password.

**To go back to macOS:** hold the power button at startup and pick macOS.

**Before turning the speakers up,** follow the low-level test in
[the speaker recipe](../installer/recipes/speakerguardd-v2-upstream/README.md).

Stuck? Open an [issue](https://github.com/betizzel/omarchy-m5/issues) and paste what you see.

Earlier releases (1 to 6) and the older developer images are superseded; what each one was and
why it was replaced is in [`docs/status-and-history.md`](status-and-history.md). What is
being sent upstream, and what waits on a test first, is in [`docs/upstream.md`](upstream.md).


## Troubleshooting

> **On release 7 to 9 and `omarchy update` fails with `aurora_drv_video.so exists in filesystem`?** Install [firmware j714s16](https://github.com/betizzel/omarchy-m5/releases/tag/firmware-j714s16) once, then update again ([#34](https://github.com/betizzel/omarchy-m5/issues/34)).

[Back to the README](../README.md)
