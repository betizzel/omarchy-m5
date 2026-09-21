#!/usr/bin/env bash
# omarchy-m5 dev harness — clone/update upstream sources into vendor/.
set -euo pipefail

cd "$(dirname "$0")/.."
mkdir -p vendor

M1N1_REPO="${M1N1_REPO:-https://github.com/AsahiLinux/m1n1.git}"
M1N1_REF="${M1N1_REF:-main}"
LINUX_REPO="${LINUX_REPO:-https://github.com/AsahiLinux/linux.git}"
LINUX_REF="${LINUX_REF:-asahi-wip-7.2}"

clone_or_update() {
    local dir="$1" repo="$2" ref="$3" depth="${4:-1}"
    if [ -d "$dir/.git" ]; then
        echo "==> $dir exists; fetching $ref"
        git -C "$dir" fetch --depth "$depth" origin "$ref" || true
        git -C "$dir" checkout FETCH_HEAD 2>/dev/null || git -C "$dir" checkout "$ref"
    else
        echo "==> Cloning $repo ($ref) -> $dir"
        git clone --depth "$depth" --branch "$ref" "$repo" "$dir"
    fi
}

# m1n1 needs submodules (it vendors some code)
if [ -d vendor/m1n1/.git ]; then
    echo "==> vendor/m1n1 exists; fetching $M1N1_REF"
    git -C vendor/m1n1 fetch origin "$M1N1_REF" || true
    git -C vendor/m1n1 checkout FETCH_HEAD 2>/dev/null || git -C vendor/m1n1 checkout "$M1N1_REF"
    git -C vendor/m1n1 submodule update --init --recursive
else
    echo "==> Cloning m1n1 ($M1N1_REF) -> vendor/m1n1"
    git clone --recursive --branch "$M1N1_REF" "$M1N1_REPO" vendor/m1n1
fi

# Kernel: shallow clone of the asahi-wip branch. ~1.5 GB even shallow.
clone_or_update vendor/linux "$LINUX_REPO" "$LINUX_REF" 1

echo
echo "==> Sources ready:"
git -C vendor/m1n1 log -1 --format='  m1n1:   %h %s (%cs)'
git -C vendor/linux log -1 --format='  linux:  %h %s (%cs)'
