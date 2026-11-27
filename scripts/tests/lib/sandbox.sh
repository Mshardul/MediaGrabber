#!/usr/bin/env bash
# Sandbox for script tests: temporary HOME, apps folder, and failing stubs for risky commands.

set -euo pipefail

SANDBOX_SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SANDBOX_REAL_PATH="$PATH"
SANDBOX_DIRS=()

sandbox_init() {
    # Fakes left over from an earlier sandbox must not answer in this one.
    export PATH="$SANDBOX_REAL_PATH"

    local sandbox_dir
    sandbox_dir="$(cd "$(mktemp -d)" && pwd -P)"
    SANDBOX_DIRS+=("$sandbox_dir")
    export SANDBOX_DIR="$sandbox_dir"
    export SANDBOX_HOME="$SANDBOX_DIR/home"
    export SANDBOX_APPS="$SANDBOX_DIR/apps"
    export SANDBOX_BIN="$SANDBOX_DIR/bin"
    export SANDBOX_REPO="$SANDBOX_DIR/repo"

    mkdir -p "$SANDBOX_HOME" "$SANDBOX_APPS" "$SANDBOX_BIN" "$SANDBOX_REPO"

    export HOME="$SANDBOX_HOME"
    export MG_APPLICATIONS_DIR="$SANDBOX_APPS"
    export MG_LSREGISTER="$SANDBOX_BIN/lsregister"

    local stubs=(git gh curl osascript open mdfind ditto pkill killall pgrep lsregister make mise xcodebuild)
    local cmd
    for cmd in "${stubs[@]}"; do
        cat >"$SANDBOX_BIN/$cmd" <<'EOF'
#!/usr/bin/env bash
echo "FAIL: $0 not faked" >&2
exit 1
EOF
        chmod +x "$SANDBOX_BIN/$cmd"
    done

    sandbox_fake_function kill 'echo "FAIL: kill not faked" >&2; return 1'

    export PATH="$SANDBOX_BIN:$PATH"
}

# The full path to rm is used because a test may have faked rm.
sandbox_cleanup() {
    local dir
    for dir in ${SANDBOX_DIRS[@]+"${SANDBOX_DIRS[@]}"}; do
        /bin/rm -rf "$dir"
    done
}

# Scripts find the repository from their own path, so a copy keeps every build folder in the sandbox.
sandbox_repo() {
    local file
    for file in "$@"; do
        /bin/mkdir -p "$SANDBOX_REPO/$(dirname "$file")"
        /bin/cp -Rp "$SANDBOX_SOURCE_ROOT/$file" "$SANDBOX_REPO/$(dirname "$file")/"
    done
}

# Sends Ctrl-C to the command's whole process group once the ready file exists.
sandbox_interrupt() {
    "$SANDBOX_SOURCE_ROOT/.venv/bin/python" -I -B "$SANDBOX_SOURCE_ROOT/scripts/tests/lib/interrupt.py" "$@"
}

sandbox_fake() {
    local name="$1"
    local body="$2"
    local path="$SANDBOX_BIN/$name"
    printf '%b\n' "$body" >"$path"
    chmod +x "$path"
}

sandbox_fake_function() {
    local name="$1"
    local body="$2"
    eval "$name() { $body; }"
    export -f "${name?}"
}

sandbox_allow_real() {
    local name="$1"
    local real_path
    real_path="$(
        PATH="$SANDBOX_REAL_PATH"
        command -v "$name" || true
    )"
    if [ -n "$real_path" ] && [ -x "$real_path" ]; then
        ln -sf "$real_path" "$SANDBOX_BIN/$name"
    fi
}
