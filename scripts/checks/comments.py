import ast
import io
import re
import tokenize
from bisect import bisect_right
from collections.abc import Mapping
from dataclasses import dataclass, field
from enum import Enum, auto
from typing import NamedTuple

from checks.files import Language
from checks.tools import Finding

ALLOWED_DIRECTIVES: Mapping[Language, tuple[str, ...]] = {
    Language.SWIFT: ("#!", "MARK:", "swiftlint:", "swiftformat:", "swift-tools-version"),
    Language.SHELL: ("#!", "shellcheck"),
    Language.PYTHON: ("#!", "noqa", "ruff:", "type:", "fmt:"),
    Language.CONFIG: ("#!", "yaml-language-server:"),
}
# These names are also ordinary words, so each needs the rest of its directive form.
_DIRECTIVE_FORMS = {
    "shellcheck": r"shellcheck\s+[\w-]+=",
    "noqa": r"noqa(?![\w-])",
    "swift-tools-version": r"swift-tools-version\s*:",
}
_DOC_COMMENT_HOME = "Sources/GrabberKit/"


class _Kind(Enum):
    # A gap is a blank or directive line: it neither joins a stack nor breaks one.
    GAP = auto()
    CODE = auto()
    COMMENT = auto()
    DOC = auto()


class _Fault(Enum):
    STACK = ("stacked-comment", "Comment lines are stacked; keep one line at most")
    BLOCK = ("block-comment", "Block comment is not closed on the line where it starts")
    DOCSTRING = ("docstring", "Docstring is longer than one line")
    LONG_DOC = ("doc-comment", "Doc comment is longer than one line")
    MISPLACED_DOC = ("doc-comment", "Doc comments are allowed only in GrabberKit")
    UNPARSED = ("parse-error", "Comments could not be checked")


_Problem = tuple[_Fault, int | None, str]


class Comment(NamedTuple):
    line: int
    text: str


@dataclass
class Source:
    comments: list[Comment] = field(default_factory=list)
    # Swift only, laid out as the file is, with comments and string contents blanked.
    code: str = ""
    unreadable: list[Finding] = field(default_factory=list)


@dataclass
class _Scan:
    kinds: list[_Kind]
    faults: list[_Problem]
    comments: list[Comment] = field(default_factory=list)
    code: str = ""
    unreadable: list[_Problem] = field(default_factory=list)
    # Lines where a doc comment opens and closes, whatever else the line holds.
    docs: set[int] = field(default_factory=set)


def read_source(path: str, text: str, language: Language) -> Source:
    scan = _scan(path, text, language)
    if scan is None:
        return Source()
    # A fault the comment check also reports is built the same way, so the two copies compare equal.
    unreadable = [
        _finding("comments" if problem in scan.faults else "rules", path, problem)
        for problem in scan.unreadable
    ]
    return Source(scan.comments, scan.code, unreadable)


def check_comments(path: str, text: str, language: Language) -> list[Finding]:
    scan = _scan(path, text, language)
    if scan is None:
        return []
    doc_allowed = path.startswith(_DOC_COMMENT_HOME)
    faults = scan.faults + _stack_faults(scan.kinds, doc_allowed)
    if not doc_allowed:
        faults += _hidden_doc_faults(scan)
    findings = [_finding("comments", path, fault) for fault in faults]
    return sorted(findings, key=lambda finding: (finding.line or 0, finding.rule))


def _finding(check: str, path: str, problem: _Problem) -> Finding:
    fault, line, detail = problem
    message = f"{fault.value[1]}: {detail}" if detail else fault.value[1]
    return Finding(check, fault.value[0], path, line, message)


def _scan(path: str, text: str, language: Language) -> _Scan | None:
    if language not in _SCANNERS:
        return None
    text = text.removeprefix("\ufeff").replace("\r\n", "\n")
    # A lone carriage return is an ordinary character to a shell.
    if language is not Language.SHELL:
        text = text.replace("\r", "\n")
    return _SCANNERS[language](path, text)


