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
# defconfig alone leaves DRM=m and DRM_SIMPLEDRM unset, which yields a
# kernel that boots but shows nothing on the panel. Fragments are merged
# in order; ours wins.
KCONFIG="${KCONFIG:-defconfig asahi.config omarchy-bringup.config omarchy-storage-net.config}"
JOBS="${JOBS:-$(nproc 2>/dev/null || sysctl -n hw.ncpu)}"

if [ ! -d "$LINUX" ]; then
    echo "ERROR: $LINUX missing. Run scripts/fetch-sources.sh first." >&2
    exit 1
fi

GMAKE="$(command -v gmake || command -v make)"
KMAKE=("$GMAKE" -C "$LINUX" ARCH=arm64 LLVM=1 -j"$JOBS")

if [ "$(uname -s)" = Darwin ]; then
    # brew LLVM for clang/lld; brew gnu-sed's gnubin first because kernel
    # scripts (gen-kernel-hwcaps.sh) use GNU sed syntax BSD sed silently
    # passes through. coreutils' gnubin is needed too: kconfig's
    # merge_config.sh (config fragments) calls `cp -T`, which BSD cp rejects.
    export PATH="$(brew --prefix coreutils)/libexec/gnubin:$(brew --prefix gnu-sed)/libexec/gnubin:$(brew --prefix llvm)/bin:$PATH"
    # Kernel needs GNU Make >= 4.0; macOS ships 3.81, so gmake is preferred
    # above. HOSTCFLAGS adds scripts/host-shim: macOS lacks <elf.h>, which
    # the kernel's host tools (sorttable, modpost, ...) require.
    KMAKE+=("HOSTCFLAGS=-I$(pwd)/scripts/host-shim"
            "HOSTCFLAGS_file2alias.o=-D_POSIX_C_SOURCE=200809L")
fi

echo "==> Overlaying dt/ into $DTS_DIR"
install -m 0644 dt/t6050.dtsi dt/t6050-pmgr.dtsi dt/t6050-jxxx.dtsi \
    dt/t6050-storage-net.dtsi dt/t6050-cpufreq.dtsi dt/t6050-j714s.dts dt/t6050-j716s.dts \
    "$DTS_DIR/"

install -m 0644 configs/omarchy-bringup.config configs/omarchy-storage-net.config \
    "$LINUX/arch/arm64/configs/"

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

# The console symbols below are load-bearing: with any of them unset the
# kernel boots and prints nothing on the panel, which looks identical to a
# hang. Assert them instead of trusting the fragment merged cleanly.
REQUIRED_Y="CONFIG_DRM CONFIG_DRM_SIMPLEDRM CONFIG_DRM_FBDEV_EMULATION
            CONFIG_FRAMEBUFFER_CONSOLE CONFIG_VT_CONSOLE CONFIG_DEVTMPFS_MOUNT
            CONFIG_NVME_APPLE CONFIG_APPLE_SART CONFIG_APPLE_DART
            CONFIG_USB_DWC3 CONFIG_USB_CONFIGFS CONFIG_USB_CONFIGFS_NCM
            CONFIG_USB_CONFIGFS_ACM"

config_ok() {
    [ -f "$LINUX/.config" ] || return 1
    for sym in $REQUIRED_Y; do
        grep -qx "$sym=y" "$LINUX/.config" || return 1
    done
}

ensure_config() {
    if config_ok && [ "${KEEP_CONFIG:-0}" = 1 ]; then
        return
    fi
    if ! config_ok; then
        echo "==> Generating config: $KCONFIG"
        # shellcheck disable=SC2086 -- KCONFIG is a list of make targets
        "${KMAKE[@]}" $KCONFIG
    fi
    for sym in $REQUIRED_Y; do
        grep -qx "$sym=y" "$LINUX/.config" \
            || { echo "ERROR: $sym is not =y after merging $KCONFIG." >&2
                 echo "       A module or unset symbol here means a silent boot:" >&2
                 echo "       the bring-up initramfs carries no kernel modules." >&2
                 exit 1; }
    done
}

case "${1:-all}" in
    dtbs)
        ensure_config
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
        ensure_config
        echo "==> Building kernel (Image.gz + dtbs)"
        "${KMAKE[@]}" Image.gz dtbs
        echo
        echo "==> Artifacts:"
        ls -lh "$LINUX/arch/arm64/boot/Image.gz" "$DTS_DIR"/t6050-*.dtb
        ;;
    *)
        "${KMAKE[@]}" "$@"
        ;;
esac
