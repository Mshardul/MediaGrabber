import unittest

from checks.repo import AddedLine
from checks.report import Kind, ReportItem, build_report, settings_changed

SWIFT = "Sources/App/X.swift"
SHELL = "scripts/a.sh"
PYTHON = "scripts/a.py"
YAML = ".github/workflows/other.yml"


class ReportTestCase(unittest.TestCase):
    def listed(self, path, *rows):
        added = [AddedLine(path, number, row) for number, row in enumerate(rows, 10)]
        return [(item.what, item.line) for item in build_report(added, [])]

    def assert_listed(self, path, what, *rows):
        for row in rows:
            with self.subTest(path=path, row=row):
                self.assertEqual(self.listed(path, row), [(what, 10)])

    def assert_ignored(self, path, *rows):
        for row in rows:
            with self.subTest(path=path, row=row):
                self.assertEqual(self.listed(path, row), [])


class AddedLineTests(ReportTestCase):
    def test_item_carries_kind_what_path_and_line(self):
        added = [AddedLine(SWIFT, 7, "let a = try? load()")]
        self.assertEqual(build_report(added, [SWIFT]), [ReportItem(Kind.RISKY, "try?", SWIFT, 7)])

    def test_text_on_an_unchanged_line_is_not_listed(self):
        added = [AddedLine(SWIFT, 3, "let b = 2")]
        self.assertEqual(build_report(added, [SWIFT]), [])

    def test_nothing_changed_gives_an_empty_report(self):
        self.assertEqual(build_report([], []), [])


class SwiftSuppressionTests(ReportTestCase):
    def test_every_swiftlint_disable_form_is_listed(self):
        self.assert_listed(
            SWIFT,
            "swiftlint:disable",
            "// swiftlint:disable force_cast",
            "// swiftlint:disable all",
            "    // swiftlint:disable:next identifier_name",
            "let a = b as! C // swiftlint:disable:this force_cast",
            "//swiftlint:disable:previous force_cast",
            "/* swiftlint:disable force_cast */",
        )

    def test_swiftformat_disable_and_inline_options_are_listed(self):
        self.assert_listed(
            SWIFT,
            "swiftformat:disable",
            "// swiftformat:disable all",
            "// swiftformat:disable:next redundantSelf",
        )
        self.assert_listed(
            SWIFT,
            "swiftformat:options",
            "// swiftformat:options --maxwidth 300",
            "// swiftformat:options:next --self insert",
        )

    def test_a_directive_after_a_closing_multiline_string_is_listed(self):
        self.assert_listed(SWIFT, "swiftlint:disable", '""") // swiftlint:disable:this x')

    def test_directives_that_silence_nothing_are_ignored(self):
        self.assert_ignored(
            SWIFT,
            "// swiftlint:enable force_cast",
            "// swiftformat:enable all",
            "// swiftformat:sort",
            "// MARK: - Disable swiftlint",
            "let swiftlintDisabled = true",
        )


