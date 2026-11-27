import io
import os
import signal
import subprocess
import sys
import tempfile
import textwrap
import time
import unittest
from pathlib import Path
from unittest import mock

from buildlog import runner
from buildlog.runner import Stage, run_stages

REPO = Path(__file__).resolve().parents[3]
CLI = REPO / "scripts" / "buildlog"
LIMIT = 20.0

# The stage starts a grandchild, so a kill that stops only the direct child leaves it running.
FAMILY = """
import os, signal, subprocess, sys, time
from pathlib import Path
if sys.argv[2] == "stubborn":
    signal.signal(signal.SIGTERM, signal.SIG_IGN)
    signal.signal(signal.SIGINT, signal.SIG_IGN)
grandchild = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(60)"])
Path(sys.argv[1] + ".new").write_text(f"{os.getpid()} {grandchild.pid}")
os.rename(sys.argv[1] + ".new", sys.argv[1])
time.sleep(60)
"""


def python(code, *args):
    return [sys.executable, "-c", textwrap.dedent(code), *args]


def alive(pid):
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    return True


class RunnerTestCase(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name).resolve()
        self.logs = self.root / "logs"
        self.out = io.StringIO()
        self.cleanups = 0

    def cleanup(self):
        self.cleanups += 1

    def run_stages(self, *stages, idle_timeout=LIMIT, cleanup=None):
        return run_stages(
            list(stages), self.logs, idle_timeout, cleanup or self.cleanup, out=self.out
        )

    def wait_until(self, condition, what):
        deadline = time.monotonic() + LIMIT
        while not condition():
            if time.monotonic() > deadline:
                self.fail(f"timed out waiting for {what}")
            time.sleep(0.02)

    def family(self, mood):
        # A file left by an earlier case would say its stage had started before it had.
        record = self.root / f"pids-{len(list(self.root.glob('pids-*')))}-{mood}"
        self.addCleanup(self.kill_recorded, record)
        return record, python(FAMILY, str(record), mood)

    def recorded(self, record):
        return [int(pid) for pid in record.read_text().split()]

    def kill_recorded(self, record):
        for pid in self.recorded(record) if record.exists() else []:
            if alive(pid):
                os.kill(pid, signal.SIGKILL)

    def assert_family_gone(self, record):
        pids = self.recorded(record)
        self.assertEqual(len(pids), 2)
        for pid, who in zip(pids, ("child", "grandchild"), strict=True):
            self.wait_until(lambda pid=pid: not alive(pid), f"the {who} to stop")


