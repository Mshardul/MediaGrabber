#!/usr/bin/env bash
# Tests for sandbox.sh — run: scripts/tests/test_sandbox.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SANDBOX_LIB="$SCRIPT_DIR/lib/sandbox.sh"
work="$(mktemp -d)"

# shellcheck source=scripts/tests/lib/sandbox.sh
source "$SANDBOX_LIB"
trap 'sandbox_cleanup; /bin/rm -rf "$work"' EXIT

fail() {
    echo "FAIL: $1" >&2
    exit 1
}
ok() { echo "ok - $1"; }

echo "=== Testing sandbox_init ==="
sandbox_init

[ -d "$SANDBOX_HOME" ] || fail "SANDBOX_HOME not created"
[ -d "$SANDBOX_APPS" ] || fail "SANDBOX_APPS not created"
[ -d "$SANDBOX_BIN" ] || fail "SANDBOX_BIN not created"
[ "$HOME" = "$SANDBOX_HOME" ] || fail "HOME not set to SANDBOX_HOME"
ok "temporary HOME and apps folder created"

echo "=== Testing failing stubs ==="
for cmd in git gh curl osascript open mdfind ditto pkill killall pgrep make mise xcodebuild; do
    if "$cmd" >/dev/null 2>&1; then
        fail "$cmd should fail but succeeded"
    fi
    ok "$cmd fails as expected"
done

echo "=== Testing kill builtin override ==="
if kill -TERM 12345 >/dev/null 2>&1; then
    fail "kill should fail but succeeded"
fi
ok "kill fails as expected"

echo "=== Testing MG_LSREGISTER fails by default ==="
if "$MG_LSREGISTER" >/dev/null 2>&1; then
    fail "MG_LSREGISTER should fail but succeeded"
fi
ok "MG_LSREGISTER fails as expected"

echo "=== Testing sandbox_fake ==="
sandbox_fake "lsregister" $'#!/usr/bin/env bash\necho "faked lsregister"'
if ! "$MG_LSREGISTER" | grep -q "faked lsregister"; then
    fail "sandbox_fake did not work for lsregister"
fi
ok "sandbox_fake works for lsregister"

echo "=== Testing sandbox_fake_function ==="
sandbox_fake_function "custom_cmd" 'echo "faked function"'
if ! custom_cmd | grep -q "faked function"; then
    fail "sandbox_fake_function did not work"
fi
ok "sandbox_fake_function works"

echo "=== Testing sandbox_allow_real ==="
sandbox_allow_real "cat"
if ! "$SANDBOX_BIN/cat" "$SANDBOX_LIB" | head -1 | grep -q "#!/usr/bin/env bash"; then
    fail "sandbox_allow_real did not work"
fi
ok "sandbox_allow_real works"
sandbox_allow_real "make"
"$SANDBOX_BIN/make" --version >/dev/null 2>&1 || fail "sandbox_allow_real did not replace the make stub"
ok "sandbox_allow_real replaces a stub"

echo "=== Testing MG_APPLICATIONS_DIR default ==="
[ "$MG_APPLICATIONS_DIR" = "$SANDBOX_APPS" ] || fail "MG_APPLICATIONS_DIR not set to sandbox apps"
ok "MG_APPLICATIONS_DIR defaults to sandbox apps"

echo "=== Testing a second sandbox is independent ==="
first_dir="$SANDBOX_DIR"
sandbox_fake "only-in-first" $'#!/usr/bin/env bash\nexit 0'
sandbox_init
[ "$MG_APPLICATIONS_DIR" = "$SANDBOX_APPS" ] || fail "MG_APPLICATIONS_DIR kept from the first sandbox"
[ "$MG_LSREGISTER" = "$SANDBOX_BIN/lsregister" ] || fail "MG_LSREGISTER kept from the first sandbox"
if command -v only-in-first >/dev/null 2>&1; then
    fail "a fake from the first sandbox is still on PATH"
fi
ok "second sandbox starts clean"

echo "=== Testing sandbox_repo ==="
sandbox_repo scripts/tests/lib/sandbox.sh
cmp -s "$SANDBOX_REPO/scripts/tests/lib/sandbox.sh" "$SANDBOX_LIB" || fail "file not copied into the sandbox repo"
case "$SANDBOX_REPO" in
"$SANDBOX_DIR"/*) ;;
*) fail "sandbox repo is outside the sandbox" ;;
esac
ok "sandbox_repo copies files into the sandbox"

echo "=== Testing sandbox_cleanup ==="
second_dir="$SANDBOX_DIR"
sandbox_fake "rm" $'#!/usr/bin/env bash\nexit 1'
sandbox_cleanup
[ ! -d "$first_dir" ] || fail "sandbox_cleanup left the first sandbox"
[ ! -d "$second_dir" ] || fail "sandbox_cleanup left the second sandbox"
ok "sandbox_cleanup removes every sandbox"

echo "=== Testing sandbox_init keeps the caller's exit trap ==="
marker="$work/trap-ran"
bash -c 'set -euo pipefail; source "$1"; trap "touch \"$2\"; sandbox_cleanup" EXIT; sandbox_init' _ "$SANDBOX_LIB" "$marker"
[ -f "$marker" ] || fail "sandbox_init replaced the caller's exit trap"
ok "caller's exit trap still runs"

echo ""
echo "All sandbox tests passed!"
exit 0
