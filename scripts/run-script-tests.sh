#!/usr/bin/env bash
# Finding tests by name keeps one list, so a new test cannot be left out of make or CI.

set -euo pipefail
shopt -s nullglob

dir=""
excludes=()
while [ $# -gt 0 ]; do
    case "$1" in
    --exclude)
        [ $# -ge 2 ] || {
            echo "--exclude needs a test name" >&2
            exit 2
        }
        excludes+=("$2")
        shift 2
        ;;
    -*)
        echo "unknown option: $1" >&2
        exit 2
        ;;
    *)
        dir="$1"
        shift
        ;;
    esac
done
dir="${dir:-$(dirname "${BASH_SOURCE[0]}")/tests}"
scripts=("$dir"/test_*.sh)

# Bash 3.2 treats an empty array as unset, hence the guarded expansions.
for wanted in ${excludes[@]+"${excludes[@]}"}; do
    found=false
    for script in ${scripts[@]+"${scripts[@]}"}; do
        if [ "${script##*/}" = "$wanted" ]; then
            found=true
        fi
    done
    "$found" || {
        echo "cannot exclude: no test named '$wanted' in $dir" >&2
        exit 2
    }
done

is_excluded() {
    local wanted
    for wanted in ${excludes[@]+"${excludes[@]}"}; do
        if [ "$wanted" = "$1" ]; then
            return 0
        fi
    done
    return 1
}

run=0
failed=0
skipped=0
skipped_names=""

for script in ${scripts[@]+"${scripts[@]}"}; do
    name="${script##*/}"
    if is_excluded "$name"; then
        skipped=$((skipped + 1))
        skipped_names="$skipped_names $name"
        continue
    fi
    printf '== %s\n' "$name"
    run=$((run + 1))
    if ! bash "$script"; then
        printf 'FAILED: %s\n' "$name"
        failed=$((failed + 1))
    fi
done

if [ "$run" -eq 0 ]; then
    echo "no test_*.sh left to run in $dir" >&2
fi
summary="script tests: $run run, $failed failed"
if [ "$skipped" -gt 0 ]; then
    summary="$summary, $skipped excluded:$skipped_names"
fi
echo "$summary"
[ "$run" -gt 0 ] && [ "$failed" -eq 0 ]
