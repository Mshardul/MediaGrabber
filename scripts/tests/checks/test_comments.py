import unittest

from checks.comments import ALLOWED_DIRECTIVES, check_comments, read_source
from checks.files import Language
from checks.tools import Finding

KIT = "Sources/GrabberKit/Engine/A.swift"
APP = "Sources/App/A.swift"


def lines(*rows):
    return "".join(f"{row}\n" for row in rows)


class CommentTestCase(unittest.TestCase):
    def found(self, language, *rows, path=None, text=None):
        defaults = {
            Language.SWIFT: APP,
            Language.SHELL: "scripts/a.sh",
            Language.PYTHON: "scripts/a.py",
            Language.CONFIG: "a.yml",
            Language.OTHER: "a.txt",
        }
        source = lines(*rows) if text is None else text
        findings = check_comments(path or defaults[language], source, language)
        return [(finding.rule, finding.line) for finding in findings]

    def swift(self, *rows, **options):
        return self.found(Language.SWIFT, *rows, **options)

    def shell(self, *rows, **options):
        return self.found(Language.SHELL, *rows, **options)

    def python(self, *rows, **options):
        return self.found(Language.PYTHON, *rows, **options)

    def config(self, *rows, **options):
        return self.found(Language.CONFIG, *rows, **options)


class FindingTests(CommentTestCase):
    def test_finding_carries_check_rule_path_line_and_message(self):
        (finding,) = check_comments("a.yml", lines("a: 1", "# one", "# two"), Language.CONFIG)
        self.assertIsInstance(finding, Finding)
        self.assertEqual(
            (finding.check, finding.rule, finding.path, finding.line),
            ("comments", "stacked-comment", "a.yml", 2),
        )
        self.assertTrue(finding.message)

    def test_findings_are_in_line_order(self):
        found = self.swift("// a", "// b", "let x = 1", "/* c", "d */", "/// e")
        self.assertEqual(found, [("stacked-comment", 1), ("block-comment", 4), ("doc-comment", 6)])

    def test_other_language_is_not_checked(self):
        self.assertEqual(self.found(Language.OTHER, "# a", "# b"), [])

    def test_empty_file_is_clean_in_every_language(self):
        for language in Language:
            self.assertEqual(self.found(language, text=""), [], language)


class StackTests(CommentTestCase):
    def test_two_comment_lines_in_every_language(self):
        for language, marker in (
            (Language.SWIFT, "//"),
            (Language.SHELL, "#"),
            (Language.PYTHON, "#"),
            (Language.CONFIG, "#"),
        ):
            with self.subTest(language=language):
                found = self.found(language, f"{marker} a", f"{marker} b")
                self.assertEqual(found, [("stacked-comment", 1)])

    def test_long_stack_is_one_finding(self):
        self.assertEqual(self.shell("# a", "# b", "# c", "# d"), [("stacked-comment", 1)])

    def test_blank_lines_do_not_break_a_stack(self):
        for language, marker in (
            (Language.SWIFT, "//"),
            (Language.SHELL, "#"),
            (Language.PYTHON, "#"),
            (Language.CONFIG, "#"),
        ):
            with self.subTest(language=language):
                found = self.found(language, f"{marker} a", "", "   ", f"    {marker} b")
                self.assertEqual(found, [("stacked-comment", 1)])

    def test_each_separate_stack_is_reported(self):
        found = self.shell("# a", "# b", "true", "# c", "# d")
        self.assertEqual(found, [("stacked-comment", 1), ("stacked-comment", 4)])

    def test_code_breaks_a_stack(self):
        self.assertEqual(self.swift("// a", "let x = 1", "// b"), [])

    def test_one_comment_is_allowed(self):
        self.assertEqual(self.swift("// why", "let x = 1"), [])

    def test_end_of_line_comment_does_not_count(self):
        self.assertEqual(self.swift("let x = 1 // a", "// b", "let y = 2 // c"), [])
        self.assertEqual(self.shell("true # a", "# b"), [])
        self.assertEqual(self.python("x = 1  # a", "# b"), [])
        self.assertEqual(self.config("a: 1 # a", "# b"), [])

    def test_crlf_line_endings(self):
        for language, marker in (
            (Language.SWIFT, "//"),
            (Language.SHELL, "#"),
            (Language.PYTHON, "#"),
            (Language.CONFIG, "#"),
        ):
            with self.subTest(language=language):
                text = f"{marker} a\r\n\r\n{marker} b\r\n"
                self.assertEqual(self.found(language, text=text), [("stacked-comment", 1)])

    def test_byte_order_mark_does_not_hide_the_first_comment(self):
        for language, marker in (
            (Language.SWIFT, "//"),
            (Language.SHELL, "#"),
            (Language.PYTHON, "#"),
            (Language.CONFIG, "#"),
        ):
            with self.subTest(language=language):
                text = f"\ufeff{marker} a\n{marker} b\n"
                self.assertEqual(self.found(language, text=text), [("stacked-comment", 1)])

    def test_last_line_without_a_newline_is_checked(self):
        self.assertEqual(self.config(text="# a\n# b"), [("stacked-comment", 1)])


