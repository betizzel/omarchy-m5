# Sending M5 work here

This repo is one place where M5 Mac owners can get a working **edge** image now, built from
everyone's work, with each part credited, and with a path for that work upstream. If you have
something that works on an M5 Mac (a kernel patch, an Aura patch, a package fix, an installer
change, a test result), please open a pull request here under your own name.

This does **not** replace upstream. Keep your pull requests in aurora-silicon/linux,
aurora-silicon/aura and the omacom repos open: they are the goal. We carry a copy of your change
until it merges upstream, then we drop our copy and take it from upstream. That is already how
[`patches/j714s-27.2/`](patches/j714s-27.2/README.md) works (see "Dropped in v272-5" there).

## Where things go

| What | Directory | Notes |
| --- | --- | --- |
| Kernel patches for the J714s image | [`patches/j714s-27.2/linux/`](patches/j714s-27.2/linux) | One numbered `git format-patch` file per change, on top of the base named in [the README](patches/j714s-27.2/README.md). Add a row to its patch table. We regenerate the recipe's concatenated `linux-j714s-27.2.patch` and bump the package; you can do it in your PR, but you don't have to |
| Aura (stage 1 loader) patches | [`patches/j714s-27.2/aura/`](patches/j714s-27.2/aura) | Same rules |
| Package recipes | [`installer/recipes/<package>/`](installer/recipes) | PKGBUILD and its files; say in the PKGBUILD comment whose change it is |
| Installer changes | [`installer/patches-j714s-r2/`](installer/patches-j714s-r2) | Patches on omacom/omarchy-mac-installer; see [`installer/README.md`](installer/README.md) |
| Docs, status, test results | [`docs/`](docs), [`README.md`](README.md) | The README table only says **Works** for what was seen on hardware |

Other directories under `patches/` are older lines kept for history; new work goes in the ones above.

## How to send it

- **One change per pull request.** A patch series for one feature is one change.
- **Keep your authorship.** Use `git format-patch` from your own branch, so the file keeps your
  `From:` and `Signed-off-by:`. Or open a PR that adds the patch file as you wrote it. Either way
  the commit in this repo is yours.
- **Say what was tested and how.** In the PR description:
  - the board (for example J714s, J714c, J716s, K114s) and its owner;
  - the firmware: macOS stub version and build (for example 27.2, 26B123);
  - the kernel or Aura base commit, or the image release and kernel package (for example v272-11);
  - what was **seen on the hardware** (looked at, heard, measured) and what was **only built**
    or checked by command. Both are useful; they are just different rows.
- **Link your upstream PR** if there is one. When it merges, we drop our copy in the next kernel.

A test report without code is welcome too: use the
[test report template](https://github.com/betizzel/omarchy-m5/issues/new?template=test-report.md).

## Boards

The repo's own images are for the J714s (14-inch MacBook Pro, M5 Pro) today, because that is
the board tested here. A board gets its own image only when an owner of that board tests it and
sends the changes it needs. Until then it can be added as clearly labelled "tested on one
machine" support. For example, chrisohearn offered `apple,k114s` installer admission for the
K114s in [#10](https://github.com/betizzel/omarchy-m5/issues/10).

## Edge, not stable

Every `omarchy-j714s-N` release is a GitHub prerelease: an edge image. It works on the hardware
listed as tested, the known gaps are listed in the README and release notes, not hidden, and
problems are fixed forward in the next release.

## Credit

Every PR author is named in the README's "What works" table and in the release notes of the
first release that carries their change. The patch tables in `patches/j714s-27.2/README.md`
keep the author of each patch.

## License

Patches keep the license of the project they apply to (GPL-2.0 for the kernel). This repo's own
scripts and docs are [MIT](LICENSE). Don't send Apple firmware.
