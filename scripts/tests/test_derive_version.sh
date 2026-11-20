#!/usr/bin/env bash
# Tests for derive-version.sh — run: scripts/tests/test_derive_version.sh
set -euo pipefail

script="$(cd "$(dirname "$0")/.." && pwd)/release/derive-version.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
fails=0
mkdir -p "$work/release-notes"
printf 'Notes.\n' > "$work/release-notes/0.1.0.md"

check() {
    local name="$1"; shift
    if "$@" >/dev/null 2>&1; then
        printf 'ok   - %s\n' "$name"
    else
        printf 'FAIL - %s\n' "$name"
        fails=$((fails + 1))
    fi
}


out="$work/github-output"
: > "$out"
check "a dispatch input is printed" \
    bash -c "cd '$work' && [ \"\$(INPUT_VERSION=0.1.0 bash '$script')\" = 0.1.0 ]"
check "the version is written to GITHUB_OUTPUT" \
    bash -c "cd '$work' && INPUT_VERSION=0.1.0 GITHUB_OUTPUT='$out' bash '$script' >/dev/null && grep -qx 'version=0.1.0' '$out'"
check "a release tag name gives the bare version" \
    bash -c "cd '$work' && [ \"\$(EVENT_NAME=release REF_NAME=v0.1.0 bash '$script')\" = 0.1.0 ]"
check "a version that is not X.Y.Z fails" \
    bash -c "! (cd '$work' && INPUT_VERSION=0.1 bash '$script')"
check "a version without release notes fails" \
    bash -c "! (cd '$work' && INPUT_VERSION=9.9.9 bash '$script')"
check "a failure writes nothing to GITHUB_OUTPUT" \
    bash -c "cd '$work' && : > '$out' && (INPUT_VERSION=9.9.9 GITHUB_OUTPUT='$out' bash '$script' || true) 2>/dev/null && [ ! -s '$out' ]"

if [ "$fails" -ne 0 ]; then
    printf '\n%d test(s) failed\n' "$fails"
    exit 1
fi
printf '\nall tests passed\n'