class DirectiveTests(CommentTestCase):
    def test_list_covers_the_planned_directives(self):
        listed = {name for names in ALLOWED_DIRECTIVES.values() for name in names}
        expected = {"MARK:", "#!", "swiftlint:", "swiftformat:", "shellcheck", "noqa"}
        expected |= {"ruff:", "type:", "fmt:", "yaml-language-server:", "swift-tools-version"}
        self.assertEqual(listed, expected)

    def test_mark_beside_a_comment(self):
        self.assertEqual(self.swift("// MARK: - Queue", "// why", "let x = 1"), [])
        self.assertEqual(self.swift("// why", "// MARK: - Queue"), [])

    def test_two_marks_are_not_a_stack(self):
        self.assertEqual(self.swift("// MARK: A", "", "//MARK: B"), [])

    def test_directive_does_not_split_a_stack(self):
        self.assertEqual(self.swift("// a", "// MARK: x", "// b"), [("stacked-comment", 1)])
        found = self.shell("# a", "# shellcheck disable=SC2016", "# b")
        self.assertEqual(found, [("stacked-comment", 1)])

    def test_swift_directives(self):
        for directive in (
            "// swift-tools-version: 5.9",
            "// swiftlint:disable:next force_cast",
            "// swiftformat:disable all",
        ):
            with self.subTest(directive=directive):
                self.assertEqual(self.swift(directive, "// why"), [])

    def test_shell_directives(self):
        for directive in ("# shellcheck disable=SC2016", "# shellcheck source=lib.sh"):
            with self.subTest(directive=directive):
                self.assertEqual(self.shell("# why", directive, "true"), [])

    def test_python_directives(self):
        for directive in (
            "# noqa",
            "# noqa: E501",
            "# ruff: noqa",
            "# type: ignore",
            "# fmt: off",
        ):
            with self.subTest(directive=directive):
                self.assertEqual(self.python("# why", directive, "x = 1"), [])

    def test_config_directive(self):
        directive = "# yaml-language-server: $schema=https://example.invalid/s.json"
        self.assertEqual(self.config(directive, "# why", "a: 1"), [])

    def test_prose_that_only_looks_like_a_directive_counts(self):
        for language, row in (
            (Language.SWIFT, "// the MARK: lines group these"),
            (Language.SWIFT, "// swiftlint is strict here"),
            (Language.SHELL, "# shellcheck is wrong about this"),
            (Language.PYTHON, "# noqable is not a word"),
        ):
            with self.subTest(row=row):
                marker = row.split()[0]
                found = self.found(language, row, f"{marker} b")
                self.assertEqual(found, [("stacked-comment", 1)])

    def test_a_directive_of_another_language_is_an_ordinary_comment(self):
        self.assertEqual(self.swift("// type: the kind", "// b"), [("stacked-comment", 1)])
        self.assertEqual(self.shell("# fmt: the layout", "# b"), [("stacked-comment", 1)])
        self.assertEqual(self.python("# MARK: x", "# b"), [("stacked-comment", 1)])

    def test_shebang_followed_by_one_comment(self):
        for language, shebang in (
            (Language.SHELL, "#!/usr/bin/env bash"),
            (Language.PYTHON, "#!/usr/bin/env python3"),
            (Language.CONFIG, "#!/usr/bin/make -f"),
        ):
            with self.subTest(language=language):
                self.assertEqual(self.found(language, shebang, "# why"), [])
        self.assertEqual(self.swift("#!/usr/bin/env swift", "// why", "let x = 1"), [])

    def test_shebang_after_the_first_line_is_a_comment(self):
        self.assertEqual(self.shell("true", "#!/bin/sh", "# b"), [("stacked-comment", 2)])

    def test_commented_out_shebang_is_a_comment(self):
        self.assertEqual(self.shell("# #!/bin/sh", "# b"), [("stacked-comment", 1)])
        self.assertEqual(self.swift("// #!/usr/bin/env swift", "// b"), [("stacked-comment", 1)])


