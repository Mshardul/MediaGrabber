import json
import os
import shutil
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from checks.files import Language, select
from checks.tools import Completed, SystemExec, run_tools

REPO = Path(__file__).resolve().parents[3]

PINS = {
    "swiftformat": "0.62.1",
    "swiftlint": "0.65.1",
    "shellcheck": "0.11.0",
    "shfmt": "3.14.1",
}
RUFF_PIN = "0.16.5"
LINTED_TWO = "Done linting! Found 0 violations, 0 serious in 2 files.\n"
SOURCES = ["Sources/A B.swift", "scripts/tool.swift", "scripts/run.sh", "scripts/gh", "a.py"]


def tool_of(argv):
    name = Path(argv[0]).name
    if name == "ruff" and argv[1] == "format":
        return "ruff-format"
    return name


def done(returncode=0, stdout="", stderr=""):
    return Completed(returncode, stdout, stderr)


class FakeExec:
    def __init__(self):
        self.calls = []
        self.replies = {}
        self.actions = {}
        self.versions = dict(PINS)
        self.ruff_version = RUFF_PIN
        self.unavailable = set()

    def run(self, argv, cwd):
        self.calls.append(list(argv))
        if argv[0] == "mise":
            return self.mise(argv)
        if argv[1:] == ["--version"]:
            return done(stdout=f"ruff {self.ruff_version}\n")
        files = [arg for arg in argv[1:] if (cwd / arg).is_file()]
        if "--show-files" in argv:
            return done(stdout="".join(f"{cwd / name}\n" for name in files))
        tool = tool_of(argv)
        if action := self.actions.get((tool, self.writes(argv))):
            action(cwd)
        if reply := self.replies.get((tool, self.writes(argv))):
            return reply
        return self.clean(tool, argv, len(files))

    def mise(self, argv):
        tool = argv[-1]
        if tool in self.unavailable:
            return done(1, stderr=f"mise ERROR {tool} is not currently active\n")
        if "--version" in argv:
            return done(stdout=self.versions[tool] + "\n")
        return done(stdout=f"/pinned/{tool}\n")

    @staticmethod
    def writes(argv):
        tool = tool_of(argv)
        if tool == "swiftformat":
            return "--lint" not in argv
        if tool == "shfmt":
            return "-w" in argv
        if tool == "ruff":
            return "--fix" in argv
        if tool == "ruff-format":
            return "--check" not in argv
        return "--fix" in argv

    def clean(self, tool, argv, count):
        if tool == "swiftformat":
            verb = "formatted" if self.writes(argv) else "require formatting"
            report = "" if self.writes(argv) else "[\n\n]\n"
            return done(stdout=report, stderr=f"0/{count} files {verb}.\n")
        if tool == "swiftlint":
            summary = f"Done linting! Found 0 violations, 0 serious in {count} files.\n"
            return done(stdout="[\n\n]\n", stderr=summary)
        if tool == "shellcheck":
            return done(stdout='{"comments":[]}\n')
        if tool == "ruff" or (tool == "ruff-format" and "--check" in argv):
            return done(stdout="[]")
        return done()

    def tool_calls(self, tool=None):
        runs = [
            argv
            for argv in self.calls
            if argv[0] != "mise" and argv[1:] != ["--version"] and "--show-files" not in argv
        ]
        return [argv for argv in runs if tool is None or tool_of(argv) == tool]


class FakeTreeTestCase(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name).resolve()
        pins = "".join(f'{name} = "{version}"\n' for name, version in PINS.items())
        self.write(".mise.toml", f"[tools]\n{pins}")
        self.write("requirements.txt", f"pytest==9.2.0\nruff=={RUFF_PIN}\n")
        self.exec = FakeExec()

    def write(self, path, content="x\n"):
        target = self.root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content)

    def sources(self, *paths):
        for path in paths:
            first = "#!/usr/bin/env bash\n" if path.endswith("gh") else "x\n"
            self.write(path, first)
        return select(paths, self.root)

    def run_on(self, *paths, fix=False):
        return run_tools(self.sources(*paths), self.root, fix, self.exec)

    def assert_broken(self, result, tool, *fragments):
        matches = [entry for entry in result.broken if entry.startswith(f"{tool}: ")]
        self.assertTrue(matches, result.broken)
        for fragment in fragments:
            self.assertIn(fragment, "\n".join(matches))


