import io
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from checks.__main__ import main
from checks.output import CheckResult, render
from checks.repo import AddedLine, GitError, GitRepo, Scope
from checks.report import Kind, ReportItem
from checks.tools import Finding
from test_files import FakeGit, nul
from test_tools import PINS, RUFF_PIN, FakeExec, done

REPO = Path(__file__).resolve().parents[3]
LOG = Path("build/logs/checks-check.log")
MODES = ("fix", "check", "fix-all", "check-all", "staged")


class FakeRepo:
    def __init__(self):
        self.listed = {scope: [] for scope in Scope}
        self.added = []
        self.since = None
        self.added_since = None
        self.fail = None
        self.calls = []

    def paths(self, scope):
        self.calls.append(("paths", scope))
        if self.fail == "paths":
            raise GitError("git diff exited 128: fatal: broken")
        return list(self.listed[scope])

    def added_lines(self, scope, base=None):
        self.calls.append(("added_lines", scope, base))
        if base is not None:
            if self.fail == "base":
                raise GitError("git diff exited 128: fatal: bad object")
            return self.added_since
        return list(self.added)

    def changed_since(self, scope, base):
        self.calls.append(("changed_since", scope, base))
        return self.since


class CliTestCase(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name).resolve()
        pins = "".join(f'{name} = "{version}"\n' for name, version in PINS.items())
        self.write(".mise.toml", f"[tools]\n{pins}")
        self.write("requirements.txt", f"ruff=={RUFF_PIN}\n")
        self.repo = FakeRepo()
        self.exec = FakeExec()

    def write(self, path, content="key: value\n"):
        target = self.root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content)

    def change(self, *paths, scope=Scope.CHANGED, content="key: value\n"):
        for path in paths:
            self.write(path, content)
        self.repo.listed[scope] += paths

    def run_cli(self, *argv, repo=None):
        out = io.StringIO()
        status = main(
            list(argv), root=self.root, repo=repo or self.repo, executor=self.exec, out=out
        )
        return status, out.getvalue()

    def log(self, mode="check"):
        return (self.root / f"build/logs/checks-{mode}.log").read_text()

    def snapshot(self):
        return {
            path.relative_to(self.root).as_posix(): path.read_bytes()
            for path in self.root.rglob("*")
            if path.is_file() and not path.is_relative_to(self.root / "build")
        }

    def rewrite(self, tool, path, content="y = 1\n"):
        self.exec.actions[(tool, True)] = lambda cwd: (cwd / path).write_text(content)


