#!/usr/bin/env bash
# Runs the app in screenshot mode on a temporary home and removes what the run created. Used by make screenshots.

set -euo pipefail

if [ $# -lt 2 ]; then
    echo "usage: screenshots.sh APP ROOT [SCENE] [THEME] [FLOW]" >&2
    exit 2
fi
app="$1"
root="$2"
scene="${3:-}"
theme="${4:-}"
flow="${5:-}"
idle_timeout="${MG_SCREENSHOT_IDLE_TIMEOUT:-60}"

mkdir -p "$root"
root="$(cd "$root" && pwd)"
# Named by the time the run started; plain mkdir stops a second run from sharing a folder.
out="$root/$(date +%s)"
mkdir "$out"

home="$(mktemp -d)"
log="${home:?}/tour.log"
pid=""

stop_app() {
    [ -n "$pid" ] || return 0
    kill -0 "$pid" 2>/dev/null || return 0
    kill "$pid" 2>/dev/null || true
    local tries=0
    while kill -0 "$pid" 2>/dev/null; do
        tries=$((tries + 1))
        if [ "$tries" -gt 50 ]; then
            kill -9 "$pid" 2>/dev/null || true
            break
        fi
        sleep 0.1
    done
    # The status of a stopped app says nothing about the run.
    wait "$pid" 2>/dev/null || true
}

remove_settings() {
    [ -s "$out/settings.domain" ] || return 0
    local domain
    domain="$(cat "$out/settings.domain")"
    rm -f "${out:?}/settings.domain"
    # Anything but a temporary run's domain could be the real settings.
    if [[ ! "$domain" =~ ^app\.mediagrabber\.mac\.home\.[0-9a-f]+$ ]]; then
        echo "left settings alone: '$domain' is not a screenshot run's domain" >&2
        return 0
    fi
    # Fails only when the run saved nothing; deleting also leaves an empty file behind.
    defaults delete "$domain" >/dev/null 2>&1 || true
    rm -f "${HOME:?}/Library/Preferences/${domain:?}.plist"
}

cleanup() {
    stop_app
    remove_settings
    # A run that saved nothing leaves no folder; rmdir removes only an empty one.
    rmdir "$out" 2>/dev/null || true
    chmod -R u+rwX "${home:?}"
    rm -rf "${home:?}"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

arguments=(-MGScreenshots "$out")
if [ -n "$scene" ]; then
    arguments+=(-MGScreenshotScene "$scene")
fi
if [ -n "$theme" ]; then
    arguments+=(-MGScreenshotTheme "$theme")
fi
if [ -n "$flow" ]; then
    arguments+=(-MGScreenshotFlow "$flow")
fi
arguments+=(-ApplePersistenceIgnoreState YES)

env MG_HOME="$home" "$app/Contents/MacOS/MediaGrabber" "${arguments[@]}" >"$log" 2>&1 &
pid=$!

# Colour only on a terminal, so a saved log stays plain.
green=""
red=""
plain=""
if { [ -t 1 ] || [ -n "${FORCE_COLOR:-}" ]; } && [ -z "${NO_COLOR:-}" ]; then
    green=$'\033[32m'
    red=$'\033[31m'
    plain=$'\033[0m'
fi

total=0
captured=0
failed=0
# The screen that has started and has no result yet.
current=""
finished=""
shown=0
last_progress=$SECONDS

pass_current() {
    printf '%s✓%s\n' "$green" "$plain"
    captured=$((captured + 1))
    current=""
}

fail_current() {
    printf '%s✗%s %s\n' "$red" "$plain" "$1"
    failed=$((failed + 1))
    current=""
}

handle_line() {
    local event rest number
    event="${1%% *}"
    rest="${1#* }"
    case "$event" in
    tour-plan)
        total="$rest"
        ;;
    tour-start)
        number="${rest%% *}"
        current="${rest#* }"
        # No newline yet: the tick or cross goes on this line when the screen is done.
        printf '[%s/%s] %s ' "$number" "$total" "$current"
        ;;
    tour-pass)
        pass_current
        ;;
    tour-fail)
        fail_current "${rest#* }"
        ;;
    tour-finished)
        finished="yes"
        ;;
    tour-abort)
        printf 'FAIL - %s\n' "$rest"
        ;;
    Screenshot)
        printf '%s\n' "$1"
        ;;
    # The system writes its own lines to the same output.
    *) ;;
    esac
}

show_new_lines() {
    local count line
    count=$(($(wc -l <"$log")))
    [ "$count" -gt "$shown" ] || return 0
    while IFS= read -r line; do
        handle_line "$line"
    done < <(sed -n "$((shown + 1)),${count}p" "$log")
    shown=$count
    last_progress=$SECONDS
}

summary_row() {
    printf '| %-8s | %7s |\n' "$1" "$2"
}

summary() {
    local rule='+----------+---------+'
    local headline="run completed"
    [ -n "$finished" ] || headline="run stopped early"
    echo
    if [ "$captured" -gt 0 ]; then
        echo "$headline. screenshots saved in $out"
    else
        echo "$headline. no screenshots saved."
    fi
    echo "$rule"
    summary_row status screens
    echo "$rule"
    summary_row captured "$captured"
    summary_row failed "$failed"
    local waiting=$((total - captured - failed))
    if [ "$waiting" -gt 0 ]; then
        summary_row "not run" "$waiting"
    fi
    echo "$rule"
    summary_row total "$total"
    echo "$rule"
}

stopped=""
while kill -0 "$pid" 2>/dev/null; do
    show_new_lines
    if [ $((SECONDS - last_progress)) -ge "$idle_timeout" ]; then
        stopped="no progress for ${idle_timeout}s"
        stop_app
        pid=""
        break
    fi
    sleep 0.2
done

status=0
if [ -n "$pid" ]; then
    wait "$pid" || status=$?
    pid=""
fi
show_new_lines

if [ -z "$finished" ] && [ -z "$stopped" ]; then
    stopped="app exited early (status $status)"
fi
if [ -n "$current" ]; then
    fail_current "${stopped:-the run ended before this screen was done}"
elif [ -n "$stopped" ] && ! grep -q '^tour-abort ' "$log"; then
    echo "FAIL - $stopped"
fi

# With nothing planned there is nothing to count.
if [ "$total" -gt 0 ]; then
    summary
else
    tail -5 "$log" | grep -v '^tour-' || true
fi
if [ "$captured" -gt 0 ]; then
    open "$out"
fi
[ -n "$finished" ] && [ "$failed" -eq 0 ] && [ "$status" -eq 0 ]