def _stack_faults(kinds: list[_Kind], doc_allowed: bool) -> list[tuple[_Fault, int, str]]:
    faults = []
    stack: list[tuple[int, _Kind]] = []
    for number, kind in enumerate([*kinds, _Kind.CODE], 1):
        if kind in (_Kind.COMMENT, _Kind.DOC):
            stack.append((number, kind))
        elif kind is _Kind.CODE and stack:
            docs = [line for line, found in stack if found is _Kind.DOC]
            if docs and not doc_allowed:
                faults.append((_Fault.MISPLACED_DOC, docs[0], ""))
            elif len(docs) > 1:
                faults.append((_Fault.LONG_DOC, docs[0], ""))
            # A stack made only of doc lines is already reported as one doc comment.
            if len(stack) > 1 and len(docs) < len(stack):
                faults.append((_Fault.STACK, stack[0][0], ""))
            stack = []
    return faults


# A run of doc lines is already reported; these share a line with code or another comment.
def _hidden_doc_faults(scan: _Scan) -> list[_Problem]:
    return [
        (_Fault.MISPLACED_DOC, line, "")
        for line in sorted(scan.docs)
        if scan.kinds[line - 1] is not _Kind.DOC
    ]


def _comment_kind(comment: str, language: Language) -> _Kind:
    if language is Language.SWIFT:
        if comment.startswith("///") or _opens_doc_block(comment):
            return _Kind.DOC
        if not comment.startswith("//"):
            return _Kind.COMMENT
    body = comment.removeprefix("//" if language is Language.SWIFT else "#").lstrip()
    for name in ALLOWED_DIRECTIVES[language]:
        # A shebang counts only as the first line of a file, which the callers handle.
        if name != "#!" and re.match(_DIRECTIVE_FORMS.get(name, re.escape(name)), body):
            return _Kind.GAP
    return _Kind.COMMENT


def _opens_doc_block(comment: str) -> bool:
    return comment.startswith("/**") and comment != "/**/"


def _hash_line_kind(number: int, line: str, language: Language) -> _Kind:
    stripped = line.strip()
    if not stripped or (number == 1 and line.startswith("#!")):
        return _Kind.GAP
    return _comment_kind(stripped, language) if stripped.startswith("#") else _Kind.CODE


# Elsewhere than TOML a quote inside a word, as in don't, opens no string.
_CONFIG_TOKEN = re.compile(
    r"""(?P<string>(?<![^\s\[{,:=(])(?:"(?:[^"\\]|\\.)*"|'(?:[^']|'')*'))|(?P<comment>(?<!\S)#.*)"""
)
_TOML_TOKEN = re.compile(r"""(?P<string>"(?:[^"\\]|\\.)*"|'[^']*')|(?P<comment>#.*)""")


def _config_comments(lines: list[str], toml: bool) -> list[Comment]:
    token = _TOML_TOKEN if toml else _CONFIG_TOKEN
    return [
        Comment(number, found.group("comment"))
        for number, line in enumerate(lines, 1)
        for found in token.finditer(line)
        if found.group("comment")
    ]


def _scan_config(path: str, text: str) -> _Scan:
    lines = text.split("\n")
    kinds = [_hash_line_kind(number, line, Language.CONFIG) for number, line in enumerate(lines, 1)]
    return _Scan(kinds, [], _config_comments(lines, path.endswith(".toml")))


def _scan_python(path: str, text: str) -> _Scan:
    try:
        tree = ast.parse(text)
        tokens = list(tokenize.generate_tokens(io.StringIO(text).readline))
    except (SyntaxError, ValueError, RecursionError, MemoryError, tokenize.TokenError) as error:
        line = getattr(error, "lineno", None)
        detail = f"Python cannot parse this file ({type(error).__name__}: {error})"
        problem = (_Fault.UNPARSED, line, detail)
        return _Scan([], [problem], unreadable=[problem])
    lines = text.split("\n")
    kinds = [_Kind.CODE if line.strip() else _Kind.GAP for line in lines]
    comments = []
    for token in tokens:
        if token.type != tokenize.COMMENT:
            continue
        row, column = token.start
        comments.append(Comment(row, token.string))
        if not lines[row - 1][:column].strip():
            kinds[row - 1] = _hash_line_kind(row, lines[row - 1], Language.PYTHON)
    docstrings = _docstrings(tree)
    comments += [Comment(node.lineno, ast.get_source_segment(text, node)) for node in docstrings]
    long = [node.lineno for node in docstrings if node.end_lineno > node.lineno]
    return _Scan(kinds, [(_Fault.DOCSTRING, line, "") for line in long], comments)


