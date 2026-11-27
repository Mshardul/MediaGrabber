#!/usr/bin/env bash
# Tests for release.sh and release-dispatch.sh — run: scripts/tests/test_release_make.sh

# shellcheck disable=SC2153
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_SCRIPT="$SCRIPT_DIR/../make/release.sh"
DISPATCH_SCRIPT="$SCRIPT_DIR/../make/release-dispatch.sh"
SANDBOX_LIB="$SCRIPT_DIR/lib/sandbox.sh"

work="$(mktemp -d)"

# shellcheck source=lib/sandbox.sh
# shellcheck disable=SC1091
source "$SANDBOX_LIB"
trap 'sandbox_cleanup; /bin/rm -rf "$work"' EXIT

fail() {
    echo "FAIL: $1" >&2
    exit 1
}
ok() { echo "ok - $1"; }

write_fake_sleep() {
    cat >"$SANDBOX_BIN/sleep" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "$SANDBOX_BIN/sleep"
}

write_fake_git() {
    cat >"$SANDBOX_BIN/git" <<'GITEOF'
#!/usr/bin/env bash
echo "git $*" >>"$FAKE_GIT_LOG"
case "$1" in
    diff)
        [ "${FAKE_GIT_DIRTY:-0}" = 1 ] && exit 1
        exit 0
        ;;
    rev-parse)
        if [[ "$*" == *"--abbrev-ref HEAD"* ]]; then
            echo "${FAKE_GIT_BRANCH:-main}"
        elif [[ "$*" == *"origin/main"* ]]; then
            echo "${FAKE_GIT_ORIGIN_SHA:-same-sha}"
        elif [[ "$*" == *"HEAD"* ]]; then
            if [ "${FAKE_GIT_DIVERGED:-0}" = 1 ]; then
                echo "local-sha"
            else
                echo "${FAKE_GIT_ORIGIN_SHA:-same-sha}"
            fi
        fi
        ;;
    fetch)
        ;;
    tag)
        if [[ "$*" == *"--list"* ]]; then
            printf '%b\n' "${FAKE_GIT_TAGS:-v1.0.0}"
        elif [[ "$*" == *"-a"* ]]; then
            for arg in "$@"; do
                if [[ "$arg" == v* ]]; then
                    echo "TAGGED:$arg" >>"$FAKE_GIT_LOG"
                fi
            done
        fi
        ;;
    push)
        for arg in "$@"; do
            if [[ "$arg" == v* ]]; then
                echo "PUSHED:$arg" >>"$FAKE_GIT_LOG"
            fi
        done
        ;;
esac
GITEOF
    chmod +x "$SANDBOX_BIN/git"
}

write_fake_gh() {
    cat >"$SANDBOX_BIN/gh" <<'GHEOF'
#!/usr/bin/env bash
echo "gh $*" >>"$FAKE_GH_LOG"
case "$1" in
    workflow)
        exit 0
        ;;
    run)
        if [[ "$2" == "list" ]]; then
            mode="${FAKE_GH_LIST_MODE:-found}"
            if [ "$mode" = broken ]; then
                echo "HTTP 502: Bad Gateway" >&2
                exit 1
            elif [ "$mode" = flaky ]; then
                n="$(cat "$SANDBOX_DIR/gh_count" 2>/dev/null || echo 0)"
                n=$((n + 1))
                echo "$n" >"$SANDBOX_DIR/gh_count"
                if [ "$n" -lt 3 ]; then
                    echo "HTTP 502: Bad Gateway" >&2
                    exit 1
                fi
                echo '[{"databaseId": 12345, "event": "workflow_dispatch", "createdAt": "2026-01-01T00:00:00Z"}]'
            elif [ "$mode" = empty ]; then
                echo ""
            elif [ "$mode" = retry ]; then
                n="$(cat "$SANDBOX_DIR/gh_count" 2>/dev/null || echo 0)"
                n=$((n + 1))
                echo "$n" >"$SANDBOX_DIR/gh_count"
                if [ "$n" -ge 3 ]; then
                    echo '[{"databaseId": 12345, "event": "workflow_dispatch", "createdAt": "2026-01-01T00:00:00Z"}]'
                else
                    echo ""
                fi
            else
                echo '[{"databaseId": 12345, "event": "workflow_dispatch", "createdAt": "2026-01-01T00:00:00Z"}]'
            fi
        elif [[ "$2" == "watch" ]]; then
            if [ "${FAKE_GH_WATCH_FAIL:-0}" = 1 ]; then
                exit 1
            fi
            exit 0
        fi
        ;;
