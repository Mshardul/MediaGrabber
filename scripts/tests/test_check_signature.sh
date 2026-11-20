#!/usr/bin/env bash
# Tests for check-signature.sh — run: scripts/tests/test_check_signature.sh
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
script="$root/release/check-signature.sh"
signer="$root/ed25519.swift"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
fails=0

check() {
    local name="$1"; shift
    if "$@" >/dev/null 2>&1; then
        printf 'ok   - %s\n' "$name"
    else
        printf 'FAIL - %s\n' "$name"
        fails=$((fails + 1))
    fi
}

keys="$(swift "$signer" keygen)"
private="$(printf '%s\n' "$keys" | sed -n 's/^private=//p')"
public="$(printf '%s\n' "$keys" | sed -n 's/^public=//p')"
other_keys="$(swift "$signer" keygen)"
other_private="$(printf '%s\n' "$other_keys" | sed -n 's/^private=//p')"

app="$work/MediaGrabber.app"
mkdir -p "$app/Contents"
plutil -create xml1 "$app/Contents/Info.plist"
plutil -insert SUPublicEDKey -string "$public" "$app/Contents/Info.plist"

dmg="$work/MediaGrabber-0.1.0.dmg"
printf 'disk image\n' > "$dmg"
length="$(stat -f%z "$dmg")"

make_appcast() {
    local version="$1" signature="$2" file="$3"
    cat > "$file" <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <item>
      <sparkle:version>$version</sparkle:version>
      <enclosure url="https://example.com/MediaGrabber-$version.dmg" sparkle:edSignature="$signature" length="$length" type="application/octet-stream"/>
    </item>
  </channel>
</rss>
XML
}

good_signature="$(swift "$signer" sign "$private" "$dmg")"
make_appcast 0.1.0 "$good_signature" "$work/appcast.xml"

check "a matching version and signature pass" \
    bash "$script" --appcast "$work/appcast.xml" --app "$app" --dmg "$dmg" --version 0.1.0

other_signature="$(swift "$signer" sign "$other_private" "$dmg")"
make_appcast 0.1.0 "$other_signature" "$work/other.xml"
check "a signature from a different key fails" \
    bash -c "! bash '$script' --appcast '$work/other.xml' --app '$app' --dmg '$dmg' --version 0.1.0"

check "a relative app path passes" \
    bash -c "cd '$work' && bash '$script' --appcast appcast.xml --app MediaGrabber.app --dmg '$dmg' --version 0.1.0"

printf 'tampered\n' >> "$dmg"
check "a tampered disk image fails" \
    bash -c "! bash '$script' --appcast '$work/appcast.xml' --app '$app' --dmg '$dmg' --version 0.1.0"

printf 'disk image\n' > "$dmg"
make_appcast 0.2.0 "$good_signature" "$work/newer.xml"
check "a newest item with another version fails" \
    bash -c "! bash '$script' --appcast '$work/newer.xml' --app '$app' --dmg '$dmg' --version 0.1.0"

if [ "$fails" -ne 0 ]; then
    printf '\n%d test(s) failed\n' "$fails"
    exit 1
fi
printf '\nall tests passed\n'
