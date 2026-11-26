import os
import re
import subprocess
from collections.abc import Callable
from enum import Enum, auto
from pathlib import Path
from typing import NamedTuple, Protocol


class Scope(Enum):
    CHANGED = auto()
    STAGED = auto()
    ALL = auto()


class AddedLine(NamedTuple):
    path: str
    line: int
    text: str


class Repo(Protocol):
    def paths(self, scope: Scope) -> list[str]: ...

    def added_lines(self, scope: Scope, base: str | None = None) -> list[AddedLine] | None: ...

    def changed_since(self, scope: Scope, base: str) -> list[str] | None: ...


class GitError(RuntimeError):
    pass


CommandRunner = Callable[[list[str], Path], subprocess.CompletedProcess[bytes]]


def run_command(argv: list[str], cwd: Path) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(argv, cwd=cwd, capture_output=True, check=False)


_GIT = ["git", "-c", "core.quotePath=false"]
_UNTRACKED = ["ls-files", "-z", "--others", "--exclude-standard"]
_EVERY_FILE = ["ls-files", "-z", "--cached", "--others", "--exclude-standard"]
# Without --no-renames a rename hides the old name, which may be a settings file.
_NAMES = ["diff", "--name-only", "-z", "--no-renames", "--no-relative"]
# Each flag overrides a user setting that would change the shape of the patch.
_PATCH = [
    "diff",
    "-U0",
    "--inter-hunk-context=0",
    "--no-color",
    "--no-ext-diff",
    "--no-textconv",
    "--no-relative",
    "--find-renames",
    "--src-prefix=a/",
    "--dst-prefix=b/",
]


class GitRepo(Repo):
    def __init__(self, root: Path, runner: CommandRunner = run_command):
        self._root = root
        self._runner = runner

    def paths(self, scope: Scope) -> list[str]:
        if scope is Scope.ALL:
            found = self._listed(_EVERY_FILE)
        elif scope is Scope.STAGED:
            found = self._listed([*_NAMES, "--cached", "--"])
        else:
            found = self._listed([*_NAMES, "HEAD", "--"]) + self._listed(_UNTRACKED)
        return list(dict.fromkeys(found))

    def changed_since(self, scope: Scope, base: str) -> list[str] | None:
        commit = self._commit(base)
        if commit is None:
            return None
        if scope is Scope.STAGED:
            return self._listed([*_NAMES, "--cached", commit, "--"])
        found = self._listed([*_NAMES, commit, "--"]) + self._listed(_UNTRACKED)
        return list(dict.fromkeys(found))

    def added_lines(self, scope: Scope, base: str | None = None) -> list[AddedLine] | None:
        against = None
        if base is not None:
            against = self._commit(base)
            if against is None:
                return None
        elif scope is not Scope.STAGED:
            against = "HEAD"
        cached = ["--cached"] if scope is Scope.STAGED else []
        revision = [against] if against else []
        added = _parse_patch(self._output([*_PATCH, *cached, *revision, "--"]))
        if scope is not Scope.STAGED:
            for path in self._listed(_UNTRACKED):
                added.extend(self._whole_file(path))
        return added

    def _run(self, arguments: list[str]) -> subprocess.CompletedProcess[bytes]:
        return self._runner([*_GIT, *arguments], self._root)

    def _output(self, arguments: list[str]) -> bytes:
        done = self._run(arguments)
        if done.returncode != 0:
            detail = done.stderr.decode(errors="replace").strip()
            command = " ".join(arguments)
            raise GitError(f"git {command} exited {done.returncode}: {detail}")
        return done.stdout

    def _listed(self, arguments: list[str]) -> list[str]:
        return [os.fsdecode(name) for name in self._output(arguments).split(b"\0") if name]

    def _commit(self, ref: str) -> str | None:
        if not ref:
            return None
        verify = ["rev-parse", "--verify", "--quiet", "--end-of-options"]
        done = self._run([*verify, f"{ref}^{{commit}}"])
        return done.stdout.decode().strip() if done.returncode == 0 else None

    def _whole_file(self, path: str) -> list[AddedLine]:
        source = self._root / path
        if source.is_symlink() or not source.is_file():
            return []
        content = source.read_bytes()
        if b"\0" in content:
            return []
        lines = content.split(b"\n")
        if lines[-1] == b"":
            lines.pop()
        return [AddedLine(path, number, _text(line)) for number, line in enumerate(lines, 1)]


def _text(line: bytes) -> str:
    return line.removesuffix(b"\r").decode(errors="replace")


_HUNK = re.compile(rb"^@@ -\d+(?:,(\d+))? \+(\d+)(?:,(\d+))? @@")


def _parse_patch(patch: bytes) -> list[AddedLine]:
    added = []
    path = None
    old_left = new_left = number = 0
    # Only a newline ends a line of a patch, so splitlines would cut some lines in two.
    for line in patch.split(b"\n"):
        if line.startswith(b"\\"):
            continue
        # Inside a hunk, counting the lines keeps an added "++ x" from reading as a file header.
        if old_left or new_left:
            marker = line[:1]
            if marker == b"+":
                added.append(AddedLine(path, number, _text(line[1:])))
            if marker != b"+":
                old_left -= 1
            if marker != b"-":
                new_left -= 1
                number += 1
        elif line.startswith(b"+++ "):
            path = _header_path(line[4:])
        elif hunk := _HUNK.match(line):
            old_count, start, new_count = hunk.groups()
            old_left = int(old_count or 1)
            new_left = int(new_count or 1)
            number = int(start)
    return added


_ESCAPE = re.compile(rb"\\([0-7]{3}|.)")
_ESCAPED = {
    b"a": b"\a",
    b"b": b"\b",
    b"t": b"\t",
    b"n": b"\n",
    b"v": b"\v",
    b"f": b"\f",
    b"r": b"\r",
}


def _unescape(match: re.Match[bytes]) -> bytes:
    code = match.group(1)
    if len(code) == 3:
        return bytes([int(code, 8)])
    return _ESCAPED.get(code, code)


def _header_path(field: bytes) -> str | None:
    # Git ends a header name containing a space with a tab, and quotes one with control characters.
    field = field.removesuffix(b"\t")
    if field.startswith(b'"'):
        field = _ESCAPE.sub(_unescape, field[1:-1])
    if field == b"/dev/null":
        return None
    return os.fsdecode(field.removeprefix(b"b/"))
