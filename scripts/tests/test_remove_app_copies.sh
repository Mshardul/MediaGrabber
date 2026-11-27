#!/usr/bin/env bash
# Tests for remove-app-copies.sh — run: scripts/tests/test_remove_app_copies.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REMOVE_SCRIPT="$SCRIPT_DIR/../remove-app-copies.sh"
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

make_rm_wrapper() {
    local log_file="$1"
    cat >"$SANDBOX_BIN/rm" <<EOF
#!/usr/bin/env bash
echo "rm called with \$*" >>"$log_file"
exec /bin/rm "\$@"
EOF
    chmod +x "$SANDBOX_BIN/rm"
}

make_failing_rm() {
    local log_file="$1"
    cat >"$SANDBOX_BIN/rm" <<EOF
#!/usr/bin/env bash
echo "rm called with \$*" >>"$log_file"
exit 1
EOF
    chmod +x "$SANDBOX_BIN/rm"
}

echo "=== Testing remove-app-copies.sh order of calls ==="

sandbox_init

calls_log="$work/calls.log"
: >"$calls_log"

app1="$SANDBOX_APPS/MediaGrabber.app"
app2="$SANDBOX_HOME/Applications/MediaGrabber.app"
mkdir -p "$app1" "$app2"

sandbox_fake "pkill" $'#!/usr/bin/env bash\necho "pkill called with $*" >>"'"$calls_log"'"\nexit 0'
sandbox_fake "mdfind" $'#!/usr/bin/env bash\necho "mdfind called with $*" >>"'"$calls_log"'"\nprintf "'"$app1"'\n'"$app2"'\n"\nexit 0'
sandbox_fake "find" $'#!/usr/bin/env bash\necho "find called with $*" >>"'"$calls_log"'"\nexit 0'
sandbox_fake "lsregister" $'#!/usr/bin/env bash\necho "lsregister called with $*" >>"'"$calls_log"'"\nexit 0'
make_rm_wrapper "$calls_log"

export MG_APPLICATIONS_DIR="$SANDBOX_APPS"
export MG_LSREGISTER="$SANDBOX_BIN/lsregister"

if ! bash "$REMOVE_SCRIPT" >"$work/output" 2>&1; then
    fail "remove-app-copies.sh failed: $(cat "$work/output")"
fi

calls="$(cat "$calls_log")"
echo "$calls" | grep -q "pkill called with -9 -x MediaGrabber" || fail "pkill not called for MediaGrabber"
echo "$calls" | grep -q "pkill called with -9 -f MediaGrabber" || fail "pkill not called for helper"
echo "$calls" | grep -q "mdfind called" || fail "mdfind not called"
echo "$calls" | grep -q "lsregister called with -u $app1" || fail "lsregister not called for app1"
echo "$calls" | grep -q "lsregister called with -u $app2" || fail "lsregister not called for app2"
echo "$calls" | grep -q "rm called with -rf $app1" || fail "rm not called for app1"
echo "$calls" | grep -q "rm called with -rf $app2" || fail "rm not called for app2"
ok "all commands called in order"

[ ! -d "$app1" ] || fail "app1 still exists"
[ ! -d "$app2" ] || fail "app2 still exists"
ok "app directories actually removed"

echo "=== Testing --keep option preserves specified app ==="
sandbox_init

calls_log="$work/calls2.log"
: >"$calls_log"

keep_app="$SANDBOX_APPS/MediaGrabber.app"
other_app="$SANDBOX_HOME/Applications/MediaGrabber.app"
mkdir -p "$keep_app" "$other_app"

