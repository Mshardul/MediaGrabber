#!/usr/bin/env bash
# Proves the appcast's newest item carries this version and signs this disk image with the app's key.
# Run: scripts/release/check-signature.sh --appcast F --app APP --dmg DMG --version X.Y.Z
set -euo pipefail

appcast="" app="" dmg="" version=""
while [ $# -gt 0 ]; do
    case "$1" in
        --appcast) appcast="${2:?}"; shift 2 ;;
        --app) app="${2:?}"; shift 2 ;;
        --dmg) dmg="${2:?}"; shift 2 ;;
        --version) version="${2:?}"; shift 2 ;;
        *) echo "unknown argument: $1" >&2; exit 1 ;;
    esac
done
[ -n "$appcast" ] && [ -n "$app" ] && [ -n "$dmg" ] && [ -n "$version" ] || {
    echo "usage: check-signature.sh --appcast F --app APP --dmg DMG --version X.Y.Z" >&2
    exit 1
}

flat="$(tr -d '\n\r' < "$appcast")"
item="${flat%%</item>*}"
got_version="$(printf '%s' "$item" | grep -o '<sparkle:version>[^<]*' | head -1 | sed 's/.*>//')"
[ "$got_version" = "$version" ] || {
    echo "newest appcast item is '$got_version', expected '$version'" >&2
    exit 1
}

signature="$(printf '%s' "$item" | grep -o 'sparkle:edSignature="[^"]*' | head -1 | sed 's/.*"//')"
[ -n "$signature" ] || { echo "newest appcast item has no signature" >&2; exit 1; }

app="$(cd "$app" && pwd)"
info="$app/Contents/Info"
if [ -f "$info.plist" ]; then
    info="$info.plist"
fi
public_key="$(defaults read "$info" SUPublicEDKey 2>/dev/null || true)"
[ -n "$public_key" ] || { echo "the app has no SUPublicEDKey" >&2; exit 1; }

if swift "$(cd "$(dirname "$0")/.." && pwd)/ed25519.swift" verify "$public_key" "$signature" "$dmg"; then
    echo "ok   - $version is the newest item and its disk image verifies against the app's key"
else
    echo "the disk image does not verify against the app's update key" >&2
    exit 1
fi