class StageTests(RunnerTestCase):
    def test_prints_one_progress_line_per_stage(self):
        status = self.run_stages(
            Stage("first", python("print('inside one')"), False),
            Stage("second", python("print('inside two')"), False),
        )
        self.assertEqual(status, 0)
        lines = self.out.getvalue().splitlines()
        self.assertEqual([line for line in lines if line.startswith("[")], lines[:2])
        self.assertEqual(lines[:2], ["[1/2] first", "[2/2] second"])
        self.assertNotIn("inside", self.out.getvalue())
        log = (self.logs / "build.log").read_text()
        self.assertIn("inside one", log)
        self.assertIn("inside two", log)

    def test_progress_line_is_visible_while_the_stage_runs(self):
        release = self.root / "release"
        seen = []

        class Watching(io.StringIO):
            def flush(inner):
                if "[1/1] slow" in inner.getvalue() and not release.exists():
                    seen.append(inner.getvalue())
                    release.touch()

        self.out = Watching()
        wait = """
            import sys, time
            from pathlib import Path
            while not Path(sys.argv[1]).exists():
                time.sleep(0.02)
        """
        status = self.run_stages(Stage("slow", python(wait, str(release)), False), idle_timeout=5)
        self.assertEqual(status, 0)
        self.assertEqual(seen, ["[1/1] slow\n"])

    def test_stage_exit_status_is_preserved(self):
        ran = self.root / "ran"
        status = self.run_stages(
            Stage("breaks", python("raise SystemExit(65)"), False),
            Stage("later", python("import sys; open(sys.argv[1], 'w')", str(ran)), False),
        )
        self.assertEqual(status, 65)
        self.assertFalse(ran.exists())
        self.assertIn("stage 'breaks' exited with status 65", self.out.getvalue())
        self.assertEqual(self.cleanups, 1)

    def test_a_stage_ended_by_a_signal_reports_the_shell_status(self):
        code = "import os, signal; os.kill(os.getpid(), signal.SIGKILL)"
        self.assertEqual(self.run_stages(Stage("killed", python(code), False)), 128 + 9)

    def test_a_command_that_cannot_start_fails_and_cleans_up(self):
        status = self.run_stages(Stage("absent", [str(self.root / "no-such-tool")], False))
        self.assertEqual(status, 127)
        self.assertIn("stage 'absent' could not start", self.out.getvalue())
        self.assertEqual(self.cleanups, 1)

    def test_a_successful_build_keeps_the_app(self):
        self.assertEqual(self.run_stages(Stage("build", python("pass"), False)), 0)
        self.assertEqual(self.cleanups, 0)

    def test_a_successful_test_run_still_removes_the_app(self):
        stage = Stage("plugin", python("print('Ran 2 tests in 0.1s')") + ["unittest"], True)
        self.assertEqual(self.run_stages(stage), 0)
        self.assertEqual(self.cleanups, 1)

    def test_a_failed_cleanup_is_reported_and_fails_the_run(self):
        def broken():
            raise OSError("cannot remove")

        stage = Stage("plugin", python("print('Ran 1 test in 0.1s')") + ["unittest"], True)
        self.assertEqual(self.run_stages(stage, cleanup=broken), 1)
        self.assertIn("a built app may remain: cannot remove", self.out.getvalue())

    def test_a_failed_cleanup_keeps_the_stage_status(self):
        def broken():
            raise OSError("cannot remove")

        stage = Stage("breaks", python("raise SystemExit(7)"), False)
        self.assertEqual(self.run_stages(stage, cleanup=broken), 7)
        self.assertIn("cannot remove", self.out.getvalue())

    def test_steady_output_does_not_count_as_hung(self):
        code = """
            import time
            for step in range(8):
                print(step, flush=True)
                time.sleep(0.25)
        """
        self.assertEqual(self.run_stages(Stage("chatty", python(code), False), idle_timeout=1), 0)


