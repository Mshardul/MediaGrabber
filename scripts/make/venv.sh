#!/usr/bin/env bash
# Local runs and CI must share one Python version, so any other one is refused.

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

fail() {
    echo "$1" >&2
    exit 1
}

version_of() {
    "$1" -c 'import sys; print("%d.%d" % sys.version_info[:2])' 2>/dev/null
}

if [ ! -f .python-version ]; then
    fail ".python-version is missing, so there is no Python version to use."
fi
wanted="$(cat .python-version)"

if [ -e .venv ] || [ -L .venv ]; then
    if ! found="$(version_of .venv/bin/python)"; then
        fail ".venv has no working Python. Move or delete .venv, then run make venv again."
    fi
    if [ "$found" != "$wanted" ]; then
        fail ".venv uses Python $found, but .python-version asks for $wanted. Move or delete .venv, then run make venv again."
    fi
else
    if ! found="$(version_of "python$wanted")" || [ "$found" != "$wanted" ]; then
        fail "Python $wanted is not installed: python$wanted did not run. Install it, then run make venv again."
    fi
    "python$wanted" -m venv .venv
fi

.venv/bin/pip install -r requirements.txt -r Tests/PluginTests/requirements.txt
