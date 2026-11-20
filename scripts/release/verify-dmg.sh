#!/usr/bin/env bash
# Mounts the disk image and checks the app inside: its version and its signature.
# Run: scripts/release/verify-dmg.sh DMG VERSION
set -euo pipefail

dmg="${1:?disk image}"
version="${2:?version}"
mounted=""

cleanup() {
    if [ -n "$mounted" ]; then
        hdiutil detach "$mounted" >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT

attachment="$(hdiutil attach "$dmg" -nobrowse -noautoopen -readonly)"
mounted="$(printf '%s\n' "$attachment" | awk -F'\t' '/\/Volumes\// { print $NF }' | tail -1)"
[ -n "$mounted" ] || { echo "could not resolve the mount point" >&2; exit 1; }

app="$mounted/MediaGrabber.app"
[ -d "$app" ] || { echo "no MediaGrabber.app in the disk image" >&2; exit 1; }

got="$(defaults read "$app/Contents/Info" CFBundleShortVersionString)"
[ "$got" = "$version" ] || { echo "app version '$got' != release '$version'" >&2; exit 1; }

codesign --verify --deep --strict "$app"
echo "ok   - the disk image holds MediaGrabber $version with a valid signature"
