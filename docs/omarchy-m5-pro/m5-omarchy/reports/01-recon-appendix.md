# 01 — Recon appendix (raw tables)

## m1n1 M5-related PRs (AsahiLinux/m1n1)

| PR | State | Title | Author | Merge SHA / date |
|---|---|---|---|---|
| 578 | merged | pmgr: support M4 Pro/Max / A18 Pro / M5 (device-mode USB on M5 Max MBP) | yuyuyureka | 3cb2ebee, 2026-05-15 |
| 610 | merged | Initial support for T6050/T6051 | yuyuyureka | b2d3f5eb, 2026-06-29 |
| 626 | merged | Support SPMI gen 4 | yuyuyureka | 2026-07 |
| 629 | merged | Initial support for T8142 (numbers confirmed by rhlvista on IRC) | yuyuyureka | b72e664f, 2026-07-19 |
| 637 | merged | nvme: fix cdw12 value to read 1 block | yuyuyureka | 2026-07 |
| 661 | merged | sart: add SARTv4 support | yuyuyureka | 9bfdf8ae |
| 657 | merged | kboot: add reserved M4 smp-ro region (CTRR_M4) | yuyuyureka | 2026-08 |
| 682 | merged | SMP stack and cache fixes (didn't fix Sven's M4 Pro issue) | svenpeter42 | 2026-09 |
| 698 | merged | Add SPTM support to hypervisor | lukasrad02 | 84b81988, 2026-10-15 |
| 737 | merged | M5 MCC + HV secondary hook support (T8142) | svenpeter42 | 578600a1, 2026-10-26 |
| 738 | merged | hv: Patch additional TLBI instructions added for M5 | svenpeter42 | 042ca91c, 2026-10-26 |
| 740 | merged | hv: fake SPTMDebug region for SPRR shadow pages | svenpeter42 | a089d960, 2026-10-26 |
| 741 | merged | hv: more sysregs found in M5's kernelcache | svenpeter42 | 1b7a258e, 2026-10-26 |
| 747 | closed | T8142 (J704) bring-up (hishamMounir; withdrawn to "GravityLinux" fork) | hishamMounir | — |
| 754 | merged | hv: Handle OSLAR and SMPRI traps in C | svenpeter42 | 34c1a1e2, 2026-11-01 |
| 758 | **open** | M5 hypervisor (cL4 contexts, SPTM setup regs, amcc masks) | svenpeter42 | opened 2026-11-01, no reviews |
| 563 | open | smp: Allow switching the boot (primary) CPU core | jannau | relevant: M5 Pro boots on an M-core |

Issue #706 (wyr1028, J704 ADT recon) was closed by its author per the LLM policy.

Fork branches checked with no T6050 content: yuyuyureka/m1n1 `smp-debug`, `find-regs-smp`, `feature/untested-t8142-pcie`, `switch_boot_cpu`. Also yuyuyureka/u-boot-asahi (`asahi`, `pmp`) and yuyuyureka/asahi-installer (no M4/M5 entries).

## Source facts (m1n1 tree @ 70757dc7)

- `src/soc.h`: `T6050 0x6050`, `T6051 0x6051`, `EARLY_UART_BASE 0x505200000` for both.
- `src/midr.h`: T6050 Sotra M=0x64, P=0x65; T6051 Sotra C M=0x68, P=0x69; T8142 Hidra E=0x62, P=0x63.
- `src/chickens.c`: all of them use `features_m4`.
- `src/smp.c`: T6050/T6051 use `CPU_START_OFF_T6031`.

## Device IDs (Asahi device list)

| Model | ID | Board | SoC |
|---|---|---|---|
| MBP 14" M5 Pro (ours) | Mac17,9 | J714sAP | T6050 |
| MBP 16" M5 Pro | Mac17,8 | J716sAP | T6050 |
| MBP 14"/16" M5 Max | Mac17,7 / 17,6 | J714cAP / J716cAP | T6051 (but one J716C ADT says 0x6050) |
| Mac mini M5 Pro | Mac17,16 | J873sAP | T6050 |
| MBP 14" M5 | Mac17,2 | J704AP | T8142 |
| MBA 13" M5 | Mac17,3 | J813AP | T8142 |

## Asahi installer gating

