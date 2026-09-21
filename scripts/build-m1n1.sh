#!/usr/bin/env bash
# omarchy-m5 dev harness — build m1n1 for T6050.
#
# Produces:
#   vendor/m1n1/build/m1n1.bin   — raw stage-1 image for kmutil configure-boot
#   vendor/m1n1/build/m1n1.macho — Mach-O variant
#
# CHAINLOADING=1 (default) builds a chainloadable image: the installed
# stage-1 m1n1 loads this build over USB via proxyclient, giving a ~7s
# dev iteration cycle without touching boot policy. Set CHAINLOADING=0
# for the image you actually install via kmutil.
set -euo pipefail

cd "$(dirname "$0")/.."

if [ ! -d vendor/m1n1 ]; then
    echo "ERROR: vendor/m1n1 missing. Run scripts/fetch-sources.sh first." >&2
    exit 1
fi

# brew LLVM provides clang/lld; m1n1's Makefile finds it via llvm-config.
# Put the active rustup toolchain's bin dir first so its cargo (which has
# the aarch64-unknown-none-softfloat target) wins over a Homebrew rustc.
RUSTUP_BIN="$(dirname "$(rustup which cargo)")"
export PATH="$RUSTUP_BIN:$(brew --prefix llvm)/bin:$PATH"

CHAINLOADING="${CHAINLOADING:-1}"
JOBS="${JOBS:-$(sysctl -n hw.ncpu)}"

echo "==> Building m1n1 (CHAINLOADING=$CHAINLOADING, -j$JOBS)"
make -C vendor/m1n1 -j"$JOBS" CHAINLOADING="$CHAINLOADING"

echo
echo "==> Artifacts:"
ls -lh vendor/m1n1/build/m1n1.bin vendor/m1n1/build/m1n1.macho 2>/dev/null || true
