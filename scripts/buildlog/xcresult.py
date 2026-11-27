import json
from dataclasses import dataclass, field
from pathlib import Path

from checks.tools import Exec


class XcresultError(Exception):
    pass


@dataclass(frozen=True)
class TestCounts:
    executed: int
    skipped: int
    failures: list[str] = field(default_factory=list)


def _field(entry: object, name: str, kind: type) -> object:
    if not isinstance(entry, dict) or name not in entry:
        raise XcresultError(f"the result summary has no field '{name}'")
    if not isinstance(entry[name], kind):
        raise XcresultError(f"the result summary field '{name}' is not a {kind.__name__}")
    return entry[name]


def _failure(entry: object) -> str:
    target, test, text = (
        _field(entry, name, str) for name in ("targetName", "testIdentifierString", "failureText")
    )
    return f"{target} {test}: {' '.join(text.split())}"


def read_xcresult(bundle: Path, exec: Exec) -> TestCounts:
    argv = ["xcrun", "xcresulttool", "get", "test-results", "summary", "--path", str(bundle)]
    done = exec.run(argv, Path.cwd())
    if done.returncode:
        raise XcresultError(f"xcresulttool exited {done.returncode}: {done.stderr.strip()}")
    try:
        summary = json.loads(done.stdout)
    except ValueError as error:
        raise XcresultError(f"xcresulttool did not print JSON: {error}") from error
    total = _field(summary, "totalTestCount", int)
    skipped = _field(summary, "skippedTests", int)
    failures = [_failure(entry) for entry in _field(summary, "testFailures", list)]
    return TestCounts(total - skipped, skipped, failures)
