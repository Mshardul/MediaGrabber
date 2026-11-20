#!/usr/bin/env bash
# Proves the built app's signature, update feed address and update key.
# Run: scripts/release/verify-app.sh APP  (EXPECTED_KEY and DRY from the environment)
set -euo pipefail

app="$(cd "${1:?app bundle}" && pwd)"
feed="https://github.com/Mshardul/MediaGrabber/releases/latest/download/appcast.xml"
info="$app/Contents/Info"
if [ -f "$info.plist" ]; then
    info="$info.plist"
fi

codesign --verify --deep --strict "$app"

got_feed="$(defaults read "$info" SUFeedURL)"
[ "$got_feed" = "$feed" ] || {
    echo "SUFeedURL is '$got_feed', expected '$feed'" >&2
    exit 1
}

if [ -n "${EXPECTED_KEY:-}" ]; then
    got_key="$(defaults read "$info" SUPublicEDKey 2>/dev/null || true)"
    [ "$got_key" = "$EXPECTED_KEY" ] || {
        echo "SUPublicEDKey in the app does not match MG_SPARKLE_PUBLIC_KEY" >&2
        exit 1
    }
elif [ "${DRY:-false}" = "true" ]; then
    echo "MG_SPARKLE_PUBLIC_KEY is unset; the dry run is not checking the update key"
else
    echo "MG_SPARKLE_PUBLIC_KEY is required to publish an update" >&2
    exit 1
fi
