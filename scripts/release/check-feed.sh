#!/usr/bin/env bash
# Proves the published feed serves this version and its disk image.
# Run: scripts/release/check-feed.sh --version X.Y.Z
#   MG_FEED_URL overrides the feed address, MG_FEED_RETRY_SECONDS the retry window (default 120).
set -euo pipefail

feed="${MG_FEED_URL:-https://github.com/Mshardul/MediaGrabber/releases/latest/download/appcast.xml}"
window="${MG_FEED_RETRY_SECONDS:-120}"
version=""

while [ $# -gt 0 ]; do
    case "$1" in
        --version) version="${2:?version required}"; shift 2 ;;
        *) echo "unknown argument: $1" >&2; exit 1 ;;
    esac
done
[ -n "$version" ] || { echo "--version is required" >&2; exit 1; }

newest_item() {
    local body="$1"
    printf '%s' "$body" | tr -d '\n\r' | sed 's:</item>.*::'
}

attempt() {
    local body item item_version url length headers got
    body="$(curl -fsSL --max-time 30 "$feed")" || { echo "feed did not answer" >&2; return 1; }
    item="$(newest_item "$body")"
    item_version="$(printf '%s' "$item" | grep -o '<sparkle:version>[^<]*' | head -1 | sed 's/.*>//')"
    [ "$item_version" = "$version" ] || { echo "newest feed item is '$item_version', expected '$version'" >&2; return 1; }
    url="$(printf '%s' "$item" | grep -o 'enclosure url="[^"]*' | head -1 | sed 's/.*"//')"
    length="$(printf '%s' "$item" | grep -o 'length="[^"]*' | head -1 | sed 's/.*"//')"
    [ -n "$url" ] && [ -n "$length" ] || { echo "newest feed item has no enclosure" >&2; return 1; }
    headers="$(curl -fsSIL --max-time 30 "$url")" || { echo "disk image did not answer: $url" >&2; return 1; }
    got="$(printf '%s' "$headers" | tr -d '\r' | awk 'tolower($1) == "content-length:" { v = $2 } END { print v }')"
    [ "$got" = "$length" ] || { echo "disk image size is '$got', feed says '$length'" >&2; return 1; }
    printf 'ok   - %s is the newest item and its disk image answers at %s bytes\n' "$version" "$length"
}

deadline=$((SECONDS + window))
while :; do
    if attempt; then
        exit 0
    fi
    now=$SECONDS
    [ "$now" -ge "$deadline" ] && break
    remaining=$((deadline - now))
    if [ "$remaining" -gt 10 ]; then
        sleep 10
    else
        sleep "$remaining"
    fi
done
echo "feed check failed after ${window}s" >&2
exit 1
