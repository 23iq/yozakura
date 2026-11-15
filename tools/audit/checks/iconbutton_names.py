"""IconButton names guard: a kit IconButton draws a private-use glyph, so a
screen reader announces it by its `accessibleName`, else its `tooltip`.
Every `IconButton {` under modules/ (or a root window file) must set one of
them, its own `Accessible.name`, or `Accessible.ignored: true` (a purely
decorative glyph); otherwise it is announced as a nameless button.
"""
from __future__ import annotations

import re

from lib.model import ERROR, REPO, Issue, repo_files

CHECK = "iconbutton-names"

_START = re.compile(r"(?<![\w.])IconButton\s*\{")
_NAMED = re.compile(r"^\s*(?:tooltip|accessibleName|Accessible\.name|Accessible\.ignored)\s*:")
_SKIP = re.compile(r"//[^\n]*|/\*.*?\*/|\"(?:[^\"\\\n]|\\.)*\"|'(?:[^'\\\n]|\\.)*'|`(?:[^`\\]|\\.)*`", re.S)


def _blank(m: re.Match) -> str:
    """A comment as spaces, a string as an empty one (newlines kept: line
    numbers and the braces of the code stay where they are)."""
    s = m.group(0)
    return re.sub(r"[^\n]", " ", s) if s.startswith("/") else '"' + "\n" * s.count("\n") + '"'


def nameless(text: str) -> list[int]:
    """Line numbers of `IconButton {` blocks that name nothing at their own
    level (a nested object's `tooltip:` does not count)."""
    code = _SKIP.sub(_blank, text)
    found = []
    for m in _START.finditer(code):
        depth, i, own = 1, m.end(), []
        line = ""
        while depth and i < len(code):
            c = code[i]
            if c == "{":
                depth += 1
            elif c == "}":
                depth -= 1
            elif depth == 1:
                line += c
                if c == "\n":
                    own.append(line)
                    line = ""
            i += 1
        own.append(line)
        if not any(_NAMED.match(x) for x in own):
            found.append(code.count("\n", 0, m.start()) + 1)
    return found


def run(cfg: dict) -> list[Issue]:
    issues = []
    for rel in repo_files(".qml"):
        if not (rel.startswith("modules/") or "/" not in rel):
            continue
        for n in nameless((REPO / rel).read_text(errors="replace")):
            issues.append(Issue(CHECK, ERROR, "IconButton without a name: set accessibleName or tooltip "
                                "(Accessible.ignored: true for a decorative glyph)", file=rel, line=n,
                                key=f"{rel}:{n}"))
    return issues
