import unittest

from checks.comments import check_comments
from checks.files import Language
from checks.rules import AGENTS_LIMIT, check_rules
from checks.tools import Finding

APP = "Sources/App/X.swift"
KIT = "Sources/GrabberKit/Engine/A.swift"
RUNNER = "Sources/GrabberKit/Onboarding/ProcessRunner.swift"
RELAUNCHER = "Sources/App/Debug/AppRelauncher.swift"


def lines(*rows):
    return "".join(f"{row}\n" for row in rows)


class RuleTestCase(unittest.TestCase):
    def found(self, language, *rows, path=None, text=None):
        defaults = {
            Language.SWIFT: APP,
            Language.SHELL: "scripts/a.sh",
            Language.PYTHON: "scripts/a.py",
            Language.CONFIG: "a.yml",
            Language.OTHER: "a.txt",
        }
        source = lines(*rows) if text is None else text
        findings = check_rules(path or defaults[language], source, language)
        return [(finding.rule, finding.line) for finding in findings]

    def swift(self, *rows, **options):
        return self.found(Language.SWIFT, *rows, **options)

    def shell(self, *rows, **options):
        return self.found(Language.SHELL, *rows, **options)

    def python(self, *rows, **options):
        return self.found(Language.PYTHON, *rows, **options)

    def config(self, *rows, **options):
        return self.found(Language.CONFIG, *rows, **options)


class FindingTests(RuleTestCase):
    def test_finding_carries_check_rule_path_line_and_message(self):
        (finding,) = check_rules(APP, lines("let a = 1", "let p = Process()"), Language.SWIFT)
        self.assertIsInstance(finding, Finding)
        self.assertEqual(
            (finding.check, finding.rule, finding.path, finding.line),
            ("rules", "process-use", APP, 2),
        )
        self.assertTrue(finding.message)

    def test_findings_are_in_line_order(self):
        found = self.swift(
            "do { try f() } catch {}", "// mg-032", "let p = Process()", "import SwiftUI", path=KIT
        )
        self.assertEqual(
            found,
            [("empty-catch", 1), ("work-reference", 2), ("process-use", 3), ("swiftui-in-kit", 4)],
        )

    def test_empty_file_is_clean_in_every_language(self):
        for language in Language:
            self.assertEqual(self.found(language, text=""), [], language)


