#!/usr/bin/env bash
# Removes built app copies from the build directory. Used by make install and make reinstall.

set -euo pipefail

APP_NAME="${APP_NAME:-MediaGrabber}"
DERIVED="${DERIVED:-build}"
MG_LSREGISTER="${MG_LSREGISTER:-/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister}"

build_dir="$(DERIVED="$DERIVED" "$(dirname "$0")/build-dir.sh")"

for config in Debug Release; do
    app="$build_dir/Build/Products/$config/$APP_NAME.app"
    if [ -d "$app" ]; then
        "$MG_LSREGISTER" -u "$app" >/dev/null 2>&1 || true
        rm -rf "$app"
    fi
done
