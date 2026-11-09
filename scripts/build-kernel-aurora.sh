#!/usr/bin/env bash
# omarchy-m5 - build the isolated J714s Aurora DCP or GPU kernel.
#
# The default keeps the verified PR #1012 base and local patch series.
# GPU flavors select PR #1173 plus the per-device J714s GPU overlay.
# CPU fallback and GPU builds are isolated; GPU display variants share a kernel.
# Toolchain approach: scripts/build-kernel.sh's LLVM=1 (clang/lld), GNU make,
# brew gnubin/llvm + host-shim workarounds on macOS.
#
# Usage (from anywhere):
#   scripts/build-kernel-aurora.sh             # prepare, config, Image.gz + dtb
#   scripts/build-kernel-aurora.sh prepare     # fetch pinned base and apply patches
#   scripts/build-kernel-aurora.sh config      # only (re)generate .config
#   scripts/build-kernel-aurora.sh dtbs        # only apple/t6050-j714s.dtb
#   scripts/build-kernel-aurora.sh menuconfig  # other args go to make as-is
#   KEEP_CONFIG=1 scripts/build-kernel-aurora.sh # keep an existing valid .config
#   LINUX=build/linux-aurora-fresh OUT=build/linux-aurora-fresh-out \
#       scripts/build-kernel-aurora.sh prepare # isolated fresh preparation
#   KERNEL_FLAVOR=aurora-gpu scripts/build-kernel-aurora.sh # isolated GPU trial
#   KERNEL_FLAVOR=aurora-gpu-simpledrm scripts/build-kernel-aurora.sh # DCP-off DT
#   make kernel-aurora                        # default build; no installation
set -euo pipefail

cd "$(dirname "$0")/.."

KERNEL_FLAVOR="${KERNEL_FLAVOR:-aurora}"
SOURCE_FLAVOR="$KERNEL_FLAVOR"
REPO_URL=https://github.com/aurora-silicon/linux
PATCH_DIRS=(patches/linux-aurora)
FRAGMENTS=(configs/aurora-j714s.config)
case "$KERNEL_FLAVOR" in
    aurora)
        BASE_SHA=5b0f106acdd71de11400464adfeb8c87a83b20b0
        DTB=apple/t6050-j714s.dtb
        ;;
    aurora-gpu|aurora-gpu-simpledrm)
        BASE_SHA=34f2f5bb4d03bbe3acce237cb67af8dc9972aa4a
        SOURCE_FLAVOR=aurora-gpu
        PATCH_DIRS+=(patches/linux-aurora-gpu)
        FRAGMENTS+=(configs/aurora-j714s-gpu.config)
        DTB=apple/t6050-j714s-gpu.dtb
        if [ "$KERNEL_FLAVOR" = aurora-gpu-simpledrm ]; then
            DTB=apple/t6050-j714s-gpu-simpledrm.dtb
        fi
        ;;
    aurora-installer)
        # The exact kernel the omarchy-mac-installer J714s image ships (N1
        # Wi-Fi/BT, T6050 PHYs, GPU). Its own DT layout: not stacked on
        # patches/linux-aurora. See docs/installer-stones.md.
        BASE_SHA=34f2f5bb4d03bbe3acce237cb67af8dc9972aa4a
        PATCH_DIRS=(patches/linux-aurora-installer)
        FRAGMENTS=(configs/aurora-j714s-installer.config)
        DTB=apple/t6050-j714s.dtb
        ;;
    *)
        echo "ERROR: unknown KERNEL_FLAVOR=$KERNEL_FLAVOR (use aurora, aurora-gpu, aurora-gpu-simpledrm or aurora-installer)" >&2
        exit 1
        ;;
esac
LINUX="${LINUX:-build/linux-$SOURCE_FLAVOR}"
OUT="${OUT:-build/linux-$SOURCE_FLAVOR-out}"
JOBS="${JOBS:-$(nproc 2>/dev/null || sysctl -n hw.ncpu)}"

GMAKE="$(command -v gmake || command -v make)"
mkdir -p "$OUT"
OUT_ABS="$(cd "$OUT" && pwd)"
KMAKE=("$GMAKE" -C "$LINUX" O="$OUT_ABS" ARCH=arm64 LLVM=1 -j"$JOBS")
# Keep explicit Rust tool selections on make's command line; Kbuild's
# defaults otherwise take precedence over environment variables.
[ -z "${RUSTC:-}" ] || KMAKE+=("RUSTC=$RUSTC")
[ -z "${BINDGEN:-}" ] || KMAKE+=("BINDGEN=$BINDGEN")

