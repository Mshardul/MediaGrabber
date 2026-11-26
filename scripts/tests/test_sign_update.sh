#!/usr/bin/env bash
# Tests for sign-update.sh — run: scripts/tests/test_sign_update.sh
set -euo pipefail

script="$(cd "$(dirname "$0")/.." && pwd)/release/sign-update.sh"
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

# A home with only DerivedData, like a CI runner that has no tuist cache folder.
home="$work/home"
tool_dir="$home/Library/Developer/Xcode/DerivedData/App/SourcePackages/artifacts/sparkle/Sparkle/bin"
mkdir -p "$tool_dir" "$work/bin" "$work/run" "$work/assets"
printf '#!/bin/sh\necho '"'"'sparkle:edSignature="SIG123" length="12"'"'"'\n' > "$tool_dir/sign_update"
chmod +x "$tool_dir/sign_update"
printf 'disk image\n' > "$work/run/MediaGrabber-0.1.0.dmg"
: > "$work/github-output"

# Stub gh that simulates "release not found"
printf '#!/usr/bin/env bash\ncase "$1 $2" in\n  "release view")\n    echo "release not found" >&2\n    exit 1\n    ;;\n  *)\n    exit 0\n    ;;\nesac\n' > "$work/bin/gh"
chmod +x "$work/bin/gh"

run_sign() {
    (cd "$work/run" && HOME="$home" PATH="$work/bin:$PATH" GITHUB_OUTPUT="$work/github-output" \
        GH_TOKEN=test GITHUB_REPOSITORY=owner/repo \
        SPARKLE_EDDSA_PRIVATE_KEY=key bash "$script" MediaGrabber-0.1.0.dmg 0.1.0 "$work/assets")
}

check "signing succeeds when no earlier release exists" run_sign
check "the appcast carries the signature" grep -q 'SIG123' "$work/assets/appcast.xml"
check "the signed output is written for the workflow" grep -qx 'signed=true' "$work/github-output"

# Test: an earlier release exists (its feed must be downloaded and kept)
cat > "$work/bin/gh" <<'STUB'
#!/usr/bin/env bash
case "$1 $2" in
  "release view") echo '{"tagName":"v0.0.9"}' ;;
  "release download")
    while [ $# -gt 0 ]; do
      [ "$1" = "--output" ] && out="$2"
      shift
    done
    printf '<item><sparkle:version>0.0.9</sparkle:version><enclosure url="u" sparkle:edSignature="OLD" length="1"/></item>\n' > "$out"
    ;;
esac
STUB
chmod +x "$work/bin/gh"

check "signing succeeds when an earlier release exists" run_sign
check "the earlier item stays in the appcast" grep -q 'OLD' "$work/assets/appcast.xml"
check "the new item joins the appcast" grep -q 'SIG123' "$work/assets/appcast.xml"

# Test: gh returns an authentication error (should fail)
printf '#!/usr/bin/env bash\ncase "$1 $2" in\n  "release view")\n    echo "authentication failed" >&2\n    exit 1\n    ;;\n  *)\n    exit 0\n    ;;\nesac\n' > "$work/bin/gh"
chmod +x "$work/bin/gh"

msg="$(cd "$work/run" && HOME="$home" PATH="$work/bin:$PATH" GITHUB_OUTPUT="$work/github-output" \
    GH_TOKEN=test GITHUB_REPOSITORY=owner/repo \
    SPARKLE_EDDSA_PRIVATE_KEY=key bash "$script" MediaGrabber-0.1.0.dmg 0.1.0 "$work/assets" 2>&1 || true)"
check "authentication error fails the script" bash -c "grep -q 'failed to look up the latest release' <<<\"$msg\""

# Test: sign_update not found
rm -rf "$home/Library"
mkdir -p "$home"
msg="$(cd "$work/run" && HOME="$home" PATH="$work/bin:$PATH" GH_TOKEN=test GITHUB_REPOSITORY=owner/repo \
    SPARKLE_EDDSA_PRIVATE_KEY=key bash "$script" MediaGrabber-0.1.0.dmg 0.1.0 "$work/assets" 2>&1 || true)"
check "the failure says sign_update was not found" bash -c "grep -q 'sign_update not found' <<<\"$msg\""

if [ "$fails" -ne 0 ]; then
    printf '\n%d test(s) failed\n' "$fails"
    exit 1
fi
printf '\nall tests passed\n'
