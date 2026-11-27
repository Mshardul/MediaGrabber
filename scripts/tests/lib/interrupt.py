import os
import signal
import subprocess
import sys
import time
from pathlib import Path

_TIMEOUT = 20.0
_FAILED = 99


def main(ready: Path, argv: list[str]) -> int:
    # A shell's background job ignores Ctrl-C, so the default is restored for the child.
    signal.signal(signal.SIGINT, signal.SIG_DFL)
    process = subprocess.Popen(argv, start_new_session=True)
    deadline = time.monotonic() + _TIMEOUT
    while not ready.exists():
        if process.poll() is not None or time.monotonic() > deadline:
            if process.poll() is None:
                os.killpg(process.pid, signal.SIGKILL)
            print(f"interrupt: the command never created {ready}", file=sys.stderr)
            return _FAILED
        time.sleep(0.05)
    os.killpg(process.pid, signal.SIGINT)
    try:
        status = process.wait(timeout=_TIMEOUT)
    except subprocess.TimeoutExpired:
        os.killpg(process.pid, signal.SIGKILL)
        print("interrupt: the command ignored Ctrl-C", file=sys.stderr)
        return _FAILED
    return status if status >= 0 else 128 - status


if __name__ == "__main__":
    sys.exit(main(Path(sys.argv[1]), sys.argv[2:]))
