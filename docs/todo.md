# TODO

What's next, roughly in order. Anyone with an M5 Mac can take one: open an issue or a pull request.

**Being worked on here**

- **Screensaver burns about 40 W.** Omarchy's screensaver (a full-screen ghostty) keeps the M5 GPU at full load
  through zink: SoC power 40 W instead of 1.9 W, GPU sensors at 90-97 C, fans at 4400 rpm, and the battery drains
  while you're away. Likely uncapped frame rate (no vsync through zink). Workaround: set `idle.screensaver` to `0`
  and `idle.lockScreensaver` to `false` in `~/.config/omarchy/shell.json`. Find the cause, then report it to Mesa.
- **Power-saver pins the CPUs to 300 MHz.** The kernel's low-power profile has a 15 W package budget (CLPC, PHPC);
  any load above it (like the screensaver) steps every cluster down to the minimum and holds it. Measure the J714s's
  real package power to see whether 15 W fits, then propose a value upstream.
- **Release 11 installer image:** built in CI, needs one from-scratch install on a J714s before it is called tested.
- **Deep sleep:** works on the 15-core J714s with [#3419](https://github.com/aurora-silicon/linux/pull/3419), but
  the PMP does not come back after the wake (CPUs capped until a reboot). Waiting on upstream; then measure the
  battery drop over a night.
- **Next kernel:** re-pin on upstream main with erikwb's power set and axboe's GPU voltages from the loader
  (aurora-silicon/linux #3255, aura #534), measured before and after with the SMC's Total System Power.
- **Camera indicator:** the green LED stays off since v272-19; upstream draws a software indicator on the display
  instead (aurora-silicon/linux #2561, in v272-23). The J714s needs the small device-tree opt-in (as #2651 did for
  the J700); test it here, then send it upstream ([#33](https://github.com/betizzel/omarchy-m5/issues/33)).
- **Next loader (m1n1):** aura's T6050 changes since our pin (funkzy's AOP handoff #474, framebuffer checks #492).

**Needs testing (owners welcome)**

- Headphone jack on 27.2 (asahi-audio #44 and alsa-ucm-conf-asahi #33 merged upstream).
- Microphones: still about 19 dB quieter than Isaac-Duarte's measurement; check the gain on more machines.
- Bluetooth headset audio (RFCOMM loads, nothing played yet).
- HDMI after a sleep on an external display (FatBoy721's fix is in the kernel).
- DisplayPort audio (three cards show up, nothing played yet).
- Thunderbolt dock with three displays (Isaac-Duarte's work is upstream).

**Not working yet (upstream work)**

- USB-C DisplayPort on the right port and on the left DFU port.
- Hardware video encode on 27.2 (probe only).
- Neural Engine: device up, no workload run yet.
- The bar's GPU widget: the aurora driver reports per-client GPU time only for some engines; no usage graph yet.

[Back to the README](../README.md)
