#!/usr/bin/env bash
# Quits MediaGrabber and removes every copy of the app on this Mac. Saved data and downloads stay.
set -euo pipefail

keep=""
if [ "${1:-}" = "--keep" ]; then
    keep="${2:?app bundle to keep}"
fi

root="$(cd "$(dirname "$0")/.." && pwd)"
bundle_id="app.mediagrabber.mac"
lsregister=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

pkill -9 -x MediaGrabber 2>/dev/null || true
# The helper outlives an app that was force-quit.
pkill -9 -f 'MediaGrabber\.app/Contents/Resources/Tools/node' 2>/dev/null || true

candidates() {
    printf '%s\n' /Applications/MediaGrabber.app "$HOME/Applications/MediaGrabber.app"
    mdfind "kMDItemCFBundleIdentifier == '$bundle_id'" 2>/dev/null || true
    # Spotlight skips Index.noindex, so build folders are searched directly.
    find "$root/build" "$HOME"/Library/Developer/Xcode/DerivedData/MediaGrabber-* \
        -type d -name MediaGrabber.app -prune 2>/dev/null || true
    # Launch Services also remembers copies that no longer exist.
    "$lsregister" -dump 2>/dev/null | sed -n 's|^path: *\(/.*/MediaGrabber\.app\)[/ ].*|\1|p'
}

failed=0
trashed=0
while IFS= read -r app; do
    case "$app" in
    */.Trash/*)
        trashed=1
        continue
        ;;
    /Volumes/*) continue ;;
    */MediaGrabber.app) ;;
    *) continue ;;
    esac
    [ "$app" = "$keep" ] && continue
    "$lsregister" -u "$app" >/dev/null 2>&1 || true
    if [ -d "$app" ]; then
        if rm -rf "$app"; then
            echo "removed $app"
        else
            echo "could not remove $app" >&2
            failed=1
        fi
    fi
done < <(candidates | sort -u)

# Apps nested inside a removed copy stay registered on their own.
"$lsregister" -dump 2>/dev/null | sed -n 's|^path: *\(/.*/MediaGrabber\.app/.*\.app\) (0x.*|\1|p' |
    while IFS= read -r nested; do
        [ -d "$nested" ] || "$lsregister" -u "$nested" >/dev/null 2>&1 || true
    done

# macOS blocks scripts from reading the Trash.
[ "$trashed" -eq 0 ] || echo "a copy is in the Trash: empty the Trash to remove it"

exit "$failed"
