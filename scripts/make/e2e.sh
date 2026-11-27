#!/usr/bin/env bash
# Runs the end-to-end test on a built app. Used by make e2e.

set -euo pipefail

CONFIG="${CONFIG:-Release}"
DERIVED="${DERIVED:-build}"
APP_NAME="${APP_NAME:-MediaGrabber}"
SIGN_APP_SCRIPT="${SIGN_APP_SCRIPT:-scripts/sign-app.sh}"
RUN_SCRIPT="${RUN_SCRIPT:-scripts/e2e/run.sh}"

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
build_dir="$(DERIVED="$DERIVED" "$repo_root/scripts/make/build-dir.sh")"
app="$build_dir/Build/Products/$CONFIG/$APP_NAME.app"

trap 'cd "$repo_root" && make --no-print-directory drop-build-app DERIVED="$DERIVED"' EXIT

cd "$repo_root"
make build CONFIG="$CONFIG"
if [ ! -d "$app" ]; then
    echo "app not found: $app" >&2
    exit 1
fi
"$SIGN_APP_SCRIPT" "$app" - && "$RUN_SCRIPT" "$app"
