#!/usr/bin/env bash
# Tests for screenshots.sh — run: scripts/tests/test_screenshots.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCREENSHOTS="$SCRIPT_DIR/../screenshots.sh"

work="$(mktemp -d)"
# shellcheck source=scripts/tests/lib/sandbox.sh
source "$SCRIPT_DIR/lib/sandbox.sh"
trap 'sandbox_cleanup; /bin/rm -rf "${work:?}"' EXIT

fail() {
    echo "FAIL: $1" >&2
    exit 1
}
ok() { echo "ok - $1"; }

domain="app.mediagrabber.mac.home.0123456789ab"

# A stand-in app: STUB_BODY says how its run goes.
app="$work/Stub.app"
mkdir -p "$app/Contents/MacOS"
cat >"$app/Contents/MacOS/MediaGrabber" <<'STUB'
#!/usr/bin/env bash
out="$2"
echo "$*" >"$STUB_RECORD/arguments"
echo "$MG_HOME" >"$STUB_RECORD/home"
echo $$ >"$STUB_RECORD/pid"
printf '%s' "$STUB_DOMAIN" >"$out/settings.domain"
mkdir -p "$HOME/Library/Preferences"
echo saved >"$HOME/Library/Preferences/$STUB_DOMAIN.plist"
eval "$STUB_BODY"
STUB
chmod +x "$app/Contents/MacOS/MediaGrabber"

# Bodies the stand-in runs; quoted heredocs keep its variables for it to expand.
succeeds="$(
    cat <<'BODY'
mkdir -p "$out/aurora"; echo png >"$out/aurora/about.png"
echo "tour-plan 1"; echo "tour-start 1 aurora/about.png"; echo "tour-pass 1"
echo "2026-11-28 12:00:00 MediaGrabber[1:2] a line from the system"; echo "tour-finished"
BODY
)"
one_fails="$(
    cat <<'BODY'
mkdir -p "$out/aurora"; echo png >"$out/aurora/a.png"; echo png >"$out/aurora/c.png"
echo "tour-plan 3"
echo "tour-start 1 aurora/a.png"; echo "tour-pass 1"
echo "tour-start 2 aurora/b.png"; echo "tour-fail 2 never settled"
echo "tour-start 3 aurora/c.png"; echo "tour-pass 3"
echo "tour-finished"; exit 1
BODY
)"
# Holds a screen open until the test has seen the line that starts it.
waits_mid_screen="$(
    cat <<'BODY'
echo "tour-plan 1"; echo "tour-start 1 aurora/about.png"
while [ ! -e "$STUB_RECORD/release" ]; do sleep 0.05; done
mkdir -p "$out/aurora"; echo png >"$out/aurora/about.png"
echo "tour-pass 1"; echo "tour-finished"
BODY
)"

# A fake that notes each call's arguments in the named record file.
recorder() {
    printf '#!/usr/bin/env bash\\necho "$*" >>"%s/%s"' "$STUB_RECORD" "$1"
}

prepare() {
    sandbox_init
    # The script stops only the stand-in it started, so it needs the real kill.
    unset -f kill
    export STUB_RECORD="$SANDBOX_DIR/record"
    sandbox_fake "defaults" "$(recorder defaults)"
    sandbox_fake "open" "$(recorder opened)"
    export STUB_DOMAIN="$domain"
    export STUB_BODY="$1"
    mkdir -p "$STUB_RECORD"
    root="$SANDBOX_DIR/screenshots"
}

# The folders that runs have made under the root, one per line.
run_folders() {
    find "$root" -mindepth 1 -maxdepth 1 -type d
}

run() {
    status=0
    bash "$SCREENSHOTS" "$app" "$root" "$@" >"$work/output" 2>&1 || status=$?
}

home_removed() {
    [ ! -e "$(cat "$STUB_RECORD/home")" ] || fail "$1: temporary home left behind"
}

app_stopped() {
    if kill -0 "$(cat "$STUB_RECORD/pid")" 2>/dev/null; then
        fail "$1: app still running"
    fi
}

# The count in a summary row, or nothing when the row is absent.
row() {
    sed -n "s/^| $1 *| *\([0-9]*\) |$/\1/p" "$work/output"
}