class ProcessUseTests(RuleTestCase):
    def test_process_in_the_app_fails(self):
        self.assertEqual(self.swift("let p = Process()"), [("process-use", 1)])

    def test_the_allowed_files_pass(self):
        for path in (RUNNER, RELAUNCHER, "scripts/make-app-icon.swift"):
            with self.subTest(path=path):
                self.assertEqual(self.swift("let p = Process()", path=path), [])

    def test_only_the_exact_paths_are_allowed(self):
        for path in (
            "Sources/App/ProcessRunner.swift",
            "Sources/App/AppRelauncher.swift",
            "Sources/GrabberKit/Onboarding/ProcessRunnerTwo.swift",
            "Sources/GrabberKit/Onboarding/Old/ProcessRunner.swift",
            "Sources/App/Debug/MyAppRelauncher.swift",
        ):
            with self.subTest(path=path):
                found = self.swift("let p = Process()", path=path)
                self.assertEqual(found, [("process-use", 1)])

    def test_files_outside_sources_pass(self):
        for path in ("Tests/GrabberKitTests/A.swift", "Project.swift", "SourcesExtra/A.swift"):
            with self.subTest(path=path):
                self.assertEqual(self.swift("let p = Process()", path=path), [])

    def test_every_way_of_naming_the_type_fails(self):
        for row in (
            "let p = Process ()",
            "let p = Process.init()",
            "let p = Foundation.Process()",
            "var p: Process?",
            "var all: [Process] = []",
            "let p = `Process`()",
            "typealias Runner = Process",
            "import class Foundation.Process",
            "let all = Set<Process>()",
            "let r = Process.run(url, arguments: [])",
        ):
            with self.subTest(row=row):
                self.assertEqual(self.swift(row), [("process-use", 1)])

    def test_look_alike_names_pass(self):
        for row in (
            "let a = ProcessLaunch(path)",
            "let a = ProcessInfo.processInfo",
            "let a = ProcessRunner()",
            "let a = MyProcess()",
            "let a = _Process()",
            "let a = Process_()",
            "let a = Process2()",
            "let a = ÉProcess()",
            "let a = process()",
            "let a = Processé()",
            "let a = $Process",
        ):
            with self.subTest(row=row):
                self.assertEqual(self.swift(row), [])

    def test_the_word_in_comments_and_strings_passes(self):
        cases = (
            ("let a = 1 // Process()",),
            ("// Process()", "let a = 1"),
            ("let a = 1 /* Process() */",),
            ('let a = "Process()"',),
            ('let a = "say \\"Process()\\""',),
            ('let a = #"a "Process()" b"#',),
            ('let a = """', "Process()", "// Process()", '"""'),
            ('let a = #"""', '"""', "Process()", "\\(Process())", '"""#'),
            ("let a = #/Process()/#",),
        )
        for rows in cases:
            with self.subTest(rows=rows):
                self.assertEqual(self.swift(*rows), [])

    def test_interpolated_code_is_code(self):
        self.assertEqual(self.swift('let a = "x \\(Process()) y"'), [("process-use", 1)])
        self.assertEqual(self.swift('let a = #"\\#(Process())"#'), [("process-use", 1)])
        found = self.swift('let a = """', "x \\(Process()) y", '"""')
        self.assertEqual(found, [("process-use", 2)])

    def test_code_after_strings_and_comments_is_still_read(self):
        found = self.swift('let a = """', "x", '""" + "/*"', "/* a */ let p = Process()")
        self.assertEqual(found, [("process-use", 4)])
        found = self.swift('let a = "//"; let p = Process()')
        self.assertEqual(found, [("process-use", 1)])

    def test_each_line_is_reported_once(self):
        found = self.swift("let p: Process = Process()", "let q = Process()")
        self.assertEqual(found, [("process-use", 1), ("process-use", 2)])

    def test_other_languages_pass(self):
        self.assertEqual(self.python("p = Process()", path="Sources/a.py"), [])
        self.assertEqual(self.shell("Process", path="Sources/a.sh"), [])


class SwiftUIInKitTests(RuleTestCase):
    def test_every_form_of_the_import_fails(self):
        for row in (
            "import SwiftUI",
            "import struct SwiftUI.Color",
            "import class SwiftUI.NSHostingView",
            "import enum SwiftUI.ColorScheme",
            "import protocol SwiftUI.View",
            "import typealias SwiftUI.A",
            "import func SwiftUI.withAnimation",
            "import let SwiftUI.a",
            "import var SwiftUI.a",
            "import SwiftUI.Color",
            "import  `SwiftUI`",
            "@testable import SwiftUI",
            "@_exported import SwiftUI",
            "@preconcurrency public import SwiftUI",
            "internal import SwiftUI",
            "import Foundation; import SwiftUI",
            "import /* why */ SwiftUI",
            "    import SwiftUI // why",
        ):
            with self.subTest(row=row):
                self.assertEqual(self.swift(row, path=KIT), [("swiftui-in-kit", 1)])

    def test_import_split_over_two_lines_fails_where_it_starts(self):
        self.assertEqual(self.swift("import", "SwiftUI", path=KIT), [("swiftui-in-kit", 1)])

    def test_the_app_and_tests_may_import_it(self):
        for path in (APP, "Tests/GrabberKitTests/A.swift", "Sources/GrabberKitUI/A.swift"):
            with self.subTest(path=path):
                self.assertEqual(self.swift("import SwiftUI", path=path), [])

    def test_other_imports_and_mentions_pass(self):
        cases = (
            ("import Foundation",),
            ("import SwiftUIExtras",),
            ("import SwiftUI_Kit",),
            ("import MySwiftUI",),
            ("import Kit.SwiftUI",),
            ("#if canImport(SwiftUI)", "#endif"),
            ("reimport SwiftUI",),
            ("// import SwiftUI",),
            ("/* import SwiftUI */",),
            ('let a = "import SwiftUI"',),
            ('let a = """', "import SwiftUI", '"""'),
        )
        for rows in cases:
            with self.subTest(rows=rows):
                self.assertEqual(self.swift(*rows, path=KIT), [])


