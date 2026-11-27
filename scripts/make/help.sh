#!/usr/bin/env bash
# Prints help for all Makefile targets. Used by make help.

set -euo pipefail

makefile="${1:-Makefile}"

if [ ! -f "$makefile" ]; then
    echo "Makefile not found: $makefile" >&2
    exit 1
fi

echo "Available targets:"
echo ""

awk '
/^## / {
    desc = substr($0, 4)
    next
}
/^[a-zA-Z0-9_.-]+:/ {
    target = substr($1, 1, length($1)-1)
    # Skip special targets and internal targets
    if (target ~ /^\./ || target ~ /^(include|override|export|unexport|vpath|VPATH|SUFFIXES|DEFAULT|PHONY|PRECIOUS|INTERMEDIATE|SECONDARY|SECONDEXPANSION|NOTPARALLEL|ONESHELL|POSIX|SILENT|EXPORT_ALL_VARIABLES|MAKE|MAKECMDGOALS|MAKESHELL|MAKEFILE_LIST|MAKEFLAGS|MAKELEVEL|MAKEOVERRIDES|MAKE_RESTARTS|MAKE_TERMERR|MAKE_TERMOUT|SHELL)$/) {
        desc = ""
        next
    }
    if (desc != "") {
        printf "  %-30s %s\n", target, desc
    } else {
        printf "  %-30s (no description)\n", target
    }
    desc = ""
}
' "$makefile"