class StopTests(RunnerTestCase):
    def test_idle_timeout_kills_the_process_group_and_runs_cleanup(self):
        for mood in ("polite", "stubborn"):
            with self.subTest(mood):
                self.cleanups = 0
                record, argv = self.family(mood)
                gone_at_cleanup = []

                def cleanup(record=record):
                    self.cleanup()
                    gone_at_cleanup.append([not alive(pid) for pid in self.recorded(record)][0])

                with mock.patch.object(runner, "STOP_GRACE", 0.5):
                    status = self.run_stages(
                        Stage("hung", argv, False), idle_timeout=1.5, cleanup=cleanup
                    )
                self.assertEqual(status, 124)
                self.assert_family_gone(record)
                self.assertEqual(self.cleanups, 1)
                self.assertEqual(gone_at_cleanup, [True])
                self.assertIn("stage 'hung' printed nothing for 1.5 seconds", self.out.getvalue())

    def start_cli(self, record_argv, cleanup_code, *cleanup_args):
        environment = {**os.environ, "MG_STAGE_IDLE_TIMEOUT": "60", "PYTHONDONTWRITEBYTECODE": "1"}
        process = subprocess.Popen(
            [sys.executable, str(CLI), "build", "@stage", "long", *record_argv]
            + ["@cleanup", *python(cleanup_code, *cleanup_args)],
            cwd=self.root,
            env=environment,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            start_new_session=True,
            text=True,
        )
        self.addCleanup(self.end, process)
        return process

    def end(self, process):
        if process.poll() is None:
            process.kill()
            process.wait()
        process.stdout.close()

    def test_interrupt_kills_children_and_runs_cleanup(self):
        cases = ((signal.SIGINT, "polite"), (signal.SIGTERM, "stubborn"), (signal.SIGHUP, "polite"))
        for number, mood in cases:
            with self.subTest(signal=number.name, mood=mood):
                record, argv = self.family(mood)
                started = self.root / f"cleaning-{number.name}"
                finished = self.root / f"cleaned-{number.name}"
                slow = """
                    import sys, time
                    from pathlib import Path
                    Path(sys.argv[1]).touch()
                    time.sleep(1)
                    Path(sys.argv[2]).touch()
                """
                process = self.start_cli(argv, slow, str(started), str(finished))
                self.wait_until(record.exists, "the stage to start")
                # The whole group is signalled, as a terminal does for Ctrl-C.
                os.killpg(process.pid, number)
                self.wait_until(
                    lambda: started.exists() or process.poll() is not None, "cleanup to start"
                )
                if not started.exists():
                    self.fail(f"ended without cleanup: {process.communicate()[0]}")
                os.killpg(process.pid, number)
                output = process.communicate(timeout=LIMIT)[0]
                self.assertEqual(process.returncode, 128 + number, output)
                self.assert_family_gone(record)
                self.assertTrue(finished.exists(), "a second interrupt must not stop cleanup")
                self.assertIn("interrupted during stage 'long'", output)


class CommandLineTests(RunnerTestCase):
    def cli(self, *args, **extra):
        return subprocess.run(
            [sys.executable, str(CLI), *args],
            cwd=self.root,
            env={**os.environ, "PYTHONDONTWRITEBYTECODE": "1", **extra},
            capture_output=True,
            text=True,
            timeout=LIMIT,
            check=False,
        )

    def test_the_idle_timeout_comes_from_the_environment(self):
        done = self.cli(
            "build",
            *("@stage", "quiet", *python("import time; time.sleep(60)")),
            *("@cleanup", *python("open('cleaned', 'w')")),
            MG_STAGE_IDLE_TIMEOUT="1",
        )
        self.assertEqual(done.returncode, 124, done.stdout + done.stderr)
        self.assertTrue((self.root / "cleaned").exists())
        self.assertTrue((self.root / "build/logs/build.log").exists())

    def test_a_failing_cleanup_command_is_reported(self):
        done = self.cli(
            "build",
            *("@stage", "breaks", *python("raise SystemExit(3)")),
            *("@cleanup", *python("raise SystemExit(5)")),
        )
        self.assertEqual(done.returncode, 3, done.stdout + done.stderr)
        self.assertIn("a built app may remain", done.stdout)

    def test_bad_arguments_run_nothing(self):
        touch = python("open('ran', 'w')")
        cases = {
            "no cleanup": (["build", "@stage", "a", *touch], {}),
            "no stage": (["build", "@cleanup", *touch], {}),
            "empty command": (["build", "@stage", "a", "@cleanup", *touch], {}),
            "stray word": (["build", "oops", "@stage", "a", *touch, "@cleanup", *touch], {}),
        }
        good = ["build", "@stage", "a", *touch, "@cleanup", *touch]
        for value in ("soon", "0", "-1", "nan", "inf"):
            cases[f"timeout {value}"] = (good, {"MG_STAGE_IDLE_TIMEOUT": value})
        for name, (argv, extra) in cases.items():
            with self.subTest(name):
                done = self.cli(*argv, **extra)
                self.assertEqual(done.returncode, 2, done.stdout + done.stderr)
                self.assertFalse((self.root / "ran").exists())