echo "=== A successful run ==="
prepare "$succeeds"
run
[ "$status" -eq 0 ] || fail "success exited $status: $(cat "$work/output")"
folder="$(run_folders)"
[[ "$(basename "$folder")" =~ ^[0-9]{10,}$ ]] || fail "run folder is not named by epoch time: $folder"
[ -s "$folder/aurora/about.png" ] || fail "image missing"
grep -q -x "$folder" "$STUB_RECORD/opened" || fail "run folder not opened"
grep -q -x -F "[1/1] aurora/about.png ✓" "$work/output" || fail "progress not shown: $(cat "$work/output")"
if grep -q "a line from the system" "$work/output"; then
    fail "the system's own lines were shown"
fi
grep -q -x -F "run completed. screenshots saved in $folder" "$work/output" ||
    fail "no closing line with the folder: $(cat "$work/output")"
[ "$(row captured)" = 1 ] && [ "$(row failed)" = 0 ] && [ "$(row total)" = 1 ] ||
    fail "wrong summary: $(cat "$work/output")"
[ -z "$(row "not run")" ] || fail "a finished run lists screens not run"
[ ! -e "$folder/settings.domain" ] || fail "marker file left behind"
grep -q -x "delete $domain" "$STUB_RECORD/defaults" || fail "settings domain not deleted"
[ ! -e "$HOME/Library/Preferences/$domain.plist" ] || fail "empty settings file left behind"
grep -q -- "-ApplePersistenceIgnoreState YES" "$STUB_RECORD/arguments" || fail "window state not ignored"
home_removed success
ok "success shows ticked progress and a summary, and cleans up"

echo "=== A line appears before its screen is done ==="
prepare "$waits_mid_screen"
bash "$SCREENSHOTS" "$app" "$root" >"$work/output" 2>&1 &
script_pid=$!
tries=0
until grep -q -F "[1/1] aurora/about.png " "$work/output" 2>/dev/null; do
    tries=$((tries + 1))
    [ "$tries" -le 100 ] || fail "no line while the screen was being captured"
    sleep 0.05
done
if grep -q -F "✓" "$work/output"; then
    fail "ticked before the screen was done"
fi
: >"$STUB_RECORD/release"
wait "$script_pid" || fail "run failed: $(cat "$work/output")"
grep -q -x -F "[1/1] aurora/about.png ✓" "$work/output" || fail "tick not added to the same line"
ok "a screen's line shows at its start and is ticked when done"

echo "=== Colours ==="
prepare "$one_fails"
FORCE_COLOR=1 run
grep -q -F $'\033[32m✓' "$work/output" || fail "tick is not green"
grep -q -F $'\033[31m✗' "$work/output" || fail "cross is not red"
prepare "$one_fails"
run
if grep -q $'\033' "$work/output"; then
    fail "colour codes written when output is not a terminal"
fi
ok "green tick and red cross on a terminal, plain text otherwise"

echo "=== Scene, theme and flow are passed on ==="
prepare "$succeeds"
run about aurora about
grep -q -- "-MGScreenshotScene about -MGScreenshotTheme aurora -MGScreenshotFlow about" "$STUB_RECORD/arguments" ||
    fail "narrowing not passed: $(cat "$STUB_RECORD/arguments")"
prepare "$succeeds"
run "" aurora onboarding
grep -q -- "-MGScreenshotTheme aurora -MGScreenshotFlow onboarding" "$STUB_RECORD/arguments" ||
    fail "flow without a scene not passed: $(cat "$STUB_RECORD/arguments")"
if grep -q -- "-MGScreenshotScene" "$STUB_RECORD/arguments"; then
    fail "an empty scene was passed on"
fi
ok "scene, theme and flow reach the app"

echo "=== One screen fails ==="
prepare "$one_fails"
run
[ "$status" -eq 1 ] || fail "failure exited $status"
grep -q -x -F "[2/3] aurora/b.png ✗ never settled" "$work/output" || fail "reason not shown: $(cat "$work/output")"
grep -q -x -F "[3/3] aurora/c.png ✓" "$work/output" || fail "later screens lost their number"
grep -q "^run completed. screenshots saved in " "$work/output" || fail "no closing line"
[ "$(row captured)" = 2 ] && [ "$(row failed)" = 1 ] && [ "$(row total)" = 3 ] ||
    fail "wrong summary: $(cat "$work/output")"
