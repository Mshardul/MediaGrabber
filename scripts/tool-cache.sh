#!/usr/bin/env bash
# The fetch and release steps both ask here, so packaging looks exactly where the build downloaded.

set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
out="${MG_TOOLS_OUT:-$root}"
case "$out" in
/*) ;;
*) out="$root/$out" ;;
esac
dir="$out/build/tool-src"

case "${1:-}" in
dir)
    printf '%s\n' "$dir"
    ;;
file)
    # Nothing is printed for a name the build does not cache.
    case "${2:?tool name}" in
    ffmpeg) printf '%s\n' "$dir/ffmpeg.tar.xz" ;;
    lame) printf '%s\n' "$dir/lame.tar.gz" ;;
    shield-source) printf '%s\n' "$dir/shield.tar.gz" ;;
    esac
    ;;
*)
    echo "usage: tool-cache.sh dir | file <name>" >&2
    exit 1
    ;;
esac
