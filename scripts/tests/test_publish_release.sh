#!/usr/bin/env bash
# Tests for publish-release.sh — run: scripts/tests/test_publish_release.sh
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
script="$root/release/publish-release.sh"
stub="$root/tests/stubs/gh"
version="0.1.0"
tag="v$version"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
fails=0

log="$work/gh.log"
state="$work/state"
assets="$work/assets"
mkdir -p "$state" "$assets"
touch "$assets/MediaGrabber-$version.dmg" "$assets/SHA256SUMS" "$assets/appcast.xml"
printf 'source\n' >"$work/source.tar.xz"
sha="$(shasum -a 256 "$work/source.tar.xz" | cut -d' ' -f1)"
printf 'ffmpeg 7.1.1 file://%s %s mirror\n' "$work/source.tar.xz" "$sha" >"$work/tools.lock"
cp "$work/source.tar.xz" "$assets/ffmpeg-7.1.1.tar.xz"
printf 'MediaGrabber-%s.dmg\nSHA256SUMS\nappcast.xml\nffmpeg-7.1.1.tar.xz\n' "$version" >"$state/assets"
: >"$work/notes.md"

printf '#!/usr/bin/env bash\nexit 0\n' >"$work/feed-ok"
printf '#!/usr/bin/env bash\nexit 1\n' >"$work/feed-fail"
chmod +x "$work/feed-ok" "$work/feed-fail"
chmod +x "$stub"

run_publish() {
    local feed="$1"
    shift
    env PATH="$root/tests/stubs:$PATH" \
        MG_GH_LOG="$log" MG_GH_STATE="$state" \
        GH_TOKEN=x GITHUB_REPOSITORY=owner/repo GITHUB_SHA=abc \
        MG_CHECK_FEED="$feed" MG_TOOLS_LOCK="$work/tools.lock" \
        "$script" --version "$version" --notes "$work/notes.md" --assets-dir "$assets" "$@"
}

reset() {
    : >"$log"
    rm -f "$state/existing" "$state/drafts"
    : >"$state/drafts"
    printf 'MediaGrabber-%s.dmg\nSHA256SUMS\nappcast.xml\nffmpeg-7.1.1.tar.xz\n' "$version" >"$state/assets"
}

check() {
    local name="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        printf 'ok   - %s\n' "$name"
    else
        printf 'FAIL - %s\n' "$name"
        fails=$((fails + 1))
    fi
}

line_of() {
    grep -n -- "$1" "$log" | head -1 | cut -d: -f1
}

check_order() {
    local name="$1" first="$2" second="$3" a b
    a="$(line_of "$first")"
    b="$(line_of "$second")"
    if [ -n "$a" ] && [ -n "$b" ] && [ "$a" -lt "$b" ]; then
        printf 'ok   - %s\n' "$name"
    else
        printf 'FAIL - %s\n' "$name"
        fails=$((fails + 1))
    fi
}

reset
check "happy path publishes and then checks the feed" run_publish "$work/feed-ok"
check_order "draft is created before it is published" "release create $tag" "-F draft=false"
check "the asset list is checked before publishing" grep -q "release view $tag --json assets" "$log"

reset
printf 'MediaGrabber-%s.dmg\nSHA256SUMS\nappcast.xml\n' "$version" >"$state/assets"
if run_publish "$work/feed-ok" >/dev/null 2>&1; then
    printf 'FAIL - a wrong asset list must fail\n'
    fails=$((fails + 1))
elif grep -q 'draft=false' "$log"; then
    printf 'FAIL - a wrong asset list must stay a draft\n'
    fails=$((fails + 1))
else
    printf 'ok   - a wrong asset list fails and stays a draft\n'
fi

reset
touch "$state/existing"
if run_publish "$work/feed-ok" >/dev/null 2>&1; then
    printf 'FAIL - an existing release must be refused without --overwrite\n'
    fails=$((fails + 1))
elif grep -q "release create $tag" "$log"; then
    printf 'FAIL - an existing release must not be created again\n'
    fails=$((fails + 1))
else
    printf 'ok   - an existing release is refused without --overwrite\n'
fi

reset
touch "$state/existing"
check "--overwrite deletes the release and its tag before creating" run_publish "$work/feed-ok" --overwrite
check_order "the overwrite delete comes before the create" "release delete $tag --yes --cleanup-tag" "release create $tag"

reset
printf '11 v0.1.0\n12 v0.2.0\n' >"$state/drafts"
run_publish "$work/feed-ok" >/dev/null 2>&1 || true
check "stale drafts for this tag are deleted" grep -q "releases/11" "$log"
if grep -q "releases/12" "$log"; then
    printf 'FAIL - another tag'"'"'s draft must be untouched\n'
    fails=$((fails + 1))
else
    printf 'ok   - another tag'"'"'s draft is untouched\n'
fi

reset
if run_publish "$work/feed-fail" >/dev/null 2>&1; then
    printf 'FAIL - a failed feed check must fail the publish\n'
    fails=$((fails + 1))
else
    printf 'ok   - a failed feed check fails the publish\n'
fi
check "a failed feed check puts the release back to draft" grep -q -- '-F draft=true' "$log"

if [ "$fails" -ne 0 ]; then
    printf '\n%d test(s) failed\n' "$fails"
    exit 1
fi
printf '\nall tests passed\n'
