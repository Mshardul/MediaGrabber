#!/usr/bin/env bash
# Runs a copy of the script against fake interpreters, so no venv is made and nothing is downloaded.

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

SCRIPT="$PWD/scripts/make/venv.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
ROOT=""
BIN=""

fail() {
    echo "FAIL: $1" >&2
    cat "$WORK/output" >&2
    exit 1
}

fake_python() {
    cat >"$1" <<FAKE
#!/bin/bash
if [ "\$1" = -c ]; then
    echo "$2"
    exit 0
fi
[ "\$*" = "-m venv .venv" ] || exit 64
echo "create with $2" >>"$WORK/calls"
mkdir -p .venv/bin
cp "$WORK/made-python" .venv/bin/python
cp "$WORK/made-pip" .venv/bin/pip
FAKE
    chmod +x "$1"
}

# Each case gets a folder of its own, so nothing is left over from the one before.
new_root() {
    local case_dir
    case_dir="$(mktemp -d "$WORK/case.XXXXXX")"
    ROOT="$case_dir/root"
    BIN="$case_dir/bin"
    : >"$WORK/calls"
    mkdir -p "$ROOT/scripts/make" "$BIN"
    cp "$SCRIPT" "$ROOT/scripts/make/venv.sh"
    echo 3.14 >"$ROOT/.python-version"
    for tool in bash cat cp dirname mkdir; do
        ln -s "$(command -v "$tool")" "$BIN/$tool"
    done
    cat >"$WORK/made-pip" <<FAKE
#!/bin/bash
echo "pip \$*" >>"$WORK/calls"
exit \${PIP_STATUS:-0}
FAKE
    chmod +x "$WORK/made-pip"
    fake_python "$WORK/made-python" 3.14
}

existing_venv() {
    mkdir -p "$ROOT/.venv/bin"
    fake_python "$ROOT/.venv/bin/python" "$1"
    cp "$WORK/made-pip" "$ROOT/.venv/bin/pip"
    echo kept >"$ROOT/.venv/marker"
}

# The closed PATH keeps every real Python out of reach.
run_script() {
    status=0
    (cd "$BIN" && PATH="$BIN" "$BIN/bash" "$ROOT/scripts/make/venv.sh") >"$WORK/output" 2>&1 || status=$?
}

expect_calls() {
    [ "$(cat "$WORK/calls")" = "$1" ] || fail "$2: calls were: $(cat "$WORK/calls")"
}

expect_output() {
    case "$(cat "$WORK/output")" in
    *"$1"*) ;;
    *) fail "$2: no '$1' in the output" ;;
    esac
}

new_root
fake_python "$BIN/python3.14" 3.14
run_script
[ "$status" = 0 ] || fail "a new venv should be made"
expect_calls $'create with 3.14\npip install -r requirements.txt -r Tests/PluginTests/requirements.txt' "new venv"

new_root
run_script
[ "$status" != 0 ] || fail "a missing Python should fail"
expect_output "Python 3.14 is not installed" "missing Python"
expect_calls "" "missing Python"
[ ! -e "$ROOT/.venv" ] || fail "a missing Python should leave no venv"

new_root
fake_python "$BIN/python3" 3.14
run_script
[ "$status" != 0 ] || fail "another interpreter name must not stand in"
expect_calls "" "no fallback"

new_root
printf '#!/bin/bash\necho "pyenv: python3.14: command not found" >&2\nexit 127\n' >"$BIN/python3.14"
chmod +x "$BIN/python3.14"
run_script
[ "$status" != 0 ] || fail "a shim without an interpreter should fail"
expect_output "Python 3.14 is not installed" "empty shim"
expect_calls "" "empty shim"

new_root
existing_venv 3.14
run_script
[ "$status" = 0 ] || fail "a matching venv should be reused"
expect_calls "pip install -r requirements.txt -r Tests/PluginTests/requirements.txt" "matching venv"

new_root
fake_python "$BIN/python3.14" 3.14
existing_venv 3.15
run_script
[ "$status" != 0 ] || fail "a venv with another version should fail"
expect_output ".venv uses Python 3.15, but .python-version asks for 3.14" "wrong version"
expect_calls "" "wrong version"
[ -f "$ROOT/.venv/marker" ] || fail "a venv with another version must be left alone"

new_root
fake_python "$BIN/python3.14" 3.14
mkdir -p "$ROOT/.venv"
run_script
[ "$status" != 0 ] || fail "a venv without Python should fail"
expect_output ".venv has no working Python" "empty venv"
expect_calls "" "empty venv"

new_root
fake_python "$BIN/python3.14" 3.14
mv "$ROOT/.python-version" "$ROOT/set-aside"
run_script
[ "$status" != 0 ] || fail "a missing .python-version should fail"
expect_output ".python-version" "missing pin"
expect_calls "" "missing pin"

new_root
existing_venv 3.14
PIP_STATUS=9 run_script
[ "$status" = 9 ] || fail "a failed install should keep its exit status, got $status"

echo "venv tests passed"
