#!/usr/bin/env bash
# Every case points the runner at a temporary folder, so it never starts the real tests again.

set -euo pipefail

runner="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/run-script-tests.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work" 2>/dev/null || true' EXIT

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

ran_calls() {
    [ "$(cat "$work/calls")" = "$1" ] || fail "$2: calls were: $(cat "$work/calls")"
}

run_runner "$runner" --exclude test_b.sh "$mixed"
[ "$status" = 0 ] || fail "an excluded failing script should not fail the run"
ran_calls $'ran test_a.sh\nran test_c.sh' "one exclusion"
expect_summary "script tests: 2 run, 0 failed, 1 excluded: test_b.sh" "one exclusion"

run_runner "$runner" --exclude test_a.sh --exclude test_c.sh "$mixed"
[ "$status" != 0 ] || fail "exclusions should not hide a failing script that still runs"
ran_calls "ran test_b.sh" "two exclusions"
expect_summary "script tests: 1 run, 1 failed, 2 excluded: test_a.sh test_c.sh" "two exclusions"

for unmatched in test_absent.sh helper.sh test_nested.sh lib/test_nested.sh 'test_*.sh' ''; do
    run_runner "$runner" --exclude test_b.sh --exclude "$unmatched" "$mixed"
    [ "$status" != 0 ] || fail "excluding '$unmatched', which names no test, should fail"
    ran_calls "" "unmatched '$unmatched'"
    grep -qF "no test named '$unmatched'" "$work/output" || fail "the unmatched name '$unmatched' should be named"
done

run_runner "$runner" --exclude test_a.sh --exclude test_b.sh "$passing"
[ "$status" != 0 ] || fail "excluding every test should fail"
expect_summary "script tests: 0 run, 0 failed, 2 excluded: test_a.sh test_b.sh" "everything excluded"

run_runner "$runner" --exclude
[ "$status" != 0 ] || fail "--exclude without a name should fail"
ran_calls "" "missing name"

run_runner "$runner" --skip test_a.sh "$passing"
[ "$status" != 0 ] || fail "an unknown option should fail"
ran_calls "" "unknown option"

run_runner "$copy/run-script-tests.sh" --exclude test_default.sh
[ "$status" != 0 ] || fail "excluding the only default test should fail"
expect_summary "script tests: 0 run, 0 failed, 1 excluded: test_default.sh" "exclusion in the default folder"

echo "script test runner tests passed"