class SwiftDocCommentTests(CommentTestCase):
    def test_one_line_doc_comment_in_grabberkit(self):
        self.assertEqual(self.swift("/// One.", "public struct A {}", path=KIT), [])

    def test_two_line_doc_comment_in_grabberkit(self):
        found = self.swift("/// One.", "/// Two.", "public struct A {}", path=KIT)
        self.assertEqual(found, [("doc-comment", 1)])

    def test_blank_line_does_not_split_a_doc_comment(self):
        found = self.swift("/// One.", "", "/// Two.", path=KIT)
        self.assertEqual(found, [("doc-comment", 1)])

    def test_doc_comments_on_separate_declarations(self):
        rows = ("/// One.", "public let a = 1", "/// Two.", "public let b = 2")
        self.assertEqual(self.swift(*rows, path=KIT), [])

    def test_doc_comment_outside_grabberkit(self):
        for path in (APP, "Tests/GrabberKitTests/A.swift", "Sources/GrabberKitExtra/A.swift"):
            with self.subTest(path=path):
                found = self.swift("/// One.", "struct A {}", path=path)
                self.assertEqual(found, [("doc-comment", 1)])

    def test_two_line_doc_comment_outside_grabberkit_is_one_finding(self):
        self.assertEqual(self.swift("/// One.", "/// Two."), [("doc-comment", 1)])

    def test_four_slashes_are_a_doc_comment(self):
        self.assertEqual(self.swift("//// One."), [("doc-comment", 1)])

    def test_doc_comment_stacked_with_a_comment_in_grabberkit(self):
        found = self.swift("// why", "/// One.", "public let a = 1", path=KIT)
        self.assertEqual(found, [("stacked-comment", 1)])

    def test_mixed_stack_outside_grabberkit_names_both_faults(self):
        found = self.swift("// why", "/// One.", "let a = 1")
        self.assertEqual(found, [("stacked-comment", 1), ("doc-comment", 2)])

    def test_end_of_line_doc_comment_is_not_a_comment_only_line(self):
        self.assertEqual(self.swift("let a = 1 /// note", path=KIT), [])
        self.assertEqual(self.swift("let a = 1 /// note"), [("doc-comment", 1)])

    def test_directive_does_not_split_a_doc_comment(self):
        found = self.swift("/// a", "// swiftlint:disable:next x", "/// b", path=KIT)
        self.assertEqual(found, [("doc-comment", 1)])


class SwiftDocBlockCommentTests(CommentTestCase):
    def test_one_line_doc_block_in_grabberkit(self):
        self.assertEqual(self.swift("/** One. */", "public struct A {}", path=KIT), [])

    def test_one_line_doc_block_outside_grabberkit(self):
        for path in (APP, "Tests/GrabberKitTests/A.swift", "Sources/GrabberKitExtra/A.swift"):
            with self.subTest(path=path):
                found = self.swift("/** One. */", "struct A {}", path=path)
                self.assertEqual(found, [("doc-comment", 1)])

    def test_three_stars_open_a_doc_block(self):
        self.assertEqual(self.swift("/*** One. */"), [("doc-comment", 1)])

    def test_empty_block_comment_is_not_a_doc_comment(self):
        self.assertEqual(self.swift("/**/", "let a = 1"), [])
        self.assertEqual(self.swift("/**/", "// b"), [("stacked-comment", 1)])
        self.assertEqual(self.swift("/**/", "/// b", path=KIT), [("stacked-comment", 1)])

    def test_multi_line_doc_block_is_one_finding_everywhere(self):
        cases = (
            ("/**", " One.", " */"),
            ("/** One.", " Two. */"),
            ("/**", "", " // two", " /* nested */", "", " */"),
        )
        for path in (APP, KIT):
            for rows in cases:
                with self.subTest(path=path, rows=rows):
                    found = self.swift("let a = 1", *rows, "let b = 2", path=path)
                    self.assertEqual(found, [("doc-comment", 2)])

    def test_doc_blocks_count_toward_a_long_doc_comment(self):
        for rows in (
            ("/** One. */", "/** Two. */"),
            ("/** One. */", "", "/// Two."),
            ("/// One.", "/** Two. */"),
            ("/**", " One. */", "/// Two."),
        ):
            for path in (APP, KIT):
                with self.subTest(path=path, rows=rows):
                    self.assertEqual(self.swift(*rows, path=path), [("doc-comment", 1)])

    def test_doc_block_stacked_with_a_comment_in_grabberkit(self):
        found = self.swift("// why", "/** One. */", "public let a = 1", path=KIT)
        self.assertEqual(found, [("stacked-comment", 1)])

    def test_mixed_stack_with_a_doc_block_outside_grabberkit(self):
        found = self.swift("// why", "/** One. */", "let a = 1")
        self.assertEqual(found, [("stacked-comment", 1), ("doc-comment", 2)])

    def test_multi_line_doc_block_stacks_like_a_doc_comment(self):
        found = self.swift("// why", "/**", " One. */", path=KIT)
        self.assertEqual(found, [("stacked-comment", 1), ("doc-comment", 2)])

    def test_doc_blocks_on_separate_declarations(self):
        rows = ("/** One. */", "public let a = 1", "/** Two. */", "public let b = 2")
        self.assertEqual(self.swift(*rows, path=KIT), [])

    def test_end_of_line_doc_block_is_not_a_comment_only_line(self):
        rows = ("// a", "let a = 1 /** note */", "// b")
        self.assertEqual(self.swift("let a = 1 /** note */", path=KIT), [])
        self.assertEqual(self.swift(*rows, path=KIT), [])
        self.assertEqual(self.swift("let a = 1 /** note */"), [("doc-comment", 1)])
        self.assertEqual(self.swift(*rows), [("doc-comment", 2)])

    def test_comment_after_a_doc_block_on_one_line(self):
        found = self.swift("/** a", " b */ // c", "let a = 1", path=KIT)
        self.assertEqual(found, [("doc-comment", 1)])

    def test_multi_line_doc_block_sharing_a_line_with_code_never_passes(self):
        for rows in (
            ("let a = 1 /** a", "b */"),
            ("/** a", "b */ let a = 1"),
        ):
            for path in (APP, KIT):
                with self.subTest(path=path, rows=rows):
                    self.assertEqual(self.swift(*rows, path=path), [("block-comment", 1)])

    def test_unterminated_doc_block_never_passes(self):
        for rows in (("/** a",), ("/** a", "b")):
            with self.subTest(rows=rows):
                self.assertEqual(self.swift(*rows, path=KIT), [("block-comment", 1)])

    def test_doc_block_text_inside_a_string(self):
        self.assertEqual(self.swift('let a = """', "/** a", "b */", '"""'), [])
        self.assertEqual(self.swift('let a = "/** a */"'), [])


