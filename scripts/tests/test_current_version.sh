#!/usr/bin/env bash
# Tests for current-version.sh — run: scripts/tests/test_current_version.sh

set -euo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/current-version.sh"
fails=0

ok_case() {
    local name="$1" tags="$2" expected="$3" actual
    actual="$(printf '%s' "$tags" | "$SCRIPT")"
    if [ "$actual" = "$expected" ]; then
        printf 'ok   - %s\n' "$name"
    else
        printf 'FAIL - %s\n      expected: %s\n      actual:   %s\n' "$name" "$expected" "$actual"
        fails=$((fails + 1))
    fi
}

ok_case "empty input"                ""                                                   0.0.0
ok_case "single tag"                 $'v0.1.0\n'                                          0.1.0
ok_case "numeric not lexical sort"   $'v0.9.0\nv0.10.0\nv0.2.0\n'                         0.10.0
ok_case "ignores non-release tags"   $'v1.2.3\nvfoo\nmedia-grabber-v9.9.9\nv1.2\nv1.2.3-rc1\n' 1.2.3
ok_case "only non-release tags"      $'vfoo\nv1.2\nv1.2.3-rc1\n'                          0.0.0
ok_case "patch decides"              $'v1.2.9\nv1.2.10\n'                                 1.2.10
ok_case "minor beats patch"          $'v1.9.9\nv1.10.0\n'                                 1.10.0
ok_case "no trailing newline"        "v2.0.0"                                             2.0.0

if [ "$fails" -ne 0 ]; then
    printf '\n%d test(s) failed\n' "$fails"
    exit 1
fi
printf '\nall tests passed\n'
