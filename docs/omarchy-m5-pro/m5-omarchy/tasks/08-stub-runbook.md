# Task 08 — Partition/stub step: exact audit and runbook (no Mac changes yet)

The PM will run the non-m1n1 disk steps on the Mac over SSH (owner types sudo/FileVault creds). The recovery path is verified: `work` sees the Mac in Port DFU (`irecovery`: Mac17,9 j714sap, MODE Port DFU) with idevicerestore HEAD ae8cfb4 + usbmuxd HEAD, over a USB 2.0 port. Output: `reports/08-stub-runbook.md`.

1. **Audit `omarchy-m5/scripts/prep-stub.sh` line by line** (and anything it calls, e.g. an asahi-installer engine):
   - which disk/partitions it touches and how it picks them (it must refuse anything but disk0 with our layout);
   - the exact `diskutil` commands and sizes;
   - what it downloads (IPSW pieces? which URL/version?) and how it verifies them;
   - which macOS version the stub OS gets (it must suit this Mac: macOS 26.6.2, mBoot-18000.161.10; betizzel used mBoot-18000.120.36);
   - whether any step involves m1n1 (those are owner steps);
   - what it leaves for the 1TR step.
   Also note any assumptions that don't hold on our Mac.
2. **Runbook for the PM:** the exact command sequence to run over SSH, split into **(a) read-only pre-checks** (`bputil -d`, `diskutil list`, free space, FileVault/SIP state, `fdesetup`) and **(b) changes**, each with its expected output and a stop condition. Include a dry-run if the script has one.
3. **The 1TR step for the owner:** exact screens and button presses (power-hold → Options → pick the stub → Terminal / Startup Security Utility?), the exact commands, and which credentials it asks for. Mark the m1n1 parts [owner-only].
4. **Undo:** exact commands to remove what step (b) creates.
End with `DONE 08`.