class SelectionTests(FakeTreeTestCase):
    def test_tool_with_empty_list_is_not_run(self):
        result = self.run_on("a.py", fix=True)
        self.assertEqual(result.broken, [])
        self.assertEqual(
            {tool_of(argv) for argv in self.exec.tool_calls()}, {"ruff", "ruff-format"}
        )
        self.assertFalse([argv for argv in self.exec.calls if argv[0] == "mise"])

    def test_no_files_runs_nothing_at_all(self):
        for fix in (False, True):
            with self.subTest(fix=fix):
                result = run_tools(select([], self.root), self.root, fix, self.exec)
                self.assertEqual(self.exec.calls, [])
                self.assertEqual((result.findings, result.edited, result.broken), ([], [], []))

    def test_config_and_other_files_reach_no_tool(self):
        self.run_on("Makefile", "README.md", "ci.yml", fix=True)
        self.assertEqual(self.exec.calls, [])

    def test_tools_get_files_never_directories(self):
        for fix in (False, True):
            self.run_on(*SOURCES, fix=fix)
        calls = self.exec.tool_calls()
        self.assertEqual(
            {tool_of(argv) for argv in calls},
            {"swiftformat", "swiftlint", "shfmt", "shellcheck", "ruff", "ruff-format"},
        )
        for argv in calls:
            with self.subTest(argv=argv):
                paths = [arg for arg in argv[1:] if (self.root / arg).exists()]
                self.assertTrue(paths)
                for path in paths:
                    self.assertTrue((self.root / path).is_file(), path)
                self.assertNotIn(".", argv)

    def test_directory_or_missing_path_is_broken_and_never_passed(self):
        self.write("folder.py/inner.txt")
        for bad in ("folder.py", "gone.py", "."):
            with self.subTest(bad=bad):
                self.exec = FakeExec()
                selection = {language: [] for language in Language}
                selection[Language.PYTHON] = [bad]
                result = run_tools(selection, self.root, True, self.exec)
                self.assertEqual(self.exec.tool_calls(), [])
                self.assert_broken(result, "files", bad)

    def test_name_that_looks_like_an_option_is_passed_as_a_path(self):
        self.run_on("-x.py", "-x.sh", fix=True)
        for argv in self.exec.tool_calls():
            with self.subTest(argv=argv):
                self.assertTrue([arg for arg in argv if arg.startswith("./-x.")])
                self.assertFalse([arg for arg in argv if arg.startswith("-x.")])

    def test_name_that_swiftformat_would_expand_is_never_passed_to_it(self):
        for name in ("Sources/A,b.swift", "Sources/A{x}.swift"):
            with self.subTest(name=name):
                self.exec = FakeExec()
                result = self.run_on(name, "Sources/Ok.swift", fix=True)
                for argv in self.exec.tool_calls("swiftformat"):
                    self.assertNotIn(name, argv)
                    self.assertIn("Sources/Ok.swift", argv)
                self.assert_broken(result, "swiftformat", name)
                self.assertIn(name, self.exec.tool_calls("swiftlint")[0])

    def test_only_expandable_names_leave_swiftformat_unrun(self):
        result = self.run_on("Sources/A,b.swift", fix=True)
        self.assertEqual(self.exec.tool_calls("swiftformat"), [])
        self.assert_broken(result, "swiftformat", "Sources/A,b.swift")


