<p align="center">
  <img src="assets/header.svg" alt="omarchy-m5: Omarchy on the 14-inch MacBook Pro with M5 Pro" width="100%">
</p>

<p align="center">
<a href="https://github.com/betizzel/omarchy-m5/stargazers"><img alt="Stars" src="https://img.shields.io/github/stars/betizzel/omarchy-m5?style=for-the-badge&logo=github&color=7aa2f7&labelColor=1a1b26"></a> <a href="https://github.com/betizzel/omarchy-m5/watchers"><img alt="Watchers" src="https://img.shields.io/github/watchers/betizzel/omarchy-m5?style=for-the-badge&logo=github&color=bb9af7&labelColor=1a1b26"></a> <a href="tools/update-source/README.md"><img alt="omarchy update: signed repo" src="https://img.shields.io/badge/omarchy%20update-signed%20repo-9ece6a?style=for-the-badge&labelColor=1a1b26"></a> <a href="docs/news.md"><img alt="Kernel v272-24" src="https://img.shields.io/badge/kernel-v272--24-bb9af7?style=for-the-badge&labelColor=1a1b26"></a> <a href="https://github.com/betizzel/omarchy-m5/releases"><img alt="Latest release" src="https://img.shields.io/github/v/release/betizzel/omarchy-m5?include_prereleases&filter=omarchy-j714s-*&style=for-the-badge&color=7aa2f7&labelColor=1a1b26&label=image"></a> <a href="https://github.com/betizzel/omarchy-m5/commits/main"><img alt="Last commit" src="https://img.shields.io/github/last-commit/betizzel/omarchy-m5?style=for-the-badge&color=e0af68&labelColor=1a1b26"></a> <a href="LICENSE"><img alt="License" src="https://img.shields.io/github/license/betizzel/omarchy-m5?style=for-the-badge&color=7dcfff&labelColor=1a1b26"></a>
</p>

<p align="center">
  <a href="#the-goal">Goal</a> ·
  <a href="#get-updates">Get updates</a> ·
  <a href="docs/news.md">What's new</a> ·
  <a href="docs/what-works.md">What works</a> ·
  <a href="docs/install.md">Install</a> ·
  <a href="docs/todo.md">TODO</a> ·
  <a href="docs/credits.md">Credits</a> ·
  <a href="CONTRIBUTING.md">Send your work</a>
</p>

## The goal

**Omarchy on the M5 Pro MacBook Pro, working like a normal laptop, through plain `omarchy update`.**

We don't reinvent anything. A lot of people are getting Linux running on the M5 Macs, each in their own repo. We
collect the parts that already work, test them on a real J714s, ship them as one signed update, and say who made
each part. When their pull request lands upstream, our copy goes away.

<p align="center"><img src="assets/pipeline.svg" alt="Collect, test on a real J714s, ship through omarchy update, send upstream" width="100%"></p>

## Get updates

```sh
curl -fsSLO https://raw.githubusercontent.com/betizzel/omarchy-m5/main/tools/update-source/enable
bash enable        # once: adds the signed [omarchy-m5] repo
omarchy update     # from then on, like any other package
```