class ResultTests(CliTestCase):
    def test_clean_run_prints_one_line_and_exits_0(self):
        self.change("a.yml", "a.py", "Sources/A.swift", "run.sh", content="")
        status, output = self.run_cli("check")
        self.assertEqual(status, 0, output)
        self.assertEqual(output, "Checks passed: 4 files checked\n")

    def test_one_file_is_counted_in_the_singular(self):
        self.change("a.yml")
        self.assertEqual(self.run_cli("check")[1], "Checks passed: 1 file checked\n")

    def test_no_files_says_nothing_verified(self):
        for mode in MODES:
            with self.subTest(mode=mode):
                status, output = self.run_cli(mode)
                self.assertEqual((status, output), (0, "0 files checked, nothing verified\n"))
        self.assertEqual(self.exec.calls, [])

    def test_only_excluded_or_unchecked_files_says_nothing_verified(self):
        self.change("scripts/support/x.sh", "build/x.py", "README.md", "image.png")
        status, output = self.run_cli("check")
        self.assertEqual((status, output), (0, "0 files checked, nothing verified\n"))
        self.assertEqual(self.exec.calls, [])

    def test_edited_files_are_named_on_a_pass(self):
        self.change("a.py", "b.py", content="x = 1\n")
        self.rewrite("ruff-format", "a.py")
        status, output = self.run_cli("fix")
        self.assertEqual(status, 0, output)
        self.assertEqual(output, "Checks passed: 2 files checked\nEdited 1 file:\n  a.py\n")

    def test_comment_and_rule_findings_fail_the_run(self):
        self.change("a.yml", content="# one\n# two\nkey: value\n")
        self.change("Sources/GrabberKit/A.swift", content="import SwiftUI\n")
        status, output = self.run_cli("check")
        self.assertEqual(status, 1, output)
        self.assertIn("comments: stacked-comment (1)\n  a.yml:1 ", output)
        self.assertIn("rules: swiftui-in-kit (1)\n  Sources/GrabberKit/A.swift:1 ", output)
        self.assertIn(f"Full log: {LOG}\n", output)

    def test_unparsable_file_is_reported_once(self):
        self.change("a.py", content="def (:\n")
        _, output = self.run_cli("check")
        self.assertEqual(output.count("a.py:1 Comments could not be checked"), 1, output)

    def test_agents_limit_is_checked_though_no_tool_reads_markdown(self):
        self.change("AGENTS.md", content="a" * 6001)
        status, output = self.run_cli("check")
        self.assertEqual(status, 1, output)
        self.assertIn("rules: agents-size (1)\n  AGENTS.md AGENTS.md has 6001", output)

    def test_broken_tool_exits_nonzero(self):
        self.change("a.py", content="x = 1\n")
        crash = "".join(f"trace {number}\n" for number in range(40))
        self.exec.replies[("ruff", False)] = done(2, stderr=crash)
        status, output = self.run_cli("check")
        self.assertEqual(status, 1, output)
        self.assertNotIn("passed", output)
        self.assertIn("ruff: ", output)
        self.assertIn("trace 39", output)
        self.assertIn("trace 20\n", output)
        self.assertNotIn("trace 19\n", output)
        self.assertIn("trace 0\n", self.log())

    def test_unpinned_tool_fails_and_is_named(self):
        self.change("run.sh", content="")
        self.write(".mise.toml", '[tools]\nshellcheck = "0.11.0"\n')
        status, output = self.run_cli("check")
        self.assertEqual(status, 1, output)
        self.assertIn("shfmt: is not pinned in .mise.toml", output)

    def test_git_failure_is_a_failure_with_a_plain_message(self):
        self.repo.fail = "paths"
        status, output = self.run_cli("check")
        self.assertEqual(status, 1)
        self.assertIn("Checks could not run", output)
        self.assertIn("fatal: broken", output)
        self.assertNotIn("passed", output)

    def test_unwritable_log_is_a_failure_with_a_plain_message(self):
        self.change("a.yml")
        self.write("build/logs", "a file where the folder belongs\n")
        status, output = self.run_cli("check")
        self.assertEqual(status, 1, output)
        self.assertIn("Checks could not run", output)

    def test_unknown_mode_exits_nonzero(self):
        with self.assertRaises(SystemExit) as raised, mock.patch("sys.stderr"):
            self.run_cli("lint")
        self.assertEqual(raised.exception.code, 2)


class SelectionThroughCommandTests(CliTestCase):
    def test_deleted_renamed_and_spaced_paths_check_only_files_that_exist(self):
        self.write("Docs Folder/new name.yml")
        self.write("unrelated.yml", "# one\n# two\n")
        git = FakeGit(tracked=nul("gone.yml", "old name.yml", "Docs Folder/new name.yml"))
        status, output = self.run_cli("check", repo=GitRepo(self.root, git))
        self.assertEqual((status, output), (0, "Checks passed: 1 file checked\n"))

    def test_untracked_file_in_a_new_directory_is_checked(self):
        self.write("brand/new/deep.yml", "# one\n# two\n")
        git = FakeGit(untracked=nul("brand/new/deep.yml"))
        status, output = self.run_cli("check", repo=GitRepo(self.root, git))
        self.assertEqual(status, 1, output)
        self.assertIn("brand/new/deep.yml:1 ", output)

    def test_each_mode_reads_its_own_set_of_files(self):
        scopes = {
            "fix": Scope.CHANGED,
            "check": Scope.CHANGED,
            "fix-all": Scope.ALL,
            "check-all": Scope.ALL,
            "staged": Scope.STAGED,
        }
        for mode, scope in scopes.items():
            with self.subTest(mode=mode):
                self.repo = FakeRepo()
                self.change("a.yml", scope=scope)
                self.assertEqual(self.run_cli(mode)[1], "Checks passed: 1 file checked\n")
                self.assertEqual(self.repo.calls[0], ("paths", scope))

    def test_report_covers_changes_even_when_every_file_is_checked(self):
        self.change(".swiftlint.yml", "a.yml", scope=Scope.ALL)
        status, output = self.run_cli("check-all")
        self.assertEqual((status, output), (0, "Checks passed: 2 files checked\n"))
        self.assertIn(("paths", Scope.CHANGED), self.repo.calls)

    def test_staged_report_reads_only_the_index(self):
        self.change("a.yml", scope=Scope.STAGED)
        self.run_cli("staged")
        self.assertIn(("added_lines", Scope.STAGED, None), self.repo.calls)
        self.assertNotIn(("paths", Scope.CHANGED), self.repo.calls)


