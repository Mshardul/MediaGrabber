#!/usr/bin/env bash
# Tests for drop-build-app.sh — run: scripts/tests/test_drop_build_app.sh

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

new_sandbox() {
    sandbox_init
    sandbox_repo scripts/make
    REPO_ROOT="$SANDBOX_REPO"
    DROP_SCRIPT="$REPO_ROOT/scripts/make/drop-build-app.sh"
}

make_rm_wrapper() {
    local log_file="$1"
    cat >"$SANDBOX_BIN/rm" <<EOF
#!/usr/bin/env bash
echo "rm called with \$*" >>"$log_file"
exec /bin/rm "\$@"
EOF
    chmod +x "$SANDBOX_BIN/rm"
}

echo "=== Testing drop-build-app.sh removes both Debug and Release ==="

new_sandbox

calls_log="$work/calls.log"
: >"$calls_log"

debug_app="$REPO_ROOT/build/Build/Products/Debug/MediaGrabber.app"
release_app="$REPO_ROOT/build/Build/Products/Release/MediaGrabber.app"
mkdir -p "$debug_app" "$release_app"

sandbox_fake "lsregister" $'#!/usr/bin/env bash\necho "lsregister called with $*" >>"'"$calls_log"'"\nexit 0'
make_rm_wrapper "$calls_log"

export DERIVED="build"
export MG_LSREGISTER="$SANDBOX_BIN/lsregister"
export APP_NAME="MediaGrabber"

cd "$REPO_ROOT"
if ! bash "$DROP_SCRIPT" >"$work/output" 2>&1; then
    fail "drop-build-app.sh failed: $(cat "$work/output")"
fi

calls="$(cat "$calls_log")"
echo "$calls" | grep -q "lsregister called with -u $debug_app" || fail "lsregister not called for Debug app"
echo "$calls" | grep -q "lsregister called with -u $release_app" || fail "lsregister not called for Release app"
echo "$calls" | grep -q "rm called with -rf $debug_app" || fail "rm not called for Debug app"
echo "$calls" | grep -q "rm called with -rf $release_app" || fail "rm not called for Release app"
ok "both Debug and Release apps removed"

[ ! -d "$debug_app" ] || fail "Debug app directory still exists"
[ ! -d "$release_app" ] || fail "Release app directory still exists"
ok "app directories actually removed"

echo "=== Testing missing build product removes nothing ==="
new_sandbox

calls_log="$work/calls2.log"
: >"$calls_log"

sandbox_fake "lsregister" $'#!/usr/bin/env bash\necho "lsregister called with $*" >>"'"$calls_log"'"\nexit 0'
make_rm_wrapper "$calls_log"

export DERIVED="build"
export MG_LSREGISTER="$SANDBOX_BIN/lsregister"
export APP_NAME="MediaGrabber"
mkdir -p "$REPO_ROOT/build/Build/Products/Debug"
mkdir -p "$REPO_ROOT/build/Build/Products/Release"

cd "$REPO_ROOT"
if ! bash "$DROP_SCRIPT" >"$work/output2" 2>&1; then
    fail "drop-build-app.sh failed: $(cat "$work/output2")"
fi

calls="$(cat "$calls_log")"
[ -z "$calls" ] || fail "no commands should be called when no apps exist"
ok "no commands called when apps missing"

echo "=== Testing failed lsregister does not stop removal ==="
new_sandbox

calls_log="$work/calls3.log"
: >"$calls_log"

debug_app3="$REPO_ROOT/build3/Build/Products/Debug/MediaGrabber.app"
mkdir -p "$debug_app3"

sandbox_fake "lsregister" $'#!/usr/bin/env bash\necho "lsregister called with $*" >>"'"$calls_log"'"\nexit 1'
make_rm_wrapper "$calls_log"

export DERIVED="build3"
export MG_LSREGISTER="$SANDBOX_BIN/lsregister"
export APP_NAME="MediaGrabber"
mkdir -p "$REPO_ROOT/build3/Build/Products/Debug"
mkdir -p "$REPO_ROOT/build3/Build/Products/Release"

cd "$REPO_ROOT"
if ! bash "$DROP_SCRIPT" >"$work/output3" 2>&1; then
    fail "drop-build-app.sh failed: $(cat "$work/output3")"
fi

calls="$(cat "$calls_log")"
echo "$calls" | grep -q "lsregister called with -u $debug_app3" || fail "lsregister called for Debug app"
echo "$calls" | grep -q "rm called with -rf $debug_app3" || fail "rm called for Debug app"
ok "removal continues even if lsregister fails"

echo "=== Testing failed removal exits non-zero ==="
new_sandbox

calls_log="$work/calls4.log"
: >"$calls_log"

debug_app4="$REPO_ROOT/build4/Build/Products/Debug/MediaGrabber.app"
mkdir -p "$debug_app4"

sandbox_fake "lsregister" $'#!/usr/bin/env bash\nexit 0'
cat >"$SANDBOX_BIN/rm" <<EOF
#!/usr/bin/env bash
echo "rm called with \$*" >>"$calls_log"
exit 1
EOF
chmod +x "$SANDBOX_BIN/rm"

export DERIVED="build4"
export MG_LSREGISTER="$SANDBOX_BIN/lsregister"
export APP_NAME="MediaGrabber"
mkdir -p "$REPO_ROOT/build4/Build/Products/Debug"
mkdir -p "$REPO_ROOT/build4/Build/Products/Release"

cd "$REPO_ROOT"
if bash "$DROP_SCRIPT" >"$work/output4" 2>&1; then
    fail "drop-build-app.sh should fail when removal fails"
fi
ok "failed removal exits non-zero"

echo "=== Testing an absolute DERIVED is used as given ==="
new_sandbox

absolute="$work/absolute-derived"
absolute_app="$absolute/Build/Products/Debug/MediaGrabber.app"
mkdir -p "$absolute_app"
sandbox_fake "lsregister" $'#!/usr/bin/env bash\nexit 0'

DERIVED="$absolute" bash "$DROP_SCRIPT" >"$work/output5" 2>&1 || fail "drop-build-app.sh failed: $(cat "$work/output5")"
[ ! -d "$absolute_app" ] || fail "app under an absolute DERIVED was left behind"
ok "absolute DERIVED is cleaned"

echo ""
echo "All drop-build-app.sh tests passed!"
exit 0
