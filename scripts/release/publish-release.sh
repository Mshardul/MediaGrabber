#!/usr/bin/env bash
# Publishes the assets folder as a draft, checks its asset list, publishes it and proves the feed.
# Run: scripts/release/publish-release.sh --version X.Y.Z --notes FILE --assets-dir DIR [--overwrite]
#   GH_TOKEN, GITHUB_REPOSITORY and GITHUB_SHA in the environment; MG_CHECK_FEED names the feed check.
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
version="" notes="" assets="" overwrite=false
while [ $# -gt 0 ]; do
    case "$1" in
        --version) version="${2:?}"; shift 2 ;;
        --notes) notes="${2:?}"; shift 2 ;;
        --assets-dir) assets="${2:?}"; shift 2 ;;
        --overwrite) overwrite=true; shift ;;
        *) echo "unknown argument: $1" >&2; exit 1 ;;
    esac
done
[ -n "$version" ] && [ -n "$notes" ] && [ -n "$assets" ] || {
    echo "usage: publish-release.sh --version X.Y.Z --notes FILE --assets-dir DIR [--overwrite]" >&2
    exit 1
}
: "${GH_TOKEN:?GH_TOKEN is required}" "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}" "${GITHUB_SHA:?GITHUB_SHA is required}"

tag="v$version"
feed_check="${MG_CHECK_FEED:-$root/scripts/release/check-feed.sh}"

drafts="$(gh release list --limit 200 --json databaseId,tagName,isDraft --jq '.[] | select(.isDraft) | "\(.databaseId) \(.tagName)"' || true)"
while read -r id draft_tag; do
    [ -n "${id:-}" ] || continue
    if [ "$draft_tag" = "$tag" ]; then
        gh api -X DELETE "repos/$GITHUB_REPOSITORY/releases/$id" >/dev/null
    fi
done <<< "$drafts"

if gh release view "$tag" >/dev/null 2>&1; then
    if [ "$overwrite" != "true" ]; then
        echo "release $tag already exists; pass --overwrite to replace it" >&2
        exit 1
    fi
    gh release delete "$tag" --yes --cleanup-tag
fi

asset_files=()
while IFS= read -r name; do
    asset_files+=("$assets/$name")
done < <("$root/scripts/release-assets.sh" allowed "$version")

gh release create "$tag" "${asset_files[@]}" \
    --draft --target "$GITHUB_SHA" --title "MediaGrabber $version" --notes-file "$notes"

release_id="$(gh release view "$tag" --json databaseId --jq .databaseId)"
gh release view "$tag" --json assets --jq '.assets[].name' |
    "$root/scripts/release-assets.sh" check "$version"

gh api -X PATCH "repos/$GITHUB_REPOSITORY/releases/$release_id" -F draft=false -f make_latest=true

if ! "$feed_check" --version "$version"; then
    gh api -X PATCH "repos/$GITHUB_REPOSITORY/releases/$release_id" -F draft=true
    exit 1
fi
