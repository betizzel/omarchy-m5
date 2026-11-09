# omarchy-m5 dev harness
.PHONY: setup fetch m1n1 m1n1-gpu m1n1-gpu-simpledrm m1n1-gpu-standalone payload-gpu-simpledrm aura aura-kernel aura-test kernel kernel-aurora kernel-aurora-gpu kernel-aurora-gpu-simpledrm kernel-aurora-installer m1n1-installer dtbs initramfs payload tether clean-vendor
AURA_ROLLBACK ?= build/m1n1-enrolled-stage1.bin
GPU_ADT ?= build/adt-runtime-j714s.bin

setup:          ## install host deps (brew llvm, rust target, ...)
	scripts/setup.sh

fetch:          ## clone/update vendor/m1n1 + vendor/linux
	scripts/fetch-sources.sh

m1n1:           ## build chainloadable m1n1 (CHAINLOADING=0 for install image)
	scripts/build-m1n1.sh

m1n1-gpu:       ## build the isolated chainloadable GPU handoff; do not enroll it
	python3 scripts/prepare-m1n1-gpu.py
	M1N1=build/m1n1-gpu CHAINLOADING=1 scripts/build-m1n1.sh
	cp build/m1n1-gpu/build/m1n1.bin build/m1n1-chain-gpu.bin

m1n1-gpu-simpledrm: ## build the separate GPU loader supporting explicit Linux DCP opt-out
	python3 scripts/prepare-m1n1-gpu.py --simpledrm
	M1N1=build/m1n1-gpu-simpledrm CHAINLOADING=1 scripts/build-m1n1.sh
	cp build/m1n1-gpu-simpledrm/build/m1n1.bin build/m1n1-chain-gpu-simpledrm.bin

m1n1-gpu-standalone: ## build a separate calibrated native loader; no enrollment
	python3 scripts/prepare-m1n1-gpu.py --simpledrm --standalone --adt "$(GPU_ADT)"
	M1N1=build/m1n1-gpu-standalone CHAINLOADING=0 scripts/build-m1n1.sh
	cp build/m1n1-gpu-standalone/build/m1n1.bin build/m1n1-stage1-gpu-simpledrm.bin

payload-gpu-simpledrm: m1n1-gpu-standalone ## package the verified GPU kernel/DT for native boot
	scripts/mkpayload.sh --m1n1 build/m1n1-stage1-gpu-simpledrm.bin \
		--kernel build/linux-aurora-gpu-out/arch/arm64/boot/Image.gz \
		--dtb build/linux-aurora-gpu-out/arch/arm64/boot/dts/apple/t6050-j714s-gpu-simpledrm.dtb \
		--out build/m1n1-gpu-simpledrm-payload.bin

aura:           ## build pinned proxy-only Mach-O Aura Stage 1 (no installation)
	scripts/build-aura.sh

aura-kernel:    ## build an isolated J714s kernel without fixed framebuffer markers
	scripts/build-aura-kernel.sh

aura-test: aura aura-kernel ## prepare RAM-only J714s tether + recovery artifacts
	python3 scripts/prepare-aura-test.py --rollback "$(AURA_ROLLBACK)"

kernel:         ## overlay DTs + build kernel (KCONFIG=asahi_defconfig to override)
	scripts/build-kernel.sh

kernel-aurora:  ## build the pinned Aurora J714s kernel with built-in DCP (no installation)
	scripts/build-kernel-aurora.sh

kernel-aurora-gpu: ## build the isolated J714s GPU trial; keep verified artifacts unchanged
	KERNEL_FLAVOR=aurora-gpu scripts/build-kernel-aurora.sh

kernel-aurora-gpu-simpledrm: ## build the shared GPU kernel with the isolated DCP-off DT
	KERNEL_FLAVOR=aurora-gpu-simpledrm scripts/build-kernel-aurora.sh

kernel-aurora-installer: ## build the installer's J714s kernel (N1 Wi-Fi/BT, PHYs, GPU)
	KERNEL_FLAVOR=aurora-installer scripts/build-kernel-aurora.sh

m1n1-installer: ## build the installer's J714s loader on omacom/m1n1 (N1 tunables)
	scripts/prepare-m1n1-installer.sh
	M1N1=build/m1n1-installer CHAINLOADING=1 scripts/build-m1n1.sh

dtbs:           ## overlay DTs + build device trees only (fast syntax check)
	scripts/build-kernel.sh dtbs

initramfs:      ## build a busybox/musl aarch64 initramfs (no root needed)
	scripts/mkinitramfs.py

payload:        ## m1n1 + bootargs + kernel + dtb + initramfs -> one boot object
	scripts/mkpayload.sh

tether:         ## pack proxyclient + artifacts for the Linux dev host
	scripts/mktether.sh

clean-vendor:   ## remove vendored sources
	rm -rf vendor/m1n1 vendor/linux vendor/aura