class WorkReferenceTests(RuleTestCase):
    def test_a_comment_naming_a_phase_or_ticket_fails_in_every_language(self):
        for language, marker in (
            (Language.SWIFT, "//"),
            (Language.SHELL, "#"),
            (Language.PYTHON, "#"),
            (Language.CONFIG, "#"),
        ):
            for reference in ("Phase 4", "mg-032"):
                with self.subTest(language=language, reference=reference):
                    found = self.found(language, f"{marker} added in {reference}")
                    self.assertEqual(found, [("work-reference", 1)])

    def test_the_forms_a_reference_takes(self):
        for reference in (
            "phase 4",
            "PHASE 12",
            "Phase-4",
            "Phase4",
            "Phases 23 to 27",
            "(Phase 4).",
            "MG-032",
            "mg-1000",
            "see mg-032, then",
            "pre-mg-032",
        ):
            with self.subTest(reference=reference):
                self.assertEqual(self.swift(f"// {reference}"), [("work-reference", 1)])

    def test_look_alikes_pass(self):
        for words in (
            "two-phase commit",
            "the parse phase",
            "phase one",
            "emphases 4 things",
            "rephrase 4 times",
            "Phaser 4",
            "img-001.png",
            "MG_HOME points at a fake home",
            "the -mg-flag",
            "mg-32 is too short to be an id",
            "mg-032abc",
            "a 100 mg-dose",
            "the ticket expired",
        ):
            with self.subTest(words=words):
                self.assertEqual(self.swift(f"// {words}"), [])

    def test_the_same_text_in_a_string_passes(self):
        cases = (
            (Language.SWIFT, ('let a = "Phase 4 // mg-032"',)),
            (Language.SWIFT, ('let a = """', "// Phase 4", '"""')),
            (Language.SWIFT, ('let a = #"/* mg-032 */"#',)),
            (Language.SWIFT, ('let phase4 = phase(4, "mg-032")',)),
            (Language.PYTHON, ('a = "# Phase 4"',)),
            (Language.PYTHON, ('a = """', "# Phase 4", "mg-032", '"""')),
            (Language.PYTHON, ('f(f"{a} # mg-032")',)),
            (Language.SHELL, ('echo "# Phase 4"',)),
            (Language.SHELL, ("echo 'see # mg-032'",)),
            (Language.SHELL, ('echo "$(date) # mg-032"',)),
            (Language.SHELL, ("echo $'it\\'s # Phase 4'",)),
            (Language.SHELL, ("cat <<EOF", "# Phase 4", "x # mg-032", "EOF")),
            (Language.SHELL, ("cat <<-'EOF'", "\t# Phase 4", "\tEOF")),
            (Language.SHELL, ("echo ${x#mg-032} $# a#mg-032 \\# mg-032",)),
            (Language.CONFIG, ('a: "see # Phase 4"',)),
            (Language.CONFIG, ("a: 'it''s # mg-032'",)),
            (Language.CONFIG, ("a: [\"x # Phase 4\", '# mg-032']",)),
            (Language.CONFIG, ('a: "\\" # Phase 4"',)),
            (Language.CONFIG, ("url: http://example.invalid/page#phase-4",)),
            (Language.CONFIG, ("name: Phase 4",)),
        )
        for language, rows in cases:
            with self.subTest(language=language, rows=rows):
                self.assertEqual(self.found(language, *rows), [])

    def test_end_of_line_comments_are_read(self):
        cases = (
            (Language.SWIFT, "let a = 1 // mg-032"),
            (Language.SWIFT, "let a = 1 /* Phase 4 */"),
            (Language.SWIFT, 'let a = "//" // mg-032'),
            (Language.SWIFT, "/* Phase 4 */ let a = 1"),
            (Language.SWIFT, 'let a = "\\(f() /* mg-032 */)"'),
            (Language.PYTHON, "a = 1  # mg-032"),
            (Language.PYTHON, "a = '#'  # Phase 4"),
            (Language.SHELL, "true # mg-032"),
            (Language.SHELL, "true;# Phase 4"),
            (Language.SHELL, "echo '#' \"#\" # mg-032"),
            (Language.SHELL, "x=$(date # Phase 4\n)"),
            (Language.CONFIG, "a: 1 # mg-032"),
            (Language.CONFIG, "a: '#' # Phase 4"),
            (Language.CONFIG, "a: don't stop # mg-032 won't"),
            (Language.CONFIG, "a: the dogs' bones # Phase 4"),
            (Language.CONFIG, "a: say 'unclosed # mg-032"),
        )
        for language, row in cases:
            with self.subTest(language=language, row=row):
                self.assertEqual(self.found(language, row), [("work-reference", 1)])

    def test_toml_comments_need_no_space(self):
        found = self.config("a = 1# mg-032", path="a.toml")
        self.assertEqual(found, [("work-reference", 1)])
        found = self.config('a = "x"# Phase 4', path=".mise.toml")
        self.assertEqual(found, [("work-reference", 1)])
        self.assertEqual(self.config("a = 'x # Phase 4'", path="a.toml"), [])

    def test_makefile_comments(self):
        found = self.config("build: ## Phase 4", "\ttrue # mg-032", path="Makefile")
        self.assertEqual(found, [("work-reference", 1), ("work-reference", 2)])

    def test_comment_lines_inside_multi_line_values_count(self):
        found = self.config("run: |", "  # Phase 4", "  true")
        self.assertEqual(found, [("work-reference", 2)])
        found = self.shell("awk '", "# mg-032", "'")
        self.assertEqual(found, [("work-reference", 2)])

    def test_a_reference_in_a_block_comment_is_reported_on_its_own_line(self):
        found = self.swift("let a = 1", "/*", " Phase 4", " mg-032", "*/")
        self.assertEqual(found, [("work-reference", 3), ("work-reference", 4)])
        found = self.swift("/**", " mg-032", " */", path=KIT)
        self.assertEqual(found, [("work-reference", 2)])

    def test_doc_and_directive_comments_are_comments(self):
        for row in ("/// mg-032", "// MARK: - Phase 4", "// swiftlint:disable x - mg-032"):
            with self.subTest(row=row):
                self.assertEqual(self.swift(row, path=KIT), [("work-reference", 1)])

    def test_python_docstrings_are_comments(self):
        self.assertEqual(self.python('"""Built in Phase 4."""'), [("work-reference", 1)])
        found = self.python("def f():", '    """Does a thing.', "", '    For mg-032."""')
        self.assertEqual(found, [("work-reference", 4)])
        found = self.python('def f(): """Phase 4."""')
        self.assertEqual(found, [("work-reference", 1)])

    def test_comment_inside_a_python_f_string_field(self):
        found = self.python('a = f"""{', "x  # mg-032", '}"""')
        self.assertEqual(found, [("work-reference", 2)])

    def test_two_references_on_one_line_are_one_finding(self):
        self.assertEqual(self.swift("// Phase 4, mg-032"), [("work-reference", 1)])

    def test_line_numbers_with_crlf_and_a_byte_order_mark(self):
        for language, marker in (
            (Language.SWIFT, "//"),
            (Language.SHELL, "#"),
            (Language.PYTHON, "#"),
            (Language.CONFIG, "#"),
        ):
            with self.subTest(language=language):
                text = f"\ufeff{marker} mg-032\r\n\r\n{marker} Phase 4\r\n"
                found = self.found(language, text=text)
                self.assertEqual(found, [("work-reference", 1), ("work-reference", 3)])

    def test_other_language_is_not_checked(self):
        self.assertEqual(self.found(Language.OTHER, "# Phase 4 mg-032", path="docs/a.md"), [])