class ShellSuppressionTests(ReportTestCase):
    def test_every_shellcheck_disable_form_is_listed(self):
        self.assert_listed(
            SHELL,
            "shellcheck disable",
            "# shellcheck disable=SC2016",
            "#shellcheck disable=all",
            "echo $a # shellcheck disable=SC2086,SC2034",
            "# shellcheck source=lib.sh disable=SC1091",
            "# shellcheck shell=bash  disable=SC2086",
        )

    def test_turning_off_dataflow_analysis_is_listed(self):
        self.assert_listed(
            SHELL, "shellcheck extended-analysis=false", "# shellcheck extended-analysis=false"
        )

    def test_following_no_source_file_is_listed(self):
        self.assert_listed(
            SHELL,
            "shellcheck source=/dev/null",
            "# shellcheck source=/dev/null",
            "#shellcheck source=/dev/null",
            '# shellcheck source="/dev/null"',
            "# shellcheck source='/dev/null'",
            "# shellcheck shell=bash source=/dev/null",
            "# shellcheck source=/dev/null shell=bash",
            '. "$env" # shellcheck source=/dev/null',
        )

    def test_each_silencing_key_on_a_shared_directive_is_listed(self):
        self.assertEqual(
            self.listed(SHELL, "# shellcheck source=/dev/null disable=SC2086"),
            [("shellcheck disable", 10), ("shellcheck source=/dev/null", 10)],
        )

    def test_ordinary_sources_and_look_alikes_are_ignored(self):
        self.assert_ignored(
            SHELL,
            "# shellcheck source=scripts/lib.sh",
            "# shellcheck source=/dev/nullable.sh",
            "# shellcheck source=/dev/null.sh",
            "# shellcheck source=/dev/null/x",
            "# shellcheck source=./dev/null",
            "# shellcheck source-path=/dev/null",
            "source /dev/null",
            "# shellcheck shell=bash # source=/dev/null",
        )

    def test_other_shellcheck_directives_are_ignored(self):
        self.assert_ignored(
            SHELL,
            "# shellcheck source=lib.sh",
            "# shellcheck shell=bash",
            "# shellcheck enable=require-variable-braces",
            "# shellcheck extended-analysis=true",
            "shellcheck --severity=style a.sh",
            "# run shellcheck # to disable=nothing",
        )


class PythonSuppressionTests(ReportTestCase):
    def test_line_noqa_in_any_case_and_spacing_is_listed(self):
        self.assert_listed(
            PYTHON,
            "noqa",
            "import os  # noqa",
            "import os  # noqa: F401, E501",
            "import os  #noqa:F401",
            "import os  # NOQA",
            "x = foo(  # NoQA : E501",
        )

    def test_file_wide_noqa_is_listed(self):
        self.assert_listed(PYTHON, "ruff: noqa", "# ruff: noqa", "#ruff:NOQA: F401")
        self.assert_listed(PYTHON, "flake8: noqa", "# flake8: noqa", "# Flake8 : NoQA")

    def test_ruff_ignore_and_range_comments_are_listed(self):
        self.assert_listed(PYTHON, "ruff: ignore", "a = 1  # ruff: ignore[E501]")
        self.assert_listed(PYTHON, "ruff: file-ignore", "# ruff:file-ignore[F401]")
        self.assert_listed(PYTHON, "ruff: disable", "# ruff: disable[E501]")

    def test_import_sorting_comments_that_skip_are_listed(self):
        self.assert_listed(
            PYTHON,
            "isort skip",
            "import a  # isort: skip",
            "# isort: skip_file",
            "# isort:off",
            "# ruff: isort: off",
            "# ruff: isort: skip_file",
        )

    def test_formatter_comments_are_listed(self):
        self.assert_listed(PYTHON, "fmt: off", "# fmt: off", "#fmt:off")
        self.assert_listed(PYTHON, "fmt: skip", "a = [1,2]  # fmt: skip")
        self.assert_listed(PYTHON, "yapf: disable", "# yapf: disable")

    def test_type_ignore_is_listed(self):
        self.assert_listed(
            PYTHON, "type: ignore", "a = b  # type: ignore", "a = b  #type:ignore[attr-defined]"
        )

    def test_two_suppressions_on_one_line_are_both_listed(self):
        self.assertEqual(
            self.listed(PYTHON, "a = b  # type: ignore  # noqa: E501"),
            [("noqa", 10), ("type: ignore", 10)],
        )

    def test_one_suppression_written_twice_on_a_line_is_listed_once(self):
        self.assertEqual(self.listed(PYTHON, "a  # noqa  # noqa"), [("noqa", 10)])

    def test_look_alikes_are_ignored(self):
        self.assert_ignored(
            PYTHON,
            "# noqable is not a word",
            "# noqa-style is not one either",
            "# fmt: on",
            "# yapf: enable",
            "# isort: on",
            "# isort: split",
            "# ruff: enable[E501]",
            "# isort: skipped",
            "# type: ignored by design",
            "# fmt: offset",
            'ALLOWED = ("#!", "noqa", "ruff:", "type:", "fmt:")',
            "noqa = True",
        )


