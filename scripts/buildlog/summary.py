import re
from collections import Counter
from collections.abc import Mapping

from buildlog.xcresult import TestCounts

CAP = 50
TAIL_LINES = 40
_LINE_LIMIT = 500

# A source location needs a column here, or a failed assertion would pass for a compiler error.
_COMPILER_ERROR = re.compile(
    r"(?:.*?:\d+:\d+: |(?:clang|ld|swiftc?|xcodebuild): )?(?:fatal )?error: "
)
_FAILED_TEST = re.compile(r"(?:FAIL|ERROR|FAILED): \S")
_WARNING = re.compile(r"(?:^|: )warning: ")
_SCRIPTS_RUN = re.compile(r"^script tests: (\d+) run, \d+ failed", re.M)
_UNITTEST_RUN = re.compile(r"^Ran (\d+) tests? in ", re.M)
_UNITTEST_SKIPPED = re.compile(r"^(?:OK|FAILED) \(.*?\bskipped=(\d+)", re.M)


def _last_number(pattern: re.Pattern[str], text: str) -> int:
    found = pattern.findall(text)
    return int(found[-1]) if found else 0


# A count that cannot be found reads as zero, which fails the stage.
def unittest_counts(output: str) -> TestCounts:
    skipped = _last_number(_UNITTEST_SKIPPED, output)
    return TestCounts(_last_number(_UNITTEST_RUN, output) - skipped, skipped)


# Script tests print the counts of the suites they run, so only the runner's own line is read.
def script_counts(output: str) -> TestCounts:
    return TestCounts(_last_number(_SCRIPTS_RUN, output), 0)


def count_line(name: str, counts: TestCounts | None) -> str:
    if counts is None:
        return f"{name}: not run"
    skipped = f", {counts.skipped} skipped" if counts.skipped else ""
    return f"{name}: {counts.executed} executed{skipped}"


def counts_lines(stages: list[str], counts: Mapping[str, TestCounts]) -> list[str]:
    return [count_line(name, counts.get(name)) for name in stages]


def _shorten(line: str) -> str:
    return line if len(line) <= _LINE_LIMIT else f"{line[:_LINE_LIMIT]} [cut]"


def failure_lines(output: str, compiles: bool, failures: list[str], log: str) -> list[str]:
    # Test stages without a compiler print "error:" in passing cases, so only their failures count.
    pattern = _COMPILER_ERROR if compiles else _FAILED_TEST
    found = Counter(line.strip() for line in output.splitlines() if pattern.match(line.strip()))
    found.update(failures)
    if found:
        shown = list(found.items())[:CAP]
        lines = [
            _shorten(line) + (f" ({times} times)" if times > 1 else "") for line, times in shown
        ]
        if omitted := len(found) - len(shown):
            lines.append(f"{omitted} more not shown. Full log: {log}")
        return lines
    tail = [line for line in output.splitlines() if not _WARNING.search(line)][-TAIL_LINES:]
    return ["End of the stage's output:", *(_shorten(line) for line in tail)]
