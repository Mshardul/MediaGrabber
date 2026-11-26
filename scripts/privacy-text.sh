#!/usr/bin/env bash
# Converts PRIVACY.md into the plain-text copy shown in the Privacy pane.
set -euo pipefail

out="${1:-Resources/privacy.txt}"
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

.venv/bin/python scripts/privacy-text.py "$out"
