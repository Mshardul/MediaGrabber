#!/usr/bin/env bash
# Prints the build folder for DERIVED. Used by the make scripts.

set -euo pipefail

DERIVED="${DERIVED:-build}"

case "$DERIVED" in
/*) echo "$DERIVED" ;;
*) echo "$(cd "$(dirname "$0")/../.." && pwd)/$DERIVED" ;;
esac
