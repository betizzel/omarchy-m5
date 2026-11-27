# 05 — Repo audit, Q1/Q2 answers, J714s build

## Headline
- **DTB built.** `build/linux/arch/arm64/boot/dts/apple/t6050-j714s.dtb`, sha256 `25201b46…2681ed`.
- **The kernel `Image.gz` is blocked on one missing host package: `bc`.** Kbuild needs it for `timeconst.h`. Building it from a downloaded GNU tarball was refused by this session's permission classifier as external code. Everything else is ready: patches applied, config merged.
- **Bootloader: owner step.** All T6050-capable m1n1 builds are upstream m1n1 or forks of it. Per the owner's note, a fork's own instructions don't override upstream's notice.
- **Q1/Q2 answered** from our dump. PMP's two gates are **`PMP`** (0x1b) and **`PMS_SRAM`** (0x1c). The **CPU cluster power managers `MCPM0`/`MCPM1`/`PCPM` are `notify_pmp`**, which is strong static support for "PMP gates SMP". (!) The provenance caveat below applies.

## A. Repo audit (checked 2026-11-04 via `gh api …/contents/{CLAUDE,AGENTS,GEMINI}.md`, `.github/copilot-instructions.md`, `/license`)

| repo | branch | license | AI instructions | our use |
|---|---|---|---|---|
| AsahiLinux/m1n1 | main | MIT | root CLAUDE.md/AGENTS.md: AI tools must not use it (c9a03479) | **no** (rule 7) |
| aurora-silicon/aura | main @ ea464790 | GPL-2.0 + inherited MIT (NOASSERTION) | Aurora policy (all 4 files): "Only public code goes in. Never copy code from proprietary sources." / "Changes are tested on the hardware they affect before they are merged." It says upstream instruction files are "never carried here". | allowed by its own text, **but it's an m1n1 fork**. See the caveat. |
| aurora-silicon/m1n1 | main | MIT | same Aurora policy | same as aura |
| edimoldovan/m1n1 | t6050-aurora | MIT | none present (no CLAUDE/AGENTS/GEMINI) | m1n1 fork with the notice absent. **Treated as restricted** (owner's note) |
| omacom/m1n1 | integration/aurora | MIT | none present; its CI script `check-upstream-ai-docs.sh` manages upstream's AI files | **treated as restricted** |
| edimoldovan/linux-aurora | t6050-j714c | GPL-2.0 (NOASSERTION) | none | allowed (reference) |
| omacom/linux-aurora | integration/aurora | GPL-2.0 | none (CONTRIBUTING is report-format only) | allowed |
| AsahiLinux/linux | asahi-wip-7.2 @ 236788cd | GPL-2.0 | none in tree (checked root) | allowed. Asahi's LLM policy only covers *contributions*, and we submit none |
| betizzel/omarchy-m5 | main @ 15cd70c1 | **no license file** (README: "Remove LICENSE for now", 10-10) | none | local use for building only. **Don't redistribute** its patches or DTs until it has a license. Ask the author. |
| omacom/omarchy-mac-pkgs | main | MIT | AGENTS.md: engineering rules (package contract, tests) | allowed |
| omacom/omarchy-mac-installer | main | MIT | AGENTS.md "goal autonomy": stop for owner authority, credentials, physical-device access | allowed |
| omacom/omarchy-mac | quattro | MIT | AGENTS.md: task guides in `agents/skills/` | allowed |

## B. Q1/Q2 (additions to report 04's findings)

(!) **Provenance:** the struct layouts (PMGR `devices` 48-byte record, `ps-groups`, `ptd-range` 32-byte entries) came from **aurora-silicon/aura** `proxyclient/.../adt.py` @ ea464790 (SPDX MIT). Aura's policy allows AI use, but **aura is an m1n1 fork and that file descends from upstream m1n1**. I used it before reading the owner's note ("don't assume a fork's instructions override upstream m1n1's notice"). Under that note, this use was probably out of bounds. **PM to decide** whether these results stand, or whether the owner re-derives them by hand. The decoder `tools/adt-pmp-decode.py` (our code, layouts transcribed from aura) is committed and labelled. Per rule 7 I have not deleted anything.

**Cross-check:** the decoded addresses match edimoldovan's independently published values: GFX `0x23_00e8_0110`, AFR `…_0100`, CS `…_0108`, `ps_pmp` `0x2_8060_0128`, PTD base `0x2_8424_0000`, and the full ptd-range table is identical to J714c.

**Q1, PMP gates and `notify_pmp`** (pmgr: 661 devices, u16 ids, 6 ps-groups):
- `pmp0` gates: **0x1b = `PMP`**, PS reg `0x2_8060_0128`, flags critical, parent 0x16 `PMS`. **0x1c = `PMS_SRAM`**, PS reg `0x2_8060_0130`, critical, parent `PMS`. `PMS` (0x16) is at `0x2_8060_0100`, critical/no_ps.
- **`notify_pmp` domains:**
  - **CPU cluster managers `MCPM0` (0x13, `0x2_8060_0090`), `MCPM1` (0x14, `…0098`) and `PCPM` (0x15, `…00a0`).**
  - GFX (0x16a, `0x23_00e8_0110`; parents AFR, GPX).
  - ANS, DISP_SYS/FE, DISPEXT0–3 SYS/FE, ATC0–3_COMMON, AUSS, SCODEC(+STREAMING), ISP_SYS, ANE_SYS, VENC0/1, MSR0/1 (+ASE_CORE), JPG, AVD_SYS, PRORES.
  - About 20 `no_ps` voltage-vote entries (`*_SOC_VNOM/VMAX`, `*_FAST`, `TRACE_FAB_GFX`, `ANE_SYS_V_PMP`).
- **Discrepancy:** in our decode, **`CS` (0x169, `0x23_00e8_0108`) has no `notify_pmp`, parent AFR only**. edimoldovan reported CS as `notify_pmp` with parents 360/359; in our data that description fits **GFX**. Either J714c and J714s differ, or one of the readings is wrong. Owner/edimoldovan to confirm.
- **New for the SMP story:** core *cluster* power on T6050 is PMP-notified. [guess] Releasing secondary clusters requires PMP to act on MCPM/PCPM requests, which fits edimoldovan's "release goes through PMP".
- **ANS (NVMe) is also `notify_pmp`.** It still works under betizzel's and edimoldovan's boots, presumably because iBoot leaves it on.

**Q2, PTD:** base = `pmp0` reg[3] `0x2_8425_0000` − 0x10000 = **`0x2_8424_0000`**. **PMP-STATUS read `0x2_8424_0010`** / write `0x2_8425_0008`. SOC-DEV-PS-REQ read `…1e00` / write `0x2_8425_0f00`; SOC-DEV-PS-ACK `…1e80`; PMP-TO-GFX `…2b50`; GFX-TO-SMC `…27a0`. The full table (29 entries) is in `tools/adt-pmp-decode.py` output and matches J714c exactly.

**Probe plan update** (report 04 §4):
- Probe #8 becomes concrete: single reads of **`0x2_8060_0128` (PMP)**, **`0x2_8060_0130` (PMS_SRAM)** and `0x2_8060_0100` (PMS).
- Add reads of `0x2_8060_0090/98/a0` (MCPM0/MCPM1/PCPM) to see cluster power state.

## C. Build

**Kernel** (`tools/build-kernel.sh`; user-level, clang 23.1.3 / lld, `LLVM=1`, no Rust because betizzel's config disables `CONFIG_RUST`):
- `AsahiLinux/linux@236788cd` + betizzel's 9 patches (all apply cleanly) + `dt/` overlay + configs `defconfig asahi.config omarchy-bringup.config omarchy-storage-net.config omarchy-smc.config`. Done in `src/linux-asahi-wip72`, output in `build/linux`.
- yes `t6050-j714s.dtb`: sha256 `25201b463eaf16daf40901dccb898507e2871fe49455c85be83fe64b6d2681ed`, model "Apple MacBook Pro (14-inch, M5 Pro, 2026)".
- no `Image.gz`: `bc: command not found` at `include/generated/timeconst.h`. Fix: `sudo pacman -S bc` (system-wide, so it needs task permission), or approve the user-level `bc` build into `tools/local`. Then rerun `tools/build-kernel.sh`; it writes `build/SHA256SUMS`.

**Bootloader: owner step** (no authorized AI path: every T6050-capable build is upstream m1n1 or a fork of it). The owner, by hand, on the host:
```sh
git clone --recursive https://github.com/AsahiLinux/m1n1.git && cd m1n1 && git checkout 70757dc7
# betizzel patches 0001,0003,0004,0005 (from omarchy-m5@15cd70c1); 0001 and 0005 need a 1-hunk hand merge each (03A); skip 0002/0006
for p in 0001 0003 0004 0005; do git apply --3way ../omarchy-m5/patches/m1n1/$p-*.patch; done   # resolve conflicts
rustup target add aarch64-unknown-none-softfloat       # needs rustup (not on ush; system rust lacks this target)
make CHAINLOADING=0 -j && cp build/m1n1.bin ../m1n1-stage1.bin
make CHAINLOADING=1 -j && cp build/m1n1.bin ../m1n1-chain.bin
```
The host also needs `rustup` (or the target's rust-std), and `picocom`/`pyserial`/`construct` for proxyclient.

## D. Before the first tethered boot
1. `bc` on the build host → build `Image.gz` (mine; needs permission).
2. Initramfs: betizzel's `mkinitramfs.py` downloads Alpine busybox (external code; needs approval) or the owner supplies one.
3. Owner builds m1n1 (above) on the machine that will be cabled to the MacBook.
4. Owner does the MacBook stub and 1TR ceremony (03A §2). Every boot/security step is owner-only.
5. Owner runs the tethered `linux.py` boot with `maxcpus=1` (03A §3) and the PMP read probes (04 §4 + above).
6. PM decision on the aura-layout provenance question (B).