def _docstrings(tree: ast.Module) -> list[ast.Constant]:
    owners = (ast.Module, ast.ClassDef, ast.FunctionDef, ast.AsyncFunctionDef)
    found = []
    for node in ast.walk(tree):
        if not isinstance(node, owners) or not node.body:
            continue
        match node.body[0]:
            case ast.Expr(value=ast.Constant(value=str()) as text):
                found.append(text)
    return found


@dataclass
class _SwiftString:
    hashes: str
    multiline: bool
    line: int

    @property
    def closer(self) -> str:
        return ('"""' if self.multiline else '"') + self.hashes


@dataclass
class _Interpolation:
    depth: int = 0


# Three quotes open a multi-line string only at a line end: #"""# is one quote in a raw string.
_SWIFT_QUOTE = re.compile(r'(#*)("""(?=[ \t]*$)|")', re.M)
_SWIFT_REGEX = re.compile(r"(#+)/[^\n]+?/\1")
_BLOCK_MARK = re.compile(r"/\*|\*/")


def _block_end(text: str, start: int) -> int | None:
    depth = 0
    for mark in _BLOCK_MARK.finditer(text, start):
        depth += 1 if mark.group() == "/*" else -1
        if depth == 0:
            return mark.end()
    return None


def _blank(characters: list[str], start: int, end: int) -> None:
    for index in range(start, min(end, len(characters))):
        if characters[index] != "\n":
            characters[index] = " "


def _scan_swift(path: str, text: str) -> _Scan:
    code: set[int] = set()
    comments: dict[int, str] = {}
    doc_blocks: list[range] = []
    faults = []
    every_comment: list[Comment] = []
    bare = list(text)
    unreadable = []
    docs: set[int] = set()
    frames: list[_SwiftString | _Interpolation] = []
    position, line = 0, 1
    while position < len(text):
        character = text[position]
        top = frames[-1] if frames else None
        if character == "\n":
            # Dropping an unfinished one-line string stops it from swallowing the lines after it.
            for index, frame in enumerate(frames):
                if isinstance(frame, _SwiftString) and not frame.multiline:
                    del frames[index:]
                    break
            line += 1
            position += 1
        elif isinstance(top, _SwiftString):
            if not character.isspace():
                code.add(line)
            escape = "\\" + top.hashes
            start = position
            if text.startswith(escape, position):
                position += len(escape)
                if text.startswith("(", position):
                    frames.append(_Interpolation())
                    position += 1
                elif not text.startswith("\n", position):
                    position += 1
            elif text.startswith(top.closer, position):
                frames.pop()
                position += len(top.closer)
                continue
            else:
                position += 1
            _blank(bare, start, position)
        elif text.startswith("//", position):
            end = text.find("\n", position)
            end = len(text) if end < 0 else end
            every_comment.append(Comment(line, text[position:end]))
            _blank(bare, position, end)
            if text.startswith("///", position):
                docs.add(line)
            if line not in code:
                comments.setdefault(line, text[position:end])
            position = end
        elif text.startswith("/*", position):
            end = _block_end(text, position)
            comment = text[position:end]
            every_comment.append(Comment(line, comment))
            _blank(bare, position, position + len(comment))
            if end is None:
                unreadable.append((_Fault.BLOCK, line, ""))
            last = line + comment.count("\n")
            if end and last == line and _opens_doc_block(comment):
                docs.add(line)
            if end and last > line and line not in code and _opens_doc_block(comment):
                doc_blocks.append(range(line, last + 1))
            elif end is None or last > line:
                faults.append((_Fault.BLOCK, line, ""))
                code.update(range(line, last + 1))
            elif line not in code:
                comments.setdefault(line, comment)
            line = last
            position = len(text) if end is None else end
        elif quote := _SWIFT_QUOTE.match(text, position):
            code.add(line)
            frames.append(_SwiftString(quote.group(1), quote.group(2) == '"""', line))
            position = quote.end()
        elif regex := _SWIFT_REGEX.match(text, position):
            code.add(line)
            delimiter = len(regex.group(1)) + 1
            _blank(bare, position + delimiter, regex.end() - delimiter)
            position = regex.end()
        else:
            if not character.isspace():
                code.add(line)
            if isinstance(top, _Interpolation):
                if character == "(":
                    top.depth += 1
                elif character == ")" and top.depth:
                    top.depth -= 1
                elif character == ")":
                    frames.pop()
                    # Its opening mark is blanked with the string, so the brackets stay paired.
                    _blank(bare, position, position + 1)
            position += 1
    for frame in frames:
        if isinstance(frame, _SwiftString) and frame.multiline:
            problem = (_Fault.UNPARSED, frame.line, "a multi-line string is never closed")
            faults.append(problem)
            unreadable.append(problem)
            break
    doc_lines: set[int] = set()
    for block in doc_blocks:
        # Code after the closing mark makes it more than a doc comment on lines of its own.
        if block[-1] in code:
            faults.append((_Fault.BLOCK, block[0], ""))
            code.update(block)
        else:
            doc_lines.update(block)
    kinds = []
    for number in range(1, line + 1):
        if number in code:
            kinds.append(_Kind.CODE)
        elif number in doc_lines:
            kinds.append(_Kind.DOC)
        elif number in comments:
            kinds.append(_comment_kind(comments[number], Language.SWIFT))
        else:
            kinds.append(_Kind.GAP)
    return _Scan(kinds, faults, every_comment, "".join(bare), unreadable, docs)