Turned it on before 2026-11-27? Run `bash enable` once more to get the GPU drivers.
[What it does and why it's safe](tools/update-source/README.md). New to all this? [Install guide](docs/install.md).

## Latest

| | |
| --- | --- |
| **GPU acceleration** | OpenGL 4.6 and Vulkan 1.4 on the M5 Pro's GPU; the desktop renders on it (glmark2 3003 against 89) |
| **Microphones** | about 17 dB louder, from Isaac-Duarte's fix |
| **Wi-Fi power save** | on by default, about -0.35 W (erikwb's measurement) |
| **Kernel v272-24** | the M5 Pro deep sleep driver, opt-in for now; lid sleep stays s2idle |

All of it through `omarchy update` since 2026-11-27. Earlier releases: [what's new](docs/news.md).

<p align="center"><img src="assets/status.svg" alt="What works on our J714s" width="100%"></p>

<p align="center"><sub>Every row, with versions, measurements and whose work it is: <a href="docs/what-works.md">what works</a>.</sub></p>

## Up next

- The screensaver keeps the GPU at full load (about 40 W); find out why, report to Mesa
- Power-saver can pin the CPUs at 300 MHz under load; tune the budget with upstream
- Deep sleep: the power-management coprocessor doesn't come back yet ([#3419](https://github.com/aurora-silicon/linux/pull/3419))
- Release 11 installer image: needs one from-scratch install on a J714s

[Full TODO](docs/todo.md), with what owners can test.

## Built from their work

<p align="center">
<a href="https://github.com/rolotrealanis98" title="rolotrealanis98"><img src="https://github.com/rolotrealanis98.png?size=96" width="56" height="56" alt="rolotrealanis98"></a>
<a href="https://github.com/edimoldovan" title="edimoldovan"><img src="https://github.com/edimoldovan.png?size=96" width="56" height="56" alt="edimoldovan"></a>
<a href="https://github.com/DjDeveloperr" title="DjDeveloperr"><img src="https://github.com/DjDeveloperr.png?size=96" width="56" height="56" alt="DjDeveloperr"></a>
<a href="https://github.com/betizzel" title="betizzel"><img src="https://github.com/betizzel.png?size=96" width="56" height="56" alt="betizzel"></a>
<a href="https://github.com/TripleU613" title="TripleU613"><img src="https://github.com/TripleU613.png?size=96" width="56" height="56" alt="TripleU613"></a>
<a href="https://github.com/FatBoy721" title="FatBoy721"><img src="https://github.com/FatBoy721.png?size=96" width="56" height="56" alt="FatBoy721"></a>
<a href="https://github.com/ja-818" title="ja-818"><img src="https://github.com/ja-818.png?size=96" width="56" height="56" alt="ja-818"></a>
<a href="https://github.com/Isaac-Duarte" title="Isaac-Duarte"><img src="https://github.com/Isaac-Duarte.png?size=96" width="56" height="56" alt="Isaac-Duarte"></a>
<a href="https://github.com/joshuaswarren" title="joshuaswarren"><img src="https://github.com/joshuaswarren.png?size=96" width="56" height="56" alt="joshuaswarren"></a>
<a href="https://github.com/erikwb" title="erikwb"><img src="https://github.com/erikwb.png?size=96" width="56" height="56" alt="erikwb"></a>
<a href="https://github.com/chrisohearn" title="chrisohearn"><img src="https://github.com/chrisohearn.png?size=96" width="56" height="56" alt="chrisohearn"></a>
<a href="https://github.com/funkzy" title="funkzy"><img src="https://github.com/funkzy.png?size=96" width="56" height="56" alt="funkzy"></a>
<a href="https://github.com/jgoyvaerts" title="jgoyvaerts"><img src="https://github.com/jgoyvaerts.png?size=96" width="56" height="56" alt="jgoyvaerts"></a>
<a href="https://github.com/axboe" title="axboe"><img src="https://github.com/axboe.png?size=96" width="56" height="56" alt="axboe"></a>
<a href="https://github.com/sithglan" title="sithglan"><img src="https://github.com/sithglan.png?size=96" width="56" height="56" alt="sithglan"></a>
<a href="https://github.com/RyanTheTide" title="RyanTheTide"><img src="https://github.com/RyanTheTide.png?size=96" width="56" height="56" alt="RyanTheTide"></a>
<a href="https://github.com/kazuhidet" title="kazuhidet"><img src="https://github.com/kazuhidet.png?size=96" width="56" height="56" alt="kazuhidet"></a>
<a href="https://github.com/IronsideXXVI" title="IronsideXXVI"><img src="https://github.com/IronsideXXVI.png?size=96" width="56" height="56" alt="IronsideXXVI"></a>
<a href="https://github.com/satchlj" title="satchlj"><img src="https://github.com/satchlj.png?size=96" width="56" height="56" alt="satchlj"></a>
<a href="https://github.com/m0d16l14n1" title="m0d16l14n1"><img src="https://github.com/m0d16l14n1.png?size=96" width="56" height="56" alt="m0d16l14n1"></a>
</p>

<p align="center"><sub>M5 owners, Aurora Silicon and omacom people whose work is in here or watched. What came from whom: <a href="docs/credits.md">credits</a>.</sub></p>

**Send your M5 work here.** Open a pull request under your own name ([how](CONTRIBUTING.md)); keep your upstream
pull request, and we drop our copy when it merges there.

## Docs

| | |
| --- | --- |
| [What works](docs/what-works.md) | every feature, tested on which kernel, and whose work |
| [Install](docs/install.md) | the installer, step by step, and going back to macOS |
| [What's new](docs/news.md) | releases and updates, newest first |
| [TODO](docs/todo.md) | what's next and what owners can test |
| [Credits](docs/credits.md) | who we collect from, what we sent upstream, repos we watch |
| [Other M5 boards](docs/boards/README.md) | K114s, J716s |
| [Help out (dev)](docs/dev.md) | building it yourself, patches, the watch script |
| [Upstream](docs/upstream.md) · [Maintenance](docs/maintenance.md) · [History](docs/status-and-history.md) | the long notes |

---

<p align="center"><sub>Built on <a href="https://asahilinux.org">Asahi Linux</a>, <a href="https://github.com/aurora-silicon">Aurora Silicon</a> and <a href="https://github.com/omacom">omacom</a>.
<a href="LICENSE">MIT</a> for this repo's own scripts and docs; patches keep the license of the project they apply to. No Apple firmware is shipped here.</sub></p>