class SwiftDocCommentBesideCodeTests(CommentTestCase):
    def assert_misplaced(self, *rows, at=(1,)):
        for path in (APP, "Tests/GrabberKitTests/A.swift", "Sources/GrabberKitExtra/A.swift"):
            with self.subTest(path=path, rows=rows):
                found = self.swift(*rows, path=path)
                self.assertEqual(found, [("doc-comment", line) for line in at])
        with self.subTest(path=KIT, rows=rows):
            self.assertEqual(self.swift(*rows, path=KIT), [])

    def test_after_code(self):
        for row in (
            "let a = 1 /// note",
            "let a = 1///note",
            "let a = 1 //// note",
            "} /// note",
            "let a = 1 /** note */",
            "let a = 1 /*** note */",
            'let a = "x" /** note */',
        ):
            self.assert_misplaced(row)

    def test_after_the_end_of_a_multi_line_string(self):
        self.assert_misplaced('let a = """', "x", '""" /// note', at=(3,))

    def test_before_and_between_code(self):
        for row in (
            "/** One. */ let a = 1",
            "f(/** a */ b)",
            'let a = "\\(b /** c */)"',
            "/** a */ #/x/#",
        ):
            self.assert_misplaced(row)

    def test_behind_another_comment_on_a_line_of_its_own(self):
        for row in ("/* a */ /** b */", "/* a */ /// b", "/**/ /** b */", "/**/ /// b"):
            self.assert_misplaced("let a = 1", row, "let b = 2", at=(2,))

    def test_one_line_is_reported_once(self):
        for row in (
            "/** a */ let a = 1 /// b",
            "let a = 1 /** a */ /** b */",
            "/** a */ /// b",
            "/** a */ /** b */",
            "/* a */ /** b */ /// c",
        ):
            self.assert_misplaced(row)

    def test_each_comment_beside_code_is_reported(self):
        self.assert_misplaced("let a = 1 /// a", "let b = 2 /** b */", at=(1, 2))

    def test_comment_beside_code_is_not_part_of_the_run_below_it(self):
        rows = ("let a = 1 /// a", "/// b", "let b = 2")
        found = self.swift(*rows)
        self.assertEqual(found, [("doc-comment", 1), ("doc-comment", 2)])
        self.assertEqual(self.swift(*rows, path=KIT), [])

    def test_run_of_its_own_lines_is_still_one_finding(self):
        found = self.swift("/** a */", "", "/// b", "let a = 1")
        self.assertEqual(found, [("doc-comment", 1)])

    def test_comment_beside_code_still_joins_no_stack(self):
        found = self.swift("let a = 1 /// a", "// b", "let b = 2 /** c */")
        self.assertEqual(found, [("doc-comment", 1), ("doc-comment", 3)])

    def test_the_same_text_in_strings_and_other_comments(self):
        for rows in (
            ('let a = "x /// y"',),
            ('let a = "x /** y */"',),
            ('let a = #"x" /** y */"#',),
            ('let a = """', "let b = 1 /// x", "/** y */ let c = 2", '"""'),
            ('let a = #"""', '""" /// x', '"""#'),
            ("let a = #/ /** y */ /#",),
            ("let a = 1 // see /// and /** x */",),
            ("// see /** x */ and ///",),
            ("let a = 1 /* /** x */ */",),
            ("let a = 1 /* /// x */",),
            ("/* /** x */ */ let a = 1",),
        ):
            with self.subTest(rows=rows):
                self.assertEqual(self.swift(*rows), [])

    def test_the_same_text_in_a_multi_line_block_comment(self):
        found = self.swift("let a = 1 /* x", "let b = 2 /// y", "/** z */ */")
        self.assertEqual(found, [("block-comment", 1)])

    def test_empty_block_comment_beside_code(self):
        for row in ("let a = 1 /**/", "/**/ let a = 1", "f(/**/)", "/* a */ /**/"):
            with self.subTest(row=row):
                self.assertEqual(self.swift(row), [])

    def test_unterminated_doc_block_after_code_is_one_finding(self):
        for path in (APP, KIT):
            with self.subTest(path=path):
                found = self.swift("let a = 1 /** a", path=path)
                self.assertEqual(found, [("block-comment", 1)])


