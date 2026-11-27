import io
import json
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path

from buildlog.runner import Stage, run_stages
from buildlog.xcresult import TestCounts, XcresultError, read_xcresult
from checks.tools import Completed

# Stands in for xcodebuild: it prints what it is told to and makes the result bundle.
FAKE_BUILD = """
import sys
from pathlib import Path
bundle = Path(sys.argv[sys.argv.index("-resultBundlePath") + 1])
if bundle.exists():
    print("the earlier bundle is still there")
    raise SystemExit(70)
sys.stdout.write(Path(sys.argv[1]).read_text())
if sys.argv[2] == "bundle":
    bundle.mkdir(parents=True)
    (bundle / "new").touch()
raise SystemExit(int(sys.argv[3]))
"""


def summary(total=3, skipped=0, failures=()):
    return {
        "totalTestCount": total,
        "skippedTests": skipped,
        "testFailures": [
            {"targetName": target, "testIdentifierString": test, "failureText": text}
            for target, test, text in failures
        ],
    }


class FakeXcresult:
    def __init__(self, payload=None, returncode=0, stdout=None):
        self.stdout = json.dumps(summary() if payload is None else payload)
        if stdout is not None:
            self.stdout = stdout
        self.returncode = returncode
        self.calls = []

    def run(self, argv, cwd):
        self.calls.append(argv)
        return Completed(self.returncode, self.stdout, "tool broke" if self.returncode else "")


class SummaryTestCase(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name).resolve()
        self.bundle = self.root / "tests.xcresult"
        self.out = ""

    def xcode(self, text="", status=0, bundle=True):
        said = self.root / f"said-{len(list(self.root.glob('said-*')))}"
        said.write_text(text)
        argv = [sys.executable, "-c", FAKE_BUILD, str(said), "bundle" if bundle else "none"]
        argv += [str(status), "-resultBundlePath", str(self.bundle)]
        return Stage("Xcode tests", argv, True)

    def printing(self, name, text, status=0, counts=True, kind=()):
        code = "import sys; sys.stdout.write(sys.argv[1]); raise SystemExit(int(sys.argv[2]))"
        return Stage(name, [sys.executable, "-c", code, text, str(status), *kind], counts)

    def plugin(self, text, status=0):
        return self.printing("plugin tests", text, status, kind=("unittest",))

    def scripts(self, text, status=0):
        return self.printing("script tests", text, status)

    def run_stages(self, *stages, executor=None):
        out = io.StringIO()
        status = run_stages(
            list(stages),
            self.root / "logs",
            20,
            lambda: None,
            name="test",
            out=out,
            executor=executor or FakeXcresult(),
        )
        self.out = out.getvalue()
        return status

    def log(self):
        return (self.root / "logs/test.log").read_text()


class CountTests(SummaryTestCase):
    def test_a_passing_run_shows_a_count_for_each_test_stage(self):
        executor = FakeXcresult(summary(total=1094, skipped=1))
        status = self.run_stages(
            self.plugin("Ran 12 tests in 0.2s\n\nOK (skipped=2)\n"),
            self.scripts("Ran 900 tests in 3s\n\nOK\nscript tests: 17 run, 0 failed\n"),
            self.xcode(),
            executor=executor,
        )
        self.assertEqual(status, 0, self.out)
        self.assertIn("plugin tests: 10 executed, 2 skipped", self.out)
        self.assertIn("script tests: 17 executed\n", self.out)
        self.assertIn("Xcode tests: 1093 executed, 1 skipped", self.out)
        self.assertIn("test passed", self.out)
        self.assertIn(f"Full log: {self.root / 'logs/test.log'}", self.out)
        self.assertEqual(
            executor.calls,
            [
                ["xcrun", "xcresulttool", "get", "test-results", "summary"]
                + ["--path", str(self.bundle)]
            ],
        )

    def test_test_stage_with_zero_executed_fails_even_with_skips(self):
        cases = {
            "plugin": (self.plugin("Ran 3 tests in 0s\n\nOK (skipped=3)\n"), None),
            "plugin with no count": (self.plugin("nothing here\n"), None),
            "scripts": (self.scripts("script tests: 0 run, 0 failed, 2 excluded: a b\n"), None),
            "scripts with another count only": (self.scripts("Ran 5 tests in 1s\n"), None),
            "Xcode": (self.xcode(), FakeXcresult(summary(total=4, skipped=4))),
            "Xcode with none": (self.xcode(), FakeXcresult(summary(total=0))),
        }
        for name, (stage, executor) in cases.items():
            with self.subTest(name):
                status = self.run_stages(stage, executor=executor)
                self.assertEqual(status, 1, self.out)
                self.assertIn(f"stage '{stage.name}' executed no tests", self.out)
                self.assertNotIn("passed", self.out)

    def test_stages_that_were_not_reached_are_said_to_be_not_run(self):
        self.run_stages(self.plugin("Ran 1 test in 0s\n\nFAILED (failures=1)\n", 1), self.xcode())
        self.assertIn("plugin tests: 1 executed", self.out)
        self.assertIn("Xcode tests: not run", self.out)