esac
GHEOF
    chmod +x "$SANDBOX_BIN/gh"
}

gh_calls() { grep -c '^gh ' "$1" 2>/dev/null || true; }
git_tagged() { grep -c '^TAGGED:' "$1" 2>/dev/null || true; }

reset_scenario() {
    unset FAKE_GIT_DIRTY FAKE_GIT_BRANCH FAKE_GIT_DIVERGED FAKE_GIT_TAGS
    unset FAKE_GH_LIST_MODE FAKE_GH_WATCH_FAIL
}

echo "=== release.sh: no bump argument calls nothing ==="
sandbox_init
reset_scenario
write_fake_sleep
write_fake_git
write_fake_gh
export FAKE_GIT_LOG="$work/git0.log"
export FAKE_GH_LOG="$work/gh0.log"
: >"$FAKE_GIT_LOG"
: >"$FAKE_GH_LOG"
output="$work/out0.txt"
if bash "$RELEASE_SCRIPT" >"$output" 2>&1; then
    fail "release.sh should fail without a bump argument"
fi
grep -q "pick one: make release-patch" "$output" || fail "missing pick-one message: $(cat "$output")"
[ "$(gh_calls "$FAKE_GH_LOG")" -eq 0 ] || fail "gh called without a bump argument"
ok "release.sh fails without a bump argument before any gh call"

echo "=== release.sh: dirty tree stops before any gh call ==="
sandbox_init
reset_scenario
write_fake_sleep
write_fake_git
write_fake_gh
export FAKE_GIT_LOG="$work/git1.log"
export FAKE_GH_LOG="$work/gh1.log"
export FAKE_GIT_DIRTY=1
: >"$FAKE_GIT_LOG"
: >"$FAKE_GH_LOG"
output="$work/out1.txt"
if bash "$RELEASE_SCRIPT" patch >"$output" 2>&1; then
    fail "release.sh should fail on a dirty tree"
fi
grep -q "working tree dirty" "$output" || fail "missing dirty-tree message: $(cat "$output")"
[ "$(gh_calls "$FAKE_GH_LOG")" -eq 0 ] || fail "gh called on a dirty tree"
ok "release.sh stops on a dirty tree before any gh call"

echo "=== release.sh: wrong branch stops before any gh call ==="
sandbox_init
reset_scenario
write_fake_sleep
write_fake_git
write_fake_gh
export FAKE_GIT_LOG="$work/git2.log"
export FAKE_GH_LOG="$work/gh2.log"
export FAKE_GIT_BRANCH=develop
: >"$FAKE_GIT_LOG"
: >"$FAKE_GH_LOG"
output="$work/out2.txt"
if bash "$RELEASE_SCRIPT" patch >"$output" 2>&1; then
    fail "release.sh should fail on the wrong branch"
fi
grep -q "not on main" "$output" || fail "missing branch message: $(cat "$output")"
[ "$(gh_calls "$FAKE_GH_LOG")" -eq 0 ] || fail "gh called on the wrong branch"
ok "release.sh stops on the wrong branch before any gh call"

