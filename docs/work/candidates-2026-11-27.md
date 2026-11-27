# Open work for the J714s, found 2026-11-27 (candidates, not taken yet)

Open PRs by M5 contributors, updated since 2026-11-20, that touch the M5 Pro (T6050, G17S, N1, t8152-aop-audio)
or the Omarchy userspace on it. Nothing here is merged or tested on our J714s yet; each is taken only after a test.

## Battery and sleep (top priority)

| PR | Who | What |
| --- | --- | --- |
| aurora-silicon/linux #3335 | erikwb | dockchannel: stop the idle console drain timer (62/s), -190 mW on a J716c |
| #3294, #3289 | erikwb | fw27 panel soft power-off on DPMS off; static-frame idle caching |
| #3293, #3329, #3292 | erikwb | CLPC deferrable timers; `ps_isp_sys` and ANE power off when idle |
| #3297, #3300, #3307, #3308 | erikwb | display interface power domains across S2R, display DART drain, idle external DCPs off |
| #3271 | axboe | N1 up across sleep only when WoWLAN is armed |
| #3346 | erikwb | N1: recover stopped firmware by warm reset |
| #2070 | rolotrealanis98 | refuse deep sleep at `.prepare` when the fw27 display sleep is unknown (matters for v272-22's deep sleep) |
| #3348 | DjDeveloperr | g17: map the sleep stop's registers nonposted |
| linux #3255 + aura #534 | axboe | M5 Pro GPU operating points filled by the loader from the ADT |
| (config) | ours | `CONFIG_APPLE_SOC_SLEEP=y` (upstream default): v272-22 candidate, building |

## GPU

- linux #3313, #3309 (funkzy): G17 render -19-24%, compute -19% (warm kicks, pooled render storage).
- linux #3342, #3330, #3319, #3311, #3251 and others (DjDeveloperr), #3324/#3325 (oreater), #2228/#2724/#2858 (jgoyvaerts): G17 submit cost and correctness.
- Mesa (arrives through omacom's edge build): oreater #1167/#1175/#1184/#1187, jgoyvaerts #554/#572/#573/#637, funkzy #1150.
- omacom/omarchy-pkgs #3694 (joshuaswarren): absolute `library_path` in the vulkan-aurora ICD (the relative path is why a test Vulkan loaded the installed library).

## Audio

- asahi-audio #45 (Isaac-Duarte) with alsa-ucm-conf-asahi #24 (edimoldovan) or #19 (DjDeveloperr): J714 microphones on the HPAI card (speech -56 -> -18 dBFS). asahi-audio #30 (DjDeveloperr) is the generator-based alternative.
- asahi-audio #44, ucm #33 (RyanTheTide): headphone-jack switching; ucm #34: no raw Speaker device while speakerguardd v2 owns the speakers.
- linux #3312, #3212 and speakerguardd #269 (DjDeveloperr): t8152-aop-audio sense pointer check, speaker mux grant races.

## Display and other

- linux #3283 (rolotrealanis98): refuse panel brightness after a DCP crash, the same fix as our kernel 0002 (drop ours when it merges).
- linux #3282 (rolotrealanis98): N1 joins open networks; #2872 (ja-818): WPA/WPA2 mixed (our 0008).
- linux #3105 (chrisohearn): hold brightness requests at the panel's floor.
- alarm-aurora #455 (RyanTheTide): perceptual backlight scale.