class SwiftBlockCommentTests(CommentTestCase):
    def test_multi_line_block_comment(self):
        found = self.swift("/*", " one", " // two", " // three", "*/", "let x = 1")
        self.assertEqual(found, [("block-comment", 1)])

    def test_multi_line_block_comment_after_code(self):
        self.assertEqual(self.swift("let x = 1 /* a", "b */"), [("block-comment", 1)])

    def test_nested_block_comment_is_one_finding(self):
        found = self.swift("/* a", "/* b */", "// c", "// d", "*/")
        self.assertEqual(found, [("block-comment", 1)])

    def test_code_after_a_nested_block_comment_is_still_checked(self):
        found = self.swift("/* /* a */ */", "let x = 1", "// b", "// c")
        self.assertEqual(found, [("stacked-comment", 3)])

    def test_unterminated_block_comment_never_passes(self):
        self.assertEqual(self.swift("let x = 1", "/* a"), [("block-comment", 2)])
        self.assertEqual(self.swift("/* a", "// b", "// c"), [("block-comment", 1)])

    def test_single_line_block_comment_is_allowed_alone(self):
        self.assertEqual(self.swift("/* why */", "let x = 1"), [])

    def test_single_line_block_comments_stack(self):
        self.assertEqual(self.swift("/* a */", "// b"), [("stacked-comment", 1)])
        self.assertEqual(self.swift("// a", "/* b */"), [("stacked-comment", 1)])

    def test_block_comment_before_code_is_a_code_line(self):
        self.assertEqual(self.swift("// a", "/* b */ let x = 1", "// c"), [])


class SwiftStringTests(CommentTestCase):
    def test_comment_lines_inside_a_multi_line_string(self):
        rows = ('let a = """', "// one", "// two", "/* three", '"""', "let b = 1")
        self.assertEqual(self.swift(*rows), [])

    def test_comment_lines_inside_a_raw_multi_line_string(self):
        rows = ('let a = #"""', '"""', "// one", "// two", '"""#', "let b = 1")
        self.assertEqual(self.swift(*rows), [])

    def test_more_hashes_need_the_same_number_to_close(self):
        rows = ('let a = ##"""', '"""#', "// one", "// two", '"""##')
        self.assertEqual(self.swift(*rows), [])

    def test_comments_after_a_multi_line_string_are_checked(self):
        for rows in (
            ('let a = """', "x", '"""', "// b", "// c"),
            ('let a = #"""', "x", '"""#', "// b", "// c"),
        ):
            with self.subTest(rows=rows):
                self.assertEqual(self.swift(*rows), [("stacked-comment", 4)])

    def test_escaped_quotes_do_not_close_a_multi_line_string(self):
        rows = ('let a = """', '\\"""', "// one", "// two", '"""')
        self.assertEqual(self.swift(*rows), [])

    def test_comment_markers_inside_ordinary_strings(self):
        for row in (
            'let a = "Sources/App/**"',
            'let a = "https://example.invalid/*"',
            'let a = "say \\"/*\\" now"',
            'let a = #"a "quote" /* here"#',
            'let a = #"""#',
            'let a = #""#',
            'let a = ""',
        ):
            with self.subTest(row=row):
                found = self.swift(row, "// b", "// c")
                self.assertEqual(found, [("stacked-comment", 2)])

    def test_trailing_comment_after_a_string(self):
        self.assertEqual(self.swift('let a = "x" /* open', "close */"), [("block-comment", 1)])

    def test_string_inside_interpolation(self):
        for row in (
            'let a = "x \\(f("/*")) y"',
            'let a = "x \\(f("\\(g(")"))")) /* y"',
            'let a = #"x \\#(f("/*")) /* y"#',
            'let a = #"x \\(not code" + "/*"',
        ):
            with self.subTest(row=row):
                found = self.swift(row, "// b", "// c")
                self.assertEqual(found, [("stacked-comment", 2)])

    def test_multi_line_string_inside_interpolation(self):
        rows = (
            'let a = """',
            "\\(f(",
            '    """',
            "    // one",
            "    // two",
            '    """',
            "))",
            "// three",
            '"""',
            "// b",
            "// c",
        )
        self.assertEqual(self.swift(*rows), [("stacked-comment", 10)])

    def test_comments_inside_multi_line_interpolation_are_comments(self):
        rows = ('let a = """', "\\(", "// one", "// two", "x)", '"""')
        self.assertEqual(self.swift(*rows), [("stacked-comment", 3)])

    def test_unfinished_single_line_string_does_not_hide_later_lines(self):
        for row in ('let a = "open', 'let a = "x \\(open', 'let a = /"/'):
            with self.subTest(row=row):
                found = self.swift(row, "// b", "// c")
                self.assertEqual(found, [("stacked-comment", 2)])

    def test_extended_regex_literal(self):
        found = self.swift('let a = #/ /* " /#', "// b", "// c")
        self.assertEqual(found, [("stacked-comment", 2)])

    def test_unterminated_multi_line_string_never_passes(self):
        found = self.swift('let a = """', "// one", "// two")
        self.assertEqual(found, [("parse-error", 1)])