class EditTests(CliTestCase):
    def tree(self, scope):
        self.change("a.py", "run.sh", "Sources/A.swift", "a.yml", scope=scope, content="")

    def test_check_modes_never_edit(self):
        for mode, scope in (("check", Scope.CHANGED), ("check-all", Scope.ALL)):
            with self.subTest(mode=mode):
                self.repo, self.exec = FakeRepo(), FakeExec()
                self.tree(scope)
                for tool in ("ruff", "ruff-format", "shfmt", "swiftformat", "swiftlint"):
                    self.rewrite(tool, "a.py")
                before = self.snapshot()
                status, output = self.run_cli(mode)
                self.assertEqual(status, 0, output)
                self.assertTrue(self.exec.tool_calls())
                self.assertFalse(
                    [argv for argv in self.exec.tool_calls() if self.exec.writes(argv)]
                )
                self.assertEqual(self.snapshot(), before)

    def test_fix_modes_let_tools_write(self):
        modes = (("fix", Scope.CHANGED), ("fix-all", Scope.ALL), ("staged", Scope.STAGED))
        for mode, scope in modes:
            with self.subTest(mode=mode):
                self.repo, self.exec = FakeRepo(), FakeExec()
                self.tree(scope)
                self.run_cli(mode)
                self.assertTrue([argv for argv in self.exec.tool_calls() if self.exec.writes(argv)])

    def test_staged_edit_exits_nonzero_and_mentions_make_fix(self):
        self.change("a.py", scope=Scope.STAGED, content="x=1\n")
        self.rewrite("ruff-format", "a.py")
        status, output = self.run_cli("staged")
        self.assertEqual(status, 1, output)
        self.assertNotIn("passed", output)
        self.assertIn("Edited 1 file:\n  a.py\n", output)
        self.assertIn("not staged", output)
        self.assertIn("rolled back", output)
        self.assertIn("make fix", output)

    def test_staged_leftover_without_an_edit_exits_nonzero(self):
        self.change("a.yml", scope=Scope.STAGED, content="# one\n# two\n")
        status, output = self.run_cli("staged")
        self.assertEqual(status, 1, output)
        self.assertNotIn("rolled back", output)

    def test_clean_staged_run_exits_0(self):
        self.change("a.yml", scope=Scope.STAGED)
        self.assertEqual(self.run_cli("staged"), (0, "Checks passed: 1 file checked\n"))

    def test_failing_fix_run_still_names_what_it_edited(self):
        self.change("a.py", content="x=1\n")
        self.change("a.yml", content="# one\n# two\n")
        self.rewrite("ruff-format", "a.py")
        status, output = self.run_cli("fix")
        self.assertEqual(status, 1, output)
        self.assertIn("Edited 1 file:\n  a.py\n", output)
        self.assertNotIn("rolled back", output)

    def test_findings_are_read_after_the_fix(self):
        self.change("a.py", content="# one\n# two\nx = 1\n")
        self.rewrite("ruff-format", "a.py", "x = 1\n")
        status, output = self.run_cli("fix")
        self.assertEqual(status, 0, output)


