#!/usr/bin/env bash
# Tests for fetch-tools.sh — run: scripts/tests/test_fetch_tools.sh
set -euo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/fetch-tools.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
fails=0

check() {
    local name="$1"; shift
    if "$@" >/dev/null 2>&1; then
        printf 'ok   - %s\n' "$name"
    else
        printf 'FAIL - %s\n' "$name"
        fails=$((fails + 1))
    fi
}

check_fails() {
    local name="$1"; shift
    if "$@" >/dev/null 2>&1; then
        printf 'FAIL - %s\n' "$name"
        fails=$((fails + 1))
    else
        printf 'ok   - %s\n' "$name"
    fi
}

mkdir -p "$work/node/node-v1/bin"
printf 'Node license text\n' > "$work/node/node-v1/LICENSE"
printf '#!/bin/sh\necho v1\n' > "$work/node/node-v1/bin/node"
chmod +x "$work/node/node-v1/bin/node"
tar -czf "$work/node.tar.gz" -C "$work/node" node-v1
printf 'yt-dlp license text\n' > "$work/yt-license"
printf 'Sparkle license text\n' > "$work/sparkle-license"
node_sha="$(shasum -a 256 "$work/node.tar.gz" | cut -d' ' -f1)"
yt_sha="$(shasum -a 256 "$work/yt-license" | cut -d' ' -f1)"
sparkle_sha="$(shasum -a 256 "$work/sparkle-license" | cut -d' ' -f1)"

cat > "$work/tools.lock" <<LOCK
node v1 file://$work/node.tar.gz $node_sha
yt-dlp-license 1 file://$work/yt-license $yt_sha
sparkle-license 1 file://$work/sparkle-license $sparkle_sha
LOCK

if MG_TOOLS_LOCK="$work/tools.lock" MG_TOOLS_OUT="$work/out" "$SCRIPT" >/dev/null 2>&1 \
    && [ -s "$work/out/Resources/Licenses/node.txt" ]; then
    printf 'ok   - an archive with a license yields a non-empty text\n'
else
    printf 'FAIL - fetch-tools.sh did not write Resources/Licenses/node.txt\n'
    fails=$((fails + 1))
fi

mkdir -p "$work/empty/node-v1"
: > "$work/empty/node-v1/LICENSE"
tar -czf "$work/empty-node.tar.gz" -C "$work/empty" node-v1
empty_sha="$(shasum -a 256 "$work/empty-node.tar.gz" | cut -d' ' -f1)"
cat > "$work/empty.lock" <<LOCK
node v1 file://$work/empty-node.tar.gz $empty_sha
LOCK
check_fails "an empty license text exits non-zero" \
    env MG_TOOLS_LOCK="$work/empty.lock" MG_TOOLS_OUT="$work/empty-out" "$SCRIPT"

cat > "$work/missing.lock" <<LOCK
node v1 file://$work/nope.tar.gz $node_sha
LOCK
check_fails "a missing archive exits non-zero" \
    env MG_TOOLS_LOCK="$work/missing.lock" MG_TOOLS_OUT="$work/missing-out" "$SCRIPT"

printf 'not a real tool\n' > "$work/yt-dlp_macos"
printf 'yt-dlp 1.0 file://%s %s\n' "$work/yt-dlp_macos" "$(printf '0%.0s' {1..64})" > "$work/bad.lock"
if MG_TOOLS_LOCK="$work/bad.lock" MG_TOOLS_OUT="$work/bad-out" "$SCRIPT" >/dev/null 2>&1; then
    printf 'FAIL - wrong checksum must make fetch-tools.sh exit non-zero\n'
    fails=$((fails + 1))
else
    printf 'ok   - wrong checksum exits non-zero\n'
fi

if [ -n "$(find "$work/bad-out/Resources/Tools" -type f 2>/dev/null)" ]; then
    printf 'FAIL - nothing may be left in Resources/Tools after a checksum mismatch\n'
    fails=$((fails + 1))
else
    printf 'ok   - nothing left in Resources/Tools\n'
fi

check "FFmpeg build keeps --disable-gpl" grep -q -- '--disable-gpl' "$SCRIPT"
check "FFmpeg build keeps --disable-nonfree" grep -q -- '--disable-nonfree' "$SCRIPT"

if [ "$fails" -ne 0 ]; then
    printf '\n%d test(s) failed\n' "$fails"
    exit 1
fi
printf '\nall tests passed\n'