`src/main.py` `CHIP_MIN_VER` ends at T6034 (M3 Max); `DEVICES` ends at j516map. Line 973 exits with "not supported yet" whenever the chip or device is missing, even in expert mode. Env vars include `EXPERT`, `INSTALLER_BASE`, `INSTALLER_DATA`, `REPO_BASE`, `IPSW_BASE`. `src/step2/step2.sh`: `bputil -nc -v $VGID` (l.107), `kmutil configure-boot -c boot.bin --raw --entry-point 2048 --lowest-virtual-address 0 -v $system_dir` (l.125).

## Asahi feature-support GPU row

M3 base: WIP. M3 Pro/Max/Ultra: TBA. M4/M4 Pro/Max/A18 Pro: TBA. M5/M5 Pro/Max: TBA (everything is TBA, and "Installer: no").

## Omarchy / Aurora repo map

| Repo | Role |
|---|---|
| omacom/omarchy-mac (stars 2k) | Original Omarchy-on-Mac desktop (from malik-na, Codeberg mirror `quattro` branch) |
| omacom/omarchy-mac-pkgs | `omarchy-mac`, `omarchy-mac-boot` packages, built via omacom/omarchy-pkgs to pkgs.omarchy.org |
| omacom/omarchy-mac-installer | Swift macOS app + Asahi v0.9.2 engine overlay; `scripts/supported-models.json` refuses `apple,j614s` ("M4 and later") |
| omacom/linux-aurora | Kernel (default `integration/aurora`); has `t8142-j813*` DTs; no t605x |
| omacom/m1n1 | m1n1 fork (default `integration/aurora`); `j873` branch = T8142/J813 + Windows-on-AS + early M6 J873g, not T6050 |
| omacom/mesa | Mesa fork; PR #19 merged G17P work from aurora-silicon/mesa |
| aurora-silicon/linux | Upstream of linux-aurora. `t6050/*` APIF review branches (base, nvme, pcie, pmp, guest-wiring, spmi, pmu-rtc, smc, display-phy, cpufreq, centauri-core/wifi/bluetooth, dcp, gpio-irqs, typec-events, usb, pmgr, mtp, platform-wiring); snapshot `t6050-gpu@ee68abb105200` (not public as a branch) |
| aurora-silicon/aura | Their bootloader/EL2 monitor (m1n1 fork, GPL-relicensed contributions) |
| aurora-silicon/aurora-silicon.github.io | `src/data/support.json` marks j714s works for most features; provenance "Project owner confirmation in this session" |
| maralcbr/omarchy-m-testing | Hardware test CLI + omarchy-m-testing.org |

Aurora discussion #142 (refreshed 2026-10-16) lists J714S and J716S as "- No matching working-tree DTS or named-board runtime result found". The APIF series is "build- and host-tested only". J716C (MarianoMiguel) and J704 (EliasJernberg) owners have asked about the site/discussion mismatch.

## Other third-party M5 efforts (noise)

- sentaxic/asahi-m5: J813, "pre-boot, nothing run on hardware".
- hishamMounir: J704 m1n1 branch; moved to a "GravityLinux" fork.

## Sources not reachable

lore.kernel.org returned 403 to both curl and WebFetch, so the mailing lists were not searched directly. GitHub code search found no `t6050`/`t8142` in AsahiLinux/linux (it only indexes the default branch).

## Details moved from the main report

- Host tools: `picocom-sec.sh`, `linux.py`, `run_guest_kernel.sh`. Hypervisor on M4+ needs `run_guest.py --sptm-mode {emulation,nested} --sptm … --txm …` (plus optional `--exclave-*`).
- Recovery fallback [guess]: libirecovery added the MacBook Pro M5 Pro/Max IDs on 2026-07-15, so `idevicerestore` from Linux might do a DFU restore. Untested.
- DFU steps (Apple 108900): cable from the DFU port to the host Mac; hold power 10 s to turn off; press and release power, then hold left Ctrl + left Option + right Shift + power for 10 s; release all but power and keep holding until the host shows DFU. Port per theapplewiki: M4/M5 MBP front-left Thunderbolt.
- Sven called M4 "rather painful" in Apr 2025 (AppleInsider: https://appleinsider.com/articles/25/04/08/asahi-linux-m4-support-hits-a-roadblock-because-of-apple-silicon-changes). The cause was SPTM + GXF lockdown, and the hypervisor side is now solved.
- Aurora's DCP targets the 26.6/27 firmware ABI (`dcp-peer-v26_6`, "Firmware-27 AFK").
- [guess] Aurora work is largely agent-driven (commit prose, "for agents" tooling, "confirmation in this session" provenance).