class EmptyCatchTests(RuleTestCase):
    def test_empty_forms_fail(self):
        for block in (
            "catch {}",
            "catch { }",
            "catch{}",
            "catch let error {}",
            "catch is CancellationError {}",
            "catch MyError.notFound {}",
            "catch .notFound {}",
            "catch (MyError.notFound) {}",
            "catch MyError.a, MyError.b {}",
            "catch MyError.code(let value) {}",
            'catch MyError.text("{") {}',
            'catch MyError.text("a \\(f()) )") {}',
            "catch let error as NSError where error.code == 4 {}",
            "catch let e where codes.contains(where: { $0 == e }) {}",
            "catch where retrying {}",
            "catch { /* why */ }",
        ):
            with self.subTest(block=block):
                found = self.swift(f"do {{ try f() }} {block}")
                self.assertEqual(found, [("empty-catch", 1)])

    def test_blank_lines_and_comments_do_not_fill_a_block(self):
        for body in (("",), ("", "   ", "\t"), ("// expected",), ("/* a */", "", "// b")):
            with self.subTest(body=body):
                found = self.swift("do {", "    try f()", "} catch {", *body, "}")
                self.assertEqual(found, [("empty-catch", 3)])

    def test_the_line_is_where_catch_is(self):
        found = self.swift("do { try f() }", "catch let e", "    where e.isFatal", "{", "}")
        self.assertEqual(found, [("empty-catch", 2)])

    def test_each_empty_block_in_a_chain_is_reported(self):
        found = self.swift("do { try f() } catch A.a {", "} catch B.b { log() } catch {}")
        self.assertEqual(found, [("empty-catch", 1), ("empty-catch", 2)])

    def test_a_block_with_a_statement_passes(self):
        for block in (
            "catch { log(error) }",
            "catch { return }",
            "catch { _ = error }",
            'catch { "fallback" }',
            'catch { "" }',
            'catch { """\n\n""" }',
            "catch { #/a/# }",
            "catch { {}() }",
            "catch let e where codes.contains(where: { $0 == e }) { log() }",
            "catch where f({}) { log() }",
        ):
            with self.subTest(block=block):
                self.assertEqual(self.swift(f"do {{ try f() }} {block}"), [])

    def test_other_uses_of_the_word_pass(self):
        cases = (
            ("publisher.catch { _ in }",),
            ("publisher", "    .catch {}"),
            ("let a = catchAll {}",),
            ("let a = didCatch {}",),
            ("run(catch: {})",),
            ("let a = `catch` {}",),
            ("// catch {}",),
            ("/* catch {} */",),
            ('let a = "catch {}"',),
            ('let a = """', "catch {", "}", '"""'),
        )
        for rows in cases:
            with self.subTest(rows=rows):
                self.assertEqual(self.swift(*rows), [])

    def test_every_swift_folder_is_covered(self):
        for path in (APP, KIT, RUNNER, "Tests/A.swift", "Project.swift", "scripts/a.swift"):
            with self.subTest(path=path):
                found = self.swift("do { try f() } catch {}", path=path)
                self.assertEqual(found, [("empty-catch", 1)])

    def test_other_languages_pass(self):
        self.assertEqual(self.python('a = "catch {}"'), [])
        self.assertEqual(self.config("a: catch {}"), [])


