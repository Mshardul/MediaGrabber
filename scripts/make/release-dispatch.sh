#!/usr/bin/env bash
# Dispatches a release workflow for make release-dry-run and make release-overwrite.

set -euo pipefail

MODE="${1:-}"
VERSION="${VERSION:-}"

if [ -z "$VERSION" ]; then
    echo "VERSION=X.Y.Z required" >&2
    exit 1
fi
if ! echo "$VERSION" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "VERSION must be N.N.N" >&2
    exit 1
fi

case "$MODE" in
dry-run)
    gh workflow run release.yml -f version="$VERSION" -f dry_run=true
    ;;
overwrite)
    read -r -p "replace the published release v$VERSION? [y/N] " ok
    [ "$ok" = y ] || {
        echo aborted
        exit 1
    }
    gh workflow run release.yml -f version="$VERSION" -f overwrite=true
    ;;
*)
    echo "usage: release-dispatch.sh <dry-run|overwrite> <VERSION>" >&2
    exit 1
    ;;
esac
