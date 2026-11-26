#!/usr/bin/env python3
"""Convert PRIVACY.md into the plain-text copy shown in the Privacy pane."""

import re
import sys
import textwrap


def strip_md(line):
    # Inline emphasis / strong emphasis
    line = re.sub(r"\*\*(.+?)\*\*", r"\1", line)
    line = re.sub(r"\*(.+?)\*", r"\1", line)
    line = re.sub(r"`(.+?)`", r"\1", line)
    # Links: [text](url) -> text
    line = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", line)
    # Images: ![alt](url) -> alt
    line = re.sub(r"!\[([^\]]*)\]\([^)]+\)", r"\1", line)
    return line


def main(argv):
    if len(argv) > 1:
        out = argv[1]
    else:
        out = "Resources/privacy.txt"
    with open("PRIVACY.md", encoding="utf-8") as handle:
        source = handle.read()
    lines = source.split("\n")
    body = []
    for line in lines:
        if line.startswith("#"):
            line = line.lstrip("#").lstrip()
        if line.strip() == "---":
            continue
        body.append(strip_md(line))
    out_lines = []
    for line in body:
        if not line.strip():
            out_lines.append("")
            continue
        out_lines.extend(
            textwrap.wrap(line, width=78, break_long_words=False, break_on_hyphens=False) or [""]
        )
    with open(out, "w", encoding="utf-8") as handle:
        handle.write("\n".join(out_lines) + "\n")


if __name__ == "__main__":
    sys.exit(main(sys.argv))
