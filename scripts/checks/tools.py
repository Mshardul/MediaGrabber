import json
import os
import re
import shlex
import subprocess
import tomllib
import unicodedata
from collections.abc import Callable, Mapping
from dataclasses import dataclass, field
from pathlib import Path
from typing import NamedTuple, Protocol

from checks.files import Language


@dataclass(frozen=True)
class Finding:
    check: str
    rule: str
    path: str
    line: int | None
    message: str


@dataclass
class RunResult:
    findings: list[Finding] = field(default_factory=list)
    edited: list[str] = field(default_factory=list)
    broken: list[str] = field(default_factory=list)
    log: str = ""


@dataclass(frozen=True)
class Completed:
    returncode: int
    stdout: str
    stderr: str


class Exec(Protocol):
    def run(self, argv: list[str], cwd: Path) -> Completed: ...


# Either one makes a tool drop rules and still report a pass.
_SILENCERS = ("SWIFTLINT_DISABLE_SOURCEKIT", "SHELLCHECK_OPTS")


class SystemExec(Exec):
    def run(self, argv: list[str], cwd: Path) -> Completed:
        environment = {name: value for name, value in os.environ.items() if name not in _SILENCERS}
        done = subprocess.run(
            argv,
            cwd=cwd,
            env=environment,
            stdin=subprocess.DEVNULL,
            capture_output=True,
            check=False,
        )
        return Completed(
            done.returncode,
            done.stdout.decode(errors="replace"),
            done.stderr.decode(errors="replace"),
        )


class _Report(NamedTuple):
    rule: str
    path: str
    line: int | None
    message: str


Parser = Callable[[Completed], list[_Report]]


def _entries(value: object) -> list:
    if not isinstance(value, list):
        raise ValueError("expected a list")
    return value


def _lint_reports(done: Completed) -> list[_Report]:
    return [
        _Report(entry["rule_id"], entry["file"], entry["line"], entry["reason"])
        for entry in _entries(json.loads(done.stdout))
    ]


def _shellcheck_reports(done: Completed) -> list[_Report]:
    return [
        _Report(f"SC{entry['code']}", entry["file"], entry["line"], entry["message"])
        for entry in _entries(json.loads(done.stdout)["comments"])
    ]


def _ruff_reports(done: Completed) -> list[_Report]:
    return [
        _Report(
            entry["code"],
            entry["filename"],
            (entry["location"] or {}).get("row"),
            entry["message"],
        )
        for entry in _entries(json.loads(done.stdout))
    ]


_SHFMT_ERROR = re.compile(r"(.+?):(\d+):\d+: (.+)")


def _shfmt_reports(done: Completed) -> list[_Report]:
    reports = [
        _Report("format", path, None, "File is not formatted")
        for path in done.stdout.split("\0")
        if path
    ]
    for line in done.stderr.splitlines():
        error = _SHFMT_ERROR.fullmatch(line)
        if not error:
            raise ValueError(line)
        path, number, message = error.groups()
        reports.append(_Report("parse-error", path, int(number), message))
    return reports


# A tool that leaves a file out can still exit 0, so its own account of the run is checked too.
Doubt = Callable[[Completed, int], str | None]


def _count_doubt(summary: re.Pattern[str], done: Completed, expected: int) -> str | None:
    found = summary.search(done.stderr)
    if found and int(found.group(1)) == expected:
        return None
    return f"did not confirm that it read all {expected} files"


_FORMAT_SUMMARY = re.compile(r"^\d+/(\d+) files? (?:requires? formatting|formatted)", re.M)
_LINT_SUMMARY = re.compile(r"^Done linting! .* in (\d+) files?\.", re.M)
_NO_SOURCEKIT = re.compile(r"^warning: .*requires SourceKit", re.M)


def _swiftformat_doubt(done: Completed, expected: int) -> str | None:
    return _count_doubt(_FORMAT_SUMMARY, done, expected)


def _swiftlint_doubt(done: Completed, expected: int) -> str | None:
    if _NO_SOURCEKIT.search(done.stderr):
        return "skipped a rule that needs SourceKit"
    return _count_doubt(_LINT_SUMMARY, done, expected)


def _ruff_doubt(done: Completed, expected: int) -> str | None:
    return "checked nothing" if "No Python files found" in done.stderr else None


def _no_doubt(done: Completed, expected: int) -> str | None:
    return None


@dataclass(frozen=True)
class _Step:
    arguments: tuple[str, ...]
    # Without a parser, only exit status 0 is a success.
    parse: Parser | None = None
    findings_status: int = 1


@dataclass(frozen=True)
class _Tool:
    name: str
    binary: str
    language: Language
    check: _Step
    fix: _Step | None = None
    doubt: Doubt = _no_doubt


