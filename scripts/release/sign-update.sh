#!/usr/bin/env bash
# Signs the disk image for Sparkle and writes appcast.xml into the assets folder.
set -euo pipefail

dmg="${1:?disk image}"
version="${2:?version}"
assets="${3:?assets directory}"
root="$(cd "$(dirname "$0")/../.." && pwd)"

if [ -z "${SPARKLE_EDDSA_PRIVATE_KEY:-}" ]; then
    if [ "${DRY:-false}" = "true" ]; then
        echo "SPARKLE_EDDSA_PRIVATE_KEY is unset; the dry run is not signing an update"
        exit 0
    fi
    echo "SPARKLE_EDDSA_PRIVATE_KEY is required to publish an update" >&2
    exit 1
fi

: "${GH_TOKEN:?GH_TOKEN is required}" "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"

tool="$(find . "$HOME/Library/Caches/tuist" "$HOME/Library/Developer/Xcode/DerivedData" -path '*Sparkle/bin/sign_update' -type f 2>/dev/null | head -1 || true)"
[ -n "$tool" ] || {
    echo "sign_update not found" >&2
    exit 1
}

key="$(mktemp)"
current="$(mktemp)"
signature_file="$(mktemp)"
lookup_error="$(mktemp)"
trap 'rm -f "$key" "$current" "$signature_file" "$lookup_error"' EXIT
printf '%s\n' "$SPARKLE_EDDSA_PRIVATE_KEY" >"$key"
chmod 600 "$key"

"$tool" --ed-key-file "$key" "$dmg" >"$signature_file"
signature="$(sed -n 's/.*edSignature="\([^"]*\)".*/\1/p' "$signature_file")"
[ -n "$signature" ] || {
    echo "sign_update did not print an edSignature" >&2
    cat "$signature_file" >&2
    exit 1
}

if gh release view --json tagName >/dev/null 2>"$lookup_error"; then
    gh release download --pattern appcast.xml --output "$current" --clobber ||
        {
            echo "the latest release has no appcast.xml, so the update feed is broken" >&2
            exit 1
        }
elif ! grep -q 'release not found' "$lookup_error"; then
    echo "failed to look up the latest release: $(cat "$lookup_error")" >&2
    exit 1
fi

length="$(wc -c <"$dmg" | tr -d " ")"
python3 "$root/scripts/appcast.py" \
    --existing "$current" \
    --version "$version" \
    --url "https://github.com/Mshardul/MediaGrabber/releases/download/v${version}/MediaGrabber-${version}.dmg" \
    --signature "$signature" \
    --length "$length" \
    --notes "https://github.com/Mshardul/MediaGrabber/releases/tag/v${version}" \
    --out "$assets/appcast.xml"
echo "ok   - signed the disk image and wrote appcast.xml"
if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "signed=true" >>"$GITHUB_OUTPUT"
fi
