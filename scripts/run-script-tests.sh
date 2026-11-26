#!/usr/bin/env bash
# Finding tests by name keeps one list, so a new test cannot be left out of make or CI.

set -euo pipefail
shopt -s nullglob

dir="${1:-$(dirname "${BASH_SOURCE[0]}")/tests}"
run=0
failed=0

for script in "$dir"/test_*.sh; do
    name="${script##*/}"
    printf '== %s\n' "$name"
    run=$((run + 1))
    if ! bash "$script"; then
        printf 'FAILED: %s\n' "$name"
        failed=$((failed + 1))
    fi
done

if [ "$run" -eq 0 ]; then
    echo "no test_*.sh found in $dir" >&2
fi
printf 'script tests: %d run, %d failed\n' "$run" "$failed"
[ "$run" -gt 0 ] && [ "$failed" -eq 0 ]
