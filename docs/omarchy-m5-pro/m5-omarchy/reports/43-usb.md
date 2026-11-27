# 43: USB0 gadget (SSH over a cable) and host mode: plan, aurora code, test sets

**Status:** built, not run. Nothing below has touched the Mac. It all runs through the hands-free kexec loop. The three m5next/ sets share the same initrd (`1a459b5b…`, copied from the proven `~/m5boot/build/kexec-nvme/B`).

| Push | m5next/ (Image + initrd + cmdline + SHA256SUMS) | m5drop/ | Writes |
|---|---|---|---|
| **1. u0** | `build/usb-v1/m5next-u0/`, usb-v1 Image `6ca13193…`, cmdline `fa31bb75…` | `loop/u0/m5drop/` | none (PMGR reads only) |
| **2. u2** (!) | `build/usb-v1/m5next-u2/`, same Image, cmdline `c1f8c4dd…` | `loop/u2/m5drop/` | PMGR: only atc0_common/usb_aon/usb/phymxwrap (kernel allow-list); ATC0 usb2phy, usb2-digital, pipehandler (logged) |
| MTP **t15** | `build/loop-v1/m5next-t15/`, loop-v1 Image `0c511a53…`, cmdline `fc10a8d7…` | `loop/t15/m5drop/` | none from us; the kernel sets DART-mtp TCR bypass at attach |

