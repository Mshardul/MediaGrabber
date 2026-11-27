#!/usr/bin/env bash
# The fetch and package steps run on fake local sources, so a changed cache path shows up as a download.

set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work" 2>/dev/null || true' EXIT

fail() {
    echo "FAIL: $1" >&2
    cat "$work/output" >&2
    exit 1
}

# A copy of the scripts keeps the default build folder, and the disk image tool, inside the sandbox.
root="$work/root"
mkdir -p "$root/scripts/release" "$work/bin" "$work/src" "$work/App.app"
cp "$repo/scripts/fetch-tools.sh" "$repo/scripts/release-assets.sh" "$repo/scripts/tool-cache.sh" "$root/scripts/"
cp "$repo/scripts/release/package-dmg.sh" "$root/scripts/release/"
cat >"$root/scripts/create-dmg" <<'FAKE'
#!/usr/bin/env bash
printf 'image\n' >"$3"
FAKE
chmod +x "$root/scripts/create-dmg"

fake_source() {
    local name="$1" license="$2" dir="$work/src/$1"
    mkdir -p "$dir"
    printf 'license of %s\n' "$name" >"$dir/$license"
    if [ "$name" != shield ]; then
        printf '#!/bin/sh\nprintf "all:\\n\\ttouch ffmpeg ffprobe\\ninstall:\\n" >Makefile\n' >"$dir/configure"
        chmod +x "$dir/configure"
    fi
    tar -czf "$work/$name.tar" -C "$work/src" "$name"
}

fake_source ffmpeg COPYING.LGPLv2.1
fake_source lame COPYING
fake_source shield LICENSE

lock="$work/tools.lock"
for row in ffmpeg:ffmpeg lame:lame shield-source:shield; do
    sha="$(shasum -a 256 "$work/${row#*:}.tar" | cut -d' ' -f1)"
    echo "${row%:*} 1.0 file://$work/${row#*:}.tar $sha mirror" >>"$lock"
done

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

fetch_then_package() {
    local out="$1" assets="$2"
    # A server that is already built keeps the fetch step from running npm.
    mkdir -p "$out/Resources/Shield/server/build" "$out/Resources/Shield/server/node_modules/express"
    : >"$out/Resources/Shield/server/build/main.js"

    : >"$MG_CURL_LOG"
    PATH="$work/bin:$PATH" MG_TOOLS_LOCK="$lock" bash "$root/scripts/fetch-tools.sh" >"$work/output" 2>&1 ||
        fail "the fetch step failed"
    [ "$(wc -l <"$MG_CURL_LOG" | tr -d ' ')" = 3 ] || fail "the fetch step should download each source once"

    : >"$MG_CURL_LOG"
    PATH="$work/bin:$PATH" MG_TOOLS_LOCK="$lock" \
        bash "$root/scripts/release/package-dmg.sh" "$work/App.app" 0.1.0 "$assets" >"$work/output" 2>&1 ||
        fail "packaging failed"
    [ ! -s "$MG_CURL_LOG" ] || fail "packaging downloaded again: $(cat "$MG_CURL_LOG")"
    [ "$(grep -c '^reused from the cache: ' "$work/output")" = 3 ] || fail "packaging should reuse all three sources"
    (cd "$assets" && shasum -a 256 -c SHA256SUMS >/dev/null) || fail "SHA256SUMS should match the assets"
    [ "$(wc -l <"$assets/SHA256SUMS" | tr -d ' ')" = 4 ] || fail "SHA256SUMS should list the image and three sources"
}

unset MG_TOOLS_OUT
fetch_then_package "$root" "$work/default-assets"

export MG_TOOLS_OUT="$work/other out"
fetch_then_package "$MG_TOOLS_OUT" "$work/override-assets"

echo "package cache tests passed"
