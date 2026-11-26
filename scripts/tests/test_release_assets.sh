#!/usr/bin/env bash
# Tests for release-assets.sh — run: scripts/tests/test_release_assets.sh
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
script="$root/release-assets.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
fails=0

check() {
    local name="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        printf 'ok   - %s\n' "$name"
    else
        printf 'FAIL - %s\n' "$name"
        fails=$((fails + 1))
    fi
}

check_fails() {
    local name="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        printf 'FAIL - %s\n' "$name"
        fails=$((fails + 1))
    else
        printf 'ok   - %s\n' "$name"
    fi
}

printf 'ffmpeg source\n' >"$work/ffmpeg.tar.xz"
printf 'helper source\n' >"$work/helper.tar.gz"
ffmpeg_sha="$(shasum -a 256 "$work/ffmpeg.tar.xz" | cut -d' ' -f1)"
helper_sha="$(shasum -a 256 "$work/helper.tar.gz" | cut -d' ' -f1)"

write_lock() {
    cat >"$work/tools.lock" <<LOCK
ffmpeg 7.1.1 file://$work/ffmpeg.tar.xz $ffmpeg_sha mirror
shield-source 2.0.2 file://$work/helper.tar.gz $helper_sha mirror
LOCK
}
write_lock
export MG_TOOLS_LOCK="$work/tools.lock"

expected="MediaGrabber-0.1.0.dmg
SHA256SUMS
appcast.xml
ffmpeg-7.1.1.tar.xz
shield-source-2.0.2.tar.gz"

got="$(bash "$script" allowed 0.1.0 | LC_ALL=C sort)"
if [ "$got" = "$(printf '%s\n' "$expected" | LC_ALL=C sort)" ]; then
    printf 'ok   - allowed lists the disk image, checksums, appcast and sources\n'
else
    printf 'FAIL - allowed list is wrong:\n%s\n' "$got"
    fails=$((fails + 1))
fi

if printf '%s\n' "$expected" | bash "$script" check 0.1.0 >/dev/null 2>&1; then
    printf 'ok   - check accepts the allowed list\n'
else
    printf 'FAIL - check rejected the allowed list\n'
    fails=$((fails + 1))
fi

check_fails "check rejects a missing source" bash -c "printf '%s\n' '$expected' | grep -v 'ffmpeg-7.1.1' | bash '$script' check 0.1.0"
check_fails "check rejects an unexpected file" bash -c "printf '%s\n' '$expected' 'notes.txt' | bash '$script' check 0.1.0"

cat >>"$work/tools.lock" <<LOCK
lame 3.100 file://$work/ffmpeg.tar.xz $ffmpeg_sha mirror
LOCK
check_fails "check rejects a new mirror entry with an unchanged list" bash -c "printf '%s\n' '$expected' | bash '$script' check 0.1.0"
write_lock

mkdir -p "$work/assets"
bash "$script" sources "$work/assets"
if [ -s "$work/assets/ffmpeg-7.1.1.tar.xz" ] && [ -s "$work/assets/shield-source-2.0.2.tar.gz" ]; then
    printf 'ok   - sources writes one file per mirror entry\n'
else
    printf 'FAIL - sources did not write the source files\n'
    fails=$((fails + 1))
fi

printf 'bad\n' >"$work/bad.tar.xz"
cat >"$work/bad.lock" <<LOCK
ffmpeg 7.1.1 file://$work/bad.tar.xz $ffmpeg_sha mirror
LOCK
mkdir -p "$work/bad-assets"
if MG_TOOLS_LOCK="$work/bad.lock" bash "$script" sources "$work/bad-assets" >/dev/null 2>&1; then
    printf 'FAIL - a wrong checksum must be rejected\n'
    fails=$((fails + 1))
elif [ -z "$(ls -A "$work/bad-assets")" ]; then
    printf 'ok   - a wrong checksum is rejected and nothing is left behind\n'
else
    printf 'FAIL - files left in the output directory after a checksum mismatch\n'
    fails=$((fails + 1))
fi

if [ "$fails" -ne 0 ]; then
    printf '\n%d test(s) failed\n' "$fails"
    exit 1
fi
printf '\nall tests passed\n'
