#!/usr/bin/env bash
# Tests for sign-update.sh — run: scripts/tests/test_sign_update.sh
set -euo pipefail

script="$(cd "$(dirname "$0")/.." && pwd)/release/sign-update.sh"
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

# A home with only DerivedData, like a CI runner that has no tuist cache folder.
home="$work/home"
tool_dir="$home/Library/Developer/Xcode/DerivedData/App/SourcePackages/artifacts/sparkle/Sparkle/bin"
mkdir -p "$tool_dir" "$work/bin" "$work/run" "$work/assets"
printf '#!/bin/sh\necho '"'"'sparkle:edSignature="SIG123" length="12"'"'"'\n' > "$tool_dir/sign_update"
printf '#!/bin/sh\nexit 1\n' > "$work/bin/gh"
chmod +x "$tool_dir/sign_update" "$work/bin/gh"
printf 'disk image\n' > "$work/run/MediaGrabber-0.1.0.dmg"
: > "$work/github-output"

run_sign() {
    (cd "$work/run" && HOME="$home" PATH="$work/bin:$PATH" GITHUB_OUTPUT="$work/github-output" \
        SPARKLE_EDDSA_PRIVATE_KEY=key bash "$script" MediaGrabber-0.1.0.dmg 0.1.0 "$work/assets")
}

check "signing finds the tool when the tuist cache folder does not exist" run_sign
check "the appcast carries the signature" grep -q 'SIG123' "$work/assets/appcast.xml"
check "the signed output is written for the workflow" grep -qx 'signed=true' "$work/github-output"

rm -rf "$home/Library"
mkdir -p "$home"
msg="$(cd "$work/run" && HOME="$home" PATH="$work/bin:$PATH" SPARKLE_EDDSA_PRIVATE_KEY=key bash "$script" MediaGrabber-0.1.0.dmg 0.1.0 "$work/assets" 2>&1 || true)"
check "the failure says sign_update was not found" bash -c "printf '%s' '$msg' | grep -q 'sign_update not found'"

if [ "$fails" -ne 0 ]; then
    printf '\n%d test(s) failed\n' "$fails"
    exit 1
fi
printf '\nall tests passed\n'
