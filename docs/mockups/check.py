"""Fails when the mockup pages break a shared rule. Run after build.py."""

import re
import sys
from collections import Counter
from html.parser import HTMLParser

import build

ROOT = build.ROOT
data = build.data

# Presentation belongs in the shared stylesheets; viewBox and path data are drawing geometry.
STYLE_ATTRIBUTES = {
    "style",
    "width",
    "height",
    "color",
    "bgcolor",
    "fill",
    "stroke",
    "stroke-width",
    "stop-color",
    "font-size",
    "font-family",
}
COLOUR = re.compile(r"#(?:[0-9a-f]{8}|[0-9a-f]{6}|[0-9a-f]{3,4})\b|\b(?:rgba?|hsla?)\(", re.I)
SIZE = re.compile(r"(?<![\w.])\d*\.?\d+(?:px|pt|rem|em)\b")
BANNED = (
    ("a phase reference", re.compile(r"\bphase\b", re.I)),
    ("a spec section reference", re.compile(r"§")),
    ("a ticket id outside a planned marker", re.compile(r"\bmg-\d+\b", re.I)),
)
VOID = {
    "area",
    "base",
    "br",
    "col",
    "embed",
    "hr",
    "img",
    "input",
    "link",
    "meta",
    "source",
    "track",
    "wbr",
}


class Page(HTMLParser):
    def __init__(self, name):
        super().__init__()
        self.name = name
        self.problems = []
        self.ids = []
        self.screens = []
        self.symbols = set()
        self.classes = Counter()
        self.links = []
        self.captions = []
        self._open = []

    def handle_starttag(self, tag, attrs):
        attributes = {key: value or "" for key, value in attrs}
        names = attributes.get("class", "").split()
        planned = "planned" in names
        self.classes.update(names)
        if tag == "figure" and "screen" in names:
            self.screens.append(attributes.get("id", ""))
        if tag == "symbol":
            self.symbols.add(attributes.get("id", ""))
        if tag == "style":
            self.problems.append("has a <style> block")
        if tag == "script" and "src" not in attributes:
            self.problems.append("has an inline script")
        for key, value in attributes.items():
            if key in STYLE_ATTRIBUTES:
                self.problems.append(f"<{tag}> sets '{key}'; move it to a stylesheet")
            elif key.startswith("on"):
                self.problems.append(f"<{tag}> has an inline '{key}' handler")
            elif key in ("href", "src"):
                self.links.append(value)
            elif key not in ("d", "viewbox", "points", "content"):
                if COLOUR.search(value) or SIZE.search(value):
                    self.problems.append(f'<{tag}> {key}="{value}" holds a literal value')
                if not planned and key != "data-ticket":
                    self._check_words(value)
        if "id" in attributes:
            self.ids.append(attributes["id"])
        if tag == "figcaption":
            self.captions.append("")
        if tag not in VOID:
            self._open.append((tag, planned))

    def handle_endtag(self, tag):
        while self._open and self._open.pop()[0] != tag:
            pass

    def handle_data(self, text):
        if any(tag == "figcaption" for tag, _ in self._open):
            self.captions[-1] += text
        if not any(planned for _, planned in self._open):
            self._check_words(text)

    def _check_words(self, text):
        for label, pattern in BANNED:
            if match := pattern.search(text):
                self.problems.append(f"holds {label}: '{match.group()}'")


def parse(name, html):
    page = Page(name)
    page.feed(html)
    page.close()
    return page


def page_problems(pages):
    parsed = {name: parse(name, html) for name, html in pages.items()}
    problems = [f"{name}: {text}" for name, page in parsed.items() for text in page.problems]
    seen = {}
    for name, page in parsed.items():
        for identifier, count in Counter(page.ids).items():
            if count > 1:
                problems.append(f"{name}: id '{identifier}' is used {count} times")
        for identifier in set(page.ids) - page.symbols:
            if identifier in seen:
                problems.append(f"{name}: id '{identifier}' is already used in {seen[identifier]}")
            seen[identifier] = name
        problems += chrome_problems(name, page)
        for caption in page.captions:
            if "\n" in caption.strip():
                problems.append(f"{name}: caption runs over one line: {caption.strip()!r}")
        for link in page.links:
            problems += link_problems(name, link, parsed)
    return problems + index_problems(parsed)