_SWIFTFORMAT = _Tool(
    "swiftformat",
    "swiftformat",
    Language.SWIFT,
    check=_Step(("--lint", "--reporter", "json"), _lint_reports),
    fix=_Step(()),
    doubt=_swiftformat_doubt,
)
# Any format flag would make shfmt ignore .editorconfig.
_SHFMT = _Tool(
    "shfmt",
    "shfmt",
    Language.SHELL,
    check=_Step(("-l=0",), _shfmt_reports),
    fix=_Step(("-w",), _shfmt_reports),
)
_RUFF_LINT = ("check", "--force-exclude", "--no-unsafe-fixes", "--output-format=json")
_RUFF = _Tool(
    "ruff",
    "ruff",
    Language.PYTHON,
    check=_Step((*_RUFF_LINT, "--no-fix"), _ruff_reports),
    fix=_Step((*_RUFF_LINT, "--fix"), _ruff_reports),
    doubt=_ruff_doubt,
)
_RUFF_FORMAT = _Tool(
    "ruff-format",
    "ruff",
    Language.PYTHON,
    check=_Step(("format", "--force-exclude", "--check", "--output-format=json"), _ruff_reports),
    fix=_Step(("format", "--force-exclude")),
    doubt=_ruff_doubt,
)
_SWIFTLINT = _Tool(
    "swiftlint",
    "swiftlint",
    Language.SWIFT,
    check=_Step(
        ("lint", "--strict", "--force-exclude", "--reporter", "json"),
        _lint_reports,
        findings_status=2,
    ),
    doubt=_swiftlint_doubt,
)
_SHELLCHECK = _Tool(
    "shellcheck",
    "shellcheck",
    Language.SHELL,
    # A settings file, personal or committed, could silence a finding.
    check=_Step(("--norc", "-x", "--format=json1"), _shellcheck_reports),
)

_FIX_ORDER = (_RUFF, _SWIFTFORMAT, _SHFMT, _RUFF_FORMAT)
_CHECK_ORDER = (_SWIFTFORMAT, _SHFMT, _RUFF, _RUFF_FORMAT, _SWIFTLINT, _SHELLCHECK)


class _Unavailable(Exception):
    def __init__(self, reason: str, output: str = ""):
        super().__init__(reason)
        self.reason = reason
        self.output = output


class _Run:
    def __init__(self, root: Path, executor: Exec):
        self.root = root
        self.result = RunResult()
        self._executor = executor
        self._binaries: dict[str, str | _Unavailable] = {}
        self._log: list[str] = []

    def command(self, argv: list[str]) -> Completed:
        self._log.append(f"$ {shlex.join(argv)}\n")
        try:
            done = self._executor.run(argv, self.root)
        except OSError as error:
            self._log.append(f"{error}\n")
            raise _Unavailable(f"could not run: {error}") from error
        self._log.append(f"[exit {done.returncode}]\n{_joined(done)}")
        return done

    def broken(self, tool: str, reason: str, output: str = "") -> None:
        entry = "\n".join([f"{tool}: {reason}", *output.splitlines()[-20:]])
        if entry not in self.result.broken:
            self.result.broken.append(entry)

    def binary(self, name: str) -> str:
        if name not in self._binaries:
            try:
                self._binaries[name] = self._ruff() if name == "ruff" else self._from_mise(name)
            except _Unavailable as problem:
                self._binaries[name] = problem
        found = self._binaries[name]
        if isinstance(found, _Unavailable):
            raise found
        return found

    def log(self) -> str:
        return "".join(self._log)

    def _answer(self, argv: list[str]) -> str:
        done = self.command(argv)
        if done.returncode != 0 or not done.stdout.strip():
            raise _Unavailable(f"is missing: {shlex.join(argv)} failed", _joined(done))
        return done.stdout.strip()

    def _from_mise(self, name: str) -> str:
        try:
            pins = tomllib.loads((self.root / ".mise.toml").read_text())["tools"]
        except (OSError, ValueError, KeyError) as error:
            raise _Unavailable(f"has no readable pin in .mise.toml: {error!r}") from error
        pin = pins.get(name)
        if isinstance(pin, dict):
            pin = pin.get("version")
        if not isinstance(pin, str):
            raise _Unavailable("is not pinned in .mise.toml")
        path = self._answer(["mise", "which", name])
        _require_version(self._answer(["mise", "which", "--version", name]), pin)
        return path

    def _ruff(self) -> str:
        try:
            requirements = (self.root / "requirements.txt").read_text()
        except (OSError, ValueError) as error:
            raise _Unavailable(f"has no readable pin in requirements.txt: {error!r}") from error
        pin = re.search(r"^ruff==([^\s;#]+)", requirements, re.M)
        if not pin:
            raise _Unavailable("is not pinned in requirements.txt")
        path = str(self.root / ".venv/bin/ruff")
        _require_version(self._answer([path, "--version"]).removeprefix("ruff "), pin.group(1))
        return path