class RiskyConstructTests(ReportTestCase):
    def test_try_question_mark_is_listed(self):
        self.assert_listed(
            SWIFT, "try?", "try? file.close()", "let a = (try? f()) ?? 1", "x(try?\tf())"
        )

    def test_try_look_alikes_are_ignored(self):
        self.assert_ignored(
            SWIFT,
            "let a = canRetry?.value",
            "let b = entry?.name",
            "let c = try f()",
            "let d = try! f()",
            "// try? would hide the error",
            "    /// Use instead of try? here",
        )

    def test_a_trailing_comment_does_not_hide_a_construct(self):
        self.assert_listed(SWIFT, "try?", "try? f() // best effort")

    def test_or_true_is_listed_in_shell_yaml_and_makefile(self):
        for path in (SHELL, YAML, "Makefile"):
            self.assert_listed(
                path,
                "|| true",
                "    rm x || true",
                "a=$(cat b ||true)",
                'x="$(y || true)"; z',
                "cmd ||   true;",
            )

    def test_or_true_look_alikes_are_ignored(self):
        self.assert_ignored(
            SHELL,
            "a || trueish",
            "a || true_value",
            "a || true-up",
            "a || ./true",
            "a | true",
            "# never write || true here",
        )
        self.assert_ignored(SWIFT, "let a = b || true")
        self.assert_ignored(PYTHON, 'text = "a || true"')

    def test_or_colon_is_listed_wherever_or_true_counts(self):
        for path in (SHELL, YAML, "Makefile", "scripts/tests/stubs/gh"):
            self.assert_listed(
                path,
                "|| :",
                "    rm x || :",
                "cmd ||:",
                "cmd ||   :;",
                "a=$(cat b || :)",
                'x="$(y)" || : # best effort',
                'bash -c "a || :"',
                "a || :>log",
                "a || :&",
                "x=`a || :`",
            )

    def test_or_colon_look_alikes_are_ignored(self):
        self.assert_ignored(
            SHELL,
            "a || :foo",
            "a || ::log",
            "a || :-",
            "a || :=b",
            "a || :}",
            "a || :$suffix",
            "a || :_done",
            "a || :.sh",
            "echo ${a:-b} || exit 1",
            "echo ${a:?missing}",
            "a | :",
            "a && :",
            "# never write || : here",
        )
        self.assert_ignored(SWIFT, "let a = b || .none == c")
        self.assert_ignored(PYTHON, 'text = "a || :"')

    def test_both_ignored_failures_on_one_line_are_listed(self):
        self.assertEqual(self.listed(SHELL, "a || :; b || true"), [("|| :", 10), ("|| true", 10)])

    def test_unchecked_sendable_is_listed(self):
        self.assert_listed(
            SWIFT,
            "@unchecked Sendable",
            "final class A: @unchecked Sendable {",
            "extension B: @retroactive @unchecked Sendable {}",
            "struct C: @unchecked  Swift.Sendable {",
        )
        self.assert_ignored(
            SWIFT, "struct C: @unchecked SendableBox {", "struct D: Sendable { // unchecked"
        )

    def test_nonisolated_unsafe_is_listed(self):
        self.assert_listed(
            SWIFT,
            "nonisolated(unsafe)",
            "nonisolated(unsafe) static var a = 1",
            "static nonisolated (unsafe) var b = 1",
        )
        self.assert_ignored(SWIFT, "nonisolated func a() {}", "nonisolated(nonsending) func b()")


