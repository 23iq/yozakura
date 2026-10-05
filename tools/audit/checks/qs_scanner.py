"""Directories Quickshell's QML scanner never reaches (types will not resolve).

Quickshell serves the config through its own VFS and synthesizes a qmldir
only for directories its scanner visits. The scanner starts at the entry
point and follows *directory* imports only:
  * `import qs.a.b`     -> scans <repo>/a/b
  * `import "dir"`      -> scans that directory
  * visiting a file     -> its own directory is scanned (every .qml in it)
JS/QML file imports (`import "X.js"`, `import "./Y.qml"`) and URLs built at
runtime (`Loader.source`, `Qt.resolvedUrl(...)`) are NOT followed.

A QML file in an unscanned directory still loads by URL, but every implicit
same-directory type it uses fails at runtime ("Foo is not a type") - plain
Qt (qmllint, the PySide6 test harness) resolves them fine, so only this
check catches it. Only directories whose files actually use a sibling type
are reported (a URL-loaded file with explicit imports only is fine). Fix:
add a directory import (`import "dir"`) from a
scanned file. Exceptions go to config.json "qsScanner.ignore" with a reason.
"""
from __future__ import annotations

from collections import deque
from pathlib import PurePosixPath

from lib.model import ERROR, REPO, Issue, repo_files
from lib.qmlscan import PATH_IMPORT, QS_IMPORT, scan_file

CHECK = "qs-scanner"


def _norm(path: str) -> str:
    parts: list[str] = []
    for p in PurePosixPath(path).parts:
        if p == "..":
            if parts:
                parts.pop()
        elif p != ".":
            parts.append(p)
    return "/".join(parts) or "."


def scanned_dirs(entry: str, qml_dirs: set[str]) -> set[str]:
    """Directories the Quickshell scanner visits starting from `entry`."""
    seen: set[str] = set()
    queue = deque([str(PurePosixPath(entry).parent) or "."])
    while queue:
        d = _norm(queue.popleft())
        if d in seen or not (REPO / d).is_dir():
            continue
        seen.add(d)
        for f in sorted((REPO / d).glob("*.qml")):
            raw = f.read_text(errors="replace")
            for mod, _alias in QS_IMPORT.findall(raw):
                queue.append("/".join(mod.split(".")[1:]) or ".")
            for target, _alias in PATH_IMPORT.findall(raw):
                if not target.endswith((".js", ".qml", ".mjs")):
                    queue.append(f"{d}/{target}")
    return seen & qml_dirs


def run(cfg: dict) -> list[Issue]:
    c = cfg.get("qsScanner", {})
    entry = c.get("entryPoint", "shell.qml")
    scope = tuple(c.get("scope", ["modules/", "config/"]))
    ignore = c.get("ignore", {})
    files = [f for f in repo_files(".qml") if f.startswith(scope)]
    qml_dirs = {str(PurePosixPath(f).parent) for f in files}
    reached = scanned_dirs(entry, qml_dirs)
    issues = []
    for d in sorted(qml_dirs - reached):
        if d in ignore:
            continue
        here = [f for f in files if str(PurePosixPath(f).parent) == d]
        names = {PurePosixPath(f).stem for f in here}
        for f in here:
            used = sorted(i for i in scan_file(REPO / f).identifiers()
                          if i in names and i != PurePosixPath(f).stem)
            if used:
                issues.append(Issue(
                    CHECK, ERROR,
                    f"uses sibling type(s) {', '.join(used)}, but {d}/ is never reached by Quickshell's "
                    f"scanner (no directory import leads there), so they will not resolve at runtime; add "
                    f"`import \"{PurePosixPath(d).name}\"` in a file of the parent directory",
                    file=f, key=d))
    return issues
