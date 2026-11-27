# TODO

What's next, roughly in order. Anyone with an M5 Mac can take one: open an issue or a pull request.

**Being worked on here**

- **Screensaver burns 17-40 W.** Omarchy's screensaver keeps the M5 GPU busy. In ghostty (2026-11-27, owner
  watching): both GPU engines 195% busy, SoC power (PHPC, "Heatpipe") 40.6 W against about 2-3 W without it, GPU
  sensors 90-97 C, fans 4400 rpm, while ghostty used 7% CPU. In foot, which draws on the CPU (measured the same
  evening): PHPC 17-18 W with `ttfx` at about 1% CPU, so most of that is Hyprland compositing the full-screen
  animation, and Hyprland's GL renderer runs through zink on the Vulkan driver (no native OpenGL on the M5). For
  scale, on an otherwise idle desktop at 6 W: full-screen `es2gears_wayland` (GL through zink) 12.4 W,
  full-screen `vkgears` (native Vulkan) 7.0 W; not the same work, so only a hint that the zink path is the
  expensive one. Workaround: `idle.screensaver` `0` and `idle.lockScreensaver` `false` in
  `~/.config/omarchy/shell.json`. Next: a like-for-like GL vs Vulkan client, then report to aurora-silicon/mesa.
- **Power-saver drives the CPUs to 300 MHz under a GPU load.** The low-power profile (`clpc.c`, T6050: ceiling
  2808 MHz, `low_power_mw` 15000) reads the SMC's package power (PHPC, which includes the GPU) every 100 ms and
  takes one CPU frequency step off for each new reading above 15 W, one back below 13.5 W. Measured on our J714s
  2026-11-27 (on battery): 15 CPUs busy settle at about 2.0 GHz and 14 W (balanced: 4.38/4.61 GHz, 52 W), so 15 W
  fits a CPU load. With the foot screensaver PHPC stays at 17 W (18 W in balanced, uncapped), so the loop steps
  every cluster down to 1.3 GHz and cluster 0 to 300 MHz within 28 s, for about 1 W. The budget isn't the
  problem: the controller throttles the CPUs for power they don't draw. `policy->cur` can't tell it apart (it
  reads at the cap 50-90% of the time even at 6 W), so the fix needs a real CPU share: the PMC's cluster power,
  CPU utilisation, or a floor on the step-down. To propose upstream with these numbers (`clpc.c` on main has
  the same loop).
- **Release 11 installer image:** [published](https://github.com/betizzel/omarchy-m5/releases/tag/omarchy-j714s-11) as a prerelease; needs one from-scratch install on a J714s before it is called tested (asked on #12).
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
- Microphones: speech peaks read about 19 dB below Isaac-Duarte's measurement. The chain isn't the cause: our
  `mic.json` is upstream's `firs/j714/mic.json` (only the name differs), the source volume is his 70 %, and the
  `omarchy_asahi_mic` loopback passes 0.00 dB on both channels (measured 2026-11-27). Next: one speech
  recording his way (p95 over 100 ms frames, `pw-record --target effect_output.j714-mic`).
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