def chrome_problems(name, page):
    if name == "screens/onboarding.html":
        return []
    windows = page.classes["window"]
    return [
        f"{name}: {windows} window(s) but {page.classes[part]} with class '{part}'"
        for part in ("titlebar", "chips")
        if page.classes[part] != windows
    ]


def link_problems(name, link, parsed):
    if re.match(r"[a-z]+:", link):
        return [f"{name}: '{link}' loads from outside the repository"]
    path, _, anchor = link.partition("#")
    folder = (ROOT / name).parent
    target = (folder / path).resolve() if path else (ROOT / name).resolve()
    relative = target.relative_to(ROOT).as_posix() if target.is_relative_to(ROOT) else None
    if relative not in parsed and not target.is_file():
        return [f"{name}: '{link}' points at a missing file"]
    if anchor and (relative not in parsed or anchor not in parsed[relative].ids):
        return [f"{name}: '{link}' points at a missing anchor"]
    return []


def index_problems(parsed):
    listed = set(parsed["screens.html"].links)
    return [
        f"screens.html: does not link to {name}#{identifier}"
        for name, page in parsed.items()
        if name != "screens.html"
        for identifier in page.screens
        if f"{name}#{identifier}" not in listed
    ]


def stale_problems(pages):
    problems = []
    for name, html in pages.items():
        target = ROOT / name
        if not target.is_file() or target.read_text(encoding="utf-8") != html:
            problems.append(f"{name}: differs from a fresh build; run build.py")
    for target in ROOT.glob("screens/*.html"):
        name = target.relative_to(ROOT).as_posix()
        if name not in pages and build.MARKER in target.read_text(encoding="utf-8"):
            problems.append(f"{name}: generated earlier but no source builds it now")
    return problems


def css_problems():
    tokens = (ROOT / "tokens.css").read_text(encoding="utf-8")
    components = (ROOT / "screens.css").read_text(encoding="utf-8")
    problems = [
        f"screens.css: literal colour '{match.group()}'; define it in tokens.css"
        for match in COLOUR.finditer(components)
    ]
    defined = set(re.findall(r"(--[\w-]+)\s*:", tokens + components))
    for used in sorted(set(re.findall(r"var\((--[\w-]+)", tokens + components)) - defined):
        problems.append(f"stylesheets use {used}, which nothing defines")
    for url in re.findall(r'url\("([^"]+)"\)', tokens):
        if not (ROOT / url).is_file():
            problems.append(f"tokens.css: '{url}' is missing")
    return problems + palette_problems(tokens)


def palette_problems(tokens):
    blocks = re.findall(r"([^{}]+)\{([^{}]*)\}", re.sub(r"/\*.*?\*/", "", tokens, flags=re.S))
    resolved = {}
    for theme, _, palettes in data.THEMES:
        for palette, _ in palettes:
            wanted = (
                f':root[data-theme="{theme}"]',
                f':root[data-theme="{theme}"][data-palette="{palette}"]',
            )
            names = set()
            for selector, body in blocks:
                if selector.strip() in wanted:
                    names |= set(re.findall(r"(--[\w-]+)\s*:", body))
            resolved[f"{theme}/{palette}"] = names
    every = set().union(*resolved.values())
    return [
        f"tokens.css: {look} lacks {', '.join(sorted(every - names))}"
        for look, names in resolved.items()
        if every - names
    ]


def data_problems():
    states = {download.state for download in data.DOWNLOADS}
    failures = {download.failure for download in data.DOWNLOADS if download.failure}
    problems = []
    if missing := set(data.STATE_LABELS) - states:
        problems.append(f"sample_data.py: no sample download in {sorted(missing)}")
    if missing := set(data.FAILURE_SENTENCES) - failures:
        problems.append(f"sample_data.py: no sample download failing with {sorted(missing)}")
    return problems


def legacy_pages(pages):
    return sorted(
        target.relative_to(ROOT).as_posix()
        for target in ROOT.glob("screens/*.html")
        if target.relative_to(ROOT).as_posix() not in pages
    )


def main():
    pages = build.render()
    problems = stale_problems(pages) + page_problems(pages) + css_problems() + data_problems()
    for problem in problems:
        print(problem)
    for name in legacy_pages(pages):
        print(f"note: old page not replaced yet, not checked: {name}")
    print(f"{len(problems)} problem(s) in {len(pages)} generated page(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
