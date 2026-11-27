# Help out (dev)

You don't need to be a kernel hacker. The easiest ways to help:

- **Got a J714s?** Try the image and tell us what works and what doesn't.
- **Found someone's M5 work that we don't have?** Open an issue with the link. That's the whole job here.
- **Want to watch the repos yourself?** `tools/watch/watch.sh` (needs `gh` logged in). The first
  run just records where everything is; after that it prints what changed.

Want to build it yourself? The kernel and bootloader patches are in [`patches/`](../patches/), the
image recipe in [`installer/`](../installer/README.md), and the full build guide is
[`docs/bringup.md`](bringup.md). What we know of but left out on purpose, and why: [`docs/left-out.md`](left-out.md). Everything detailed (status history, how each piece was
found, the old notes) lives in [`docs/status-and-history.md`](status-and-history.md).


[Back to the README](../README.md)
