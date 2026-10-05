"""Dead QML/JS files: not reachable from the shell entry points.

Builds a reference graph like knip does for JS:
  * `import qs.a.b`       -> makes <repo>/a/b visible (types resolved by file name)
  * `import "x.js"`, `import "dir"`, `import "./X.qml"` -> file / dir edges
  * the file's own directory is always visible (implicit import)
  * a capitalised identifier `Foo` -> Foo.qml in any visible directory
  * a string literal ending in `.qml` / `.js` -> files with that path suffix
Everything reachable from `entryPoints` (config.json) is alive. The rest is
reported as dead: "unreferenced" (no incoming edge at all) or "only used by
dead files". Singletons are included; an unreferenced singleton is never
instantiated by Quickshell either.
"""
from __future__ import annotations

import re
from collections import defaultdict
from pathlib import PurePosixPath

from lib.model import REPO, WARN, Issue, repo_files
from lib.qmlscan import PATH_IMPORT, QS_IMPORT, scan_file

CHECK = "dead-code"
_FILE_REF = re.compile(r"([\w./-]+\.(?:qml|js))$")


def _dir(path: str) -> str:
    return str(PurePosixPath(path).parent)


def _norm(path: str) -> str:
    parts: list[str] = []
    for p in PurePosixPath(path).parts:
        if p == "..":
            if parts:
                parts.pop()
        elif p != ".":
            parts.append(p)
    return "/".join(parts) or "."


def build_graph(files: list[str]) -> dict[str, set[str]]:
    by_dir_name: dict[tuple[str, str], str] = {}
    by_basename: dict[str, list[str]] = defaultdict(list)
    for f in files:
        by_dir_name[(_dir(f), PurePosixPath(f).stem)] = f
        by_basename[PurePosixPath(f).name].append(f)

    graph: dict[str, set[str]] = {f: set() for f in files}
    for f in files:
        scan = scan_file(REPO / f)
        raw = (REPO / f).read_text(errors="replace")
        here = _dir(f)
        visible = {here}
        for mod, _alias in QS_IMPORT.findall(raw):
            visible.add("/".join(mod.split(".")[1:]) or ".")
        for target, _alias in PATH_IMPORT.findall(raw):
            resolved = _norm(f"{here}/{target}")
            if target.endswith((".js", ".qml")):
                if resolved in graph:
                    graph[f].add(resolved)
            else:
                visible.add(resolved)
        for ident in scan.identifiers():
            if ident[:1].isupper():
                for d in visible:
                    hit = by_dir_name.get((d, ident))
                    if hit and hit != f and hit.endswith(".qml"):
                        graph[f].add(hit)
        for _line, value in scan.strings:
            m = _FILE_REF.search(value)
            if not m:
                continue
            ref = m.group(1)
            rel = _norm(f"{here}/{ref}")
            if rel in graph:
                graph[f].add(rel)
                continue
            suffix = _norm(ref.lstrip("./"))
            for cand in by_basename.get(PurePosixPath(ref).name, []):
                if cand.endswith(suffix) and cand != f:
                    graph[f].add(cand)
    return graph


def run(cfg: dict) -> list[Issue]:
    c = cfg.get("deadCode", {})
    files = repo_files(".qml", ".js")
    graph = build_graph(files)
    roots = [f for f in c.get("entryPoints", ["shell.qml"]) if f in graph]
    alive: set[str] = set()
    stack = list(roots)
    while stack:
        f = stack.pop()
        if f in alive:
            continue
        alive.add(f)
        stack.extend(graph[f] - alive)
    incoming: dict[str, set[str]] = defaultdict(set)
    for src, dsts in graph.items():
        for d in dsts:
            incoming[d].add(src)

    scope = tuple(c.get("scope", ["modules/", "config/"]))
    ignore = set(c.get("ignore", {}))
    issues = []
    for f in files:
        if f in alive or not f.startswith(scope) or f in ignore:
            continue
        users = sorted(incoming.get(f, set()))
        if users:
            why = "only referenced by dead files: " + ", ".join(users[:3]) + ("..." if len(users) > 3 else "")
        else:
            why = "never referenced"
        issues.append(Issue(CHECK, WARN, f"dead file ({why})", file=f, key=f))
    return issues