class ShellHeredocTests(CommentTestCase):
    def assert_skipped(self, *rows):
        self.assertEqual(self.shell(*rows), [])

    def assert_checked(self, *rows):
        found = self.shell(*rows, "# y", "# z")
        self.assertEqual(found, [("stacked-comment", len(rows) + 1)])

    def test_unquoted_heredoc(self):
        self.assert_skipped("cat <<EOF", "# a", "# b", "EOF")

    def test_quoted_heredocs(self):
        for opener in ("<<'EOF'", '<<"EOF"', "<<\\EOF", "<< EOF", "<< 'EOF'", "<<E'O'F"):
            with self.subTest(opener=opener):
                self.assert_skipped(f"cat {opener}", "# a", "# b", "EOF")

    def test_tab_stripping_heredoc(self):
        self.assert_skipped("cat <<-EOF", "\t# a", "\t# b", "\tEOF")
        self.assert_skipped("cat <<- 'EOF'", "\t# a", "\t# b", "EOF")

    def test_comments_after_a_heredoc_are_checked(self):
        self.assert_checked("cat <<EOF", "x", "EOF")
        self.assert_checked("cat <<-EOF", "\tx", "\tEOF")

    def test_only_an_exact_line_ends_a_heredoc(self):
        self.assert_skipped("cat <<EOF", " EOF", "# a", "# b", "EOF ", "\tEOF", "# c", "EOF")

    def test_two_heredocs_on_one_line(self):
        self.assert_skipped("cat <<A <<B", "# a", "# b", "A", "# c", "# d", "B")
        self.assert_checked("cat <<A <<B", "A", "B")

    def test_rest_of_the_opening_line_is_still_read(self):
        self.assert_skipped("cat <<EOF >out && echo 'done'", "# a", "# b", "EOF")

    def test_heredoc_starts_after_a_continued_line(self):
        self.assert_skipped("cat <<EOF \\", "  >out", "# a", "# b", "EOF")

    def test_heredoc_starts_after_a_quote_that_spans_lines(self):
        self.assert_skipped("cat <<EOF | grep 'a", "b'", "# a", "# b", "EOF")

    def test_heredoc_in_command_substitution(self):
        self.assert_skipped("x=$(cat <<EOF", "# a", "# b", "EOF", ")")
        self.assert_skipped('x="$(cat <<EOF', "# a", "# b", "EOF", ')"')
        self.assert_skipped("x=`cat <<EOF", "# a", "# b", "EOF", "`")

    def test_crlf_heredoc(self):
        text = "cat <<EOF\r\n# a\r\n# b\r\nEOF\r\n"
        self.assertEqual(self.shell(text=text), [])

    def test_here_string_is_not_a_heredoc(self):
        self.assert_checked("cat <<< word", "# a", "true", "word")
        found = self.shell("cat <<<word", "# a", "# b", "word")
        self.assertEqual(found, [("stacked-comment", 2)])
        found = self.shell('cat <<< "$x"', "# a", "# b")
        self.assertEqual(found, [("stacked-comment", 2)])

    def test_shift_is_not_a_heredoc(self):
        for row in (
            "x=$((1 << n))",
            "x=$(( (1<<n) + 1 ))",
            "(( x <<= n ))",
            "(( x = 1 << n ))",
            "for (( i = 1 << n; i; i-- )); do :; done",
            'echo "$((1 << n))"',
            "x=$(( $(echo 1) << n ))",
            "echo ${a[1<<n]}",
        ):
            with self.subTest(row=row):
                found = self.shell(row, "# a", "# b", "n", "n ))")
                self.assertEqual(found, [("stacked-comment", 2)])

    def test_heredoc_marker_inside_quotes(self):
        for row in (
            "echo 'use <<EOF'",
            'echo "use <<EOF"',
            "echo $'it\\'s <<EOF'",
            "echo \\<\\<EOF",
            'echo "\\"<<EOF"',
        ):
            with self.subTest(row=row):
                found = self.shell(row, "# a", "# b", "EOF")
                self.assertEqual(found, [("stacked-comment", 2)])

    def test_heredoc_marker_inside_a_quote_from_an_earlier_line(self):
        found = self.shell("echo 'usage:", "  cat <<EOF", "'", "# a", "# b", "EOF")
        self.assertEqual(found, [("stacked-comment", 4)])

    def test_heredoc_marker_inside_a_comment(self):
        found = self.shell("# see <<EOF", "true", "# a", "# b", "EOF")
        self.assertEqual(found, [("stacked-comment", 3)])
        found = self.shell("true;# see <<EOF", "# a", "# b", "EOF")
        self.assertEqual(found, [("stacked-comment", 2)])

    def test_quote_inside_a_comment_opens_nothing(self):
        self.assert_skipped("true # don't", "cat <<EOF", "# a", "# b", "EOF")

    def test_hash_that_starts_no_comment(self):
        for row in ("echo $#", "echo ${#x}", "echo ${x#'a'}", "echo a#'b'", "echo $((16#ff))"):
            with self.subTest(row=row):
                self.assert_skipped(f"{row}; cat <<EOF", "# a", "# b", "EOF")

    def test_process_id_does_not_start_a_quoted_string(self):
        self.assert_skipped("echo $$'\\'; cat <<EOF", "# a", "# b", "EOF")

    def test_each_heredoc_is_ended_once(self):
        found = self.shell("cat <<EOF", "x", "EOF", "# a", "# b", "EOF")
        self.assertEqual(found, [("stacked-comment", 4)])

    def test_unterminated_heredoc_hides_nothing(self):
        found = self.shell("cat <<EOF", "# a", "# b")
        self.assertEqual(found, [("stacked-comment", 2)])

    def test_heredoc_after_an_unterminated_one_is_still_skipped(self):
        self.assert_skipped("cat <<NEVER", "cat <<EOF", "# a", "# b", "EOF")

    def test_comment_lines_inside_a_quoted_string_count(self):
        found = self.shell("awk '", "# a", "# b", "'")
        self.assertEqual(found, [("stacked-comment", 2)])


