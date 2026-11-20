#!/usr/bin/env bash
# Tests for check-feed.sh — run: scripts/tests/test_check_feed.sh
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
script="$root/release/check-feed.sh"
work="$(mktemp -d)"
site="$work/site"
mkdir -p "$site"
servers=()
fails=0

cleanup() {
    for pid in "${servers[@]:-}"; do kill "$pid" 2>/dev/null || true; done
    rm -rf "$work"
}
trap cleanup EXIT

check() {
    local name="$1"; shift
    if "$@" >/dev/null 2>&1; then
        printf 'ok   - %s\n' "$name"
    else
        printf 'FAIL - %s\n' "$name"
        fails=$((fails + 1))
    fi
}

start_server() {
    local log="$work/server.log"
    : > "$log"
    python3 "$root/e2e/fixture-server.py" --root "$@" > "$log" 2>&1 &
    local pid=$!
    servers+=("$pid")
    for _ in $(seq 1 100); do
        grep -q '^listening ' "$log" && break
        sleep 0.05
    done
    sed -n 's/^listening //p' "$log"
}

write_feed() {
    local version="$1" enclosure="$2" length="$3" file="$4"
    cat > "$file" <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>MediaGrabber</title>
    <item>
      <sparkle:version>$version</sparkle:version>
      <enclosure url="$enclosure" sparkle:edSignature="sig" length="$length" type="application/octet-stream"/>
    </item>
  </channel>
</rss>
XML
}

printf 'disk image\n' > "$site/clip.dmg"
length="$(stat -f%z "$site/clip.dmg")"
base="$(start_server "$site")"
feed_url="$base/feed.xml"
write_feed 0.1.0 "$base/clip.dmg" "$length" "$site/feed.xml"

run_check() {
    MG_FEED_URL="$feed_url" MG_FEED_RETRY_SECONDS="${1:-5}" "$script" --version "${2:-0.1.0}"
}

check "a matching feed and disk image pass" run_check 5

write_feed 0.0.9 "$base/clip.dmg" "$length" "$site/feed.xml"
(sleep 1; write_feed 0.1.0 "$base/clip.dmg" "$length" "$site/feed.xml") &
check "a stale feed that catches up within the window passes" run_check 12

write_feed 0.0.9 "$base/clip.dmg" "$length" "$site/feed.xml"
check "a stale feed that never catches up fails" bash -c "! MG_FEED_URL='$feed_url' MG_FEED_RETRY_SECONDS=2 '$script' --version 0.1.0"

write_feed 0.1.0 "$base/missing.dmg" "$length" "$site/feed.xml"
check "a 404 disk image fails" bash -c "! MG_FEED_URL='$feed_url' MG_FEED_RETRY_SECONDS=2 '$script' --version 0.1.0"

write_feed 0.1.0 "$base/clip.dmg" "$((length + 1))" "$site/feed.xml"
check "a size mismatch fails" bash -c "! MG_FEED_URL='$feed_url' MG_FEED_RETRY_SECONDS=2 '$script' --version 0.1.0"

write_feed 0.1.0 "$base/clip.dmg" "$length" "$site/feed.xml"
redirect_base="$(start_server "$site" --redirect "/redirect.xml=$feed_url")"
feed_url="$redirect_base/redirect.xml"
check "a redirected feed is followed" run_check 5

if [ "$fails" -ne 0 ]; then
    printf '\n%d test(s) failed\n' "$fails"
    exit 1
fi
printf '\nall tests passed\n'
