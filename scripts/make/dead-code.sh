#!/usr/bin/env bash
# Runs Periphery to find dead Swift code. Used by make dead-code.

set -euo pipefail

APP_NAME="${APP_NAME:-MediaGrabber}"
DERIVED="${DERIVED:-build}"
CONFIG="${CONFIG:-Debug}"

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD_DIR="$(DERIVED="$DERIVED" "$REPO_ROOT/scripts/make/build-dir.sh")"

trap 'APP_NAME="$APP_NAME" DERIVED="$DERIVED" "$REPO_ROOT/scripts/make/drop-build-app.sh"' EXIT

cd "$REPO_ROOT"
make --no-print-directory tools generate

mise exec -- xcodebuild \
    -workspace "$REPO_ROOT/$APP_NAME.xcworkspace" \
    -destination 'platform=macOS' \
    -derivedDataPath "$BUILD_DIR" \
    -scheme "$APP_NAME-Workspace" \
    -configuration "$CONFIG" \
    build-for-testing

INDEX_STORE="$BUILD_DIR/Index.noindex/DataStore"

mise exec -- periphery scan \
    --project "$REPO_ROOT/$APP_NAME.xcworkspace" \
    --schemes "$APP_NAME-Workspace" \
    --skip-build \
    --index-store-path "$INDEX_STORE" \
    --skip-schemes-validation