class PythonTests(CommentTestCase):
    def test_hash_lines_inside_a_string(self):
        rows = ('x = """', "# a", "# b", '"""', "y = '# c'")
        self.assertEqual(self.python(*rows), [])

    def test_comments_inside_brackets(self):
        found = self.python("x = [", "    # a", "    # b", "    1,", "]")
        self.assertEqual(found, [("stacked-comment", 2)])

    def test_one_line_docstrings(self):
        rows = (
            '"""Module."""',
            "class A:",
            '    """Class."""',
            "    def f(self):",
            '        """Method."""',
            "async def g():",
            '    """Async."""',
        )
        self.assertEqual(self.python(*rows), [])

    def test_multi_line_docstring_in_every_position(self):
        cases = {
            1: ('"""Module.', "More.", '"""'),
            2: ("class A:", '    """Class.', '    """'),
            3: ("x = 1", "def f():", '    """Function.', "", '    More."""'),
            4: ("class A:", "    x = 1", "    async def f(self):", '        r"""A.', '"""'),
        }
        for line, rows in cases.items():
            with self.subTest(rows=rows):
                self.assertEqual(self.python(*rows), [("docstring", line)])

    def test_docstring_joined_across_lines(self):
        found = self.python("def f():", '    ("one"', '     "two")')
        self.assertEqual(found, [("docstring", 2)])

    def test_comment_lines_inside_a_multi_line_docstring_do_not_count(self):
        found = self.python('"""A.', "# b", "# c", '"""')
        self.assertEqual(found, [("docstring", 1)])

    def test_other_multi_line_strings_are_not_docstrings(self):
        self.assertEqual(self.python("x = 1", '"""A.', 'B."""'), [])

    def test_comment_and_docstring_are_not_a_stack(self):
        self.assertEqual(self.python("# why", '"""Module."""', "# why", "x = 1"), [])

    def test_unparsable_file_never_passes(self):
        cases = {
            "def f(:\n    pass\n": 1,
            'x = 1\ny = """open\n': 2,
            "x = (\n": 1,
            "if True:\n        a = 1\n    b = 2\n": 3,
            "x = 1\n\0\n": None,
        }
        for text, line in cases.items():
            with self.subTest(text=text):
                ((rule, reported),) = self.python(text=text)
                self.assertEqual(rule, "parse-error")
                if line:
                    self.assertEqual(reported, line)

    def test_nesting_too_deep_to_parse_never_passes(self):
        text = f"x = {'-' * 100_000}1\n"
        ((rule, _),) = self.python(text=text)
        self.assertEqual(rule, "parse-error")

    def test_lone_carriage_returns_end_lines(self):
        self.assertEqual(self.python(text="# a\r# b\r"), [("stacked-comment", 1)])

    def test_form_feed_does_not_shift_line_numbers(self):
        found = self.python(text="x = 1\n\x0c\n# a\n# b\n")
        self.assertEqual(found, [("stacked-comment", 3)])