## What already exists (cite)
- **aurora-silicon/linux (GPL-2.0; no AI-instruction files; m1n1/aura not read).** It has T6050 USB code, all on branches and **not in integration/aurora**. Their own header says "modeled ACKs are not hardware proof".
  - **`t6050/usb` f00c0038ee:** `dwc3-apple` T6050 support, the controller plus native tunables (`drd-cfg`, `drd-bulk`, `drd-ausbc`, and eight `apple,tunable-*` tables from the ADT).
  - **`t6050/display-phy` 2aaccf67c6:** `atc-t6050-dp.c` (GPL-2.0) and the MIT headers `usb-t6050/apple_t6050_usb_phy.h`, `apple_t6050_usb3_pipe.h` and `apple_t6050_usb2_reset.h`. These contain the eUSB2 **host** sequence, the USB3 init sequences and the cold **dummy-PIPE** sequence (mux 0x42).
  - **`j716c/t6050-combo-phy` (c24e75ca9d) `atc-t6050-combo.h`:** the combo PHY. USB2 runs only in host mode (`combo_usb2_mode` rejects anything that isn't `PHY_MODE_USB_HOST`). Its banks: `usb2phy` = bank 0, `usb2-digital` = bank 1, `pipehandler` = bank 44.
  - **integration `t6040-usb2.c` (M4 Pro, GPL-2.0 OR BSD-2-Clause):** register names: USBCTL 0x0 (MODE 2 = host), CTL 0x4 (RESET 0, PORT_RESET 1, APB_RESET_N 2, SIDDQ 3), SIG 0x8 (VBUSDET force val/en bits 1:0), MISCTUNE 0x1c (clock-gate bits 29/30).
  - **`t604x.dtsi`:** the same bank layout (`bank0` = atc-phy reg[0], `bank1` = reg[1], `pipehandler` = usb-drd reg[3]).
  - **Not found:** a T6050 device-mode eUSB2 sequence, or a public T6050 USB DT.
- **ADT (NATIVE dump).**
  - `atc-phy0` reg[0] 0x2a2a90000 (usb2phy), reg[1] 0x2a2800000 (usb2-digital). `usb-drd0` reg[3] 0x2a2a84000 (pipehandler).
  - Tunables:
    - `tunable_USB2PHY_DFLT` = {0x8: 0x7003/0x3, 0x18: 0x703/0x103}
    - `_DEV` = {0x8: 0x7003/0x3}
    - `_HOST` = {0x8: 0x7003/0x7003}
    - `usb-drd0 tunable_PIPE_HANDLER_DEFAULT` = {0x44: 4/4}
  - PMGR (decoded `devices`): ATC0_COMMON 0x280600208; ATC0_USB_AON/USB/PHYMXWRAP at block offsets 0x148/0x150/0x158 (betizzel's 0x2883001xx); ATC0_USB parents COMMON + USB_AON. The DART gate ATC0_USB_DART is virtual (child of ATC0_USB).
  - `usb-drd0` has `usb-repeater` and `Usb2Repeater`, an external eUSB2 repeater.
- **betizzel (REPORTED, `research/betizzel-2026-11-04-reset-usb.txt`):** their m1n1 gadget worked like this:
  - power the chain (about 10 ms polls, AUTO_ENABLE cleared);
  - take the eUSB2 PHY out of reset with SIG = 0x01c1000f (VBUS forced);
  - set PIPE to the dummy PHY and release DWC3;
  - then plain `snps,dwc3` with no phys.
  
  No PD controller, no PMP and no repeater setup were needed.

## Why runtime DT, not a new DTB
- **kexec reuses the live FDT.** gz16's `kexec -s` without `--dtb` keeps the m5boot-built tree, including m5boot's reserved-memory list and framebuffer.
- **A kernel-built DTB is unsafe.** `build/usb-v1/t6050-j714s-U2.dtb` (`4d4a8518…`) lacks m5boot's reserved-memory, so it is kept only as a reference. `tools/kernel/dts/t6050-j714s-m5-U2.dtsi` documents the same delta.
- **So the m5_usb module applies the U2 delta with an `of_changeset`.** usb-v1 has `CONFIG_OF_DYNAMIC` via `OF_OVERLAY`.
  - Status "okay" for the four `ps_atc0_*` pwrstate nodes (storage-net.dtsi disables them).
  - dwc3_0's DARTs: dart_0 → atc0_usb, dart_1 → atc0_phymxwrap.
  - After PHY bring-up, dwc3_0 → atc0_usb.
  - The PMGR writes are then made by the kernel's pwrstate driver. Patch 0002 allows only the cmdline allow-list (`m5_pmgr_allow=ans,atc0_common,atc0_usb_aon,atc0_usb,atc0_phymxwrap`) and logs every write.

## The sets
- **usb-v1 kernel** (`build/usb-v1/Image` `6ca13193…`, Image.gz `cad22862…`):
  - Built from loop-v1's configuration plus `tools/kernel/m5-usb.config`: configfs NCM/ECM/ACM, XHCI plus DWC3 dual-role, USB HID and storage, OF_OVERLAY.
  - vermagic is unchanged (`7.2.2-m5slim+`).
  - Built from the same tree and patches 0001–0003 as loop-v1.
- **Module `tools/loop/usb-mod/m5_usb.c`** (GPL). Every write is logged with old, new and readback.
  - **`op=state`:** reads PMGR ATC0 COMMON/USB_AON/USB/PHYMXWRAP/COMMON_DP_0..3. It reads the PHY and PIPE registers **only if the four main domains report actual = 0xf**. This is the SError guard: gz5 is suspected to be an unpowered USB0 DART read.
  - **`op=dt_power`, `op=dt_dwc3`:** the live-DT changesets above.
  - **`op=dev`:** refuses unless powered. Then:
    1. DFLT and DEV tunables.
    2. aurora's usb2 sequence: SIDDQ off; RESET and PORT_RESET off; usb2-digital |= 9; APB_RESET_N; clock gates off.
    3. SIG = 0x01c1000f (`sig=` parameter; REPORTED value).
    4. USBCTL is left alone (`usbctl=` parameter).
    5. If DWC3 is still in reset: aurora's cold dummy PIPE (mux → 0x42), the ADT PIPE tunable, then AON_GEN DWC3_RESET_N.
    
    The device-mode parts are a HYPOTHESIS: the DEV tunable in place of HOST, the forced VBUS, and leaving USBCTL as is.
- **u0 (read-only):** `op=state`. It decides whether ATC0 is off at hand-off, which betizzel guessed but never measured.
- **u2 (!):** state → dt_power → state → dev → dt_dwc3 → configfs gadget `ncm.usb0` + `ecm.usb1` on the first UDC → usb0 10.55.0.1/24, usb1 10.55.1.1/24 → `systemctl start sshd`. Then it logs `udc state` and `operstate` every minute for 10 minutes, so there is an SSH window.
  - `m5.autoreboot=900`, and the guard still applies.
  - sshd uses key auth only: `/etc/ssh/m5_authorized_keys` (our public key) through an sshd_config.d drop-in, with passwords off.
  - **Host side:** plug a cable into the **left-rear port by MagSafe** (usb-drd0 = Port-USB-C@1). Then on the host run `ip addr add 10.55.0.2/24 dev <ncm if>` and `ssh -i <key> alarm@10.55.0.1`.
- **Expected outcomes and what each means:**
  - **u2 power steps fail:** the allow-list or genpd parenting needs fixing. Look at the logged `m5 pmgr:` lines.
  - **`dev` works but the UDC never reaches `configured`:** the device-mode PHY settings are wrong. Next try `usbctl=` values and `sig=0`.
  - **dwc3 -110 on soft reset:** PIPE or DWC3 reset release failed. The pipe dump is in the log.

## Host mode (USB keyboard): not built yet
- **There are two blockers:**
  - **VBUS:** the Mac must source VBUS, which the PD controller (sn201202x on gen-4 SPMI, per betizzel) controls. We have no driver for it.
  - **Repeater:** aurora notes that on T6040 the PD controller resets the eUSB2 repeater on each connect. Aurora's T6050 tipd SPMI work (branch `t6050/typec-events`, 542659c0e5) is the place to look.
- **Possible shortcut:** a self-powered hub with its own supply might enumerate without VBUS from the Mac (HYPOTHESIS).
- **Next set (u3) after u2 works:** HOST tunable, `usbctl=2`, `dr_mode` host, xHCI.

## MTP (PM note, NATIVE t14): next test t15
- **t14:** the unused SID 15 TCR write stuck, so only configured streams are frozen.
- **t15:** the same loop-v1 kernel with `iommu.passthrough=1`.
  - `apple_dart_def_domain_type()` returns 0, so it follows the default. DART pagesize 16K equals PAGE_SIZE, bypass is supported, and the DART isn't locked.
  - So apple-dart attaches the MTP with an **identity domain**, writing TCR bypass **at attach, before the TCRs freeze**. This is the DVA == PA contract aurora's MTP handoff needs.
  - The m5drop part is read-only: crc, ASC and DART before and after the stock re-probe, plus the input proof.
  - **Watch:** DART TCR sid 0 should read bypass (bit 1 set) rather than 0x9. If the DATA crc changes or the mailbox drains, the MTP has run.
  - Side effect: every bypass-capable DART in the live DT goes identity. NVMe uses a SART, not a DART.

Labels: aurora and betizzel REPORTED; ADT facts NATIVE; sequences in device mode HYPOTHESIS; all sets untested.
