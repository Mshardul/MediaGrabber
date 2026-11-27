#!/usr/bin/env bash
# Tests for e2e.sh — run: scripts/tests/test_e2e.sh

# shellcheck disable=SC2153
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SANDBOX_LIB="$SCRIPT_DIR/lib/sandbox.sh"

work="$(mktemp -d)"
# shellcheck source=lib/sandbox.sh
# shellcheck disable=SC1091,SC2153
source "$SANDBOX_LIB"
trap 'sandbox_cleanup; /bin/rm -rf "$work"' EXIT

fail() {
    echo "FAIL: $1" >&2
    exit 1
}
ok() { echo "ok - $1"; }

new_sandbox() {
    sandbox_init
    sandbox_repo scripts/make
    calls_log="$SANDBOX_DIR/calls.log"
    : >"$calls_log"
    sandbox_fake "make" $'#!/usr/bin/env bash\necho "make $*" >>"'"$calls_log"'"\nexit 0'
    sandbox_fake "sign-app.sh" $'#!/usr/bin/env bash\necho "sign-app.sh $*" >>"'"$calls_log"'"\nexit 0'
    sandbox_fake "run.sh" $'#!/usr/bin/env bash\necho "run.sh $*" >>"'"$calls_log"'"\nexit 0'
    export CONFIG="Release" DERIVED="build" APP_NAME="MediaGrabber"
    export SIGN_APP_SCRIPT="$SANDBOX_BIN/sign-app.sh" RUN_SCRIPT="$SANDBOX_BIN/run.sh"
}

make_app() {
    mkdir -p "$1/Build/Products/Release/MediaGrabber.app"
    app="$1/Build/Products/Release/MediaGrabber.app"
}

run_e2e() {
    bash "$SANDBOX_REPO/scripts/make/e2e.sh" >"$work/output" 2>&1
}

assert_calls_in_order() {
    local last=0 line expected
    for expected in "$@"; do
        line="$(grep -n -m1 -F -x -- "$expected" "$calls_log" | cut -d: -f1 || true)"
        [ -n "$line" ] || fail "missing call '$expected' in: $(cat "$calls_log")"
        [ "$line" -gt "$last" ] || fail "call out of order: $expected"
        last="$line"
    done
}

cleanup_call() { echo "make --no-print-directory drop-build-app DERIVED=$DERIVED"; }

echo "=== Testing e2e.sh builds, signs, runs and cleans up ==="
new_sandbox
make_app "$SANDBOX_REPO/build"
run_e2e || fail "e2e.sh failed: $(cat "$work/output")"
assert_calls_in_order "make build CONFIG=Release" "sign-app.sh $app -" "run.sh $app" "$(cleanup_call)"
ok "build, sign, run and cleanup called in order"

echo "=== Testing an absolute DERIVED is used as given ==="
new_sandbox
export DERIVED="$work/absolute-derived"
make_app "$DERIVED"
run_e2e || fail "e2e.sh failed: $(cat "$work/output")"
assert_calls_in_order "run.sh $app" "$(cleanup_call)"
ok "absolute DERIVED is run"

echo "=== Testing e2e.sh fails when app not found ==="
new_sandbox
if run_e2e; then
    fail "e2e.sh should fail when app not found"
fi
grep -q "app not found" "$work/output" || fail "error message not found: $(cat "$work/output")"
ok "missing app fails with correct message"

echo "=== Testing e2e.sh removes built app after failure ==="
new_sandbox
make_app "$SANDBOX_REPO/build"
sandbox_fake "sign-app.sh" $'#!/usr/bin/env bash\nexit 1'
if run_e2e; then
    fail "e2e.sh should fail when sign-app.sh fails"
fi
assert_calls_in_order "$(cleanup_call)"
ok "built app removed after sign-app.sh failure"

echo "=== Testing e2e.sh removes built app after interrupt ==="
new_sandbox
make_app "$SANDBOX_REPO/build"
ready="$SANDBOX_DIR/ready"
sandbox_fake "run.sh" $'#!/usr/bin/env bash\ntouch "'"$ready"'"\nexec sleep 30'
status=0
sandbox_interrupt "$ready" bash "$SANDBOX_REPO/scripts/make/e2e.sh" >"$work/output" 2>&1 || status=$?
[ "$status" -eq 130 ] || fail "expected status 130 after Ctrl-C, got $status: $(cat "$work/output")"
assert_calls_in_order "$(cleanup_call)"
ok "built app removed after interrupt"

echo ""
echo "All e2e.sh tests passed!"
