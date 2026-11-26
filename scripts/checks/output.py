from dataclasses import dataclass
from itertools import zip_longest
from pathlib import Path

from checks.report import Kind, ReportItem, settings_changed
from checks.tools import Finding, RunResult

CAP = 50
_FULL_MODES = frozenset({"fix-all", "check-all"})
_REPORT_TITLE = "Suppression and settings report"
_NO_BASE = (
    "no usable base to compare with, so there is no report. The check result is not affected."
)
_REMINDER = "A check setting, a pinned tool or the check script changed: run make check-all."
_NOT_STAGED = (
    "The hook edited files and has not staged them. Review and stage the edits, then commit again.",
    "If the edits are rolled back because they overlap unstaged changes, run make fix.",
)


@dataclass
class CheckResult(RunResult):
    checked: int = 0


def render(
    result: CheckResult,
    report: list[ReportItem] | None,
    mode: str,
    log_path: Path,
    cap: int = CAP,
) -> tuple[str, int]:
    stopped = mode == "staged" and bool(result.edited)
    failed = bool(result.findings or result.broken or stopped)
    lines = [_headline(result, failed)]
    for entry in result.broken:
        lines += entry.splitlines()
    lines += _finding_lines(result.findings, cap, log_path)
    lines += _edited_lines(result.edited)
    if stopped:
        lines += _NOT_STAGED
    lines += _report_lines(report, cap, log_path)
    if mode not in _FULL_MODES and _needs_full_check(report):
        lines.append(_REMINDER)
    if failed:
        lines.append(f"Full log: {log_path}")
    return "".join(f"{line}\n" for line in lines), int(failed)


def write_log(path: Path, result: CheckResult, report: list[ReportItem] | None) -> None:
    lines = [result.log.rstrip("\n"), "", "Tool problems:", *result.broken, "", "Findings:"]
    lines += [f"{f.check}: {f.rule}: {_finding_line(f)}" for f in result.findings]
    lines += ["", "Edited files:", *result.edited, "", f"{_REPORT_TITLE}:"]
    lines += [_NO_BASE] if report is None else [_item_line(item) for item in report]
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8", errors="replace")


# The summary file is shared with other CI steps, so it is added to and never replaced.
def write_summary(path: Path, report: list[ReportItem] | None, base: str | None) -> None:
    lines = [f"## {_REPORT_TITLE}", ""]
    if report is None:
        lines.append(f"There is {_NO_BASE}")
    else:
        lines += [f"Compared with {base or 'the last commit'}.", ""]
        if report:
            lines += ["```text", *(_item_line(item) for item in report), "```"]
        else:
            lines.append("Nothing to list.")
    with path.open("a", encoding="utf-8", errors="replace") as summary:
        summary.write("\n".join(lines) + "\n")


def _count(number: int, noun: str) -> str:
    return f"{number} {noun}{'' if number == 1 else 's'}"


def _headline(result: CheckResult, failed: bool) -> str:
    if failed:
        parts = [_count(len(result.findings), "finding")]
        if result.broken:
            parts.append(_count(len(result.broken), "tool problem"))
        return f"Checks failed: {', '.join(parts)}, {_count(result.checked, 'file')} selected"
    if not result.checked:
        return "0 files checked, nothing verified"
    return f"Checks passed: {_count(result.checked, 'file')} checked"


def _finding_line(finding: Finding) -> str:
    place = finding.path if finding.line is None else f"{finding.path}:{finding.line}"
    return f"{place} {' '.join(finding.message.split())}"


def _finding_lines(findings: list[Finding], cap: int, log_path: Path) -> list[str]:
    groups: dict[tuple[str, str], list[Finding]] = {}
    for finding in findings:
        groups.setdefault((finding.check, finding.rule), []).append(finding)
    # One each in turn, so a rule with many findings cannot hide what the others look like.
    turns = zip_longest(*([(key, n) for n in range(len(found))] for key, found in groups.items()))
    shown = [slot[0] for turn in turns for slot in turn if slot][:cap]
    lines = []
    for key, found in groups.items():
        lines.append(f"{key[0]}: {key[1]} ({len(found)})")
        lines += [f"  {_finding_line(finding)}" for finding in found[: shown.count(key)]]
    if omitted := len(findings) - len(shown):
        lines.append(f"{_count(omitted, 'more finding')} not shown. Full log: {log_path}")
    return lines


def _edited_lines(edited: list[str]) -> list[str]:
    if not edited:
        return []
    return [f"Edited {_count(len(edited), 'file')}:", *(f"  {path}" for path in edited)]


def _item_line(item: ReportItem) -> str:
    place = item.path if item.line is None else f"{item.path}:{item.line}"
    return f"{item.kind.value}: {place} ({item.what})"


def _report_lines(report: list[ReportItem] | None, cap: int, log_path: Path) -> list[str]:
    if report is None:
        return [f"{_REPORT_TITLE}: {_NO_BASE}"]
    if not report:
        return []
    lines = [f"{_REPORT_TITLE}:", *(f"  {_item_line(item)}" for item in report[:cap])]
    if omitted := len(report[cap:]):
        lines.append(f"{_count(omitted, 'more report item')} not shown. Full log: {log_path}")
    return lines


def _needs_full_check(report: list[ReportItem] | None) -> bool:
    return settings_changed([item.path for item in report or [] if item.kind is Kind.SETTING])