class BundleTests(SummaryTestCase):
    def test_old_result_bundle_is_removed_before_run(self):
        self.bundle.mkdir()
        (self.bundle / "old").touch()
        self.assertEqual(self.run_stages(self.xcode()), 0, self.out)
        self.assertEqual([path.name for path in self.bundle.iterdir()], ["new"])

    def test_old_result_bundle_is_removed_even_when_an_earlier_stage_fails(self):
        self.bundle.mkdir()
        self.run_stages(self.scripts("script tests: 1 run, 1 failed\n", 1), self.xcode())
        self.assertFalse(self.bundle.exists())

    def test_a_path_that_is_not_a_result_bundle_is_never_removed(self):
        self.bundle = self.root / "keep"
        self.bundle.mkdir()
        self.assertEqual(self.run_stages(self.xcode()), 1)
        self.assertTrue(self.bundle.exists())
        self.assertIn("must end in .xcresult", self.out)

    def test_missing_new_bundle_fails(self):
        self.bundle.mkdir()
        executor = FakeXcresult()
        status = self.run_stages(self.xcode(bundle=False), executor=executor)
        self.assertEqual(status, 1, self.out)
        self.assertIn("no new result bundle", self.out)
        self.assertEqual(executor.calls, [])

    def test_a_failed_stage_keeps_its_status_when_the_bundle_is_missing(self):
        self.assertEqual(self.run_stages(self.xcode(status=65, bundle=False)), 65)
        self.assertIn("no new result bundle", self.out)

    def test_an_unreadable_bundle_fails_a_passing_stage(self):
        status = self.run_stages(self.xcode(), executor=FakeXcresult(returncode=64))
        self.assertEqual(status, 1, self.out)
        self.assertIn("tool broke", self.out)

    def test_reported_failures_fail_a_stage_that_exited_0(self):
        executor = FakeXcresult(summary(failures=[("Kit", "Suite/testA()", "wrong")]))
        self.assertEqual(self.run_stages(self.xcode(), executor=executor), 1)
        self.assertIn("Kit Suite/testA(): wrong", self.out)


class XcresultTests(unittest.TestCase):
    def read(self, executor):
        return read_xcresult(Path("a.xcresult"), executor)

    def test_executed_leaves_out_skipped_tests(self):
        failure = ("Kit", "Suite/testA()", "line one\n  line two")
        counts = self.read(FakeXcresult(summary(10, 3, [failure])))
        self.assertEqual(counts, TestCounts(7, 3, ["Kit Suite/testA(): line one line two"]))

    def test_each_missing_field_is_named(self):
        full = summary(failures=[("Kit", "Suite/testA()", "wrong")])
        for field in ("totalTestCount", "skippedTests", "testFailures"):
            with self.subTest(field):
                partial = {key: value for key, value in full.items() if key != field}
                with self.assertRaisesRegex(XcresultError, field):
                    self.read(FakeXcresult(partial))
        for field in ("targetName", "testIdentifierString", "failureText"):
            with self.subTest(field):
                entry = {k: v for k, v in full["testFailures"][0].items() if k != field}
                with self.assertRaisesRegex(XcresultError, field):
                    self.read(FakeXcresult({**full, "testFailures": [entry]}))

    def test_output_that_cannot_be_read_is_an_error(self):
        wrong = {**summary(), "totalTestCount": "3"}
        for name, executor in {
            "not JSON": FakeXcresult(stdout="oops"),
            "not an object": FakeXcresult(stdout="[]"),
            "wrong type": FakeXcresult(wrong),
            "tool failed": FakeXcresult(returncode=1),
        }.items():
            with self.subTest(name), self.assertRaises(XcresultError):
                self.read(executor)


