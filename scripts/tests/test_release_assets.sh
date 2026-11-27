#!/usr/bin/env bash
# Tests for release-assets.sh — run: scripts/tests/test_release_assets.sh
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
script="$root/release-assets.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work" 2>/dev/null || true' EXIT
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
# A temporary build folder keeps every case away from the real download cache.
export MG_TOOLS_OUT="$work/out"

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

# The fake curl records each download and serves only local files.
mkdir -p "$work/bin"
cat >"$work/bin/curl" <<'FAKE'
#!/usr/bin/env bash
out="" url=""
while [ $# -gt 0 ]; do
    case "$1" in
    -o)
        out="$2"
        shift
        ;;
    file://*) url="$1" ;;
    esac
    shift
done
echo "$url" >>"$MG_CURL_LOG"
cp "${url#file://}" "$out"
FAKE
chmod +x "$work/bin/curl"
export MG_CURL_LOG="$work/curl.log"

cache="$MG_TOOLS_OUT/build/tool-src"
printf 'lame source\n' >"$work/lame.tar.gz"
lame_sha="$(shasum -a 256 "$work/lame.tar.gz" | cut -d' ' -f1)"
cat >"$work/cache.lock" <<LOCK
ffmpeg 7.1.1 file://$work/ffmpeg.tar.xz $ffmpeg_sha mirror
lame 3.100 file://$work/lame.tar.gz $lame_sha mirror
shield-source 2.0.2 file://$work/helper.tar.gz $helper_sha mirror
LOCK
assets_of_cache_lock="ffmpeg-7.1.1.tar.xz:ffmpeg.tar.xz lame-3.100.tar.gz:lame.tar.gz shield-source-2.0.2.tar.gz:helper.tar.gz"

fill_cache() {
    rm -rf "$cache"
    mkdir -p "$cache"
    cp "$work/ffmpeg.tar.xz" "$cache/ffmpeg.tar.xz"
    cp "$work/lame.tar.gz" "$cache/lame.tar.gz"
    cp "$work/helper.tar.gz" "$cache/shield.tar.gz"
}

run_sources() {
    : >"$MG_CURL_LOG"
    rm -rf "$work/cached-assets"
    status=0
    PATH="$work/bin:$PATH" MG_TOOLS_LOCK="$work/cache.lock" \
        bash "$script" sources "$work/cached-assets" >"$work/sources.log" 2>&1 || status=$?
}

assets_are_right() {
    local pair
    for pair in $assets_of_cache_lock; do
        cmp -s "$work/cached-assets/${pair%:*}" "$work/${pair#*:}" || return 1
    done
    [ "$(find "$work/cached-assets" -mindepth 1 | wc -l | tr -d ' ')" = 3 ]
}

downloads() {
    wc -l <"$MG_CURL_LOG" | tr -d ' '
}

said() {
    grep -qF -- "$1" "$work/sources.log"
}

fill_cache
run_sources
check "cached sources succeed" test "$status" = 0
check "cached sources make no download call" test "$(downloads)" = 0
check "cached sources give the right assets" assets_are_right
for pair in $assets_of_cache_lock; do
    check "reuse of ${pair%:*} is reported" said "reused from the cache: ${pair%:*}"
done

fill_cache
printf 'tampered\n' >"$cache/lame.tar.gz"
run_sources
check "a cached file with a bad checksum falls back to a download" test "$status" = 0
check "only the rejected source is downloaded" test "$(cat "$MG_CURL_LOG")" = "file://$work/lame.tar.gz"
check "the rejected file never becomes an asset" assets_are_right
check "the rejection names the file and the reason" said "rejected $cache/lame.tar.gz: checksum mismatch"
check "the fallback download is reported" said "downloaded: lame-3.100.tar.gz"
check "the cached file is left as it was" grep -qx 'tampered' "$cache/lame.tar.gz"

fill_cache
rm "$cache/shield.tar.gz"
run_sources
check "a missing cached file falls back to a download" test "$status" = 0
check "only the missing source is downloaded" test "$(cat "$MG_CURL_LOG")" = "file://$work/helper.tar.gz"
check "a missing cached file still gives the right assets" assets_are_right
check "the missing file is named" said "not in the cache: $cache/shield.tar.gz"

fill_cache
rm "$cache/lame.tar.gz"
mkdir "$cache/lame.tar.gz"
run_sources
check "a cache entry that is not a file falls back to a download" test "$status" = 0
check "an entry that is not a file still gives the right assets" assets_are_right

rm -rf "$cache"
run_sources
check "with no cache every source is downloaded" test "$status" = 0
check "with no cache there is one download per source" test "$(downloads)" = 3
check "with no cache the assets are right" assets_are_right

: >"$MG_CURL_LOG"
PATH="$work/bin:$PATH" MG_TOOLS_LOCK="$work/cache.lock" \
    bash "$script" sources "$work/cached-assets" >"$work/sources.log" 2>&1
check "an asset already in place is not fetched again" test "$(downloads)" = 0
check "an asset already in place is reported" said "already in place: lame-3.100.tar.gz"

fill_cache
printf 'tampered\n' >"$cache/ffmpeg.tar.xz"
printf 'bad\n' >"$work/bad-upstream.tar.xz"
printf 'ffmpeg 7.1.1 file://%s %s mirror\n' "$work/bad-upstream.tar.xz" "$ffmpeg_sha" >"$work/bad-both.lock"
mkdir -p "$work/stale-assets"
bad_asset="$(MG_TOOLS_LOCK="$work/bad-both.lock" bash "$script" allowed 0.1.0 | tail -n 1)"
printf 'stale\n' >"$work/stale-assets/$bad_asset"
check_fails "a bad cache and a bad download fail" \
    env PATH="$work/bin:$PATH" MG_TOOLS_LOCK="$work/bad-both.lock" bash "$script" sources "$work/stale-assets"
check "nothing unverified is left in the assets" test -z "$(ls -A "$work/stale-assets")"

printf 'unknown 1 file://%s %s mirror\n' "$work/lame.tar.gz" "$lame_sha" >"$work/unknown.lock"
: >"$MG_CURL_LOG"
PATH="$work/bin:$PATH" MG_TOOLS_LOCK="$work/unknown.lock" \
    bash "$script" sources "$work/unknown-assets" >"$work/sources.log" 2>&1
check "a source the build does not cache is downloaded" test "$(downloads)" = 1
check "a source the build does not cache is reported" said "the build keeps no cached copy of unknown"

check "the real lock still has mirrored sources" grep -q ' mirror$' "$root/tools.lock"
uncached="$(awk 'NF >= 5 && $5 == "mirror" { print $1 }' "$root/tools.lock" |
    while read -r name; do
        [ -n "$("$root/tool-cache.sh" file "$name")" ] || echo "$name"
    done)"
check "every mirrored source in the real lock has a cache path" test -z "$uncached"

if [ "$fails" -ne 0 ]; then
    printf '\n%d test(s) failed\n' "$fails"
    exit 1
fi
printf '\nall tests passed\n'