class LanguageScopeTests(ReportTestCase):
    def test_documents_and_data_files_are_not_scanned(self):
        row = "try? || true # noqa swiftlint:disable # shellcheck disable=SC1 @unchecked Sendable"
        for path in ("AGENTS.md", "docs/coding-standards.md", "notes.txt", "a.json"):
            self.assert_ignored(path, row)

    def test_each_syntax_counts_only_where_its_tool_reads_it(self):
        self.assert_ignored(SWIFT, "let a = 1 // # noqa", "// # shellcheck disable=SC1")
        self.assert_ignored(SHELL, "echo 'swiftlint:disable'", "echo 'try?' # noqa")
        self.assert_ignored(PYTHON, "# shellcheck disable=SC1", 'a = "try? swiftlint:disable"')

    def test_a_script_without_an_extension_is_read_as_shell_or_python(self):
        path = "scripts/tests/stubs/gh"
        self.assert_listed(path, "|| true", "cat x || true")
        self.assert_listed(path, "shellcheck disable", "# shellcheck disable=SC2016")
        self.assert_listed(path, "noqa", "import os  # noqa")

    def test_an_added_shebang_decides_the_language_of_any_name(self):
        found = self.listed_from_the_top("tools/run.command", "#!/bin/sh", "a || true")
        self.assertEqual(found, [("|| true", 2)])

    def listed_from_the_top(self, path, *rows):
        added = [AddedLine(path, number, row) for number, row in enumerate(rows, 1)]
        return [(item.what, item.line) for item in build_report(added, [path])]

    def test_excluded_and_vendored_files_are_not_scanned(self):
        for path in (
            "scripts/create-dmg",
            "scripts/support/a.sh",
            "build/a.swift",
            "Derived/Sources/a.swift",
            "Resources/Shield/server/a.sh",
            ".venv/lib/a.py",
        ):
            self.assert_ignored(path, "a || true # noqa swiftlint:disable try?")


class MakefileTests(ReportTestCase):
    def assert_check_lines(self, *rows):
        self.assert_listed("Makefile", "check line in Makefile", *rows)

    def test_a_line_naming_a_check_target_is_listed(self):
        self.assert_check_lines(
            "check:",
            "fix: venv",
            "check-all: PY := other",
            "fix-all:",
            ".PHONY: build check fix",
            "test: check",
            "\t@$(MAKE) check-all",
            "\tmake fix",
            ".DEFAULT_GOAL := check",
        )

    def test_a_line_naming_the_check_script_is_listed(self):
        self.assert_check_lines(
            "\t$(PY) scripts/checks $@",
            "CHECKS := .venv/bin/python scripts/checks/__main__.py",
        )

    def test_makefile_lines_are_settings(self):
        (item,) = build_report([AddedLine("Makefile", 4, "check:")], ["Makefile"])
        self.assertEqual(item, ReportItem(Kind.SETTING, "check line in Makefile", "Makefile", 4))

    def test_unrelated_lines_and_look_alikes_are_ignored(self):
        self.assert_ignored(
            "Makefile",
            "build: tools generate",
            "scripts-test:",
            "\tscripts/tests/test_check_feed.sh",
            "\tscripts/release/check-signature.sh",
            "\tscripts/tests/test_checks.sh",
            "\t$(PY) scripts/tests/checks",
            "\t$(PY) scripts/checks-old",
            "VERSION_CHECK = test -n x",
            "\t@$(VERSION_CHECK)",
            "\tgh run watch --check",
            "prefix := /usr/local",
            "\techo checked fixtures",
            "# make check runs scripts/checks",
            "build: tools # then check",
        )

    def test_only_the_makefile_counts(self):
        self.assert_ignored(SHELL, "make check")
        self.assert_ignored(YAML, "      - run: make check-all")