@dataclass
class _ShellFrame:
    opener: str
    start: int = 0
    depth: int = 0
    in_double_quotes: bool = False


_SHELL_CODE = ("", "(", "`")
_SHELL_BREAKS = " \t\n;|&()<>`"
# Longest first, so that each opener wins over its own prefix.
_SHELL_EXPANSIONS = (("$((", "(("), ("$(", "("), ("${", "{"))


def _heredoc_delimiter(text: str, position: int) -> tuple[str, int] | None:
    word = []
    quoted = False
    while position < len(text) and text[position] not in _SHELL_BREAKS:
        character = text[position]
        if character in "'\"":
            end = text.find(character, position + 1)
            if end < 0:
                return None
            word.append(text[position + 1 : end])
            position = end + 1
            quoted = True
        elif character == "\\":
            word.append(text[position + 1 : position + 2])
            position += 2
            quoted = True
        else:
            word.append(character)
            position += 1
    return ("".join(word), position) if word or quoted else None


def _heredoc_end(text: str, position: int, delimiter: str, strip_tabs: bool) -> int | None:
    while position < len(text):
        end = text.find("\n", position)
        end = len(text) if end < 0 else end
        row = text[position:end]
        if (row.lstrip("\t") if strip_tabs else row) == delimiter:
            return end + 1
        position = end + 1
    return None


