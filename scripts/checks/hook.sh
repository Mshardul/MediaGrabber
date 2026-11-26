#!/usr/bin/env bash
# Without this, a missing tool surfaces as an error that does not say what to do.

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

if ! command -v mise >/dev/null 2>&1; then
    echo "The commit checks could not run: mise was not found on PATH. See docs/development.md." >&2
    exit 1
fi

if [ ! -x .venv/bin/python ]; then
    echo "The commit checks could not run: .venv is missing or has no Python. Run make venv." >&2
    exit 1
fi

exec .venv/bin/python scripts/checks staged
