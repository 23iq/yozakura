"""Brand literal guard: legacy names must not leak back into the code.

The app identity lives in one place per language (backend/pkg/brand,
modules/globals/Brand.qml + BrandActions.js, scripts/lib/brand.{sh,py}).
Everything else derives ids, dirs, env vars and namespaces from there. This
check fails on tracked text files whose lines match config.json
"brandLiterals.pattern", except files matched by "brandLiterals.allow"
(glob -> reason; e.g. credits, migration and legacy-compat code) and lines
matched by one of "brandLiterals.ignoreLines" (regex -> reason).
"brandLiterals" may also be a list of such rules (one per legacy name, e.g.
the legacy app id and the external compositor daemon yozd replaced).
"""
from __future__ import annotations

import fnmatch
import re
import subprocess

from lib.model import ERROR, REPO, Issue

CHECK = "brand-literals"


def _tracked() -> list[str]:
    out = subprocess.run(["git", "ls-files", "--cached", "--others", "--exclude-standard"],
                         cwd=REPO, capture_output=True, text=True, check=True).stdout
    return sorted(set(out.splitlines()))


def _text(path) -> str | None:
    try:
        data = path.read_bytes()
    except OSError:
        return None
    if b"\0" in data[:8192]:
        return None
    return data.decode("utf-8", errors="replace")


def run(cfg: dict) -> list[Issue]:
    rules = cfg.get("brandLiterals") or []
    if isinstance(rules, dict):
        rules = [rules]
    rules = [c for c in rules if c.get("pattern")]
    if not rules:
        return []
    files = _tracked()
    issues = []
    for c in rules:
        issues += _run_rule(c, files)
    return issues


def _run_rule(c: dict, files: list[str]) -> list[Issue]:
    flags = re.IGNORECASE if c.get("ignoreCase") else 0
    pattern = re.compile(c["pattern"], flags)
    allow = list(c.get("allow", {}))
    ignore = [re.compile(r) for r in c.get("ignoreLines", {})]
    issues = []
    for rel in files:
        if any(fnmatch.fnmatch(rel, g) for g in allow):
            continue
        path = REPO / rel
        if not path.is_file():
            continue
        text = _text(path)
        if text is None or not pattern.search(text):
            continue
        for n, line in enumerate(text.splitlines(), 1):
            if pattern.search(line) and not any(r.search(line) for r in ignore):
                issues.append(Issue(CHECK, ERROR, f"legacy brand literal: {line.strip()[:120]}",
                                    file=rel, line=n, key=rel))
    return issues
