# omarchy-m5 dev harness
.PHONY: setup fetch m1n1 kernel dtbs clean-vendor

setup:          ## install host deps (brew llvm, rust target, ...)
	scripts/setup.sh

fetch:          ## clone/update vendor/m1n1 + vendor/linux
	scripts/fetch-sources.sh

m1n1:           ## build chainloadable m1n1 (CHAINLOADING=0 for install image)
	scripts/build-m1n1.sh

kernel:         ## overlay DTs + build kernel (KCONFIG=asahi_defconfig to override)
	scripts/build-kernel.sh

dtbs:           ## overlay DTs + build device trees only (fast syntax check)
	scripts/build-kernel.sh dtbs

clean-vendor:   ## remove vendored sources
	rm -rf vendor/m1n1 vendor/linux
