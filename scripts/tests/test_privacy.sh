#!/usr/bin/env bash
# The Privacy pane must show the same plain-text copy that PRIVACY.md converts to.
# Run: scripts/tests/test_privacy.sh

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root"
fails=0

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

check() {
    local name="$1"; shift
    if "$@" >/dev/null 2>&1; then
        printf 'ok   - %s\n' "$name"
    else
        printf 'FAIL - %s\n' "$name"
        fails=$((fails + 1))
    fi
}

.venv/bin/python scripts/privacy-text.py "$work/expected.txt"

check "committed Privacy.txt exists" test -s Resources/Privacy.txt
if diff -u "$work/expected.txt" Resources/Privacy.txt >/dev/null 2>&1; then
    printf 'ok   - committed Privacy.txt matches a fresh conversion\n'
else
    printf 'FAIL - committed Resources/Privacy.txt differs from a fresh conversion\n'
    fails=$((fails + 1))
fi

if [ "$fails" -ne 0 ]; then
    printf '\n%d test(s) failed\n' "$fails"
    exit 1
fi
printf '\nall tests passed\n'