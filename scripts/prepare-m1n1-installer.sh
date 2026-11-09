#!/usr/bin/env bash
# omarchy-m5 - prepare the installer's J714s m1n1 in build/m1n1-installer.
# Base is omacom/m1n1 (not AsahiLinux): kboot_n1.c only exists there.
set -euo pipefail

cd "$(dirname "$0")/.."

REPO=https://github.com/omacom/m1n1
BASE_SHA=02785a35e046901d5686ab9059b2c08b6256752a
DIR="${M1N1:-build/m1n1-installer}"

if [ ! -e "$DIR/.git" ]; then
    [ ! -e "$DIR" ] || { echo "ERROR: $DIR exists but is not a Git checkout." >&2; exit 1; }
    git init -q "$DIR"
    git -C "$DIR" fetch --depth 1 "$REPO" "$BASE_SHA"
    git -C "$DIR" checkout -q -b j714s-installer FETCH_HEAD
    git -C "$DIR" submodule update --init --recursive
fi
# ponytail: one-patch series, so "applied" == HEAD is one commit above base.
if [ "$(git -C "$DIR" rev-parse HEAD)" = "$BASE_SHA" ]; then
    git -C "$DIR" -c user.name=omarchy-m5 -c user.email=omarchy-m5@localhost \
        am -q "$PWD"/patches/m1n1-installer/*.patch
elif [ "$(git -C "$DIR" rev-parse HEAD~1)" != "$BASE_SHA" ]; then
    echo "ERROR: $DIR is not $BASE_SHA plus patches/m1n1-installer; leaving it untouched." >&2
    exit 1
fi
echo "==> $DIR ready ($BASE_SHA + patches/m1n1-installer)"