# Quotes are followed so that a quoted << opens nothing and a quoted # ends no line.
class _ShellReader:
    def __init__(self, text: str):
        self.text = text
        self.position = 0
        self.frames = [_ShellFrame("")]
        self.pending: list[tuple[str, bool]] = []
        self.skipped: set[int] = set()
        self.comments: dict[int, str] = {}
        self._starts = [0, *(match.end() for match in re.finditer("\n", text))]

    def line_of(self, position: int) -> int:
        return bisect_right(self._starts, position)

    def heredoc_lines(self) -> set[int]:
        while self.position < len(self.text):
            opener = self.frames[-1].opener
            character = self.text[self.position]
            if opener == "'":
                self._close_on(character, "'")
            elif character == "\\":
                self.position += 2
            elif opener == "$'":
                self._close_on(character, "'")
            elif opener == '"':
                if character == '"' or not self._expansion():
                    self._close_on(character, '"')
            elif self.text.startswith("$$", self.position):
                self.position += 2
            elif not self._expansion():
                self._unquoted(character)
        return self.skipped

    def _close_on(self, character: str, closer: str) -> None:
        if character == closer:
            self.frames.pop()
        self.position += 1

    def _open(self, opener: str, length: int) -> None:
        top = self.frames[-1]
        quoted = opener == "{" and (top.opener == '"' or top.in_double_quotes)
        self.frames.append(_ShellFrame(opener, self.position, in_double_quotes=quoted))
        self.position += length

    def _expansion(self) -> bool:
        for found, opener in _SHELL_EXPANSIONS:
            if self.text.startswith(found, self.position):
                self._open(opener, len(found))
                return True
        if self.text[self.position] != "`":
            return False
        if self.frames[-1].opener == "`":
            self._close_on("`", "`")
        else:
            self._open("`", 1)
        return True

    def _unquoted(self, character: str) -> None:
        top = self.frames[-1]
        if character == '"':
            self._open('"', 1)
        elif character == "'" and not top.in_double_quotes:
            self._open("'", 1)
        elif top.opener == "{":
            self._close_on(character, "}")
        elif top.opener == "((":
            self._arithmetic(character)
        else:
            self._command(character)

    def _arithmetic(self, character: str) -> None:
        top = self.frames[-1]
        if character == "(":
            top.depth += 1
        elif character == ")" and top.depth:
            top.depth -= 1
        elif character == ")":
            self.frames.pop()
            self.position += self.text.startswith("))", self.position)
        self.position += 1

    def _command(self, character: str) -> None:
        text, position = self.text, self.position
        if text.startswith("$'", position):
            self._open("$'", 2)
        elif character == "#" and (position == 0 or text[position - 1] in _SHELL_BREAKS):
            end = text.find("\n", position)
            self.position = len(text) if end < 0 else end
            self.comments[self.line_of(position)] = text[position : self.position]
        elif text.startswith("<<", position):
            self._heredoc_opener()
        elif text.startswith("((", position):
            self._open("((", 2)
        elif character == "(":
            self._open("(", 1)
        elif character == ")":
            if self.frames[-1].opener == "(":
                self.frames.pop()
            self.position += 1
        else:
            self.position += 1
            if character == "\n":
                self._skip_bodies()

    def _heredoc_opener(self) -> None:
        self.position += 2
        strip_tabs = self.text.startswith("-", self.position)
        self.position += strip_tabs
        while self.text.startswith((" ", "\t"), self.position):
            self.position += 1
        if found := _heredoc_delimiter(self.text, self.position):
            delimiter, self.position = found
            self.pending.append((delimiter, strip_tabs))

    def _skip_bodies(self) -> None:
        for delimiter, strip_tabs in self.pending:
            # With no end line nothing is skipped, so a misread opener hides no comment.
            if end := _heredoc_end(self.text, self.position, delimiter, strip_tabs):
                first = self.line_of(self.position)
                self.skipped.update(range(first, self.line_of(end - 1) + 1))
                self.position = end
        self.pending = []


def _scan_shell(path: str, text: str) -> _Scan:
    reader = _ShellReader(text)
    skipped = reader.heredoc_lines()
    lines = text.split("\n")
    kinds = [
        _Kind.CODE if number in skipped else _hash_line_kind(number, line, Language.SHELL)
        for number, line in enumerate(lines, 1)
    ]
    # A line that starts with # counts as a comment even in a quote, as it does for the line kinds.
    own_lines = {
        number: line.strip()
        for number, line in enumerate(lines, 1)
        if number not in skipped and line.strip().startswith("#")
    }
    comments = [Comment(*found) for found in sorted((reader.comments | own_lines).items())]
    unreadable = []
    # A quote or bracket still open here may have hidden an end-of-line comment.
    if len(reader.frames) > 1:
        line = reader.line_of(reader.frames[1].start)
        unreadable.append((_Fault.UNPARSED, line, "a quote or bracket is never closed"))
    return _Scan(kinds, [], comments, unreadable=unreadable)


_SCANNERS = {
    Language.SWIFT: _scan_swift,
    Language.SHELL: _scan_shell,
    Language.PYTHON: _scan_python,
    Language.CONFIG: _scan_config,
}
