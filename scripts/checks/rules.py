import re
from collections.abc import Iterator

from checks.comments import Comment, read_source
from checks.files import Language
from checks.tools import Finding

AGENTS_LIMIT = 6000
_AGENTS_FILE = "AGENTS.md"
_PROCESS_HOMES = frozenset(
    {
        "Sources/GrabberKit/Onboarding/ProcessRunner.swift",
        "Sources/App/Debug/AppRelauncher.swift",
    }
)
_PROCESS = re.compile(r"(?<![\w$])Process(?!\w)")
_SWIFTUI_IMPORT = re.compile(
    r"(?<![\w.`$])import\s+"
    r"(?:(?:typealias|struct|class|actor|enum|protocol|let|var|func|macro)\s+)?"
    r"`?SwiftUI(?!\w)"
)
# After a dot it is a method such as Combine's, and in backticks it is a name.
_CATCH = re.compile(r"(?<![\w.`$#@])catch(?![\w`])(?!\s*:)")
_BRACKET = re.compile(r"[()\[\]{}]")
_EMPTY_REST = re.compile(r"\s*\}")
# Ticket ids have at least three digits, and a phase is a reference only with its number.
_WORK_REFERENCE = re.compile(r"\b(?:phases?[ \t-]*\d+|mg-\d{3,}\b)", re.I)

_MESSAGES = {
    "process-use": "Process may be used only in ProcessRunner and AppRelauncher",
    "swiftui-in-kit": "GrabberKit must not import SwiftUI",
    "work-reference": "Comment refers to a phase or ticket; say what the code needs instead",
    "empty-catch": "Catch block is empty; handle, pass up or log the error",
}


def check_rules(path: str, text: str, language: Language) -> list[Finding]:
    source = read_source(path, text, language)
    found = {("work-reference", line) for line in _work_reference_lines(source.comments)}
    if language is Language.SWIFT:
        found.update(_swift_faults(path, source.code))
    findings = [Finding("rules", rule, path, line, _MESSAGES[rule]) for rule, line in found]
    findings += source.unreadable
    if path == _AGENTS_FILE:
        findings += _size_faults(path, text)
    return sorted(findings, key=lambda finding: (finding.line or 0, finding.rule))


def _work_reference_lines(comments: list[Comment]) -> Iterator[int]:
    for comment in comments:
        for offset, row in enumerate(comment.text.split("\n")):
            if _WORK_REFERENCE.search(row):
                yield comment.line + offset


def _swift_faults(path: str, code: str) -> Iterator[tuple[str, int]]:
    matches: list[tuple[str, int]] = []
    if path.startswith("Sources/") and path not in _PROCESS_HOMES:
        matches += [("process-use", found.start()) for found in _PROCESS.finditer(code)]
    if path.startswith("Sources/GrabberKit/"):
        matches += [("swiftui-in-kit", found.start()) for found in _SWIFTUI_IMPORT.finditer(code)]
    matches += [
        ("empty-catch", found.start())
        for found in _CATCH.finditer(code)
        if _opens_empty_block(code, found.end())
    ]
    for rule, position in matches:
        yield rule, code.count("\n", 0, position) + 1


# A catch pattern may hold braces of its own, but only inside round or square brackets.
def _opens_empty_block(code: str, start: int) -> bool:
    depth = 0
    for bracket in _BRACKET.finditer(code, start):
        character = bracket.group()
        if character == "{" and depth == 0:
            return _EMPTY_REST.match(code, bracket.end()) is not None
        depth += 1 if character in "([{" else -1
        if depth < 0:
            return False
    return False


def _size_faults(path: str, text: str) -> list[Finding]:
    # A line ending counts once however it is written, so every checkout gets one answer.
    length = len(text.removeprefix("\ufeff").replace("\r\n", "\n"))
    if length <= AGENTS_LIMIT:
        return []
    message = f"{path} has {length} characters; the limit is {AGENTS_LIMIT}"
    return [Finding("rules", "agents-size", path, None, message)]