class CommandLineTests(FakeTreeTestCase):
    def test_swiftlint_gets_strict_and_force_exclude_never_fix(self):
        for fix in (False, True):
            self.run_on("Sources/A.swift", fix=fix)
        calls = self.exec.tool_calls("swiftlint")
        self.assertEqual(len(calls), 2)
        for argv in calls:
            self.assertEqual(argv[1], "lint")
            self.assertIn("--strict", argv)
            self.assertIn("--force-exclude", argv)
            self.assertNotIn("--fix", argv)

    def test_shfmt_gets_no_format_flags(self):
        for fix in (False, True):
            self.run_on("scripts/run.sh", fix=fix)
        flags = {arg for argv in self.exec.tool_calls("shfmt") for arg in argv if arg[0] == "-"}
        self.assertEqual(flags, {"-l=0", "-w"})

    def test_check_run_passes_no_write_flag_to_any_tool(self):
        self.run_on(*SOURCES, fix=False)
        calls = self.exec.tool_calls()
        self.assertEqual(len(calls), 6)
        for argv in calls:
            with self.subTest(argv=argv):
                self.assertFalse(self.exec.writes(argv))
                self.assertNotIn("-w", argv)
                self.assertNotIn("--fix", argv)
        self.assertIn("--no-fix", self.exec.tool_calls("ruff")[0])
        self.assertIn("--check", self.exec.tool_calls("ruff-format")[0])

    def test_fix_order_is_linter_fixes_then_formatters_then_verify(self):
        self.run_on(*SOURCES, fix=True)
        steps = [(tool_of(argv), self.exec.writes(argv)) for argv in self.exec.tool_calls()]
        self.assertEqual(
            steps,
            [
                ("ruff", True),
                ("swiftformat", True),
                ("shfmt", True),
                ("ruff-format", True),
                ("swiftformat", False),
                ("shfmt", False),
                ("ruff", False),
                ("ruff-format", False),
                ("swiftlint", False),
                ("shellcheck", False),
            ],
        )

    def test_ruff_never_gets_unsafe_fixes(self):
        for fix in (False, True):
            self.run_on("a.py", fix=fix)
        for argv in self.exec.tool_calls("ruff"):
            self.assertIn("--no-unsafe-fixes", argv)
            self.assertNotIn("--unsafe-fixes", argv)

    def test_ruff_always_gets_force_exclude(self):
        self.run_on("a.py", fix=True)
        for argv in self.exec.calls:
            if tool_of(argv).startswith("ruff") and argv[1:] != ["--version"]:
                self.assertIn("--force-exclude", argv)

    def test_shellcheck_runs_at_all_severities(self):
        self.run_on("scripts/run.sh")
        (argv,) = self.exec.tool_calls("shellcheck")
        self.assertFalse([arg for arg in argv if arg.startswith(("-S", "--severity"))])
        self.assertIn("--format=json1", argv)

    def test_shellcheck_never_reads_a_settings_file(self):
        self.run_on("scripts/run.sh", fix=True)
        (argv,) = self.exec.tool_calls("shellcheck")
        self.assertIn("--norc", argv)

    def test_every_tool_is_run_by_its_pinned_path(self):
        self.run_on(*SOURCES, fix=True)
        for argv in self.exec.tool_calls():
            with self.subTest(argv=argv):
                name = Path(argv[0]).name
                ruff = str(self.root / ".venv/bin/ruff")
                self.assertEqual(argv[0], ruff if name == "ruff" else f"/pinned/{name}")


