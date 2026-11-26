#!/usr/bin/env bash
# Every case points the runner at a temporary folder, so it never starts the real tests again.

set -euo pipefail

runner="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/run-script-tests.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

fail() {
    echo "FAIL: $1" >&2
    cat "$work/output" >&2
    exit 1
}

fake_test() {
    mkdir -p "$(dirname "$1")"
    printf '#!/usr/bin/env bash\necho "ran %s" >>"%s"\nexit %s\n' "${1##*/}" "$work/calls" "$2" >"$1"
    chmod +x "$1"
}

run_runner() {
    : >"$work/calls"
    status=0
    "$@" >"$work/output" 2>&1 || status=$?
}

expect_summary() {
    [ "$(tail -n 1 "$work/output")" = "$1" ] || fail "$2: the last line should be '$1'"
}

mixed="$work/mixed tests"
fake_test "$mixed/test_a.sh" 0
fake_test "$mixed/test_b.sh" 3
fake_test "$mixed/test_c.sh" 0
fake_test "$mixed/helper.sh" 1
fake_test "$mixed/lib/test_nested.sh" 1
run_runner "$runner" "$mixed"
[ "$status" != 0 ] || fail "a failing script should fail the run"
expect_summary "script tests: 3 run, 1 failed" "one failure"
[ "$(cat "$work/calls")" = $'ran test_a.sh\nran test_b.sh\nran test_c.sh' ] ||
    fail "each test_*.sh should run once, and a failure should not stop the rest"
grep -q 'FAILED: test_b.sh' "$work/output" || fail "the failing script should be named"

passing="$work/passing"
fake_test "$passing/test_a.sh" 0
fake_test "$passing/test_b.sh" 0
run_runner "$runner" "$passing"
[ "$status" = 0 ] || fail "passing scripts should pass the run"
expect_summary "script tests: 2 run, 0 failed" "all passing"

mkdir -p "$work/empty"
run_runner "$runner" "$work/empty"
[ "$status" != 0 ] || fail "an empty folder should fail"
expect_summary "script tests: 0 run, 0 failed" "empty folder"

run_runner "$runner" "$work/absent"
[ "$status" != 0 ] || fail "a missing folder should fail"
expect_summary "script tests: 0 run, 0 failed" "missing folder"

copy="$work/root/scripts"
fake_test "$copy/tests/test_default.sh" 0
cp "$runner" "$copy/run-script-tests.sh"
run_runner "$copy/run-script-tests.sh"
[ "$status" = 0 ] || fail "with no folder given, the tests beside the runner should run"
expect_summary "script tests: 1 run, 0 failed" "default folder"

echo "script test runner tests passed"