if [ "$(uname -s)" = Darwin ]; then
    # See scripts/build-kernel.sh: GNU sed/coreutils (merge_config.sh uses
    # `cp -T`), brew LLVM, and scripts/host-shim for <elf.h>.
    export PATH="$(brew --prefix coreutils)/libexec/gnubin:$(brew --prefix gnu-sed)/libexec/gnubin:$(brew --prefix llvm)/bin:$PATH"
    KMAKE+=("HOSTCFLAGS=-I$(pwd)/scripts/host-shim"
            "HOSTCFLAGS_file2alias.o=-D_POSIX_C_SOURCE=200809L")
fi

# Accept only the pinned base plus an ordered prefix of our patch series.
# Compare patch identities, not just commit counts; git am may change commit
# IDs on a fresh checkout. Never reset or clean an existing source tree.
prepare() {
    if [ ! -e "$LINUX/.git" ]; then
        if [ -e "$LINUX" ]; then
            echo "ERROR: $LINUX exists but is not a Git checkout; leaving it untouched." >&2
            exit 1
        fi
        echo "==> Fetching $REPO_URL $BASE_SHA into $LINUX"
        git init -q "$LINUX"
        git -C "$LINUX" fetch --depth 1 "$REPO_URL" "$BASE_SHA"
        git -C "$LINUX" checkout -q -b j714s FETCH_HEAD
    fi
    if ! git -C "$LINUX" merge-base --is-ancestor "$BASE_SHA" HEAD; then
        echo "ERROR: $LINUX HEAD is not based on $BASE_SHA." >&2
        exit 1
    fi
    if ! git -C "$LINUX" diff --quiet ||
       ! git -C "$LINUX" diff --cached --quiet; then
        echo "ERROR: $LINUX has tracked changes; preserve or commit them before preparing." >&2
        exit 1
    fi
    local patches=() series=() dir
    local commits commit expected actual applied=0
    for dir in "${PATCH_DIRS[@]}"; do
        series=("$PWD/$dir"/*.patch)
        if [ ! -f "${series[0]}" ]; then
            echo "ERROR: no patches found in $dir." >&2
            exit 1
        fi
        patches+=("${series[@]}")
    done
    if [ -n "$(git -C "$LINUX" rev-list --min-parents=2 "$BASE_SHA..HEAD")" ]; then
        echo "ERROR: $LINUX contains merge commits above the pinned base." >&2
        exit 1
    fi
    commits="$(git -C "$LINUX" rev-list --reverse "$BASE_SHA..HEAD")"
    for commit in $commits; do
        if [ "$applied" -ge "${#patches[@]}" ]; then
            echo "ERROR: $LINUX has commits beyond the tracked patch series." >&2
            exit 1
        fi
        expected="$(git patch-id --stable < "${patches[$applied]}")"
        actual="$(git -C "$LINUX" show --pretty=email --no-ext-diff "$commit" |
            git patch-id --stable)"
        if [ -z "$expected" ] || [ "${expected%% *}" != "${actual%% *}" ]; then
            echo "ERROR: $commit does not match ${patches[$applied]}." >&2
            echo "       Leaving the source tree untouched; reconcile it manually or use LINUX/OUT for a fresh build." >&2
            exit 1
        fi
        applied=$((applied + 1))
    done
    if [ "$applied" -lt "${#patches[@]}" ]; then
        echo "==> Applying remaining $KERNEL_FLAVOR patches (${applied}/${#patches[@]} already applied)"
        git -C "$LINUX" -c user.name=omarchy-m5 -c user.email=omarchy-m5@localhost \
            am -q "${patches[@]:$applied}"
    fi
}

# Required built-ins: the initramfs and rootfs carry no modules, so a modular
# driver would silently lose its console, storage, input or battery support.
REQUIRED_Y="CONFIG_DRM CONFIG_DRM_SIMPLEDRM CONFIG_DRM_FBDEV_EMULATION
            CONFIG_FRAMEBUFFER_CONSOLE CONFIG_VT_CONSOLE CONFIG_DEVTMPFS_MOUNT
            CONFIG_ARM64_16K_PAGES CONFIG_APPLE_AIC CONFIG_APPLE_PMGR_PWRSTATE
            CONFIG_NVME_APPLE CONFIG_APPLE_SART CONFIG_APPLE_DART
            CONFIG_APPLE_MAILBOX CONFIG_APPLE_RTKIT CONFIG_APPLE_RTKIT_HELPER
            CONFIG_APPLE_DOCKCHANNEL CONFIG_HID_DOCKCHANNEL
            CONFIG_HID_APPLE CONFIG_HID_GENERIC
            CONFIG_HID_MAGICMOUSE CONFIG_HID_APPLE_MTP_HAPTIC
            CONFIG_MFD_MACSMC CONFIG_MACSMC_POWER CONFIG_SPMI_APPLE CONFIG_APPLE_WATCHDOG
            CONFIG_USB_DWC3 CONFIG_USB_CONFIGFS CONFIG_USB_CONFIGFS_EEM
            CONFIG_USB_CONFIGFS_NCM CONFIG_USB_CONFIGFS_ACM CONFIG_DRM_APPLE"
REQUIRED_UNSET="CONFIG_RUST"
if [ "$SOURCE_FLAVOR" = aurora-gpu ]; then
    REQUIRED_Y+=" CONFIG_RUST CONFIG_DRM_ASAHI CONFIG_APPLE_PMP_REPORT
                  CONFIG_RUST_APPLE_MAILBOX CONFIG_RUST_APPLE_RTKIT CONFIG_CRYPTO_LIB_SHA256"
    REQUIRED_UNSET="CONFIG_APPLE_PMP CONFIG_APPLE_AOP CONFIG_APPLE_SEP
                    CONFIG_DRM_ASAHI_G15 CONFIG_DRM_ASAHI_G16 CONFIG_DRM_ASAHI_G18
                    CONFIG_DRM_ASAHI_M5 CONFIG_DRM_APPLE_DCP_T8132
                    CONFIG_APPLE_T8132_PLATFORM_HANDOFF"
fi
if [ "$KERNEL_FLAVOR" = aurora-installer ]; then
    # Mirrors the installer's kernel/j714s-required.config (modular root
    # stack via initramfs; DCP and SMC power stay off in this freeze).
    REQUIRED_Y="CONFIG_EFI CONFIG_EFI_STUB CONFIG_MODULES CONFIG_BLK_DEV_INITRD
                CONFIG_DEVTMPFS CONFIG_DEVTMPFS_MOUNT CONFIG_NVME_APPLE
                CONFIG_APPLE_SART CONFIG_APPLE_DART CONFIG_EXT4_FS
                CONFIG_CRYPTO_AES CONFIG_VFAT_FS CONFIG_DRM_ASAHI
                CONFIG_GPIO_MACSMC CONFIG_SENSORS_MACSMC_HWMON
                CONFIG_ARM_APPLE_SOC_CPUFREQ"
    REQUIRED_UNSET="CONFIG_POWER_RESET_MACSMC CONFIG_MACSMC_POWER"
fi

config_ok() {
    local cfg="$OUT/.config"
    [ -f "$cfg" ] || return 1
    for sym in $REQUIRED_Y; do grep -qx "$sym=y" "$cfg" || return 1; done
    for sym in $REQUIRED_UNSET; do ! grep -q "^$sym=" "$cfg" || return 1; done
}

gen_config() {
    echo "==> Generating $OUT/.config: defconfig + asahi.config + ${FRAGMENTS[*]}"
    "${KMAKE[@]}" defconfig
    # -m: merge only; olddefconfig below resolves the result in $OUT.
    "$LINUX/scripts/kconfig/merge_config.sh" -m -O "$OUT" "$OUT/.config" \
        "$LINUX/arch/arm64/configs/asahi.config" "${FRAGMENTS[@]}"
    "${KMAKE[@]}" olddefconfig
}

ensure_config() {
    if config_ok && [ "${KEEP_CONFIG:-0}" = 1 ]; then
        return
    fi
    gen_config
    local bad=0
    for sym in $REQUIRED_Y; do
        grep -qx "$sym=y" "$OUT/.config" || { echo "ERROR: $sym is not =y" >&2; bad=1; }
    done
    for sym in $REQUIRED_UNSET; do
        ! grep -q "^$sym=" "$OUT/.config" || { echo "ERROR: $sym is set" >&2; bad=1; }
    done
    [ "$bad" = 0 ] || { echo "       after merging asahi.config + ${FRAGMENTS[*]}." >&2; exit 1; }
}

case "${1:-all}" in
    prepare)
        prepare
        ;;
    config)
        prepare
        KEEP_CONFIG=0 ensure_config
        ;;
    dtbs)
        prepare
        ensure_config
        echo "==> Building $DTB"
        "${KMAKE[@]}" "$DTB"
        ls -lh "$OUT/arch/arm64/boot/dts/$DTB"
        ;;
    all)
        prepare
        ensure_config
        echo "==> Building Image.gz + $DTB"
        "${KMAKE[@]}" Image.gz "$DTB"
        echo
        echo "==> Artifacts:"
        ls -lh "$OUT/arch/arm64/boot/Image.gz" "$OUT/arch/arm64/boot/dts/$DTB"
        ;;
    *)
        prepare
        "${KMAKE[@]}" "$@"
        ;;
esac
