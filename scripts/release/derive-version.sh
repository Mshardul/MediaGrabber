#!/usr/bin/env bash
set -euo pipefail
version="${INPUT_VERSION:-}"
if [[ -z "$version" ]]; then
    case "${EVENT_NAME:-}" in
        release) version="${REF_NAME#v}" ;;
        *) version="" ;;
    esac
fi
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "invalid version: $version" >&2
    exit 1
fi
notes="release-notes/${version}.md"
if [[ ! -s "$notes" ]]; then
    echo "missing release notes: $notes" >&2
    exit 1
fi
printf '%s\n' "$version"
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    printf 'version=%s\n' "$version" >> "$GITHUB_OUTPUT"
fi
