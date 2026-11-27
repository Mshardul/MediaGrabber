#!/usr/bin/env bash
# Bytecode is off so that a test run leaves no untracked files behind.

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=scripts .venv/bin/python - <<'PY'
import sys
import unittest

suite = unittest.defaultTestLoader.discover("scripts/tests/buildlog")
result = unittest.TextTestRunner(verbosity=2).run(suite)
# A run with no tests or with a skip has not verified anything, so neither may pass.
sys.exit(not (result.wasSuccessful() and result.testsRun and not result.skipped))
PY
