#!/usr/bin/env bash
# Tests for appcast.py — run: scripts/tests/test_appcast.sh [python]

set -euo pipefail

PY="${1:-python3}"
SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/appcast.py"
PROJECT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/Project.swift"
EXPECTED_FEED="https://github.com/Mshardul/MediaGrabber/releases/latest/download/appcast.xml"
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

"$PY" "$SCRIPT" --existing "$work/none.xml" --version 0.1.0 \
    --url https://example.com/MediaGrabber-0.1.0.dmg --signature sig1 --length 100 \
    --notes https://example.com/notes/0.1.0 --out "$work/first.xml"
"$PY" "$SCRIPT" --existing "$work/first.xml" --version 0.2.0 \
    --url https://example.com/MediaGrabber-0.2.0.dmg --signature sig2 --length 200 \
    --notes https://example.com/notes/0.2.0 --out "$work/second.xml"

feed="$work/second.xml"
check "feed is well-formed xml" xmllint --noout "$feed"
check "two items" test "$(grep -c '<item>' "$feed")" = 2
check "newest item first" test "$(grep -o '<sparkle:version>[^<]*' "$feed" | head -1)" = '<sparkle:version>0.2.0'
check "older item kept second" test "$(grep -o '<sparkle:version>[^<]*' "$feed" | tail -1)" = '<sparkle:version>0.1.0'
check "new enclosure url" grep -q 'enclosure url="https://example.com/MediaGrabber-0.2.0.dmg"' "$feed"
check "new enclosure signature" grep -q 'sparkle:edSignature="sig2"' "$feed"
check "new enclosure length" grep -q 'length="200"' "$feed"
check "minimum system version" grep -q '<sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>' "$feed"
check "release notes link" grep -q '<sparkle:releaseNotesLink>https://example.com/notes/0.2.0<' "$feed"
script_feed="$(sed -n 's/^FEED = "\(.*\)"$/\1/p' "$SCRIPT")"
project_feed="$(sed -n 's/.*"SUFeedURL": "\([^"]*\)".*/\1/p' "$PROJECT")"
check "script feed is the release asset" test "$script_feed" = "$EXPECTED_FEED"
check "project feed is the release asset" test "$project_feed" = "$EXPECTED_FEED"
check "script and project feeds match" test "$script_feed" = "$project_feed"

"$PY" "$SCRIPT" --existing "$work/none.xml" --version 0.1.0 \
    --url https://example.com/a.dmg --signature sigA --length 1 \
    --notes https://example.com/notes/a --out "$work/re1.xml"
"$PY" "$SCRIPT" --existing "$work/re1.xml" --version 0.1.0 \
    --url https://example.com/b.dmg --signature sigB --length 2 \
    --notes https://example.com/notes/b --out "$work/re2.xml"
check "reinsert keeps one item" test "$(grep -c '<item>' "$work/re2.xml")" = 1
check "reinsert keeps one version entry" test "$(grep -c '<sparkle:version>0.1.0</sparkle:version>' "$work/re2.xml")" = 1
check "reinsert carries the second signature" grep -q 'sparkle:edSignature="sigB"' "$work/re2.xml"
check "reinsert drops the first signature" test "$(grep -c 'sigA' "$work/re2.xml")" = 0

: > "$work/empty.xml"
"$PY" "$SCRIPT" --existing "$work/empty.xml" --version 0.1.0 \
    --url https://example.com/a.dmg --signature sigA --length 1 \
    --notes https://example.com/notes/a --out "$work/from-empty.xml"
check "empty existing is well-formed" xmllint --noout "$work/from-empty.xml"
check "empty existing yields one item" test "$(grep -c '<item>' "$work/from-empty.xml")" = 1
check "missing existing is well-formed" xmllint --noout "$work/first.xml"
check "missing existing yields one item" test "$(grep -c '<item>' "$work/first.xml")" = 1

check "self-test" "$PY" "$SCRIPT" --self-test

exit "$fails"
