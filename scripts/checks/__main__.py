import argparse
import sys
from collections.abc import Mapping
from pathlib import Path
from typing import NamedTuple, TextIO

# Run as a folder, Python puts only that folder on the path, where the package cannot be found.
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from checks.comments import check_comments
from checks.files import Language, select
from checks.output import CheckResult, render, write_log, write_summary
from checks.repo import GitError, GitRepo, Repo, Scope
from checks.report import ReportItem, build_report
from checks.rules import check_rules
from checks.tools import Exec, Finding, SystemExec, run_tools

_ROOT = Path(__file__).resolve().parents[2]


class _Mode(NamedTuple):
    scope: Scope
    fix: bool


_MODES = {
    "fix": _Mode(Scope.CHANGED, True),
    "check": _Mode(Scope.CHANGED, False),
    "fix-all": _Mode(Scope.ALL, True),
    "check-all": _Mode(Scope.ALL, False),
    "staged": _Mode(Scope.STAGED, True),
}
_CHECKED_LANGUAGES = (Language.SWIFT, Language.SHELL, Language.PYTHON, Language.CONFIG)
# No language covers it, but the size rule applies to it.
_AGENTS_FILE = "AGENTS.md"


def _arguments(argv: list[str] | None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(prog="scripts/checks", description="Run the project checks.")
    parser.add_argument("mode", choices=_MODES, help="which files to check, and whether to fix")
    parser.add_argument("--summary-base", metavar="REF", help="compare the report with this commit")
    parser.add_argument("--summary-file", metavar="PATH", help="add the report to this file")
    return parser.parse_args(argv)


def _text_checks(selection: Mapping[Language, list[str]], root: Path) -> tuple[list[Finding], int]:
    targets = [(path, language) for language in _CHECKED_LANGUAGES for path in selection[language]]
    targets += [
        (path, Language.OTHER) for path in selection[Language.OTHER] if path == _AGENTS_FILE
    ]
    findings = []
    for path, language in sorted(targets, key=lambda target: target[0]):
        text = (root / path).read_bytes().decode(errors="replace")
        findings += check_comments(path, text, language)
        findings += check_rules(path, text, language)
    # Both checks report a file they cannot read, in the same words.
    return list(dict.fromkeys(findings)), len(targets)


def _compare(repo: Repo, scope: Scope, base: str) -> tuple[list[ReportItem] | None, str]:
    try:
        paths = repo.changed_since(scope, base)
        added = repo.added_lines(scope, base)
    except GitError as error:
        # The comparison is only for show, so it must not change the result.
        return None, f"Report base {base!r}: {error}\n"
    if paths is None or added is None:
        return None, f"Report base {base!r} is not a commit here\n"
    return build_report(added, paths), ""


def _report(repo: Repo, scope: Scope, base: str | None) -> tuple[list[ReportItem] | None, str]:
    if base is not None:
        return _compare(repo, scope, base)
    # The report is about what changed, even when every file is checked.
    changed = Scope.CHANGED if scope is Scope.ALL else scope
    return build_report(repo.added_lines(changed), repo.paths(changed)), ""


def _check(args: argparse.Namespace, root: Path, repo: Repo, executor: Exec) -> tuple[str, int]:
    mode = _MODES[args.mode]
    selection = select(repo.paths(mode.scope), root)
    ran = run_tools(selection, root, mode.fix, executor)
    # Read after the tools, so that line numbers match the files a fix has rewritten.
    found, checked = _text_checks(selection, root)
    report, note = _report(repo, mode.scope, args.summary_base)
    result = CheckResult(ran.findings + found, ran.edited, ran.broken, ran.log + note, checked)
    log_path = Path("build/logs") / f"checks-{args.mode}.log"
    write_log(root / log_path, result, report)
    text, status = render(result, report, args.mode, log_path)
    if args.summary_file is not None:
        try:
            write_summary(Path(args.summary_file), report, args.summary_base)
        except OSError as error:
            return f"{text}Could not write the summary file: {error}\n", 1
    return text, status


def main(
    argv: list[str] | None = None,
    *,
    root: Path = _ROOT,
    repo: Repo | None = None,
    executor: Exec | None = None,
    out: TextIO | None = None,
) -> int:
    args = _arguments(argv)
    try:
        text, status = _check(args, root, repo or GitRepo(root), executor or SystemExec())
    except (GitError, OSError) as error:
        text, status = f"Checks could not run, so nothing is verified: {error}\n", 1
    (out or sys.stdout).write(text)
    return status


if __name__ == "__main__":
    sys.exit(main())
