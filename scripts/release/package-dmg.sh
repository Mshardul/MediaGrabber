#!/usr/bin/env bash
# Puts the disk image, the pinned source files and SHA256SUMS into one assets folder.
# Run: scripts/release/package-dmg.sh APP VERSION ASSETS_DIR
set -euo pipefail

app="${1:?app bundle}"
version="${2:?version}"
assets="${3:?assets directory}"
root="$(cd "$(dirname "$0")/../.." && pwd)"

mkdir -p "$assets"
dmg="$assets/MediaGrabber-$version.dmg"
staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT
cp -R "$app" "$staging/"
rm -f "$dmg"
"$root/scripts/create-dmg" --volname "MediaGrabber $version" "$dmg" "$staging"
[ -f "$dmg" ] || { echo "dmg not created" >&2; exit 1; }

MG_TOOLS_LOCK="${MG_TOOLS_LOCK:-$root/scripts/tools.lock}" \
    "$root/scripts/release-assets.sh" sources "$assets"

(
    cd "$assets"
    find . -maxdepth 1 -type f ! -name SHA256SUMS | sed 's|^\./||' | LC_ALL=C sort |
        while IFS= read -r file; do
            shasum -a 256 "$file"
        done > SHA256SUMS
    shasum -a 256 -c SHA256SUMS
)
