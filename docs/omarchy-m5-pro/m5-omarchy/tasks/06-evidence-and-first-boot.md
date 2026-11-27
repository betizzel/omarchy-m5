# Task 06 — Evidence ledger + concrete first-boot procedure (no Mac changes)

Owner's requirements, verbatim intent: tighten evidence before any change to the Mac is proposed. Outputs: `reports/06-evidence.md`, `reports/06-first-boot.md`. Don't modify the MacBook. Check every repo's own AI instructions before using it (rule 7).

## A. Evidence ledger (`06-evidence.md`)
1. **J714s/T6050 boot claims:** for each claim we rely on (betizzel/omarchy-m5, edimoldovan J714c, scottjones J815, Yureka #578/#610…), give the exact URL + commit SHA or comment permalink + a short quote, and label it: **OBSERVED-BY-US** (our dumps), **REPORTED-NATIVE** (whose hardware, which board), **REPORTED-VM**, or **HYPOTHESIS**.
2. **Failures vs hypotheses:** separate observed symptoms (cores power on but don't fetch; `+0x44` read faults; GPU jobs stall on `cs`; bulk PTD read crash) from explanations. Specifically assess the claim "PMP explains both the CPU and the GPU failures": who claims it, what evidence supports each half, what would falsify it, and the alternatives (SPTM per betizzel, etc.).
3. **m1n1 restriction:** quote upstream's CLAUDE.md/AGENTS.md verbatim with path + commit. Then, for each fork/derivative we'd need (aurora-silicon/aura, edimoldovan/m1n1@t6050-aurora, betizzel's m1n1 patches, any prebuilt m1n1 binary), check whether the branch still carries that notice and what its own instructions say. **Don't assume a fork's instructions override the inherited requirement.** Conclude conservatively which concrete steps an AI session must not do, and why, with citations.

## B. First-boot procedure (`06-first-boot.md`)
1. **Why the extra boot partition and reduced security are needed:** cite Apple's Platform Security Guide (boot policy per OS / LocalPolicy, Permissive Security, `kmutil configure-boot`) and the Asahi installer procedure (asahi-installer source/docs, after checking their AI instructions). Give the **real** size requirement with a citation (the stub container size and minimum free space). Our earlier "~40 GB" was uncited, so correct it. List **exactly** what changes on the Mac: partitions/containers created, which boot policy changes and for which OS only, NVRAM/SIP/boot-args and their scope (per-OS or global), and what stays untouched (main macOS security, recoveryOS, SEP/firmware).
2. **Equipment:**
   - Host candidate: **"work"**, a Lenovo ThinkStation P3 Tiny Gen 2 (Intel Core Ultra 200, two 20 Gbps USB root hubs, so USB-C ports likely; no `/sys/class/typec`), Arch-based Omarchy, Python 3.14.8, `pyserial` not installed.
   - State what's needed: the exact cable type (C-to-C data, A-to-C OK?), which MacBook port, the host ports, and the host software.
   - Say whether "work" is sufficient and what's missing.
   - Also: can DFU revive/restore be done from Linux (e.g. idevicerestore + macvdmtool or similar), or does it strictly need another Mac? Cite.
3. **Step-by-step first boot:**
   - Every step that changes the Mac is marked (!) for owner approval, with exact commands.
   - Owner steps that are owner-only because of the restriction in A3 are marked with the citation.
   - Give the expected output at each stage (m1n1 banner/log lines, proxy connect, kernel earlycon lines, what "single-core boot reached a shell" looks like) and the known failure modes.
4. **Recovery procedure:** boot picker → macOS; removing the stub and restoring the partition layout; DFU revive vs restore (what each preserves).
5. **Artifacts:** list the Task 05 build outputs (paths, SHA-256, how built, checks performed: dtc compile, `file`, config sanity) and what's still unbuilt.

End with `DONE 06`.