class ConfigTests(CommentTestCase):
    def test_comments_inside_a_yaml_run_block(self):
        found = self.config("steps:", "  - run: |", "      # a", "      # b", "      true")
        self.assertEqual(found, [("stacked-comment", 3)])

    def test_comments_in_toml(self):
        found = self.config("[tools]", "# a", "# b", 'x = "1"', path=".mise.toml")
        self.assertEqual(found, [("stacked-comment", 2)])

    def test_comments_inside_a_toml_multi_line_value(self):
        found = self.config('x = """', "# a", "# b", '"""', path="a.toml")
        self.assertEqual(found, [("stacked-comment", 2)])

    def test_comments_in_a_makefile_including_recipes(self):
        found = self.config("build:", "\t# a", "# b", "\ttrue", path="Makefile")
        self.assertEqual(found, [("stacked-comment", 2)])

    def test_heredoc_look_alike_in_config_hides_nothing(self):
        found = self.config("run: |", "  cat <<EOF", "  # a", "  # b", "  EOF")
        self.assertEqual(found, [("stacked-comment", 3)])

    def test_slashes_are_not_comments(self):
        self.assertEqual(self.config("// a", "// b", "/* c", "d */"), [])


class ReaderTests(unittest.TestCase):
    def comments(self, language, *rows, path="a"):
        source = read_source(path, lines(*rows), language)
        return [(comment.line, comment.text) for comment in source.comments]

    def test_swift_comments_and_code(self):
        rows = ('let a = "x // y" // one', "/* two", "three */ f(b)")
        source = read_source(APP, lines(*rows), Language.SWIFT)
        self.assertEqual(
            [(comment.line, comment.text) for comment in source.comments],
            [(1, "// one"), (2, "/* two\nthree */")],
        )
        self.assertEqual(
            [row.split() for row in source.code.split("\n")],
            [["let", "a", "=", '"', '"'], [], ["f(b)"], []],
        )

    def test_swift_code_keeps_lines_and_columns(self):
        text = lines('let a = """', "  \\(b) c", '  """ // d', "e(/* f */)", 'g("h \\(i) j")')
        source = read_source(APP, text, Language.SWIFT)
        self.assertEqual(
            [len(row) for row in source.code.split("\n")], [len(row) for row in text.split("\n")]
        )
        for column, character in enumerate(source.code):
            self.assertIn(character, (" ", text[column]))
        self.assertEqual(source.code.count("("), source.code.count(")"))

    def test_python_comments_include_end_of_line_and_docstrings(self):
        found = self.comments(Language.PYTHON, '"""Doc."""', "a = '# no'  # yes", "# own")
        self.assertEqual(sorted(found), [(1, '"""Doc."""'), (2, "# yes"), (3, "# own")])

    def test_shell_comments_include_end_of_line(self):
        found = self.comments(Language.SHELL, "true '# no' # yes", "  # own")
        self.assertEqual(sorted(found), [(1, "# yes"), (2, "# own")])

    def test_config_comments_include_end_of_line(self):
        found = self.comments(Language.CONFIG, "a: '# no' # yes", "  # own")
        self.assertEqual(sorted(found), [(1, "# yes"), (2, "# own")])

    def test_only_swift_has_a_code_view(self):
        for language in (Language.SHELL, Language.PYTHON, Language.CONFIG, Language.OTHER):
            with self.subTest(language=language):
                self.assertEqual(read_source("a", "x\n", language).code, "")

    def test_readable_files_report_nothing(self):
        for language in Language:
            with self.subTest(language=language):
                self.assertEqual(read_source("a", "x\n", language).unreadable, [])


if __name__ == "__main__":
    unittest.main()