# The real Makefile runs against a fake Python, so no recipe reaches a build tool.
class MakefileTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name).resolve()
        (self.root / "Makefile").write_bytes((REPO / "Makefile").read_bytes())
        self.calls = self.root / "calls"
        self.script("fake-python", f"printf '%s\\n' \"$@\" >>'{self.calls}'")
        for tool in ("xcodebuild", "mise"):
            self.script(tool, f"echo '{tool} was reached' >>'{self.calls}'; exit 99")

    def script(self, name, body):
        path = self.root / name
        path.write_text(f"#!/bin/sh\n{body}\n")
        path.chmod(0o755)

    def make(self, *args):
        inherited = ("MAKEFLAGS", "MFLAGS", "MAKELEVEL", "CONFIG", "ONLY", "DERIVED", "PY")
        environment = {k: v for k, v in os.environ.items() if k not in inherited}
        environment["PATH"] = f"{self.root}:/usr/bin:/bin"
        done = subprocess.run(
            ["/usr/bin/make", "-C", str(self.root), f"PY={self.root}/fake-python", *args],
            env=environment,
            capture_output=True,
            text=True,
            timeout=LIMIT,
            check=False,
        )
        self.assertEqual(done.returncode, 0, done.stdout + done.stderr)
        words = self.calls.read_text().splitlines()
        self.assertEqual(words[:2], ["-B", "scripts/buildlog"])
        return words[2:]

    def parts(self, words):
        found = []
        for word in words:
            if word.startswith("@"):
                found.append([word])
            else:
                found[-1].append(word)
        return found

    def test_make_test_runs_every_stage_through_the_runner(self):
        words = self.make("test", "SCRIPT_TEST_ARGS=--exclude one.sh")
        self.assertEqual(words[0], "test")
        plugin, scripts, generate, xcode, cleanup = self.parts(words[1:])
        self.assertEqual(plugin[:2], ["@tests", "plugin tests"])
        self.assertIn("unittest", plugin)
        self.assertIn("test_*.py", plugin)
        self.assertEqual(
            scripts,
            ["@tests", "script tests", "scripts/run-script-tests.sh", "--exclude", "one.sh"],
        )
        self.assertEqual(generate[:3], ["@stage", "generate", "mise"])
        self.assertEqual(xcode[:3], ["@tests", "Xcode tests", "xcodebuild"])
        self.assertEqual(xcode[-1], "test")
        self.assertIn("MediaGrabber-Workspace", xcode)
        self.assertIn("platform=macOS", xcode)
        self.assertEqual(xcode[xcode.index("-resultBundlePath") + 1], "build/logs/tests.xcresult")
        self.assertFalse([word for word in xcode if word.startswith("-only-testing")])
        self.assertEqual(
            cleanup, ["@cleanup", "make", "--no-print-directory", "drop-build-app", "DERIVED=build"]
        )

    def test_make_test_passes_only_and_derived_on(self):
        words = self.make("test", "ONLY=GrabberKitTests/Some", "DERIVED=other")
        self.assertIn("-only-testing:GrabberKitTests/Some", words)
        self.assertEqual(words[words.index("-derivedDataPath") + 1], "other")
        self.assertEqual(words[-1], "DERIVED=other")

    def test_make_build_runs_every_stage_through_the_runner(self):
        words = self.make("build", "CONFIG=Release")
        self.assertEqual(words[0], "build")
        tools, generate, build, cleanup = self.parts(words[1:])
        self.assertEqual(tools, ["@stage", "tools", "scripts/fetch-tools.sh"])
        self.assertEqual(generate[:3], ["@stage", "generate", "mise"])
        self.assertEqual(build[:3], ["@stage", "build", "xcodebuild"])
        self.assertEqual(build[build.index("-configuration") + 1], "Release")
        self.assertEqual(build[-1], "build")
        self.assertEqual(cleanup[-2:], ["drop-build-app", "DERIVED=build"])


if __name__ == "__main__":
    unittest.main()