def _require_version(found: str, pin: str) -> None:
    if found != pin:
        raise _Unavailable(f"is version {found}, but the pin is {pin}")


def _joined(done: Completed) -> str:
    streams = (done.stdout, done.stderr)
    return "".join(text if text.endswith("\n") else f"{text}\n" for text in streams if text)


# A name starting with a dash would otherwise be read as an option.
def _argument(path: str) -> str:
    return f"./{path}" if path.startswith("-") else path


# SwiftFormat splits a name at commas, which rewrites other files, and globs one with braces.
def _expands(path: str) -> bool:
    return any(character in path for character in ",{}")


def _canonical(root: Path, path: str) -> str:
    # Tools spell one file differently: absolute or relative, and through links such as /tmp.
    relative = os.path.relpath(os.path.realpath(root / path), os.path.realpath(root))
    return unicodedata.normalize("NFC", relative)


def _run_step(run: _Run, tool: _Tool, step: _Step, files: list[str]) -> list[Finding]:
    try:
        binary = run.binary(tool.binary)
        done = run.command([binary, *step.arguments, *map(_argument, files)])
    except _Unavailable as problem:
        run.broken(tool.name, problem.reason, problem.output)
        return []

    def broken(reason: str) -> None:
        run.broken(tool.name, f"{reason} (exit status {done.returncode})", _joined(done))

    reports: list[_Report] = []
    if step.parse:
        try:
            reports = step.parse(done)
        except ValueError, KeyError, TypeError, AttributeError:
            broken("gave output that could not be read")
            return []
    allowed = {0, step.findings_status} if reports else {0}
    if done.returncode not in allowed:
        broken("failed")
    elif doubt := tool.doubt(done, len(files)):
        broken(doubt)

    given = {_canonical(run.root, path): path for path in files}
    findings = []
    for report in reports:
        key = _canonical(run.root, report.path)
        if key not in given:
            broken(f"reported a file it was not given: {key}")
        path = given.get(key, key)
        findings.append(Finding(tool.name, report.rule, path, report.line, report.message))
    return findings


def _check_ruff_reads_all(run: _Run, tools: list[_Tool], files: list[str]) -> None:
    # Ruff drops a file that its settings exclude without saying so when others remain.
    try:
        binary = run.binary("ruff")
        arguments = ["check", "--force-exclude", "--show-files", *map(_argument, files)]
        done = run.command([binary, *arguments])
    except _Unavailable:
        return
    shown = {_canonical(run.root, line) for line in done.stdout.splitlines() if line}
    missing = [path for path in files if _canonical(run.root, path) not in shown]
    if done.returncode == 0 and not missing:
        return
    for tool in tools:
        run.broken(tool.name, f"would not check: {', '.join(missing)}", _joined(done))


def _plan_files(run: _Run, selection: Mapping[Language, list[str]]) -> dict[str, list[str]]:
    usable: dict[Language, list[str]] = {}
    for language in {tool.language for tool in _CHECK_ORDER}:
        usable[language] = []
        for path in selection.get(language, []):
            # A tool given a directory or a missing path may go on to check other files.
            if (run.root / path).is_file() and not (run.root / path).is_symlink():
                usable[language].append(path)
            else:
                run.broken("files", f"not a file, so no tool was given it: {path}")
    files = {tool.name: usable[tool.language] for tool in _CHECK_ORDER}
    if unsafe := [path for path in files[_SWIFTFORMAT.name] if _expands(path)]:
        reason = "reads commas and braces in a name as a pattern, so rename: "
        run.broken(_SWIFTFORMAT.name, reason + ", ".join(unsafe))
        files[_SWIFTFORMAT.name] = [path for path in usable[Language.SWIFT] if not _expands(path)]
    return files


def _contents(root: Path, paths: set[str]) -> dict[str, bytes | None]:
    return {path: (root / path).read_bytes() if (root / path).is_file() else None for path in paths}


def run_tools(
    selection: Mapping[Language, list[str]], root: Path, fix: bool, exec: Exec
) -> RunResult:
    run = _Run(root.resolve(), exec)
    files = _plan_files(run, selection)
    before = _contents(run.root, {path for paths in files.values() for path in paths})
    if python := files[_RUFF.name]:
        _check_ruff_reads_all(run, [_RUFF, _RUFF_FORMAT], python)
    if fix:
        for tool in _FIX_ORDER:
            if files[tool.name]:
                # The check pass below reports whatever the fix pass leaves.
                _run_step(run, tool, tool.fix, files[tool.name])
    for tool in _CHECK_ORDER:
        if files[tool.name]:
            run.result.findings += _run_step(run, tool, tool.check, files[tool.name])
    after = _contents(run.root, set(before))
    run.result.edited = sorted(path for path in before if before[path] != after[path])
    run.result.log = run.log()
    return run.result