class AgentsSizeTests(RuleTestCase):
    def agents(self, text, path="AGENTS.md", language=Language.OTHER):
        return self.found(language, path=path, text=text)

    def test_the_limit(self):
        self.assertEqual(AGENTS_LIMIT, 6000)
        self.assertEqual(self.agents("a" * 6001), [("agents-size", None)])
        self.assertEqual(self.agents("a" * 6000), [])

    def test_the_message_gives_the_count_and_the_limit(self):
        (finding,) = check_rules("AGENTS.md", "a" * 6123, Language.OTHER)
        self.assertIn("6123", finding.message)
        self.assertIn("6000", finding.message)

    def test_characters_are_counted_not_bytes(self):
        for character in ("é", "—", "\U0001f600"):
            with self.subTest(character=character):
                self.assertEqual(self.agents(character * 6000), [])
                self.assertEqual(self.agents(character * 6001), [("agents-size", None)])

    def test_a_line_ending_is_one_character(self):
        for ending in ("\n", "\r\n", "\r"):
            with self.subTest(ending=ending):
                self.assertEqual(self.agents(f"abc{ending}" * 1500), [])
                over = f"abc{ending}" * 1500 + "a"
                self.assertEqual(self.agents(over), [("agents-size", None)])

    def test_a_byte_order_mark_is_not_counted(self):
        self.assertEqual(self.agents("\ufeff" + "a" * 6000), [])

    def test_only_the_file_at_the_root_is_limited(self):
        for path in ("docs/AGENTS.md", "CLAUDE.md", "docs/coding-standards.md", "OLD-AGENTS.md"):
            with self.subTest(path=path):
                self.assertEqual(self.agents("a" * 7000, path=path), [])