class FindingTests(FakeTreeTestCase):
    def test_findings_are_read_with_repository_relative_paths(self):
        swift = str(self.root / "Sources/A B.swift")
        python = str(self.root / "a.py")
        lint = [{"file": swift, "line": 3, "rule_id": "identifier_name", "reason": "short"}]
        shell = {"comments": [{"file": "scripts/run.sh", "line": 2, "code": 2086, "message": "q"}]}
        ruff = [{"filename": python, "location": {"row": 1}, "code": "F401", "message": "unused"}]
        self.exec.replies = {
            ("swiftlint", False): done(
                2, json.dumps(lint), "Done linting! Found 1 violation, 1 serious in 2 files.\n"
            ),
            ("shellcheck", False): done(1, json.dumps(shell)),
            ("ruff", False): done(1, json.dumps(ruff)),
            ("shfmt", False): done(1, "scripts/gh\0", "scripts/run.sh:3:6: reached EOF\n"),
        }
        result = self.run_on(*SOURCES)
        self.assertEqual(result.broken, [])
        self.assertEqual(
            [(f.check, f.rule, f.path, f.line) for f in result.findings],
            [
                ("shfmt", "format", "scripts/gh", None),
                ("shfmt", "parse-error", "scripts/run.sh", 3),
                ("ruff", "F401", "a.py", 1),
                ("swiftlint", "identifier_name", "Sources/A B.swift", 3),
                ("shellcheck", "SC2086", "scripts/run.sh", 2),
            ],
        )

    def test_finding_for_a_file_that_was_not_passed_is_broken(self):
        report = [
            {"file": str(self.root / "Other.swift"), "line": 1, "rule_id": "r", "reason": "m"}
        ]
        self.exec.replies[("swiftlint", False)] = done(
            2, json.dumps(report), "Done linting! Found 1 violation, 1 serious in 1 file.\n"
        )
        result = self.run_on("Sources/A.swift")
        self.assertEqual([f.path for f in result.findings], ["Other.swift"])
        self.assert_broken(result, "swiftlint", "Other.swift")

    def test_unparsable_failure_is_broken_not_clean(self):
        replies = {
            "swiftformat": done(1, "garbage", "0/2 files require formatting.\n"),
            "swiftlint": done(2, "garbage", LINTED_TWO),
            "shellcheck": done(1, "garbage"),
            "shfmt": done(1, "", "something exploded\n"),
            "ruff": done(1, "garbage"),
            "ruff-format": done(1, "{}"),
        }
        for tool, reply in replies.items():
            with self.subTest(tool=tool):
                self.exec = FakeExec()
                self.exec.replies[(tool, False)] = reply
                self.assert_broken(self.run_on(*SOURCES), tool, "could not be read")

    def test_unparsable_output_is_broken_even_on_exit_0(self):
        for tool in ("swiftformat", "swiftlint", "shellcheck", "ruff", "ruff-format"):
            for output in ("", "{}", "null", '[{"surprise": 1}]'):
                with self.subTest(tool=tool, output=output):
                    self.exec = FakeExec()
                    summary = "0/2 files require formatting.\n" + LINTED_TWO
                    self.exec.replies[(tool, False)] = done(0, output, summary)
                    self.assert_broken(self.run_on(*SOURCES), tool, "could not be read")

    def test_finding_exit_status_without_findings_is_broken(self):
        self.exec.replies[("ruff", False)] = done(1, "[]")
        self.assert_broken(self.run_on("a.py"), "ruff")
        self.exec.replies = {("shfmt", False): done(1)}
        self.assert_broken(self.run_on("scripts/run.sh"), "shfmt")

    def test_crash_is_broken_and_shows_the_last_20_lines(self):
        noise = "".join(f"line {number}\n" for number in range(1, 31))
        for status in (-11, 134):
            with self.subTest(status=status):
                self.exec.replies[("shellcheck", False)] = done(status, '{"comments":[]}', noise)
                result = self.run_on("scripts/run.sh")
                (entry,) = result.broken
                shown = entry.splitlines()[1:]
                self.assertEqual(shown, [f"line {number}" for number in range(11, 31)])
                self.assertIn(str(status), entry.splitlines()[0])

    def test_failing_exit_status_keeps_the_findings_it_could_read(self):
        report = {"comments": [{"file": "scripts/run.sh", "line": 1, "code": 1000, "message": "m"}]}
        self.exec.replies[("shellcheck", False)] = done(2, json.dumps(report), "bad option\n")
        result = self.run_on("scripts/run.sh")
        self.assertEqual([f.rule for f in result.findings], ["SC1000"])
        self.assert_broken(result, "shellcheck", "bad option")

    def test_tool_that_skipped_a_file_is_broken(self):
        replies = {
            "swiftformat": done(0, "[]", "0/1 files require formatting, 1 file skipped.\n"),
            "swiftlint": done(0, "[]", "Done linting! Found 0 violations, 0 serious in 1 file.\n"),
        }
        for tool, reply in replies.items():
            with self.subTest(tool=tool):
                self.exec = FakeExec()
                self.exec.replies[(tool, False)] = reply
                self.assert_broken(self.run_on("Sources/A.swift", "Sources/B.swift"), tool)

    def test_run_that_says_nothing_about_its_file_count_is_broken(self):
        for tool, writes in (("swiftformat", False), ("swiftformat", True), ("swiftlint", False)):
            with self.subTest(tool=tool, writes=writes):
                self.exec = FakeExec()
                self.exec.replies[(tool, writes)] = done(0, "[]")
                self.assert_broken(self.run_on("Sources/A.swift", fix=writes), tool)

    def test_skipped_sourcekit_rule_is_broken(self):
        warning = (
            "warning: Skipping enabled rule 'statement_position' because it requires SourceKit\n"
            "Done linting! Found 0 violations, 0 serious in 1 file.\n"
        )
        self.exec.replies[("swiftlint", False)] = done(0, "[]", warning)
        self.assert_broken(self.run_on("Sources/A.swift"), "swiftlint", "SourceKit")

    def test_python_file_that_ruff_would_leave_out_is_broken(self):
        self.write("dist/d.py")
        self.write("a.py")

        class Dropping(FakeExec):
            def run(self, argv, cwd):
                if "--show-files" in argv:
                    self.calls.append(list(argv))
                    return done(stdout=f"{cwd / 'a.py'}\n")
                return super().run(argv, cwd)

        self.exec = Dropping()
        result = self.run_on("a.py", "dist/d.py")
        self.assert_broken(result, "ruff", "dist/d.py")

    def test_ruff_finding_no_python_files_is_broken(self):
        self.exec.replies[("ruff", False)] = done(
            0, "[]", "warning: No Python files found under the given path(s)\n"
        )
        self.assert_broken(self.run_on("a.py"), "ruff", "No Python files found")

    def test_failed_fix_step_is_broken_and_verify_still_runs(self):
        for tool in ("ruff", "swiftformat", "shfmt", "ruff-format"):
            with self.subTest(tool=tool):
                self.exec = FakeExec()
                self.exec.replies[(tool, True)] = done(70, "", "write step exploded\n")
                result = self.run_on(*SOURCES, fix=True)
                self.assert_broken(result, tool, "write step exploded")
                self.assertEqual(len(self.exec.tool_calls()), 10)

    def test_leftovers_in_a_fix_step_are_reported_once_by_verify(self):
        report = [
            {
                "filename": str(self.root / "a.py"),
                "location": {"row": 1},
                "code": "E501",
                "message": "long",
            }
        ]
        for writes in (True, False):
            self.exec.replies[("ruff", writes)] = done(1, json.dumps(report))
        result = self.run_on("a.py", fix=True)
        self.assertEqual(result.broken, [])
        self.assertEqual([f.rule for f in result.findings], ["E501"])

    def test_log_holds_each_command_and_all_its_output(self):
        noise = "".join(f"noise {number}\n" for number in range(100))
        self.exec.replies[("shellcheck", False)] = done(0, '{"comments":[]}', noise)
        result = self.run_on("scripts/run.sh")
        for expected in ("/pinned/shellcheck", "/pinned/shfmt", "scripts/run.sh", "noise 0\n"):
            self.assertIn(expected, result.log)


