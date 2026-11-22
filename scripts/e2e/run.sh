#!/usr/bin/env bash
# End-to-end check of a built MediaGrabber.app: tools, downloads, licenses, helper, launch.
# Run: scripts/e2e/run.sh APP
set -euo pipefail

app="$(cd "${1:?app bundle}" && pwd)"
root="$(cd "$(dirname "$0")/../.." && pwd)"

home="$(mktemp -d)"
trap 'cleanup' EXIT

server_pid=""
fixture_pid=""
app_pid=""

cleanup() {
    [ -n "$server_pid" ] && kill "$server_pid" 2>/dev/null || true
    [ -n "$fixture_pid" ] && kill "$fixture_pid" 2>/dev/null || true
    [ -n "$app_pid" ] && kill "$app_pid" 2>/dev/null || true
    wait 2>/dev/null || true
    rm -rf "$home"
}

env_i() { env -i HOME="$home" PATH=/usr/bin:/bin "$@"; }

tools="$app/Contents/Resources/Tools"
shield="$app/Contents/Resources/Shield"
licenses="$app/Contents/Resources/Licenses"

fail() { echo "FAIL - $*" >&2; exit 1; }
ok() { echo "ok - $*"; }

# --- Bundled tools ---
for spec in "yt-dlp --version" "ffmpeg -version" "ffprobe -version" "node --version"; do
    set -- $spec
    bin="$1"; shift
    out="$(env_i "$tools/$bin" "$@" 2>&1)" || fail "$bin did not run"
    [ -n "$out" ] || fail "$bin printed no output"
    ok "$bin"
done

# --- Download: generate a clip with ffmpeg, fetch it with yt-dlp ---
fixture="$home/clip"
mkdir -p "$fixture"
env_i "$tools/ffmpeg" -y -f lavfi -i testsrc=duration=2:size=320x240:rate=15 -f lavfi -i sine=duration=2 "$fixture/source.mov" >/dev/null 2>&1 || fail "ffmpeg could not generate a clip"
[ -s "$fixture/source.mov" ] || fail "clip is empty"

download="$home/download"
mkdir -p "$download"
/usr/bin/python3 "$root/scripts/e2e/fixture-server.py" --root "$fixture" > "$home/fixture.log" 2>&1 &
fixture_pid=$!
for _ in $(seq 1 100); do grep -q "^listening " "$home/fixture.log" && break; sleep 0.1; done
fixture_url="$(sed -n "s/^listening //p" "$home/fixture.log")"
[ -n "$fixture_url" ] || fail "fixture server did not start"

env_i "$tools/yt-dlp" --no-config -o "$download/%(title)s.%(ext)s" "$fixture_url/source.mov" >"$home/yt-dlp.log" 2>&1 || { tail -5 "$home/yt-dlp.log" >&2; fail "yt-dlp could not download the clip"; }
[ -n "$(find "$download" -type f -size +0c)" ] || fail "downloaded file is empty"
ok "download"

# --- License and resource files ---
for f in "$licenses"/*.txt; do
    [ -s "$f" ] || fail "license text empty: $(basename "$f")"
done
ok "license texts"

[ -s "$app/Contents/Resources/Privacy.txt" ] || fail "Privacy.txt is empty"
ok "Privacy.txt"

[ -s "$shield/plugin.zip" ] || fail "plugin.zip is empty"
ok "plugin.zip"

# --- Audio extraction ---
for fmt in m4a mp3; do
    env_i "$tools/ffmpeg" -y -i "$fixture/source.mov" -vn "$home/audio.$fmt" >/dev/null 2>&1 || fail "ffmpeg could not extract $fmt"
    probe="$(env_i "$tools/ffprobe" -v error -select_streams a -show_entries stream=codec_type -of csv=p=0 "$home/audio.$fmt" 2>&1)"
    [ "$probe" = "audio" ] || fail "ffprobe did not report an audio stream for $fmt"
done
ok "audio extraction"

# --- Shield helper ---
port="$(/usr/bin/python3 -c 'import socket; s=socket.socket(); s.bind(("",0)); print(s.getsockname()[1]); s.close()')"

env_i "$tools/node" "$shield/server/build/main.js" --port "$port" > "$home/shield.log" 2>&1 &
server_pid=$!

for _ in $(seq 1 100); do
    if /usr/bin/curl -fsS "http://127.0.0.1:$port/ping" >/dev/null 2>&1; then break; fi
    sleep 0.1
done
/usr/bin/curl -fsS "http://127.0.0.1:$port/ping" >/dev/null 2>&1 || fail "helper did not answer /ping"
ok "helper"

# --- Optional launch ---
if [ "${MG_E2E_LAUNCH:-}" = "1" ]; then
    executable="$app/Contents/MacOS/MediaGrabber"

    real_logs="$HOME/Library/Logs/MediaGrabber"
    real_before="$(ls -1 "$real_logs" 2>/dev/null | wc -l)"

    env MG_HOME="$home" "$executable" >/dev/null 2>&1 &
    app_pid=$!

    alive_until=$((SECONDS + 10))
    while [ $SECONDS -lt $alive_until ]; do
        kill -0 "$app_pid" 2>/dev/null || fail "app exited within 10 seconds of starting"
        sleep 0.5
    done

    grep -q '"event":"app.launched"' "$home/Library/Logs/MediaGrabber/app.log" 2>/dev/null \
        || fail "app.launched is not in the log under the fake home"

    kill -TERM "$app_pid" 2>/dev/null || true
    hard=$((SECONDS + 15))
    while kill -0 "$app_pid" 2>/dev/null; do
        [ $SECONDS -lt $hard ] || { kill -9 "$app_pid" 2>/dev/null || true; fail "app did not quit when asked"; }
        sleep 0.5
    done
    wait "$app_pid" 2>/dev/null || true
    real_after="$(ls -1 "$real_logs" 2>/dev/null | wc -l)"
    [ "$real_before" = "$real_after" ] || fail "the run wrote to the real home"
    ok "launch"
else
    echo "skip - launch (set MG_E2E_LAUNCH=1 on a clean machine)"
fi
