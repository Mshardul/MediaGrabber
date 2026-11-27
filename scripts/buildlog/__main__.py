import math
import os
import subprocess
import sys
from pathlib import Path

# Run as a folder, Python puts only that folder on the path, where the package cannot be found.
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from buildlog.runner import Stage, run_stages

_LOG_DIR = Path("build/logs")
_IDLE_TIMEOUT = 600.0
_CLEANUP_TIMEOUT = 120
_STAGE_MARKS = {"@stage": False, "@tests": True}
_CLEANUP_MARK = "@cleanup"
_USAGE = "usage: scripts/buildlog NAME (@stage|@tests STAGE-NAME COMMAND...)... @cleanup COMMAND..."


# The commands stay in the Makefile, so the targets that CI runs and these stages share them.
def _parse(argv: list[str]) -> tuple[str, list[Stage], list[str]]:
    marks = [at for at, word in enumerate(argv) if word in (*_STAGE_MARKS, _CLEANUP_MARK)]
    if not marks or marks[0] != 1:
        raise ValueError(_USAGE)
    stages, cleanup = [], []
    for start, end in zip(marks, [*marks[1:], len(argv)], strict=True):
        mark, words = argv[start], argv[start + 1 : end]
        if mark == _CLEANUP_MARK:
            cleanup = words
        elif len(words) < 2:
            raise ValueError(_USAGE)
        else:
            stages.append(Stage(words[0], words[1:], _STAGE_MARKS[mark]))
    if not stages or not cleanup:
        raise ValueError(_USAGE)
    return argv[0], stages, cleanup


def _idle_timeout() -> float:
    text = os.environ.get("MG_STAGE_IDLE_TIMEOUT")
    if text is None:
        return _IDLE_TIMEOUT
    try:
        seconds = float(text)
    except ValueError:
        seconds = 0
    if not (seconds > 0 and math.isfinite(seconds)):
        raise ValueError(f"MG_STAGE_IDLE_TIMEOUT must be a number of seconds above 0: {text!r}")
    return seconds


def main(argv: list[str]) -> int:
    try:
        name, stages, command = _parse(argv)
        idle_timeout = _idle_timeout()
    except ValueError as error:
        print(error, file=sys.stderr)
        return 2
    log_path = _LOG_DIR / f"{name}.log"

    def cleanup() -> None:
        # In a session of its own, so a second Ctrl-C does not reach it.
        with log_path.open("ab") as log:
            subprocess.run(
                command,
                stdin=subprocess.DEVNULL,
                stdout=log,
                stderr=subprocess.STDOUT,
                start_new_session=True,
                timeout=_CLEANUP_TIMEOUT,
                check=True,
            )

    return run_stages(stages, _LOG_DIR, idle_timeout, cleanup, name=name)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