class PinTests(FakeTreeTestCase):
    def assert_unrun(self, result, tool):
        self.assertEqual(self.exec.tool_calls(tool), [])
        self.assert_broken(result, tool)

    def test_unpinned_tool_is_broken_even_if_on_path(self):
        self.write(".mise.toml", '[tools]\nswiftlint = "0.65.1"\n')
        result = self.run_on("scripts/run.sh", fix=True)
        self.assert_unrun(result, "shellcheck")
        self.assert_unrun(result, "shfmt")
        self.assert_broken(result, "shfmt", ".mise.toml")

    def test_missing_ruff_pin_is_broken(self):
        self.write("requirements.txt", "pytest==9.2.0\nruff>=0.16\n")
        result = self.run_on("a.py", fix=True)
        self.assert_unrun(result, "ruff")
        self.assert_unrun(result, "ruff-format")

    def test_missing_or_unreadable_pin_file_is_broken(self):
        for content in (None, "[tools\n"):
            with self.subTest(content=content):
                self.exec = FakeExec()
                if content is None:
                    (self.root / ".mise.toml").unlink()
                else:
                    self.write(".mise.toml", content)
                self.assert_unrun(self.run_on("scripts/run.sh"), "shellcheck")
        (self.root / "requirements.txt").unlink()
        self.assert_unrun(self.run_on("a.py"), "ruff")

    def test_pin_may_be_written_as_a_table(self):
        self.write(".mise.toml", '[tools]\nshfmt = { version = "3.14.1" }\nshellcheck = "0.11.0"\n')
        self.assertEqual(self.run_on("scripts/run.sh").broken, [])

    def test_tool_that_mise_cannot_resolve_is_broken_and_named(self):
        self.exec.unavailable = {"shfmt"}
        result = self.run_on("scripts/run.sh", fix=True)
        self.assert_unrun(result, "shfmt")
        self.assert_broken(result, "shfmt", "not currently active")
        self.assertEqual(len(result.broken), 1)
        self.assertEqual(len(self.exec.tool_calls("shellcheck")), 1)

    def test_version_other_than_the_pin_is_broken(self):
        self.exec.versions["swiftlint"] = "0.1.0"
        self.exec.ruff_version = "0.1.0"
        result = self.run_on("Sources/A.swift", "a.py")
        self.assert_unrun(result, "swiftlint")
        self.assert_unrun(result, "ruff")
        self.assert_broken(result, "swiftlint", "0.1.0", "0.65.1")

    def test_command_that_cannot_start_is_broken(self):
        class Missing(FakeExec):
            def run(self, argv, cwd):
                raise FileNotFoundError(2, "No such file or directory", argv[0])

        self.exec = Missing()
        result = self.run_on(*SOURCES, fix=True)
        for tool in ("swiftformat", "swiftlint", "shfmt", "shellcheck", "ruff", "ruff-format"):
            self.assert_broken(result, tool, "No such file or directory")