echo "=== release.sh: diverged branch stops before any gh call ==="
sandbox_init
reset_scenario
write_fake_sleep
write_fake_git
write_fake_gh
export FAKE_GIT_LOG="$work/git3.log"
export FAKE_GH_LOG="$work/gh3.log"
export FAKE_GIT_DIVERGED=1
: >"$FAKE_GIT_LOG"
: >"$FAKE_GH_LOG"
output="$work/out3.txt"
if bash "$RELEASE_SCRIPT" patch >"$output" 2>&1; then
    fail "release.sh should fail on a diverged branch"
fi
grep -q "local main != origin/main" "$output" || fail "missing diverged message: $(cat "$output")"
[ "$(gh_calls "$FAKE_GH_LOG")" -eq 0 ] || fail "gh called on a diverged branch"
ok "release.sh stops on a diverged branch before any gh call"

echo "=== release.sh: dry-run poll retries then succeeds ==="
sandbox_init
reset_scenario
write_fake_sleep
write_fake_git
write_fake_gh
export FAKE_GIT_LOG="$work/git4.log"
export FAKE_GH_LOG="$work/gh4.log"
export FAKE_GH_LIST_MODE=retry
: >"$FAKE_GIT_LOG"
: >"$FAKE_GH_LOG"
output="$work/out4.txt"
printf 'yes\ny\n' | bash "$RELEASE_SCRIPT" patch >"$output" 2>&1 || true
list_calls=$(grep -c 'gh run list' "$FAKE_GH_LOG" || true)
[ "$list_calls" -eq 3 ] || fail "expected 3 list calls before success, got $list_calls"
grep -q "pushed v1.0.1" "$output" || fail "retry did not reach success: $(cat "$output")"
ok "release.sh retries an empty lookup then proceeds"

echo "=== release.sh: dry-run poll stops after 30 tries ==="
sandbox_init
reset_scenario
write_fake_sleep
write_fake_git
write_fake_gh
export FAKE_GIT_LOG="$work/git5.log"
export FAKE_GH_LOG="$work/gh5.log"
export FAKE_GH_LIST_MODE=empty
: >"$FAKE_GIT_LOG"
: >"$FAKE_GH_LOG"
output="$work/out5.txt"
printf 'yes\ny\n' | bash "$RELEASE_SCRIPT" patch >"$output" 2>&1 || true
list_calls=$(grep -c 'gh run list' "$FAKE_GH_LOG" || true)
[ "$list_calls" -eq 30 ] || fail "expected 30 list calls, got $list_calls"
grep -q "no dry-run workflow found" "$output" || fail "missing no-workflow message: $(cat "$output")"
[ "$(git_tagged "$FAKE_GIT_LOG")" -eq 0 ] || fail "tag created after poll gave up"
ok "release.sh stops after 30 tries with no tag"

echo "=== release.sh: dry-run poll retries after a failed lookup ==="
sandbox_init
reset_scenario
write_fake_sleep
write_fake_git
write_fake_gh
export FAKE_GIT_LOG="$work/git14.log"
export FAKE_GH_LOG="$work/gh14.log"
export FAKE_GH_LIST_MODE=flaky
: >"$FAKE_GIT_LOG"
: >"$FAKE_GH_LOG"
output="$work/out15.txt"
printf 'yes\ny\n' | bash "$RELEASE_SCRIPT" patch >"$output" 2>&1 || true
grep -q "pushed v1.0.1" "$output" || fail "failed lookup ended the release: $(cat "$output")"
ok "release.sh retries a failed lookup then proceeds"

echo "=== release.sh: lookups that keep failing report the error ==="
sandbox_init
reset_scenario
write_fake_sleep
write_fake_git
write_fake_gh
export FAKE_GIT_LOG="$work/git15.log"
export FAKE_GH_LOG="$work/gh15.log"
export FAKE_GH_LIST_MODE=broken
: >"$FAKE_GIT_LOG"
: >"$FAKE_GH_LOG"
output="$work/out16.txt"
if printf 'yes\ny\n' | bash "$RELEASE_SCRIPT" patch >"$output" 2>&1; then
    fail "release.sh should fail when every lookup fails"