grep -q -x "$(run_folders)" "$STUB_RECORD/opened" || fail "the captured screens were not opened"
home_removed failure
ok "a failed screen is crossed, counted and fails the run"

echo "=== The run cannot start ==="
prepare 'echo "tour-abort no scene named zzz"; exit 1'
run
[ "$status" -eq 1 ] || fail "abort exited $status"
grep -q -x -F "FAIL - no scene named zzz" "$work/output" || fail "reason not shown: $(cat "$work/output")"
if grep -q "exited early" "$work/output"; then
    fail "a stated reason was followed by a vague one"
fi
[ -z "$(run_folders)" ] || fail "a run that saved nothing left a folder"
home_removed abort
ok "a run that cannot start says why and leaves no folder"

echo "=== The app dies or is quit before finishing ==="
for code in 3 0; do
    prepare "echo 'tour-plan 4'; echo 'tour-start 1 aurora/a.png'; exit $code"
    run
    [ "$status" -eq 1 ] || fail "exit $code reported $status"
    grep -q -F "[1/4] aurora/a.png ✗ app exited early (status $code)" "$work/output" ||
        fail "exit $code not reported: $(cat "$work/output")"
    grep -q "^run stopped early. no screenshots saved." "$work/output" || fail "no closing line"
    [ "$(row failed)" = 1 ] && [ "$(row "not run")" = 3 ] && [ "$(row total)" = 4 ] ||
        fail "wrong summary: $(cat "$work/output")"
    home_removed "exit $code"
done
prepare 'exit 3'
run
grep -q -x -F "FAIL - app exited early (status 3)" "$work/output" ||
    fail "a death before the first screen is not reported: $(cat "$work/output")"
ok "an unfinished run fails and counts what never ran, even on a clean exit"

echo "=== The app stops making progress ==="
prepare 'echo "tour-plan 2"; echo "tour-start 1 aurora/a.png"; exec sleep 30'
MG_SCREENSHOT_IDLE_TIMEOUT=1 run
[ "$status" -eq 1 ] || fail "stall exited $status"
grep -q -F "[1/2] aurora/a.png ✗ no progress for 1s" "$work/output" ||
    fail "stall not reported on its screen: $(cat "$work/output")"
[ "$(row failed)" = 1 ] && [ "$(row "not run")" = 1 ] || fail "wrong summary: $(cat "$work/output")"
app_stopped stall
home_removed stall
ok "a stalled app is stopped and counted"

echo "=== An interrupted run ==="
prepare 'exec sleep 30'
bash "$SCREENSHOTS" "$app" "$root" >"$work/output" 2>&1 &
script_pid=$!
tries=0
while [ ! -s "$STUB_RECORD/pid" ]; do
    tries=$((tries + 1))
    [ "$tries" -le 100 ] || fail "stand-in app never started"
    sleep 0.05
done
kill -TERM "$script_pid"
if wait "$script_pid"; then
    fail "interrupted run reported success"
fi
app_stopped interrupt
home_removed interrupt
ok "an interrupt leaves no app and no temporary home"

echo "=== Earlier runs ==="
prepare "$succeeds"
mkdir -p "$root/1700000000/aurora"
echo old >"$root/1700000000/aurora/about.png"
run about
[ "$status" -eq 0 ] || fail "run exited $status: $(cat "$work/output")"
[ "$(cat "$root/1700000000/aurora/about.png")" = old ] || fail "an earlier run was changed"
[ "$(run_folders | wc -l)" -eq 2 ] || fail "run did not get its own folder: $(run_folders)"
ok "each run gets its own folder and earlier ones are untouched"

echo "=== A domain that is not a screenshot run's ==="
prepare "$succeeds"
export STUB_DOMAIN="app.mediagrabber.mac"
run
[ -e "$HOME/Library/Preferences/app.mediagrabber.mac.plist" ] || fail "real settings file removed"
[ ! -e "$STUB_RECORD/defaults" ] || fail "real settings domain deleted"
ok "real settings are never removed"

echo ""
echo "All screenshots.sh tests passed!"
