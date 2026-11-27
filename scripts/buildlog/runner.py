import os
import shlex
import shutil
import signal
import subprocess
import sys
import time
from collections.abc import Callable, Iterator
from contextlib import contextmanager
from dataclasses import dataclass, field
from pathlib import Path
from typing import BinaryIO, TextIO

from checks.tools import Exec, SystemExec

from buildlog.summary import counts_lines, failure_lines, script_counts, unittest_counts
from buildlog.xcresult import TestCounts, XcresultError, read_xcresult

STOP_GRACE = 10.0
_POLL = 0.1
_BUNDLE_FLAG = "-resultBundlePath"
_SIGNALS = (signal.SIGINT, signal.SIGTERM, signal.SIGHUP)
_TIMED_OUT = 124
_CANNOT_START = 127


@dataclass(frozen=True)
class Stage:
    name: str
    argv: list[str]
    counts_tests: bool

    @property
    def bundle(self) -> Path | None:
        if _BUNDLE_FLAG not in self.argv[:-1]:
            return None
        return Path(self.argv[self.argv.index(_BUNDLE_FLAG) + 1])


@dataclass
class _Outcome:
    status: int = 0
    # Why the run failed, as the end of a sentence about the stage.
    reason: str = ""
    stage: str = ""
    details: list[str] = field(default_factory=list)


# The handler only records the signal, so that a second one cannot cut the cleanup short.
@contextmanager
def _signals() -> Iterator[list[int]]:
    received: list[int] = []
    previous = {}
    for number in _SIGNALS:
        # A run started with nohup ignores the hang-up on purpose.
        if number == signal.SIGHUP and signal.getsignal(number) == signal.SIG_IGN:
            continue
        previous[number] = signal.signal(number, lambda got, frame: received.append(got))
    try:
        yield received
    finally:
        for number, handler in previous.items():
            signal.signal(number, handler)


def _group_alive(group: int) -> bool:
    try:
        os.killpg(group, 0)
    # macOS answers "not permitted" for a group that holds only exited processes.
    except ProcessLookupError, PermissionError:
        return False
    return True


def _signal_group(group: int, number: int) -> None:
    try:
        os.killpg(group, number)
    # The group ended first, and the wait that follows confirms it.
    except ProcessLookupError, PermissionError:
        return


def _group_ends(process: subprocess.Popen) -> bool:
    deadline = time.monotonic() + STOP_GRACE
    while time.monotonic() < deadline:
        # macOS can call a group gone before its exited child is able to be collected.
        gone = not _group_alive(process.pid)
        if process.poll() is not None and gone:
            return True
        time.sleep(_POLL)
    return False


# Each stage leads a process group of its own, so its grandchildren are stopped along with it.
def _stop(process: subprocess.Popen) -> bool:
    _signal_group(process.pid, signal.SIGTERM)
    if _group_ends(process):
        return True
    _signal_group(process.pid, signal.SIGKILL)
    return _group_ends(process)


def _watch(
    process: subprocess.Popen, log: BinaryIO, idle_timeout: float, received: list[int]
) -> _Outcome:
    size, changed = -1, time.monotonic()
    while True:
        if received:
            return _interrupted(received)
        status = process.poll()
        if status is not None:
            status = status if status >= 0 else 128 - status
            return _Outcome(status, f"exited with status {status}" if status else "")
        now = os.fstat(log.fileno()).st_size
        if now != size:
            size, changed = now, time.monotonic()
        elif time.monotonic() - changed >= idle_timeout:
            return _Outcome(_TIMED_OUT, f"printed nothing for {idle_timeout:g} seconds")
        time.sleep(_POLL)


def _interrupted(received: list[int]) -> _Outcome:
    return _Outcome(128 + received[0], "was interrupted")


def _run_stage(stage: Stage, log: BinaryIO, idle_timeout: float, received: list[int]) -> _Outcome:
    try:
        # Output goes straight to the file, so a process left behind cannot hold a pipe open.
        process = subprocess.Popen(
            stage.argv,
            stdin=subprocess.DEVNULL,
            stdout=log,
            stderr=subprocess.STDOUT,
            start_new_session=True,
        )
    except OSError as error:
        return _Outcome(_CANNOT_START, f"could not start: {error}")
    finished = False
    try:
        outcome = _watch(process, log, idle_timeout, received)
        finished = process.returncode is not None and not received
    finally:
        if not finished and not _stop(process):
            print(f"Processes of stage '{stage.name}' are still running.", file=sys.stderr)
    return outcome


def _remove_bundles(stages: list[Stage]) -> None:
    for bundle in (stage.bundle for stage in stages):
        if bundle is None:
            continue
        # The path comes from the command line, and a whole folder is removed.
        if bundle.suffix != ".xcresult":
            raise OSError(f"a result bundle path must end in .xcresult: {bundle}")
        if bundle.exists():
            shutil.rmtree(bundle)


