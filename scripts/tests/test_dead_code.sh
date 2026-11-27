#!/usr/bin/env bash
# Tests for dead-code.sh — run: scripts/tests/test_dead_code.sh

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
    export DERIVED="build" APP_NAME="MediaGrabber" CONFIG="Debug"
    app="$SANDBOX_REPO/build/Build/Products/Debug/MediaGrabber.app"

    sandbox_fake "make" $'#!/usr/bin/env bash\necho "make $*" >>"'"$calls_log"'"\nexit 0'
    sandbox_fake "lsregister" $'#!/usr/bin/env bash\necho "lsregister $*" >>"'"$calls_log"'"\nexit 0'

    cat >"$SANDBOX_BIN/mise" <<'EOF'
#!/usr/bin/env bash
[ "$1 $2" = "exec --" ] || {
    echo "FAIL: mise not faked for $*" >&2
    exit 1
}
shift 2
exec "$@"
EOF

    cat >"$SANDBOX_BIN/xcodebuild" <<EOF
#!/usr/bin/env bash
echo "xcodebuild \$*" >>"$calls_log"
while [ \$# -gt 0 ]; do
    if [ "\$1" = "-derivedDataPath" ]; then
        mkdir -p "\$2/Index.noindex/DataStore" "\$2/Build/Products/Debug/MediaGrabber.app"
    fi
    shift
done
EOF
    chmod +x "$SANDBOX_BIN/xcodebuild"

    fake_periphery 'exit 0'
}

# The fake refuses an index path that the fake build did not create.
fake_periphery() {
    cat >"$SANDBOX_BIN/periphery" <<EOF
#!/usr/bin/env bash
echo "periphery \$*" >>"$calls_log"
args=("\$@")
while [ \$# -gt 0 ]; do
    if [ "\$1" = "--index-store-path" ] && [ ! -d "\$2" ]; then
        echo "no index store at \$2" >&2
        exit 1
    fi
    shift
done
$1
EOF
    chmod +x "$SANDBOX_BIN/periphery"
}

run_dead_code() {
    bash "$SANDBOX_REPO/scripts/make/dead-code.sh" >"$work/output" 2>&1
}

assert_app_removed() {
    [ ! -d "$app" ] || fail "built app still exists $1"
    grep -q -F -x "lsregister -u $app" "$calls_log" || fail "built app not unregistered $1"
}

echo "=== Testing dead-code.sh prepares, builds and scans ==="
new_sandbox
run_dead_code || fail "dead-code.sh failed: $(cat "$work/output")"

last_line=0
for expected in "make --no-print-directory tools generate" "xcodebuild " "periphery scan "; do
    line="$(grep -n -m1 -F -- "$expected" "$calls_log" | cut -d: -f1 || true)"
    [ -n "$line" ] || fail "missing call '$expected' in: $(cat "$calls_log")"
    [ "$line" -gt "$last_line" ] || fail "call out of order: $expected"
    last_line="$line"
done
grep -q "^xcodebuild .*-derivedDataPath $SANDBOX_REPO/build .*build-for-testing" "$calls_log" ||
    fail "app and tests not built into build/: $(cat "$calls_log")"
for flag in --skip-build --index-store-path --skip-schemes-validation --project --schemes; do
    grep -q -- "^periphery .*$flag" "$calls_log" || fail "$flag not passed to periphery"
done
ok "tools and project prepared, app and tests built, periphery given its options"

assert_app_removed "after success"
ok "built app removed and unregistered after success"

echo "=== Testing built app removed after periphery failure ==="
new_sandbox
fake_periphery 'exit 1'
if run_dead_code; then
    fail "dead-code.sh should fail when periphery fails"
fi
assert_app_removed "after periphery failure"
ok "built app removed after periphery failure"

echo "=== Testing built app removed after interrupt ==="
new_sandbox
ready="$SANDBOX_DIR/ready"
fake_periphery "touch '$ready'; exec sleep 30"
status=0
sandbox_interrupt "$ready" bash "$SANDBOX_REPO/scripts/make/dead-code.sh" >"$work/output" 2>&1 || status=$?
[ "$status" -eq 130 ] || fail "expected status 130 after Ctrl-C, got $status: $(cat "$work/output")"
assert_app_removed "after interrupt"
ok "built app removed after interrupt"

echo ""
echo "All dead-code.sh tests passed!"
