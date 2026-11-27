#!/usr/bin/env bash
# Tests for help.sh and make help — run: scripts/tests/test_make_help.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELP_SCRIPT="$SCRIPT_DIR/../make/help.sh"
MAKEFILE="$SCRIPT_DIR/../../Makefile"
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

echo "=== Testing help.sh output ==="

sandbox_init

output="$work/help_output.txt"
bash "$HELP_SCRIPT" "$MAKEFILE" >"$output"

grep -q "Available targets:" "$output" || fail "header not found"
grep -q "fix" "$output" || fail "fix target not listed"
grep -q "check" "$output" || fail "check target not listed"
grep -q "build" "$output" || fail "build target not listed"
grep -q "install" "$output" || fail "install target not listed"
grep -q "run" "$output" || fail "run target not listed"
grep -q "test" "$output" || fail "test target not listed"
grep -q "e2e" "$output" || fail "e2e target not listed"
grep -q "release" "$output" || fail "release target not listed"
ok "help.sh lists all expected targets"

echo "=== Testing make help ==="

sandbox_init

output="$work/make_help_output.txt"
sandbox_allow_real make
cd "$(dirname "$MAKEFILE")"
make help >"$output" 2>&1

grep -q "Available targets:" "$output" || fail "make help header not found"
grep -q "fix" "$output" || fail "make help fix target not listed"
grep -q "check" "$output" || fail "make help check target not listed"
grep -q "build" "$output" || fail "make help build target not listed"
grep -q "install" "$output" || fail "make help install target not listed"
grep -q "run" "$output" || fail "make help run target not listed"
grep -q "test" "$output" || fail "make help test target not listed"
grep -q "e2e" "$output" || fail "make help e2e target not listed"
grep -q "release" "$output" || fail "make help release target not listed"
ok "make help lists all expected targets"

echo "=== Testing all public targets have descriptions ==="

sandbox_init

# Succeeds only when help describes every target in the given Makefile.
all_described() {
    bash "$HELP_SCRIPT" "$1" >"$work/described_output.txt"
    ! grep -F "(no description)" "$work/described_output.txt"
}

cat >"$work/test_makefile" <<'EOF'
## This has a description
target_with_desc:
	@echo "with desc"

target_without_desc:
	@echo "without desc"
EOF

output="$work/test_help_output.txt"
bash "$HELP_SCRIPT" "$work/test_makefile" >"$output"
grep -q "target_with_desc .*This has a description" "$output" || fail "description not shown: $(cat "$output")"
grep -q "target_without_desc .*(no description)" "$output" || fail "missing description not flagged"
ok "described and undescribed targets are told apart"

all_described "$MAKEFILE" || fail "a public target in the Makefile has no description"
ok "every public target in the Makefile has a description"

cp "$MAKEFILE" "$work/undocumented_makefile"
printf '\nundocumented:\n\t@true\n' >>"$work/undocumented_makefile"
if all_described "$work/undocumented_makefile" >/dev/null; then
    fail "a new target without a description was not caught"
fi
ok "a new target without a description is caught"

echo ""
echo "All help.sh and make help tests passed!"
exit 0
