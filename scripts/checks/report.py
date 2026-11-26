import re
from collections.abc import Iterator
from dataclasses import dataclass
from enum import Enum
from pathlib import PurePosixPath

from checks.files import Language, _is_excluded, language_of
from checks.repo import AddedLine


class Kind(Enum):
    # Members are declared in the order the report lists them.
    SETTING = "setting"
    SUPPRESSION = "suppression"
    RISKY = "risky"


@dataclass(frozen=True)
class ReportItem:
    kind: Kind
    what: str
    path: str
    # None when the whole file is the item, which may no longer exist.
    line: int | None


_Patterns = tuple[tuple[str, re.Pattern[str]], ...]


def _patterns(*pairs: tuple[str, str]) -> _Patterns:
    return tuple((what, re.compile(pattern)) for what, pattern in pairs)


# Matched on the raw line: one line cannot tell whether it sits inside a multi-line string.
_SUPPRESSIONS: dict[Language, _Patterns] = {
    Language.SWIFT: _patterns(
        ("swiftlint:disable", r"swiftlint:disable"),
        ("swiftformat:disable", r"swiftformat:disable"),
        ("swiftformat:options", r"swiftformat:options"),
    ),
    Language.SHELL: _patterns(
        ("shellcheck disable", r"#\s*shellcheck\s+(?:[^#]*?\s)?disable="),
        (
            "shellcheck extended-analysis=false",
            r"#\s*shellcheck\s+(?:[^#]*?\s)?extended-analysis=false",
        ),
        (
            "shellcheck source=/dev/null",
            r"""#\s*shellcheck\s+(?:[^#]*?\s)?source=["']?/dev/null(?![\w./-])""",
        ),
    ),
    Language.PYTHON: _patterns(
        ("noqa", r"#\s*(?i:noqa)(?![\w-])"),
        ("ruff: noqa", r"#\s*ruff\s*:\s*(?i:noqa)(?![\w-])"),
        ("flake8: noqa", r"(?i)#\s*flake8\s*:\s*noqa(?![\w-])"),
        ("ruff: ignore", r"#\s*ruff\s*:\s*ignore\["),
        ("ruff: file-ignore", r"#\s*ruff\s*:\s*file-ignore\["),
        ("ruff: disable", r"#\s*ruff\s*:\s*disable\["),
        ("isort skip", r"#\s*(?:ruff\s*:\s*)?isort\s*:\s*(?:skip_file|skip|off)(?![\w-])"),
        ("fmt: off", r"#\s*fmt\s*:\s*off(?![\w-])"),
        ("fmt: skip", r"#\s*fmt\s*:\s*skip(?![\w-])"),
        ("yapf: disable", r"#\s*yapf\s*:\s*disable(?![\w-])"),
        ("type: ignore", r"#\s*type\s*:\s*ignore(?![\w-])"),
    ),
}

_IGNORED_FAILURE = _patterns(
    ("|| true", r"\|\|\s*true(?![\w./-])"),
    # Only an end of the word may follow, so that :foo, ::log and :- do not count.
    ("|| :", r"""\|\|\s*:(?![^\s;&|()<>"'`])"""),
)
_RISKY: dict[Language, _Patterns] = {
    Language.SWIFT: _patterns(
        ("try?", r"(?<![\w$`.])try\?"),
        ("@unchecked Sendable", r"@unchecked\s+(?:Swift\.)?Sendable(?!\w)"),
        ("nonisolated(unsafe)", r"(?<!\w)nonisolated\s*\(\s*unsafe\s*\)"),
    ),
    Language.SHELL: _IGNORED_FAILURE,
    # YAML run blocks and Makefile recipes are shell.
    Language.CONFIG: _IGNORED_FAILURE,
}
_COMMENT_MARKS = {Language.SWIFT: "//", Language.SHELL: "#", Language.CONFIG: "#"}

_LINT_SETTING = "lint or format setting"
_PINNED_TOOL = "pinned tool"
_CHECK_SCRIPT = "check script"
# A tool reads the nearest of these, so one in any folder counts.
_LINT_FILES = frozenset(
    {
        ".swiftlint.yml",
        ".swiftformat",
        ".editorconfig",
        "pyproject.toml",
        "ruff.toml",
        ".ruff.toml",
        ".shellcheckrc",
        "shellcheckrc",
    }
)
# Pins are read from the root only.
_ROOT_FILES = {
    ".mise.toml": _PINNED_TOOL,
    "requirements.txt": _PINNED_TOOL,
    ".python-version": _PINNED_TOOL,
    ".pre-commit-config.yaml": "hook setting",
    ".github/workflows/ci.yml": "CI workflow",
}
_CHECK_SCRIPT_FOLDER = "scripts/checks/"
# These change what the checks do, so a run that sees one should cover every file.
_NEEDS_FULL_CHECK = frozenset({_LINT_SETTING, _PINNED_TOOL, _CHECK_SCRIPT})

_MAKEFILE = "Makefile"
_MAKEFILE_LINE = "check line in Makefile"
# The edges keep out names such as check-feed, VERSION_CHECK, --check and scripts/tests/checks.
_CHECK_MENTION = re.compile(
    r"(?<![\w./-])(?:check-all|check|fix-all|fix)(?![\w./=-])|(?<![\w-])scripts/checks(?![\w-])"
)
_MAKE_COMMENT = re.compile(r"(?:^|(?<=\s))#.*")


def build_report(added: list[AddedLine], paths: list[str]) -> list[ReportItem]:
    items = {
        ReportItem(Kind.SETTING, what, path, None) for path in paths if (what := _setting_of(path))
    }
    first_lines = {line.path: line.text for line in added if line.line == 1}
    for line in added:
        if not _is_excluded(line.path):
            items.update(_line_items(line, first_lines.get(line.path, "")))
    order = list(Kind)
    return sorted(
        items, key=lambda item: (order.index(item.kind), item.path, item.line or 0, item.what)
    )


def settings_changed(paths: list[str]) -> bool:
    return any(_setting_of(path) in _NEEDS_FULL_CHECK for path in paths)


def _setting_of(path: str) -> str | None:
    if _is_excluded(path):
        return None
    if PurePosixPath(path).name in _LINT_FILES:
        return _LINT_SETTING
    if path.startswith(_CHECK_SCRIPT_FOLDER):
        return _CHECK_SCRIPT
    return _ROOT_FILES.get(path)


def _line_items(line: AddedLine, first_line: str) -> Iterator[ReportItem]:
    if line.path == _MAKEFILE and _CHECK_MENTION.search(_MAKE_COMMENT.sub("", line.text)):
        yield ReportItem(Kind.SETTING, _MAKEFILE_LINE, line.path, line.line)
    for language in _languages(line.path, first_line):
        yield from _matches(Kind.SUPPRESSION, _SUPPRESSIONS.get(language, ()), line, line.text)
        mark = _COMMENT_MARKS.get(language)
        # A construct named in a comment of its own does nothing.
        if mark and not line.text.lstrip().startswith(mark):
            yield from _matches(Kind.RISKY, _RISKY.get(language, ()), line, line.text)


def _languages(path: str, first_line: str) -> tuple[Language, ...]:
    language = language_of(path, first_line)
    if language is not Language.OTHER:
        return (language,)
    # Without its first line, a script with no extension may be either of these.
    return () if PurePosixPath(path).suffix else (Language.SHELL, Language.PYTHON)


def _matches(kind: Kind, patterns: _Patterns, line: AddedLine, text: str) -> Iterator[ReportItem]:
    for what, pattern in patterns:
        if pattern.search(text):
            yield ReportItem(kind, what, line.path, line.line)
