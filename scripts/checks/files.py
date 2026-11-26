import os
import unicodedata
from collections.abc import Iterable
from enum import Enum, auto
from fnmatch import fnmatchcase
from pathlib import Path, PurePosixPath


class Language(Enum):
    SWIFT = auto()
    SHELL = auto()
    PYTHON = auto()
    CONFIG = auto()
    OTHER = auto()


# As in .gitignore: a slash before the end ties an entry to the root, else it matches at any depth.
EXCLUDED: tuple[str, ...] = (
    "scripts/create-dmg",
    "scripts/support/",
    "*.xcodeproj",
    "*.xcworkspace",
    "Derived/",
    ".build/",
    "build/",
    "*.xcuserstate",
    "xcuserdata/",
    "*.dmg",
    "/SHA256SUMS",
    ".sparkle-private-key",
    "Resources/Tools/",
    "Resources/Shield/",
    "Resources/Licenses/",
    ".venv/",
    "__pycache__/",
    ".ruff_cache/",
    ".pytest_cache/",
    ".playwright-mcp/",
)

_EXTENSIONS = {
    ".swift": Language.SWIFT,
    ".sh": Language.SHELL,
    ".bash": Language.SHELL,
    ".py": Language.PYTHON,
    ".yml": Language.CONFIG,
    ".yaml": Language.CONFIG,
    ".toml": Language.CONFIG,
}
_SHELLS = {"sh", "bash", "dash", "ksh"}


def language_of(path: str, first_line: str) -> Language:
    name = PurePosixPath(path)
    if name.name == "Makefile":
        return Language.CONFIG
    if language := _EXTENSIONS.get(name.suffix):
        return language
    interpreter = _interpreter(first_line)
    if interpreter in _SHELLS:
        return Language.SHELL
    if interpreter.startswith("python"):
        return Language.PYTHON
    return Language.OTHER


def _interpreter(first_line: str) -> str:
    if not first_line.startswith("#!"):
        return ""
    words = first_line[2:].split()
    if words and PurePosixPath(words[0]).name == "env":
        words = [word for word in words[1:] if not word.startswith("-") and "=" not in word]
    return PurePosixPath(words[0]).name if words else ""


def select(paths: Iterable[str], root: Path) -> dict[Language, list[str]]:
    selection: dict[Language, list[str]] = {language: [] for language in Language}
    listings: dict[Path, dict[str, str]] = {}
    for path in sorted(set(paths)):
        if _is_excluded(path):
            continue
        if found := _file_on_disk(root, path, listings):
            selection[language_of(path, _first_line(found))].append(path)
    return selection


def _is_excluded(path: str) -> bool:
    parts = path.split("/")
    for entry in EXCLUDED:
        pattern = entry.strip("/")
        only_directories = entry.endswith("/")
        if "/" in entry.removesuffix("/"):
            depth = pattern.count("/") + 1
            matched = parts[:depth] == pattern.split("/")
            if matched and (len(parts) > depth or not only_directories):
                return True
        else:
            candidates = parts[:-1] if only_directories else parts
            if any(fnmatchcase(part, pattern) for part in candidates):
                return True
    return False


# The default macOS disk ignores case, so exists() would also accept the old name after a rename.
def _file_on_disk(root: Path, path: str, listings: dict[Path, dict[str, str]]) -> Path | None:
    current = root
    for part in PurePosixPath(path).parts:
        if current not in listings:
            if not current.is_dir():
                return None
            listings[current] = {_composed(name): name for name in os.listdir(current)}
        name = listings[current].get(_composed(part))
        if name is None:
            return None
        current /= name
    return current if current.is_file() and not current.is_symlink() else None


# Git and the disk can spell one accented name with different code points.
def _composed(name: str) -> str:
    return unicodedata.normalize("NFC", name)


def _first_line(path: Path) -> str:
    with path.open("rb") as source:
        return source.readline(256).decode(errors="replace")
