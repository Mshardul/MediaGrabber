#!/usr/bin/env bash
# Replaces the installed app with the built product. Used by make install and make reinstall.

set -euo pipefail

APP_NAME="${APP_NAME:-MediaGrabber}"
BUNDLE_ID="${BUNDLE_ID:-app.mediagrabber.mac}"
CONFIG="${CONFIG:-Debug}"
DERIVED="${DERIVED:-build}"
MG_APPLICATIONS_DIR="${MG_APPLICATIONS_DIR:-/Applications}"
MG_LSREGISTER="${MG_LSREGISTER:-/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister}"

build_dir="$(DERIVED="$DERIVED" "$(dirname "$0")/build-dir.sh")"
APP="${APP:-$build_dir/Build/Products/$CONFIG/$APP_NAME.app}"
INSTALLED="$MG_APPLICATIONS_DIR/$APP_NAME.app"

osascript_output="$(osascript -e 'tell application "System Events" to get unix id of (every process whose bundle identifier is "'"$BUNDLE_ID"'")' 2>/dev/null || true)"
if [ -n "$osascript_output" ]; then
    IFS=',' read -r -a pids <<<"$(echo "$osascript_output" | tr -d ' ')"
    if [ ${#pids[@]} -gt 0 ]; then
        kill -9 "${pids[@]}" 2>/dev/null || true
    fi
fi

killall -9 "$APP_NAME" >/dev/null 2>&1 || true

while pgrep -x "$APP_NAME" >/dev/null 2>&1; do
    sleep 0.05
done

if [ ! -d "$APP" ]; then
    echo "build product missing: $APP" >&2
    exit 1
fi

rm -rf "$INSTALLED" || {
    echo "could not remove $INSTALLED" >&2
    exit 1
}
ditto "$APP" "$INSTALLED" || {
    echo "could not copy $APP to $INSTALLED" >&2
    exit 1
}
"$MG_LSREGISTER" -f "$INSTALLED"

make --no-print-directory drop-build-app DERIVED="$DERIVED"

if [ "${MG_NO_OPEN:-}" != "1" ]; then
    open "$INSTALLED"
fi