class ReportOutputTests(CliTestCase):
    def test_report_alone_keeps_exit_0(self):
        for mode, scope in (("check", Scope.CHANGED), ("staged", Scope.STAGED)):
            with self.subTest(mode=mode):
                self.repo = FakeRepo()
                self.change("run.yml", scope=scope)
                self.repo.added = [AddedLine("run.yml", 7, "run: make test || true")]
                status, output = self.run_cli(mode)
                self.assertEqual(status, 0, output)
                self.assertEqual(
                    output,
                    "Checks passed: 1 file checked\n"
                    "Suppression and settings report:\n"
                    "  risky: run.yml:7 (|| true)\n",
                )

    def test_report_shows_when_no_file_can_be_checked(self):
        self.repo.listed[Scope.CHANGED] = [".swiftlint.yml"]
        status, output = self.run_cli("check")
        self.assertEqual(status, 0, output)
        self.assertTrue(output.startswith("0 files checked, nothing verified\n"), output)
        self.assertIn("  setting: .swiftlint.yml (lint or format setting)\n", output)

    def test_settings_change_prints_one_check_all_reminder(self):
        for mode, scope in (
            ("fix", Scope.CHANGED),
            ("check", Scope.CHANGED),
            ("staged", Scope.STAGED),
        ):
            with self.subTest(mode=mode):
                self.repo = FakeRepo()
                self.change(".swiftlint.yml", ".mise.toml.example.yml", scope=scope)
                self.repo.listed[scope] += ["requirements.txt", "scripts/checks/deleted.py"]
                _, output = self.run_cli(mode)
                self.assertEqual(output.count("make check-all"), 1, output)

    def test_full_runs_and_other_settings_print_no_reminder(self):
        self.repo.listed[Scope.CHANGED] = [".swiftlint.yml"]
        for mode in ("fix-all", "check-all"):
            with self.subTest(mode=mode):
                self.assertNotIn("make check-all", self.run_cli(mode)[1])
        self.repo.listed[Scope.CHANGED] = [".pre-commit-config.yaml", ".github/workflows/ci.yml"]
        self.assertNotIn("make check-all", self.run_cli("check")[1])

    def test_unusable_summary_base_is_stated_and_status_unchanged(self):
        for content, expected in (("key: value\n", 0), ("# one\n# two\n", 1)):
            for failure in (None, "base"):
                with self.subTest(expected=expected, failure=failure):
                    self.repo = FakeRepo()
                    self.repo.fail = failure
                    self.change("a.yml", scope=Scope.ALL, content=content)
                    summary = self.root / "build/summary.md"
                    summary.unlink(missing_ok=True)
                    status, output = self.run_cli(
                        "check-all", "--summary-base", "0000000", "--summary-file", str(summary)
                    )
                    self.assertEqual(status, expected, output)
                    self.assertIn("no usable base", output)
                    self.assertIn("no usable base", summary.read_text())
                    self.assertNotIn("Nothing to list", summary.read_text())

    def test_empty_summary_base_is_unusable_rather_than_ignored(self):
        self.change("a.yml", scope=Scope.ALL)
        status, output = self.run_cli("check-all", "--summary-base", "")
        self.assertEqual(status, 0, output)
        self.assertIn("no usable base", output)
        self.assertIn(("added_lines", Scope.ALL, ""), self.repo.calls)

    def test_summary_base_decides_what_the_report_compares(self):
        self.change("a.yml", scope=Scope.ALL)
        self.repo.since = [".swiftlint.yml"]
        self.repo.added_since = [AddedLine("a.yml", 2, "x || true")]
        summary = self.root / "build/summary.md"
        self.write("build/summary.md", "earlier step\n")
        status, output = self.run_cli(
            "check-all", "--summary-base", "abc123", "--summary-file", str(summary)
        )
        self.assertEqual(status, 0, output)
        self.assertIn(("changed_since", Scope.ALL, "abc123"), self.repo.calls)
        written = summary.read_text()
        self.assertTrue(written.startswith("earlier step\n"), written)
        for text in (output, written):
            self.assertIn("setting: .swiftlint.yml (lint or format setting)", text)
            self.assertIn("risky: a.yml:2 (|| true)", text)
        self.assertIn("Compared with abc123", written)

    def test_summary_with_nothing_new_says_so_and_keeps_output_to_one_line(self):
        self.change("a.yml", scope=Scope.ALL)
        summary = self.root / "build/summary.md"
        _, output = self.run_cli("check-all", "--summary-file", str(summary))
        self.assertEqual(output, "Checks passed: 1 file checked\n")
        self.assertIn("Nothing to list", summary.read_text())

    def test_unwritable_summary_file_is_not_silent(self):
        self.change("a.yml", scope=Scope.ALL)
        status, output = self.run_cli("check-all", "--summary-file", str(self.root))
        self.assertEqual(status, 1, output)
        self.assertIn("summary", output)


def findings(rule, count):
    return [Finding("swiftlint", rule, f"{rule}.swift", n, f"bad {n}") for n in range(count)]


