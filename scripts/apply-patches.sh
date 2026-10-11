#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# apply-patches.sh - apply our local m1n1/linux patches to the vendored trees.
#
# vendor/ is gitignored, so anything we change upstream has to live here as a
# patch or it is lost on the next `make fetch`.
#
#   scripts/apply-patches.sh            # apply everything not already applied
#   scripts/apply-patches.sh --list     # show status without touching anything
#   scripts/apply-patches.sh --refresh  # regenerate patches from the worktrees

set -euo pipefail

cd "$(dirname "$0")/.."

MODE="apply"
case "${1:-}" in
    --list) MODE="list" ;;
    --refresh) MODE="refresh" ;;
    "") ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
esac

# Files a patch owns are the ones named in its own `+++ b/` headers, so a
# tree can carry several patches and a refresh never silently drops a file.
# Prefixes are pinned to a/ b/: a user's diff.mnemonicPrefix (i/ w/) or
# diff.noprefix would otherwise change what the headers look like.
GITDIFF=(diff --src-prefix=a/ --dst-prefix=b/)
# To start a new patch:
#   git -C vendor/<tree> diff --src-prefix=a/ --dst-prefix=b/ HEAD -- FILES \
#       > patches/<tree>/NNNN-name.patch
patch_files() {
    sed -n 's|^+++ [a-z]/||p' "$1"
}

for tree in m1n1 linux; do
    dir="vendor/$tree"
    [ -d "$dir" ] || continue
    patches=(patches/"$tree"/*.patch)
    [ -e "${patches[0]}" ] || continue

    if [ "$MODE" = refresh ]; then
        owned=()
        for out in "${patches[@]}"; do
            mapfile -t paths < <(patch_files "$out")
            # An empty list would turn the diff below into a whole-tree dump.
            [ "${#paths[@]}" -gt 0 ] \
                || { echo "$out names no files (+++ headers?)" >&2; exit 1; }
            owned+=("${paths[@]}")
            # `add -N` so files we created appear in the diff at all, and
            # `diff HEAD` because `git apply --3way` stages what it merges - a
            # plain `git diff` silently drops those hunks and saves a subset
            # of what we actually built.
            git -C "$dir" add -N -- "${paths[@]}" 2>/dev/null || true
            git -C "$dir" "${GITDIFF[@]}" HEAD -- "${paths[@]}" > "$out"
            # A patch we cannot reverse-apply does not describe the worktree.
            git -C "$dir" apply --reverse --check "../../$out" \
                || { echo "refreshed $out does not match $dir" >&2; exit 1; }
            echo "refreshed $out ($(wc -l < "$out") lines, verified against $dir)"
        done
        # Worktree changes no patch owns are lost on the next `make fetch`.
        # The DT Makefile is maintained by build-kernel.sh's overlay instead.
        # (On macOS this also lists phantom case-only header diffs such as
        # xt_MARK.h vs xt_mark.h; those are filesystem noise.)
        unowned=$(comm -23 <(git -C "$dir" diff HEAD --name-only \
                               | grep -vx 'arch/arm64/boot/dts/apple/Makefile' | sort) \
                           <(printf '%s\n' "${owned[@]}" | sort))
        [ -z "$unowned" ] || { echo "WARNING: changed in $dir but in no patch:" >&2
                               printf '  %s\n' $unowned >&2; }
        continue
    fi

    for p in "${patches[@]}"; do
        rel="../../$p"
        if git -C "$dir" apply --reverse --check "$rel" 2>/dev/null; then
            echo "already applied: $p"
            continue
        fi
        if [ "$MODE" = list ]; then
            echo "NOT applied:     $p"
            continue
        fi
        if git -C "$dir" apply --3way "$rel"; then
            echo "applied:         $p"
        else
            echo "FAILED to apply: $p (upstream moved? rebase the patch)" >&2
            exit 1
        fi
    done
done
