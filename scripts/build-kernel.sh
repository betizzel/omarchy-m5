#!/usr/bin/env bash
# omarchy-m5 dev harness — build linux-asahi with the t6050 DTs overlaid.
#
# Copies dt/*.dts{i,} into vendor/linux/arch/arm64/boot/dts/apple/ and
# registers the board DTBs in that directory's Makefile (idempotent,
# marker-delimited block).
#
# Usage:
#   scripts/build-kernel.sh           # defconfig + full kernel build
#   scripts/build-kernel.sh dtbs      # DTBs only (fast syntax check)
#   scripts/build-kernel.sh menuconfig
#   KCONFIG=asahi_defconfig scripts/build-kernel.sh
set -euo pipefail

cd "$(dirname "$0")/.."

LINUX=vendor/linux
DTS_DIR="$LINUX/arch/arm64/boot/dts/apple"
KCONFIG="${KCONFIG:-defconfig}"
JOBS="${JOBS:-$(sysctl -n hw.ncpu)}"

if [ ! -d "$LINUX" ]; then
    echo "ERROR: $LINUX missing. Run scripts/fetch-sources.sh first." >&2
    exit 1
fi

# brew LLVM for clang/lld; brew gnu-sed's gnubin first because kernel
# scripts (gen-kernel-hwcaps.sh) use GNU sed syntax BSD sed silently
# passes through.
export PATH="$(brew --prefix gnu-sed)/libexec/gnubin:$(brew --prefix llvm)/bin:$PATH"
# Kernel needs GNU Make >= 4.0; macOS ships 3.81, so prefer brew's gmake.
# HOSTCFLAGS adds scripts/host-shim: macOS lacks <elf.h>, which the
# kernel's host tools (sorttable, modpost, ...) require.
GMAKE="$(command -v gmake || command -v make)"
KMAKE=("$GMAKE" -C "$LINUX" ARCH=arm64 LLVM=1 -j"$JOBS"
       "HOSTCFLAGS=-I$(pwd)/scripts/host-shim"
       "HOSTCFLAGS_file2alias.o=-D_POSIX_C_SOURCE=200809L")

echo "==> Overlaying dt/ into $DTS_DIR"
install -m 0644 dt/t6050.dtsi dt/t6050-pmgr.dtsi dt/t6050-jxxx.dtsi \
    dt/t6050-j714s.dts dt/t6050-j716s.dts "$DTS_DIR/"

MK="$DTS_DIR/Makefile"
BEGIN='# >>> omarchy-m5'
END='# <<< omarchy-m5'
if ! grep -qF "$BEGIN" "$MK"; then
    echo "==> Registering t6050 DTBs in $MK"
    cat >> "$MK" <<'EOF'
# >>> omarchy-m5
dtb-$(CONFIG_ARCH_APPLE) += t6050-j714s.dtb
dtb-$(CONFIG_ARCH_APPLE) += t6050-j716s.dtb
# <<< omarchy-m5
EOF
fi

case "${1:-all}" in
    dtbs)
        if [ ! -f "$LINUX/.config" ]; then
            echo "==> Generating $KCONFIG (needed for dtbs)"
            "${KMAKE[@]}" "$KCONFIG"
        fi
        echo "==> Building DTBs only"
        "${KMAKE[@]}" dtbs
        echo
        echo "==> Built DTBs:"
        ls -lh "$DTS_DIR"/t6050-*.dtb
        ;;
    menuconfig|defconfig|asahi_defconfig|olddefconfig)
        "${KMAKE[@]}" "$1"
        ;;
    all)
        if [ ! -f "$LINUX/.config" ]; then
            echo "==> Generating $KCONFIG"
            "${KMAKE[@]}" "$KCONFIG"
        fi
        echo "==> Building kernel (Image + dtbs + modules)"
        "${KMAKE[@]}"
        echo
        echo "==> Artifacts:"
        ls -lh "$LINUX/arch/arm64/boot/Image" "$DTS_DIR"/t6050-*.dtb
        ;;
    *)
        "${KMAKE[@]}" "$@"
        ;;
esac
