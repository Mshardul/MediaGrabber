#!/usr/bin/env bash
# Tests for verify-app.sh — run: scripts/tests/test_verify_app.sh
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
script="$root/release/verify-app.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
fails=0
feed="https://github.com/Mshardul/MediaGrabber/releases/latest/download/appcast.xml"

check() {
    local name="$1"; shift
    if "$@" >/dev/null 2>&1; then
        printf 'ok   - %s\n' "$name"
    else
        printf 'FAIL - %s\n' "$name"
        fails=$((fails + 1))
    fi
}

make_app() {
    local app="$1" feed_url="$2" key="$3"
    mkdir -p "$app/Contents/MacOS"
    cp /usr/bin/true "$app/Contents/MacOS/Fake"
    plutil -create xml1 "$app/Contents/Info.plist"
    plutil -insert CFBundleExecutable -string Fake "$app/Contents/Info.plist"
    plutil -insert CFBundleIdentifier -string test.fake "$app/Contents/Info.plist"
    plutil -insert SUFeedURL -string "$feed_url" "$app/Contents/Info.plist"
    plutil -insert SUPublicEDKey -string "$key" "$app/Contents/Info.plist"
    codesign --force --sign - "$app" >/dev/null 2>&1
}

make_app "$work/Good.app" "$feed" "KEY1"
make_app "$work/WrongFeed.app" "https://example.com/appcast.xml" "KEY1"

check "a relative app path with the right feed and key passes" \
    bash -c "cd '$work' && EXPECTED_KEY=KEY1 bash '$script' Good.app"
check "an absolute app path passes" \
    env EXPECTED_KEY=KEY1 bash "$script" "$work/Good.app"
check "a wrong feed address fails" \
    bash -c "! EXPECTED_KEY=KEY1 bash '$script' '$work/WrongFeed.app'"
check "a key that is not the expected one fails" \
    bash -c "! EXPECTED_KEY=KEY2 bash '$script' '$work/Good.app'"
check "a missing expected key fails when publishing" \
    bash -c "! env -u EXPECTED_KEY DRY=false bash '$script' '$work/Good.app'"
check "a missing expected key passes in a dry run" \
    env -u EXPECTED_KEY DRY=true bash "$script" "$work/Good.app"

if [ "$fails" -ne 0 ]; then
    printf '\n%d test(s) failed\n' "$fails"
    exit 1
fi
printf '\nall tests passed\n'