class ShortOutputTests(SummaryTestCase):
    def test_compiler_errors_and_failed_tests_are_shown_once_with_repeat_count(self):
        error = "/repo/Sources/A.swift:4:9: error: cannot find 'x' in scope\n"
        noise = "CompileSwift normal arm64\n" * 100
        failure = ("Kit", "Suite/testA()", "XCTAssertEqual failed")
        executor = FakeXcresult(summary(failures=[failure, failure]))
        status = self.run_stages(self.xcode(error + noise + error + error, 65), executor=executor)
        self.assertEqual(status, 65)
        self.assertEqual(self.out.count("cannot find 'x' in scope"), 1)
        self.assertIn("error: cannot find 'x' in scope (3 times)", self.out)
        self.assertEqual(self.out.count("XCTAssertEqual failed"), 1)
        self.assertIn("Kit Suite/testA(): XCTAssertEqual failed (2 times)", self.out)
        self.assertNotIn("CompileSwift", self.out)

    def test_errors_without_a_source_location_are_shown(self):
        lines = [
            'error: Signing for "MediaGrabber" requires a team',
            "xcodebuild: error: Unable to find a destination",
            "clang: error: linker command failed with exit code 1",
        ]
        self.run_stages(self.printing("build", "\n".join(["noise", *lines]) + "\n", 65, False))
        for line in lines:
            self.assertIn(line, self.out)
        self.assertNotIn("noise", self.out)

    def test_failed_unit_and_script_tests_are_named(self):
        text = "FAIL: the sum is wrong\nFAILED: test_b.sh\nscript tests: 2 run, 1 failed\n"
        self.run_stages(self.scripts("error: expected by a passing case\n" + text, 1))
        self.assertIn("FAIL: the sum is wrong", self.out)
        self.assertIn("FAILED: test_b.sh", self.out)
        self.assertNotIn("expected by a passing case", self.out)
        text = "ERROR: test_x (mod.Case.test_x)\nRan 1 test in 0s\n\nFAILED (errors=1)\n"
        self.run_stages(self.plugin(text, 1))
        self.assertIn("ERROR: test_x (mod.Case.test_x)", self.out)

    def test_capped_errors_say_how_many_were_left_out(self):
        text = "".join(f"/repo/A.swift:{n}:1: error: number {n}\n" for n in range(1, 61))
        self.run_stages(self.printing("build", text, 65, False))
        self.assertIn("error: number 50\n", self.out)
        self.assertNotIn("error: number 51\n", self.out)
        self.assertIn("10 more not shown", self.out)

    def test_warnings_stay_out_of_short_output_and_in_the_log(self):
        warning = "/repo/A.swift:1:1: warning: unused variable 'y'\n"
        cases = {
            "passed": self.printing("build", warning, 0, False),
            "compile error": self.printing(
                "build", warning + "/repo/A.swift:2:2: error: bad\n", 65, False
            ),
            "unknown failure": self.printing("build", warning + "it just stopped\n", 65, False),
        }
        for name, stage in cases.items():
            with self.subTest(name):
                self.run_stages(stage)
                self.assertNotIn("unused variable", self.out)
                self.assertIn("unused variable", self.log())

    def test_unknown_failure_shows_stage_name_and_log_tail(self):
        earlier = self.printing("first", "from the first stage\n", 0, False)
        text = "".join(f"line {n}\n" for n in range(1, 101)) + "x" * 5000 + "\n"
        status = self.run_stages(earlier, self.printing("generate", text, 3, False))
        self.assertEqual(status, 3)
        self.assertIn("test failed: stage 'generate' exited with status 3", self.out)
        self.assertIn("line 100\n", self.out)
        self.assertIn("line 62\n", self.out)
        self.assertNotIn("line 61\n", self.out)
        self.assertNotIn("from the first stage", self.out)
        self.assertLess(max(map(len, self.out.splitlines())), 600)
        self.assertIn("Full log:", self.out)

    def test_the_tail_of_a_short_stage_does_not_reach_into_the_one_before(self):
        earlier = self.printing("first", "from the first stage\n", 0, False)
        self.run_stages(earlier, self.printing("second", "only this\n", 1, False))
        self.assertIn("only this", self.out)
        self.assertNotIn("from the first stage", self.out)

    def test_output_that_is_not_utf8_is_still_shown(self):
        code = "import sys; sys.stdout.buffer.write(b'\\xff broke\\n'); raise SystemExit(1)"
        stage = Stage("odd", [sys.executable, "-c", textwrap.dedent(code)], False)
        self.assertEqual(self.run_stages(stage), 1)
        self.assertIn("broke", self.out)


if __name__ == "__main__":
    unittest.main()