class RenderTests(unittest.TestCase):
    def test_long_output_is_capped_grouped_by_rule_with_omitted_count_and_log_path(self):
        result = CheckResult(findings=findings("line_length", 70) + findings("todo", 2), checked=2)
        text, status = render(result, [], "check", LOG)
        self.assertEqual(status, 1)
        shown = [line for line in text.splitlines() if ".swift:" in line]
        self.assertEqual(len(shown), 50)
        self.assertEqual(text.count("swiftlint: line_length (70)"), 1)
        self.assertEqual(text.count("swiftlint: todo (2)"), 1)
        self.assertEqual(sum("todo.swift:" in line for line in shown), 2)
        self.assertIn(f"22 more findings not shown. Full log: {LOG}", text)

    def test_every_failing_rule_keeps_its_heading_past_the_cap(self):
        result = CheckResult(findings=[*findings("a", 3), *findings("b", 3), *findings("c", 3)])
        text, _ = render(result, [], "check", LOG, cap=2)
        for rule in "abc":
            self.assertIn(f"swiftlint: {rule} (3)", text)
        self.assertEqual(sum(".swift:" in line for line in text.splitlines()), 2)
        self.assertIn("7 more findings not shown", text)

    def test_exactly_the_cap_omits_nothing(self):
        text, _ = render(CheckResult(findings=findings("a", 50)), [], "check", LOG)
        self.assertNotIn("not shown", text)

    def test_long_report_is_capped_with_settings_kept(self):
        added = [ReportItem(Kind.RISKY, "try?", "A.swift", n) for n in range(80)]
        items = [ReportItem(Kind.SETTING, "pinned tool", ".mise.toml", None), *added]
        text, status = render(CheckResult(checked=1), items, "check", LOG)
        self.assertEqual(status, 0)
        self.assertIn("setting: .mise.toml (pinned tool)", text)
        self.assertEqual(sum("(try?)" in line for line in text.splitlines()), 49)
        self.assertIn(f"31 more report items not shown. Full log: {LOG}", text)

    def test_message_with_line_breaks_stays_on_one_line(self):
        result = CheckResult(findings=[Finding("ruff", "E1", "a.py", None, "one\ntwo")])
        self.assertIn("  a.py one two\n", render(result, [], "check", LOG)[0])


class LogTests(CliTestCase):
    def test_log_holds_every_finding_and_the_whole_report(self):
        for number in range(60):
            self.change(f"f{number:02}.yml", content="# one\n# two\n")
        self.repo.added = [AddedLine("f00.yml", n, "x || true") for n in range(60)]
        _, output = self.run_cli("check")
        self.assertIn("10 more findings not shown", output)
        log = self.log()
        for number in range(60):
            self.assertIn(f"f{number:02}.yml:1 ", log)
            self.assertIn(f"risky: f00.yml:{number} (|| true)", log)

    def test_log_holds_the_commands_that_ran(self):
        self.change("a.py", content="x = 1\n")
        self.run_cli("check")
        self.assertIn("$ ", self.log())
        self.assertIn("--output-format=json", self.log())


class EntryPointTests(unittest.TestCase):
    def test_folder_runs_as_a_command(self):
        completed = subprocess.run(
            [sys.executable, "-B", "scripts/checks", "--help"],
            cwd=REPO,
            env={"PATH": "/nonexistent"},
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(completed.returncode, 0, completed.stderr)
        for word in (*MODES, "--summary-base", "--summary-file"):
            self.assertIn(word, completed.stdout)


class HookWrapperTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name).resolve()
        (self.root / "scripts/checks").mkdir(parents=True)
        shutil.copy2(REPO / "scripts/checks/hook.sh", self.root / "scripts/checks/hook.sh")
        self.bin = self.root / "bin"
        self.bin.mkdir()

    def fake(self, path, body):
        target = self.root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(f"#!/bin/sh\n{body}\n")
        target.chmod(0o755)

    def run_hook(self):
        # The closed PATH keeps a real mise out of reach.
        return subprocess.run(
            [str(self.root / "scripts/checks/hook.sh")],
            cwd=self.root / "bin",
            env={"PATH": os.pathsep.join([str(self.bin), "/usr/bin", "/bin"])},
            capture_output=True,
            text=True,
            check=False,
        )

    def test_wrapper_is_executable(self):
        self.assertTrue(os.access(REPO / "scripts/checks/hook.sh", os.X_OK))

    def test_missing_mise_gives_a_plain_error(self):
        self.fake(".venv/bin/python", "echo ran")
        completed = self.run_hook()
        self.assertEqual(completed.returncode, 1)
        self.assertIn("mise was not found", completed.stderr)
        self.assertEqual(completed.stdout, "")

    def test_missing_venv_gives_a_plain_error(self):
        self.fake("bin/mise", "exit 0")
        completed = self.run_hook()
        self.assertEqual(completed.returncode, 1)
        self.assertIn(".venv", completed.stderr)
        self.assertIn("make venv", completed.stderr)

    def test_runs_staged_mode_from_the_root_and_keeps_its_status(self):
        self.fake("bin/mise", "exit 0")
        self.fake(".venv/bin/python", 'echo "$PWD: $*"; exit 7')
        completed = self.run_hook()
        self.assertEqual(completed.returncode, 7, completed.stderr)
        self.assertEqual(completed.stdout, f"{self.root}: scripts/checks staged\n")


if __name__ == "__main__":
    unittest.main()
