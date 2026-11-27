#!/usr/bin/env bash
# Tests for replace-installed.sh — run: scripts/tests/test_replace_installed.sh

# shellcheck disable=SC2153
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPLACE_SCRIPT="$SCRIPT_DIR/../make/replace-installed.sh"
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

echo "=== Testing replace-installed.sh order of calls ==="

sandbox_init

fake_app="$work/fake_app.app"
mkdir -p "$fake_app/Contents/MacOS"
echo '#!/bin/sh' >"$fake_app/Contents/MacOS/MediaGrabber"
chmod +x "$fake_app/Contents/MacOS/MediaGrabber"

calls_log="$work/calls.log"
: >"$calls_log"

sandbox_fake "osascript" $'#!/usr/bin/env bash\necho "osascript called" >>"'"$calls_log"'"\necho "12345, 67890"\nexit 0'
sandbox_fake "killall" $'#!/usr/bin/env bash\necho "killall called" >>"'"$calls_log"'"\nexit 0'
# shellcheck disable=SC2016
sandbox_fake "pgrep" $'#!/usr/bin/env bash\necho "pgrep called" >>"'"$calls_log"'"\nexit 1'
# shellcheck disable=SC2016
sandbox_fake "ditto" $'#!/usr/bin/env bash\necho "ditto called with $*" >>"'"$calls_log"'"\nmkdir -p "$2"\nexit 0'
sandbox_fake "lsregister" $'#!/usr/bin/env bash\necho "lsregister called with $*" >>"'"$calls_log"'"\nexit 0'
sandbox_fake "open" $'#!/usr/bin/env bash\necho "open called with $*" >>"'"$calls_log"'"\nexit 0'
sandbox_fake "make" $'#!/usr/bin/env bash\necho "make called with $*" >>"'"$calls_log"'"\nexit 0'
sandbox_fake_function "kill" 'echo "kill called with $*" >>"'"$calls_log"'"'

export APP="$fake_app"
export CONFIG="Debug"
export DERIVED="$work/derived"
export MG_APPLICATIONS_DIR="$SANDBOX_APPS"
export MG_LSREGISTER="$SANDBOX_BIN/lsregister"

mkdir -p "$DERIVED/Build/Products/Debug"

if ! bash "$REPLACE_SCRIPT" >"$work/output" 2>&1; then
    fail "replace-installed.sh failed: $(cat "$work/output")"
fi

last_line=0
for expected in "osascript called" "kill called with -9 12345 67890" "killall called" "pgrep called" \
    "ditto called with $fake_app $SANDBOX_APPS/MediaGrabber.app" "lsregister called with -f" \
    "make called with --no-print-directory drop-build-app DERIVED=$DERIVED" "open called with"; do
    line="$(grep -n -m1 -F -- "$expected" "$calls_log" | cut -d: -f1 || true)"
    [ -n "$line" ] || fail "missing call: $expected"
    [ "$line" -gt "$last_line" ] || fail "call out of order: $expected"
    last_line="$line"
done
ok "all commands called in order"

echo "=== Testing missing build product exits non-zero ==="
sandbox_init
export APP="$work/missing.app"
export CONFIG="Debug"
export DERIVED="$work/derived2"
export MG_APPLICATIONS_DIR="$SANDBOX_APPS"
export MG_LSREGISTER="$SANDBOX_BIN/lsregister"
mkdir -p "$DERIVED/Build/Products/Debug"

if bash "$REPLACE_SCRIPT" >"$work/output2" 2>&1; then
    fail "replace-installed.sh should fail with missing build product"
fi
grep -q "build product missing" "$work/output2" || fail "error message not found"
ok "missing build product fails with correct message"

echo "=== Testing failed removal exits non-zero ==="
sandbox_init
fake_app2="$work/fake_app2.app"
mkdir -p "$fake_app2/Contents/MacOS"
echo '#!/bin/sh' >"$fake_app2/Contents/MacOS/MediaGrabber"
chmod +x "$fake_app2/Contents/MacOS/MediaGrabber"

calls_log="$work/calls3.log"
: >"$calls_log"

sandbox_fake "osascript" $'#!/usr/bin/env bash\necho "12345, 67890"\nexit 0'
sandbox_fake "killall" $'#!/usr/bin/env bash\nexit 0'
sandbox_fake "pgrep" $'#!/usr/bin/env bash\nexit 1'
sandbox_fake "rm" $'#!/usr/bin/env bash\necho "rm called with $*" >>"'"$calls_log"'"\nexit 1'
sandbox_fake "ditto" $'#!/usr/bin/env bash\nexit 0'
sandbox_fake "lsregister" $'#!/usr/bin/env bash\nexit 0'
sandbox_fake "open" $'#!/usr/bin/env bash\nexit 0'
sandbox_fake_function "kill" 'return 0'

export APP="$fake_app2"
export CONFIG="Debug"
export DERIVED="$work/derived3"
export MG_APPLICATIONS_DIR="$SANDBOX_APPS"
export MG_LSREGISTER="$SANDBOX_BIN/lsregister"
mkdir -p "$DERIVED/Build/Products/Debug"

if bash "$REPLACE_SCRIPT" >"$work/output3" 2>&1; then
    fail "replace-installed.sh should fail when removal fails"
fi
grep -q "could not remove" "$work/output3" || fail "error message not found"
ok "failed removal exits non-zero"

echo "=== Testing an absolute DERIVED is used as given ==="
sandbox_init
sandbox_repo scripts/make

absolute="$work/absolute-derived"
mkdir -p "$absolute/Build/Products/Debug/MediaGrabber.app"
calls_log="$work/calls4.log"
: >"$calls_log"

sandbox_fake "osascript" $'#!/usr/bin/env bash\nexit 0'
sandbox_fake "killall" $'#!/usr/bin/env bash\nexit 0'
sandbox_fake "pgrep" $'#!/usr/bin/env bash\nexit 1'
sandbox_fake "ditto" $'#!/usr/bin/env bash\necho "ditto called with $*" >>"'"$calls_log"'"\nexit 0'
sandbox_fake "lsregister" $'#!/usr/bin/env bash\nexit 0'
sandbox_fake "open" $'#!/usr/bin/env bash\nexit 0'
sandbox_fake "make" $'#!/usr/bin/env bash\nexit 0'

unset APP
DERIVED="$absolute" bash "$SANDBOX_REPO/scripts/make/replace-installed.sh" >"$work/output4" 2>&1 ||
    fail "replace-installed.sh failed: $(cat "$work/output4")"
grep -q -F "ditto called with $absolute/Build/Products/Debug/MediaGrabber.app " "$calls_log" ||
    fail "wrong build product copied: $(cat "$calls_log")"
ok "absolute DERIVED is installed from"

echo ""
echo "All replace-installed.sh tests passed!"
exit 0