class SettingFileTests(unittest.TestCase):
    LINT = (
        ".swiftlint.yml",
        "Tests/.swiftlint.yml",
        ".swiftformat",
        "Sources/App/.swiftformat",
        ".editorconfig",
        "scripts/.editorconfig",
        "pyproject.toml",
        "scripts/pyproject.toml",
        "ruff.toml",
        "scripts/.ruff.toml",
        ".shellcheckrc",
        "scripts/tests/.shellcheckrc",
        "scripts/shellcheckrc",
    )
    PINS = (".mise.toml", "requirements.txt", ".python-version")
    SCRIPT = (
        "scripts/checks/__main__.py",
        "scripts/checks/files.py",
        "scripts/checks/report.py",
        "scripts/checks/new/deeper.py",
    )
    OTHERS = {".pre-commit-config.yaml": "hook setting", ".github/workflows/ci.yml": "CI workflow"}
    UNRELATED = (
        "Sources/A.swift",
        "Makefile",
        "Tests/PluginTests/requirements.txt",
        "Tests/.mise.toml",
        "docs/.python-version",
        "docs/.pre-commit-config.yaml",
        "ci.yml",
        ".github/workflows/release.yml",
        "docs/my.swiftlint.yml",
        ".swiftlint.yml.orig",
        "not-pyproject.toml",
        "scripts/tests/checks/test_files.py",
        "scripts/tests/test_checks.sh",
        "scripts/checks-old/a.py",
        "docs/shellcheckrc.md",
        "scripts/tools.lock",
        "scripts/support/.shellcheckrc",
        "scripts/checks/__pycache__/files.pyc",
        "Resources/Shield/server/.editorconfig",
        ".venv/lib/pkg/pyproject.toml",
        "build/checkouts/Sparkle/.swiftlint.yml",
    )

    def assert_files(self, what, paths):
        for path in paths:
            with self.subTest(path=path):
                self.assertEqual(
                    build_report([], [path]), [ReportItem(Kind.SETTING, what, path, None)]
                )

    def test_lint_and_format_settings_are_listed_wherever_a_tool_reads_them(self):
        self.assert_files("lint or format setting", self.LINT)

    def test_tool_pins_are_listed(self):
        self.assert_files("pinned tool", self.PINS)

    def test_the_check_script_is_listed(self):
        self.assert_files("check script", self.SCRIPT)

    def test_the_hook_and_ci_are_listed(self):
        for path, what in self.OTHERS.items():
            self.assert_files(what, [path])

    def test_unrelated_and_excluded_files_are_not_listed(self):
        for path in self.UNRELATED:
            with self.subTest(path=path):
                self.assertEqual(build_report([], [path]), [])
                self.assertFalse(settings_changed([path]))

    def test_a_deleted_or_renamed_settings_file_is_listed_from_its_path_alone(self):
        paths = [".swiftlint.yml", "docs/old-lint.yml"]
        self.assertEqual([item.path for item in build_report([], paths)], [".swiftlint.yml"])
        self.assertTrue(settings_changed(paths))

    def test_settings_changed_is_true_for_settings_pins_and_the_check_script(self):
        for path in (*self.LINT, *self.PINS, *self.SCRIPT):
            with self.subTest(path=path):
                self.assertTrue(settings_changed(["Sources/A.swift", path]))

    def test_settings_changed_is_false_for_the_rest(self):
        self.assertFalse(settings_changed([]))
        self.assertFalse(settings_changed(["Sources/A.swift"]))
        self.assertFalse(settings_changed([*self.OTHERS, "Makefile"]))

    def test_a_settings_file_is_listed_once_however_many_lines_it_gained(self):
        added = [AddedLine(".swiftlint.yml", 1, "excluded:"), AddedLine(".swiftlint.yml", 2, "  -")]
        self.assertEqual(len(build_report(added, [".swiftlint.yml", ".swiftlint.yml"])), 1)


class OrderTests(unittest.TestCase):
    def test_settings_come_first_then_suppressions_then_risky_constructs(self):
        added = [
            AddedLine("b.swift", 2, "try? f()"),
            AddedLine("b.swift", 11, "// swiftlint:disable all"),
            AddedLine("a.swift", 5, "try? f()"),
            AddedLine("b.swift", 9, "// swiftlint:disable all"),
            AddedLine("Makefile", 3, "check:"),
        ]
        found = build_report(added, ["pyproject.toml", ".mise.toml"])
        self.assertEqual(
            [(item.kind, item.path, item.line) for item in found],
            [
                (Kind.SETTING, ".mise.toml", None),
                (Kind.SETTING, "Makefile", 3),
                (Kind.SETTING, "pyproject.toml", None),
                (Kind.SUPPRESSION, "b.swift", 9),
                (Kind.SUPPRESSION, "b.swift", 11),
                (Kind.RISKY, "a.swift", 5),
                (Kind.RISKY, "b.swift", 2),
            ],
        )


if __name__ == "__main__":
    unittest.main()
