# Other M5 boards

- **K114s** (14-inch OLED, M5 Pro, `apple,k114s`): admitted in developer builds, experimental, tested on one machine by chrisohearn; no image here, and admission alone gives a keyboard-only system.
  Notes: [`docs/boards/k114s.md`](k114s.md) and [chrisohearn/omarchy-m5p-oled](https://github.com/chrisohearn/omarchy-m5p-oled).
- **J716s** (16-inch, M5 Pro, `apple,j716s`): admitted in developer builds, experimental, tested on one machine by ja-818 on the 27.2 stub with release 9's image ([#28](https://github.com/betizzel/omarchy-m5/issues/28), [#29](https://github.com/betizzel/omarchy-m5/pull/29)). Works there: all 18 CPUs, panel, keyboard, trackpad, USB, Bluetooth, lid sleep; Wi-Fi with a device-tree change not carried here yet.
  In kernel v272-19 (built and booted on our J714s, not released yet; 0009-0011 there): front camera ([#31](https://github.com/betizzel/omarchy-m5/pull/31)); jack, microphones and light sensor with the speakers held off ([#32](https://github.com/betizzel/omarchy-m5/pull/32)). Not tested on a J716s in this build.
  Earlier report on the 27.3 beta with rolotrealanis98's own kernel: [#23](https://github.com/betizzel/omarchy-m5/issues/23).

[Back to the README](../../README.md)
