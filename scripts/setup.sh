#!/usr/bin/env bash
# omarchy-m5 dev harness — host dependency setup (macOS + Homebrew).
# Idempotent; safe to re-run.
set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> Checking Homebrew"
if ! command -v brew >/dev/null; then
    echo "ERROR: Homebrew not found. Install from https://brew.sh first." >&2
    exit 1
fi

# llvm+lld: m1n1's Makefile locates clang via `brew --prefix llvm`/llvm-config.
# The kernel build uses the same LLVM toolchain via LLVM=1.
# dtc: standalone device-tree compiler for quick syntax checks.
# bc/bison/flex/openssl: kernel build host tools.
PKGS=(llvm lld dtc bc bison flex openssl make gnu-sed)
echo "==> Installing brew packages: ${PKGS[*]}"
brew install "${PKGS[@]}"

echo "==> Checking rustup"
if ! command -v rustup >/dev/null; then
    echo "ERROR: rustup not found. Install via https://rustup.rs" >&2
    exit 1
fi

echo "==> Adding Rust target aarch64-unknown-none-softfloat (m1n1 stage-1)"
rustup target add aarch64-unknown-none-softfloat

LLVM_BIN="$(brew --prefix llvm)/bin"
echo
echo "==> Done. Toolchain summary:"
"$LLVM_BIN/clang" --version | head -1
rustup target list --installed | grep aarch64 || true
echo
echo "NOTE: kernel/m1n1 builds need brew LLVM first in PATH."
echo "      The build scripts in scripts/ handle this automatically."
echo "      For manual work: export PATH=\"$LLVM_BIN:\$PATH\""