class UnreadableFileTests(RuleTestCase):
    def assert_same_as_comment_check(self, path, text, language):
        rules = check_rules(path, text, language)
        comments = check_comments(path, text, language)
        self.assertEqual(len(rules), 1, rules)
        self.assertEqual(rules, comments)

    def test_unparsable_python_gives_the_comment_checks_own_finding(self):
        self.assert_same_as_comment_check("a.py", "def f(:\n    # Phase 4\n", Language.PYTHON)

    def test_unclosed_swift_string_gives_the_comment_checks_own_finding(self):
        text = lines('let a = """', "text")
        self.assert_same_as_comment_check(APP, text, Language.SWIFT)

    def test_unclosed_swift_block_comment_gives_the_comment_checks_own_finding(self):
        text = lines("let a = 1", "/* open", "let p = Process()")
        self.assert_same_as_comment_check(APP, text, Language.SWIFT)

    def test_what_was_read_before_the_fault_is_still_checked(self):
        found = self.swift("let p = Process()", 'let a = """', "text")
        self.assertEqual(found, [("process-use", 1), ("parse-error", 2)])

    def test_a_closed_multi_line_block_comment_is_not_unreadable(self):
        self.assertEqual(self.swift("/* a", "b */", "let a = 1"), [])

    def test_shell_left_open_at_the_end_never_passes(self):
        cases = (
            (("true", "echo 'open # mg-032"), 2),
            (('echo "open', "true # Phase 4"), 1),
            (("x=$(date", "true"), 1),
            (("echo ${x", "true"), 1),
            (("x=$((1 + 2", "true"), 1),
            (("x=`date", "true"), 1),
            (("echo $'open",), 1),
        )
        for rows, line in cases:
            with self.subTest(rows=rows):
                self.assertEqual(self.shell(*rows), [("parse-error", line)])

    def test_complete_shell_is_not_reported(self):
        rows = (
            "case $x in",
            "a) echo ')' ;;",
            "(b) echo ;;",
            "esac",
            'x="$(case $y in c) echo 1 ;; esac)"',
            "f() { (cd /tmp && ls); }",
            "cat <<EOF",
            "don't",
            "EOF",
            'echo "${x:-\'}"',
            "# don't",
            "true # it's",
        )
        self.assertEqual(self.shell(*rows), [])


if __name__ == "__main__":
    unittest.main()
