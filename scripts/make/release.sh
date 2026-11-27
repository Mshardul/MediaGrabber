#!/usr/bin/env bash
# Runs the release workflow with a version bump for make release.

set -euo pipefail

BUMP="${1:-}"

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo_root"

if [ -z "$BUMP" ]; then
    echo "pick one: make release-patch | release-minor | release-major" >&2
    exit 1
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "working tree dirty — commit first" >&2
    exit 1
fi

if [ "$(git rev-parse --abbrev-ref HEAD)" != "main" ]; then
    echo "not on main" >&2
    exit 1
fi

git fetch --quiet origin main
if [ "$(git rev-parse HEAD)" != "$(git rev-parse origin/main)" ]; then
    echo "local main != origin/main — push or pull first" >&2
    exit 1
fi

CURRENT_VERSION=$(git tag --list 'v[0-9]*' | scripts/current-version.sh)
next=$(scripts/bump-version.sh "$CURRENT_VERSION" "$BUMP") || exit 1
echo "$CURRENT_VERSION  ->  $next"

trigger="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
gh workflow run release.yml -f version="$next" -f dry_run=true >/dev/null

id=""
lookup_errors="$(mktemp)"
trap 'rm -f "$lookup_errors"' EXIT
for _ in $(seq 1 30); do
    # A failed lookup is often temporary, so it is retried and its error kept for the final message.
    id="$(gh run list --workflow release.yml --json databaseId,event,createdAt -q '[.[] | select(.event=="workflow_dispatch" and .createdAt > "'"$trigger"'")] | .[0].databaseId // empty' 2>"$lookup_errors")" || id=""
    [ -n "$id" ] && break
    sleep 5
done

[ -n "$id" ] || {
    echo "no dry-run workflow found; it may still be running on GitHub" >&2
    cat "$lookup_errors" >&2
    exit 1
}

gh run watch "$id" --exit-status || {
    echo "dry-run release failed"
    exit 1
}

cat docs/release-checklist.md

read -r -p "type yes to proceed: " ok
[ "$ok" = yes ] || {
    echo aborted
    exit 1
}

read -r -p "tag v$next and push? [y/N] " confirm
[ "$confirm" = y ] || {
    echo aborted
    exit 1
}

git tag -a "v$next" -m "MediaGrabber v$next"
git push origin "v$next"
echo "pushed v$next — CI builds the release now"