fi
list_calls=$(grep -c 'gh run list' "$FAKE_GH_LOG" || true)
[ "$list_calls" -eq 30 ] || fail "expected 30 list calls, got $list_calls"
grep -q "no dry-run workflow found" "$output" || fail "missing no-workflow message: $(cat "$output")"
grep -q "HTTP 502: Bad Gateway" "$output" || fail "last lookup error not shown: $(cat "$output")"
[ "$(git_tagged "$FAKE_GIT_LOG")" -eq 0 ] || fail "tag created after lookups failed"
ok "release.sh reports the last lookup error with no tag"

echo "=== release.sh: failed dry run stops without tagging ==="
sandbox_init
reset_scenario
write_fake_sleep
write_fake_git
write_fake_gh
export FAKE_GIT_LOG="$work/git6.log"
export FAKE_GH_LOG="$work/gh6.log"
export FAKE_GH_WATCH_FAIL=1
: >"$FAKE_GIT_LOG"
: >"$FAKE_GH_LOG"
output="$work/out6.txt"
printf 'yes\ny\n' | bash "$RELEASE_SCRIPT" patch >"$output" 2>&1 || true
grep -q "dry-run release failed" "$output" || fail "missing failed-dry-run message: $(cat "$output")"
[ "$(git_tagged "$FAKE_GIT_LOG")" -eq 0 ] || fail "tag created after a failed dry run"
ok "release.sh stops on a failed dry run without tagging"

echo "=== release.sh: any answer but yes creates no tag ==="
sandbox_init
reset_scenario
write_fake_sleep
write_fake_git
write_fake_gh
export FAKE_GIT_LOG="$work/git7.log"
export FAKE_GH_LOG="$work/gh7.log"
: >"$FAKE_GIT_LOG"
: >"$FAKE_GH_LOG"
output="$work/out7.txt"
printf 'no\n' | bash "$RELEASE_SCRIPT" patch >"$output" 2>&1 || true
grep -q "aborted" "$output" || fail "missing aborted message: $(cat "$output")"
[ "$(git_tagged "$FAKE_GIT_LOG")" -eq 0 ] || fail "tag created when answer was not yes"
ok "release.sh aborts when the first answer is not yes"

echo "=== release.sh: any answer but y creates no tag ==="
sandbox_init
reset_scenario
write_fake_sleep
write_fake_git
write_fake_gh
export FAKE_GIT_LOG="$work/git8.log"
export FAKE_GH_LOG="$work/gh8.log"
: >"$FAKE_GIT_LOG"
: >"$FAKE_GH_LOG"
output="$work/out8.txt"
printf 'yes\nn\n' | bash "$RELEASE_SCRIPT" patch >"$output" 2>&1 || true
grep -q "aborted" "$output" || fail "missing aborted message: $(cat "$output")"
[ "$(git_tagged "$FAKE_GIT_LOG")" -eq 0 ] || fail "tag created when answer was not y"
ok "release.sh aborts when the tag answer is not y"

echo "=== release.sh: success path tags then pushes vX.Y.Z ==="
sandbox_init
reset_scenario
write_fake_sleep
write_fake_git
write_fake_gh
export FAKE_GIT_LOG="$work/git9.log"
export FAKE_GH_LOG="$work/gh9.log"
export FAKE_GIT_TAGS='v0.1.0\nv0.2.0\nv1.0.0'
: >"$FAKE_GIT_LOG"
: >"$FAKE_GH_LOG"
output="$work/out9.txt"
printf 'yes\ny\n' | bash "$RELEASE_SCRIPT" patch >"$output" 2>&1 || true
grep -q '^TAGGED:v1.0.1$' "$FAKE_GIT_LOG" || fail "missing tag v1.0.1: $(cat "$FAKE_GIT_LOG")"
grep -q '^PUSHED:v1.0.1$' "$FAKE_GIT_LOG" || fail "missing push v1.0.1: $(cat "$FAKE_GIT_LOG")"
tag_line=$(grep -n '^TAGGED:' "$FAKE_GIT_LOG" | head -n1 | cut -d: -f1)
push_line=$(grep -n '^PUSHED:' "$FAKE_GIT_LOG" | head -n1 | cut -d: -f1)
[ "$tag_line" -lt "$push_line" ] || fail "tag was not recorded before push"
grep -q "pushed v1.0.1" "$output" || fail "missing success message: $(cat "$output")"
ok "release.sh tags then pushes vX.Y.Z on success"

