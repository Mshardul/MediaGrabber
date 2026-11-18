#!/usr/bin/env bash
# Reads tag names on stdin and prints the highest vN.N.N as a bare N.N.N, or 0.0.0 when none qualifies

set -euo pipefail

latest="$({ grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' || true; } | sed 's/^v//' | sort -t. -k1,1n -k2,2n -k3,3n | tail -n 1)"
printf '%s\n' "${latest:-0.0.0}"
