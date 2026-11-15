"""Singleton members guard: every `Look.x` (and the other kit / theme
singletons listed in config.json "singletonMembers") used in a QML file
under modules/ (or a root window file) must be a member that singleton
declares (property, function, signal), or one QtObject has. A member that
moved or was renamed (Look.cardRowHeight -> FittedFrame.cardRowHeight)
otherwise only shows at runtime as `undefined`.
"""
from __future__ import annotations

import re

from lib.model import ERROR, REPO, Issue, repo_files

CHECK = "singleton-members"

# members every QtObject has
_BUILTIN = {"objectName", "toString", "destroyed", "objectNameChanged"}
_DECL = re.compile(r"^\s*(?:(?:readonly|default|required)\s+)*property\s+[\w.<>]+\s+(\w+)"
                   r"|^\s*function\s+(\w+)\s*\(|^\s*signal\s+(\w+)", re.M)
_COMMENT = re.compile(r"//[^\n]*|/\*.*?\*/", re.S)
_STRING = re.compile(r'"(?:[^"\\\n]|\\.)*"|\'(?:[^\'\\\n]|\\.)*\'')


def members_of(text: str) -> set[str]:
    """The members a singleton's QML declares (and their change signals)."""
    text = _COMMENT.sub("", text)
    names = set(_BUILTIN)
    for m in _DECL.finditer(text):
        name = next(g for g in m.groups() if g)
        names.add(name)
        names.add(name + "Changed")
    return names


def unknown_uses(text: str, known: dict[str, set[str]]) -> list[tuple[int, str, str]]:
    """(line, singleton, member) for each `Name.member` that Name does not declare
    (comments and strings aside; `Name.Upper` is an enum or a type)."""
    use = re.compile(r"(?<![\w.])(" + "|".join(map(re.escape, known)) + r")\.([A-Za-z_]\w*)")
    found = []
    for n, line in enumerate(text.splitlines(), 1):
        code = _COMMENT.sub("", _STRING.sub('""', line))
        for m in use.finditer(code):
            name, member = m.group(1), m.group(2)
            if member not in known[name] and not member[:1].isupper():
                found.append((n, name, member))
    return found


def run(cfg: dict) -> list[Issue]:
    defs = (cfg.get("singletonMembers") or {}).get("singletons", {})
    if not defs:
        return []
    known = {name: members_of((REPO / rel).read_text()) for name, rel in defs.items()}
    issues = []
    for rel in repo_files(".qml"):
        if not (rel.startswith("modules/") or "/" not in rel):
            continue
        for n, name, member in unknown_uses((REPO / rel).read_text(errors="replace"), known):
            issues.append(Issue(CHECK, ERROR, f"{name}.{member} is not a member of {defs[name]}",
                                file=rel, line=n, key=f"{name}.{member}"))
    return issues