def _count(stage: Stage, output: str, executor: Exec) -> TestCounts:
    if stage.bundle is None:
        return unittest_counts(output) if "unittest" in stage.argv else script_counts(output)
    if not stage.bundle.exists():
        raise XcresultError(f"there is no new result bundle at {stage.bundle}")
    return read_xcresult(stage.bundle, executor)


def _judge(stage: Stage, outcome: _Outcome, counts: TestCounts) -> None:
    if outcome.status:
        return
    if counts.failures:
        outcome.status, outcome.reason = 1, "reported failed tests"
    elif counts.executed <= 0:
        outcome.status = 1
        outcome.reason = f"executed no tests ({counts.skipped} skipped)"


class _Run:
    def __init__(self, log_path: Path, idle_timeout: float, out: TextIO, executor: Exec):
        self.log_path = log_path
        self.idle_timeout = idle_timeout
        self.out = out
        self.executor = executor
        self.counts: dict[str, TestCounts] = {}

    def say(self, line: str) -> None:
        self.out.write(f"{line}\n")
        self.out.flush()

    def stages(self, stages: list[Stage], received: list[int]) -> _Outcome:
        _remove_bundles(stages)
        with self.log_path.open("ab", buffering=0) as log:
            for number, stage in enumerate(stages, 1):
                if received:
                    return _Outcome(stage=stage.name)
                self.say(f"[{number}/{len(stages)}] {stage.name}")
                outcome = self.one(stage, log, received)
                if outcome.status:
                    return outcome
        return _Outcome()

    def one(self, stage: Stage, log: BinaryIO, received: list[int]) -> _Outcome:
        log.write(f"\n== {stage.name}: {shlex.join(stage.argv)}\n".encode(errors="replace"))
        start = os.fstat(log.fileno()).st_size
        outcome = _run_stage(stage, log, self.idle_timeout, received)
        outcome.stage = stage.name
        output = self.log_path.read_bytes()[start:].decode(errors="replace")
        failures, problem = [], []
        # A stopped stage has no result worth reading.
        stopped = received or outcome.status in (_TIMED_OUT, _CANNOT_START)
        if stage.counts_tests and not stopped:
            try:
                counts = _count(stage, output, self.executor)
            except (XcresultError, OSError) as error:
                problem = [f"Test results: {error}"]
                outcome.status = outcome.status or 1
                outcome.reason = outcome.reason or "has no test results"
            else:
                self.counts[stage.name] = counts
                failures = counts.failures
                _judge(stage, outcome, counts)
        if outcome.status:
            compiles = not stage.counts_tests or stage.bundle is not None
            outcome.details = problem
            outcome.details += failure_lines(output, compiles, failures, str(self.log_path))
        return outcome


def run_stages(
    stages: list[Stage],
    log_dir: Path,
    idle_timeout: float,
    cleanup: Callable[[], None],
    *,
    name: str = "build",
    out: TextIO | None = None,
    executor: Exec | None = None,
) -> int:
    log_dir.mkdir(parents=True, exist_ok=True)
    log_path = log_dir / f"{name}.log"
    log_path.write_bytes(b"")
    run = _Run(log_path, idle_timeout, out or sys.stdout, executor or SystemExec())
    outcome = None
    cleanup_problem = ""
    with _signals() as received:
        try:
            outcome = run.stages(stages, received)
        except OSError as error:
            outcome = _Outcome(1, f"could not run: {error}")
        finally:
            if received and outcome is not None:
                stage = outcome.stage
                outcome = _interrupted(received)
                outcome.stage = stage
            # A build's app is what install copies; a test run's app is never kept.
            keep = outcome is not None and not outcome.status
            if not keep or any(stage.counts_tests for stage in stages):
                try:
                    cleanup()
                except (OSError, subprocess.SubprocessError) as error:
                    cleanup_problem = f"Cleanup failed, so a built app may remain: {error}"
                    # Said at once, because an exception on its way out would hide a later line.
                    run.say(cleanup_problem)
    status = outcome.status or (1 if cleanup_problem else 0)
    if outcome.reason == "was interrupted":
        run.say(f"{name} interrupted during stage '{outcome.stage}'")
    elif outcome.status:
        run.say(f"{name} failed: stage '{outcome.stage}' {outcome.reason}")
        for line in outcome.details:
            run.say(line)
    elif not status:
        run.say(f"{name} passed")
    for line in counts_lines([s.name for s in stages if s.counts_tests], run.counts):
        run.say(line)
    run.say(f"Full log: {log_path}")
    return status
