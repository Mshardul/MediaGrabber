#!/usr/bin/env bash
# Lists, checks and downloads the source files a release must carry beside the app.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
lock="${MG_TOOLS_LOCK:-$root/scripts/tools.lock}"

mirror_rows() {
    awk 'NF >= 5 && $5 == "mirror" { print $1, $2, $3, $4 }' "$lock"
}

asset_name() {
    local name="$1" version="$2" url="$3" base ext
    base="${url##*/}"
    ext="${base#*.}"
    printf '%s-%s.%s\n' "$name" "$version" "$ext"
}

allowed() {
    local version="$1"
    printf 'MediaGrabber-%s.dmg\nSHA256SUMS\nappcast.xml\n' "$version"
    while read -r name v url _; do
        [ -n "$name" ] || continue
        asset_name "$name" "$v" "$url"
    done < <(mirror_rows)
}

check() {
    local version="$1" actual allowed_list missing extra
    actual="$(mktemp)"
    allowed_list="$(mktemp)"
    trap 'rm -f "$actual" "$allowed_list"' RETURN
    LC_ALL=C sort >"$actual"
    allowed "$version" | LC_ALL=C sort >"$allowed_list"
    missing="$(comm -23 "$allowed_list" "$actual")"
    extra="$(comm -13 "$allowed_list" "$actual")"
    if [ -n "$missing" ] || [ -n "$extra" ]; then
        while read -r name; do [ -z "$name" ] || printf 'missing asset: %s\n' "$name" >&2; done <<<"$missing"
        while read -r name; do [ -z "$name" ] || printf 'unexpected asset: %s\n' "$name" >&2; done <<<"$extra"
        return 1
    fi
}

matches() {
    printf '%s  %s\n' "$1" "$2" | shasum -a 256 -c - >/dev/null 2>&1
}

# The copy is what gets checked, so the verified bytes are the ones that ship.
reuse_cached() {
    local name="$1" sha="$2" dest="$3" cached
    # Callers test this function, which turns off set -e inside it, so hard failures exit here.
    cached="$("$root/scripts/tool-cache.sh" file "$name")" || exit 1
    if [ -z "$cached" ]; then
        printf 'the build keeps no cached copy of %s\n' "$name"
    elif [ ! -e "$cached" ]; then
        printf 'not in the cache: %s\n' "$cached"
    elif [ ! -f "$cached" ] || ! cp "$cached" "$dest.partial"; then
        printf 'rejected %s: it could not be copied as a file\n' "$cached"
    elif ! matches "$sha" "$dest.partial"; then
        printf 'rejected %s: checksum mismatch\n' "$cached"
    else
        mv "$dest.partial" "$dest" || exit 1
        return 0
    fi
    rm -f "$dest.partial"
    return 1
}

sources() {
    local outdir="$1" name version url sha asset dest
    mkdir -p "$outdir"
    while read -r name version url sha; do
        [ -n "$name" ] || continue
        asset="$(asset_name "$name" "$version" "$url")"
        dest="$outdir/$asset"
        if matches "$sha" "$dest"; then
            printf 'already in place: %s\n' "$asset"
            continue
        fi
        rm -f "$dest" "$dest.partial"
        if reuse_cached "$name" "$sha" "$dest"; then
            printf 'reused from the cache: %s\n' "$asset"
            continue
        fi
        if ! curl -fsSL --retry 3 -o "$dest.partial" "$url"; then
            rm -f "$dest.partial"
            printf 'download failed: %s\n' "$asset" >&2
            return 1
        fi
        if ! matches "$sha" "$dest.partial"; then
            printf 'checksum mismatch: %s\n' "$asset" >&2
            rm -f "$dest.partial"
            return 1
        fi
        mv "$dest.partial" "$dest"
        printf 'downloaded: %s\n' "$asset"
    done < <(mirror_rows)
}

case "${1:-}" in
allowed)
    [ -n "${2:-}" ] || {
        echo "version required" >&2
        exit 1
    }
    allowed "$2"
    ;;
check)
    [ -n "${2:-}" ] || {
        echo "version required" >&2
        exit 1
    }
    check "$2"
    ;;
sources)
    [ -n "${2:-}" ] || {
        echo "output directory required" >&2
        exit 1
    }
    sources "$2"
    ;;
*)
    echo "usage: release-assets.sh allowed|check <version> | sources <outdir>" >&2
    exit 1
    ;;
esac