sandbox_fake "pkill" $'#!/usr/bin/env bash\necho "pkill called with $*" >>"'"$calls_log"'"\nexit 0'
sandbox_fake "mdfind" $'#!/usr/bin/env bash\necho "mdfind called with $*" >>"'"$calls_log"'"\nprintf "'"$keep_app"'\n'"$other_app"'\n"\nexit 0'
sandbox_fake "find" $'#!/usr/bin/env bash\necho "find called with $*" >>"'"$calls_log"'"\nexit 0'
sandbox_fake "lsregister" $'#!/usr/bin/env bash\necho "lsregister called with $*" >>"'"$calls_log"'"\nexit 0'
make_rm_wrapper "$calls_log"

export MG_APPLICATIONS_DIR="$SANDBOX_APPS"
export MG_LSREGISTER="$SANDBOX_BIN/lsregister"

if ! bash "$REMOVE_SCRIPT" --keep "$keep_app" >"$work/output2" 2>&1; then
    fail "remove-app-copies.sh failed: $(cat "$work/output2")"
fi

calls="$(cat "$calls_log")"
echo "$calls" | grep -q "rm called with -rf $other_app" || fail "rm not called for other app"
if echo "$calls" | grep -q "rm called with -rf $keep_app"; then
    fail "rm should not be called for kept app"
fi
ok "--keep option preserves specified app"

[ -d "$keep_app" ] || fail "kept app was removed"
[ ! -d "$other_app" ] || fail "other app not removed"
ok "kept app directory preserved"

echo "=== Testing failed removal exits non-zero ==="
sandbox_init

calls_log="$work/calls3.log"
: >"$calls_log"

app3="$SANDBOX_APPS/MediaGrabber.app"
mkdir -p "$app3"

sandbox_fake "pkill" $'#!/usr/bin/env bash\nexit 0'
sandbox_fake "mdfind" $'#!/usr/bin/env bash\nprintf "'"$app3"'\n"\nexit 0'
sandbox_fake "find" $'#!/usr/bin/env bash\nexit 0'
sandbox_fake "lsregister" $'#!/usr/bin/env bash\nexit 0'
make_failing_rm "$calls_log"

export MG_APPLICATIONS_DIR="$SANDBOX_APPS"
export MG_LSREGISTER="$SANDBOX_BIN/lsregister"

if bash "$REMOVE_SCRIPT" >"$work/output3" 2>&1; then
    fail "remove-app-copies.sh should fail when removal fails"
fi
ok "failed removal exits non-zero"

echo "=== Testing Trash and Volumes are skipped ==="
sandbox_init

calls_log="$work/calls4.log"
: >"$calls_log"

trash_app="$SANDBOX_HOME/.Trash/MediaGrabber.app"
vol_app="/Volumes/External/MediaGrabber.app"
real_app="$SANDBOX_APPS/MediaGrabber.app"
mkdir -p "$trash_app" "$real_app"

sandbox_fake "pkill" $'#!/usr/bin/env bash\nexit 0'
sandbox_fake "mdfind" $'#!/usr/bin/env bash\nprintf "'"$trash_app"'\n'"$vol_app"'\n'"$real_app"'\n"\nexit 0'
sandbox_fake "find" $'#!/usr/bin/env bash\nexit 0'
sandbox_fake "lsregister" $'#!/usr/bin/env bash\nexit 0'
make_rm_wrapper "$calls_log"

export MG_APPLICATIONS_DIR="$SANDBOX_APPS"
export MG_LSREGISTER="$SANDBOX_BIN/lsregister"

if ! bash "$REMOVE_SCRIPT" >"$work/output4" 2>&1; then
    fail "remove-app-copies.sh failed: $(cat "$work/output4")"
fi

calls="$(cat "$calls_log")"
if echo "$calls" | grep -q "rm called with -rf $trash_app"; then
    fail "Trash app should be skipped"
fi
if echo "$calls" | grep -q "rm called with -rf $vol_app"; then
    fail "Volumes app should be skipped"
fi
echo "$calls" | grep -q "rm called with -rf $real_app" || fail "real app should be removed"
ok "Trash and Volumes paths are skipped"

echo ""
echo "All remove-app-copies.sh tests passed!"
exit 0