class EditedTests(FakeTreeTestCase):
    def test_edited_lists_only_files_whose_content_changed(self):
        def rewrite(cwd):
            (cwd / "scripts/run.sh").write_text("changed\n")
            os.utime(cwd / "scripts/gh", (0, 0))
            (cwd / "a.py").write_text((cwd / "a.py").read_text())

        self.exec.actions[("shfmt", True)] = rewrite
        result = self.run_on(*SOURCES, fix=True)
        self.assertEqual(result.edited, ["scripts/run.sh"])

    def test_file_removed_by_a_tool_counts_as_edited(self):
        self.exec.actions[("shfmt", True)] = lambda cwd: (cwd / "scripts/run.sh").unlink()
        self.assertEqual(self.run_on("scripts/run.sh", fix=True).edited, ["scripts/run.sh"])

    def test_write_by_a_check_run_would_be_reported(self):
        self.exec.actions[("shellcheck", False)] = lambda cwd: (cwd / "scripts/run.sh").write_text(
            ""
        )
        self.assertEqual(self.run_on("scripts/run.sh").edited, ["scripts/run.sh"])


class SystemExecTests(unittest.TestCase):
    def test_settings_that_silence_a_check_are_not_passed_on(self):
        settings = {
            "SWIFTLINT_DISABLE_SOURCEKIT": "1",
            "SHELLCHECK_OPTS": "-e SC2086",
            "KEPT": "1",
        }
        code = f"import os; print([name for name in {list(settings)} if name in os.environ])"
        with mock.patch.dict(os.environ, settings):
            completed = SystemExec().run([sys.executable, "-c", code], REPO)
        self.assertEqual(completed.stdout, "['KEPT']\n")

    def test_returns_status_and_both_streams_without_waiting_for_input(self):
        code = (
            "import sys; print(repr(sys.stdin.read())); "
            "sys.stderr.buffer.write(b'\\xff'); sys.exit(3)"
        )
        completed = SystemExec().run([sys.executable, "-c", code], REPO)
        self.assertEqual(completed, Completed(3, "''\n", "�"))


# mise needs the real home to find its tools, so only ShellCheck gets the temporary one.
class PersonalSettingsExec(SystemExec):
    def __init__(self, environment):
        self.environment = environment
        self.shellcheck = []

    def run(self, argv, cwd):
        if Path(argv[0]).name != "shellcheck":
            return super().run(argv, cwd)
        self.shellcheck = list(argv)
        return self.run_at_home(argv, cwd)

    def run_at_home(self, argv, cwd):
        with mock.patch.dict(os.environ, self.environment):
            return super().run(argv, cwd)


CONFIG_FILES = (".mise.toml", ".swiftformat", ".swiftlint.yml", ".editorconfig", "pyproject.toml")

SOURCEKIT_EXAMPLES = {
    "statement_position": """func pick(flag: Bool) {
    if flag {
        print(1)
    }
    else {
        print(2)
    }
}
""",
    "unavailable_condition": """func pick() {
    if #available(macOS 15, *) {
    } else {
        print("old")
    }
}
""",
    "void_function_in_ternary": """func pick(flag: Bool) {
    flag ? print("a") : print("b")
}
""",
}


class RealToolTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name).resolve()
        # Real tools rewrite files, so the sandbox must be outside the repository.
        self.assertFalse(self.root.is_relative_to(REPO), self.root)
        for name in (*CONFIG_FILES, "requirements.txt"):
            shutil.copyfile(REPO / name, self.root / name)
        (self.root / ".venv/bin").mkdir(parents=True)
        (self.root / ".venv/bin/ruff").symlink_to(REPO / ".venv/bin/ruff")
        environment = mock.patch.dict(
            os.environ,
            {
                "MISE_TRUSTED_CONFIG_PATHS": str(self.root),
                "MISE_STATE_DIR": str(self.root / ".mise-state"),
                "MISE_OFFLINE": "1",
            },
        )
        environment.start()
        self.addCleanup(environment.stop)
        self.paths = []

    def write(self, path, content):
        target = self.root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content)
        self.paths.append(path)

    def run_real(self, fix=False):
        return run_tools(select(self.paths, self.root), self.root, fix, SystemExec())

    def contents(self):
        return {path: (self.root / path).read_text() for path in self.paths}

    def assert_reported(self, check, path, rule=None):
        before = self.contents()
        result = self.run_real()
        self.assertEqual(result.broken, [], result.log)
        found = [(f.check, f.rule, f.path) for f in result.findings]
        matches = [f for f in found if f[0] == check and f[2] == path and rule in (None, f[1])]
        self.assertTrue(matches, result.log)
        self.assertEqual(self.contents(), before)
        self.assertEqual(result.edited, [])

    def test_swiftformat_reports_a_bad_file(self):
        self.write("Sources/A B.swift", "func pick() {\n  print(1)\n}\n")
        self.assert_reported("swiftformat", "Sources/A B.swift", "indent")

    def test_swiftlint_reports_a_bad_file_under_scripts(self):
        self.write("scripts/release/tool.swift", "let x = 1\n")
        self.assert_reported("swiftlint", "scripts/release/tool.swift", "identifier_name")

    def test_swiftlint_reports_statement_position(self):
        self.assert_sourcekit_rule("statement_position")

    def test_swiftlint_reports_unavailable_condition(self):
        self.assert_sourcekit_rule("unavailable_condition")

    def test_swiftlint_reports_void_function_in_ternary(self):
        self.assert_sourcekit_rule("void_function_in_ternary")

    def assert_sourcekit_rule(self, rule):
        self.write("Sources/Pick.swift", SOURCEKIT_EXAMPLES[rule])
        with mock.patch.dict(os.environ, {"SWIFTLINT_DISABLE_SOURCEKIT": "1"}):
            self.assert_reported("swiftlint", "Sources/Pick.swift", rule)

    def test_shellcheck_reports_info_and_style_findings(self):
        self.write("scripts/info.sh", "#!/usr/bin/env bash\necho $1\n")
        self.write("scripts/style.sh", '#!/usr/bin/env bash\nnow="`date`"\necho "$now"\n')
        self.assert_reported("shellcheck", "scripts/info.sh", "SC2086")
        self.assert_reported("shellcheck", "scripts/style.sh", "SC2006")

    def test_shellcheck_ignores_every_settings_file_that_would_silence_it(self):
        for settings in (
            "scripts/.shellcheckrc",
            "scripts/shellcheckrc",
            ".shellcheckrc",
            "home/.shellcheckrc",
            "xdg/shellcheckrc",
        ):
            with self.subTest(settings=settings):
                self.assert_cannot_silence(settings)

    def assert_cannot_silence(self, settings):
        self.paths = []
        self.write("scripts/info.sh", "#!/usr/bin/env bash\necho $1\n")
        selection = select(self.paths, self.root)
        target = self.root / settings
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text("disable=SC2086\n")
        self.addCleanup(target.unlink, missing_ok=True)
        personal = {"HOME": str(self.root / "home"), "XDG_CONFIG_HOME": str(self.root / "xdg")}
        executor = PersonalSettingsExec(personal)

        result = run_tools(selection, self.root, False, executor)

        self.assertEqual(result.broken, [], result.log)
        self.assertIn(("shellcheck", "SC2086"), [(f.check, f.rule) for f in result.findings])
        # Without the flag the same file hides the finding, so the test can tell the two apart.
        trusting = [argument for argument in executor.shellcheck if argument != "--norc"]
        silenced = executor.run_at_home(trusting, self.root)
        self.assertEqual(silenced.returncode, 0, silenced.stdout + silenced.stderr)
        target.unlink()

    def test_shfmt_reports_two_space_indent_without_an_extension(self):
        self.write("scripts/tests/stubs/gh", "#!/usr/bin/env bash\nif true; then\n  :\nfi\n")
        self.assert_reported("shfmt", "scripts/tests/stubs/gh", "format")

    def test_shfmt_reports_a_script_it_cannot_parse(self):
        self.write("scripts/broken.sh", '#!/usr/bin/env bash\necho "open\n')
        self.assert_reported("shfmt", "scripts/broken.sh", "parse-error")

    def test_ruff_lint_reports_a_bad_file(self):
        self.write("scripts/checks/bad.py", "import os\n")
        self.assert_reported("ruff", "scripts/checks/bad.py", "F401")

    def test_ruff_format_reports_a_bad_file(self):
        self.write("scripts/checks/bad.py", "value=1\n")
        self.assert_reported("ruff-format", "scripts/checks/bad.py", "unformatted")

    def test_check_run_passes_after_a_fix_run(self):
        self.write(
            "Sources/A B.swift",
            """func pick(first: Bool, second: Bool) {
  if first,
     second {
    print(1) ;
  }
  else {
    print(2)
  }
}
""",
        )
        self.write("scripts/run.sh", '#!/usr/bin/env bash\nif true; then\n  echo "a"\nfi\n')
        self.write("scripts/tests/stubs/gh", '#!/usr/bin/env bash\nif true; then\n  echo "b"\nfi\n')
        self.write("scripts/checks/tool.py", "import sys\nimport os\nvalue=sys.argv\n")
        self.assertTrue(self.run_real().findings)

        fixed = self.run_real(fix=True)
        self.assertEqual((fixed.findings, fixed.broken), ([], []), fixed.log)
        self.assertEqual(fixed.edited, sorted(self.paths))
        indented = '#!/usr/bin/env bash\nif true; then\n    echo "b"\nfi\n'
        self.assertEqual(self.contents()["scripts/tests/stubs/gh"], indented)
        self.assertNotIn("import os", self.contents()["scripts/checks/tool.py"])

        checked = self.run_real()
        self.assertEqual((checked.findings, checked.edited, checked.broken), ([], [], []))

    def test_fix_run_leaves_unselected_neighbours_alone(self):
        self.write("Sources/Picked.swift", "let  value = 1\n")
        bystander = self.root / "Sources/Other.swift"
        bystander.write_text("let  other = 1\n")
        self.assertEqual(self.run_real(fix=True).edited, ["Sources/Picked.swift"])
        self.assertEqual(bystander.read_text(), "let  other = 1\n")

    def test_fix_run_never_lets_a_comma_in_a_name_reach_other_files(self):
        self.write("Sources/A,b.swift", "let  value = 1\n")
        bystanders = [self.root / "Sources/A/Inner.swift", self.root / "b.swift"]
        for bystander in bystanders:
            bystander.parent.mkdir(parents=True, exist_ok=True)
            bystander.write_text("let  other = 1\n")
        result = self.run_real(fix=True)
        self.assertEqual([path.read_text() for path in bystanders], ["let  other = 1\n"] * 2)
        self.assertEqual([entry.split(":")[0] for entry in result.broken], ["swiftformat"])

    def test_file_that_a_tool_excludes_never_counts_as_checked(self):
        for path, content, tools in (
            ("Derived/X.swift", "let value = 1\n", ("swiftformat", "swiftlint")),
            ("dist/x.py", "import os\n", ("ruff", "ruff-format")),
        ):
            for company in (False, True):
                with self.subTest(path=path, company=company):
                    self.paths = []
                    self.write(path, content)
                    if company:
                        suffix = Path(path).suffix
                        self.write(
                            f"Sources/ok{suffix}", "value = 1\n" if suffix == ".py" else content
                        )
                    selection = {language: [] for language in Language}
                    language = Language.PYTHON if path.endswith(".py") else Language.SWIFT
                    selection[language] = sorted(self.paths)
                    result = run_tools(selection, self.root, False, SystemExec())
                    named = {entry.split(":")[0] for entry in result.broken}
                    self.assertLessEqual(set(tools), named, result.log)

    def test_unpinned_tool_is_broken_with_real_mise(self):
        (self.root / ".mise.toml").write_text('[tools]\nshellcheck = "0.11.0"\n')
        self.write("scripts/run.sh", "#!/usr/bin/env bash\n")
        result = self.run_real()
        self.assertEqual([entry.split(":")[0] for entry in result.broken], ["shfmt"], result.log)


if __name__ == "__main__":
    unittest.main()