echo "=== release-dispatch.sh: missing or bad VERSION calls nothing ==="
sandbox_init
reset_scenario
write_fake_gh
export FAKE_GH_LOG="$work/gh10.log"
: >"$FAKE_GH_LOG"
output="$work/out10.txt"
if bash "$DISPATCH_SCRIPT" dry-run >"$output" 2>&1; then
    fail "release-dispatch.sh should fail without VERSION"
fi
grep -q "VERSION=X.Y.Z required" "$output" || fail "missing VERSION-required message: $(cat "$output")"
[ "$(gh_calls "$FAKE_GH_LOG")" -eq 0 ] || fail "gh called without VERSION"
output="$work/out11.txt"
if VERSION="1.2" bash "$DISPATCH_SCRIPT" dry-run >"$output" 2>&1; then
    fail "release-dispatch.sh should fail with a bad VERSION"
fi
grep -q "VERSION must be N.N.N" "$output" || fail "missing bad-VERSION message: $(cat "$output")"
[ "$(gh_calls "$FAKE_GH_LOG")" -eq 0 ] || fail "gh called with a bad VERSION"
ok "release-dispatch.sh calls nothing without a valid VERSION"

echo "=== release-dispatch.sh: dry-run dispatches with dry_run=true ==="
sandbox_init
reset_scenario
write_fake_gh
export FAKE_GH_LOG="$work/gh11.log"
: >"$FAKE_GH_LOG"
VERSION="2.0.0" bash "$DISPATCH_SCRIPT" dry-run >"$work/out12.txt" 2>&1 || true
grep -q '^gh workflow run release.yml -f version=2.0.0 -f dry_run=true$' "$FAKE_GH_LOG" || fail "wrong dry-run call: $(cat "$FAKE_GH_LOG")"
ok "release-dispatch.sh dry-run calls gh with dry_run=true"

echo "=== release-dispatch.sh: declining overwrite calls nothing ==="
sandbox_init
reset_scenario
write_fake_gh
export FAKE_GH_LOG="$work/gh12.log"
: >"$FAKE_GH_LOG"
output="$work/out13.txt"
printf 'n\n' | VERSION="2.0.0" bash "$DISPATCH_SCRIPT" overwrite >"$output" 2>&1 || true
grep -q "aborted" "$output" || fail "missing aborted message: $(cat "$output")"
[ "$(gh_calls "$FAKE_GH_LOG")" -eq 0 ] || fail "gh called when overwrite declined"
ok "release-dispatch.sh overwrite aborts when declined"

echo "=== release-dispatch.sh: accepting overwrite dispatches with overwrite=true ==="
sandbox_init
reset_scenario
write_fake_gh
export FAKE_GH_LOG="$work/gh13.log"
: >"$FAKE_GH_LOG"
printf 'y\n' | VERSION="2.0.0" bash "$DISPATCH_SCRIPT" overwrite >"$work/out14.txt" 2>&1 || true
grep -q '^gh workflow run release.yml -f version=2.0.0 -f overwrite=true$' "$FAKE_GH_LOG" || fail "wrong overwrite call: $(cat "$FAKE_GH_LOG")"
ok "release-dispatch.sh overwrite calls gh with overwrite=true when accepted"

echo ""
echo "All release tests passed!"
exit 0
