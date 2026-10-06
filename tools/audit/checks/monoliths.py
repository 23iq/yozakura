"""Monolith warnings: source files above the line threshold (informational).

Files over the limit are listed with their growth vs $BASE so a change that
keeps inflating an existing monolith is visible in review. New code belongs
in small focused files (see AGENTS.md "Definition of done"). A file that
must stay one file lists its reason in config.json `monoliths.allow` and is
reported as info only.
"""
from __future__ import annotations

import os
import subprocess

from lib.model import INFO, REPO, WARN, Issue, repo_files

CHECK = "monoliths"
SUFFIXES = (".qml", ".js", ".py", ".sh", ".go")


def _base_lines(ref: str, rel: str) -> int | None:
    r = subprocess.run(["git", "show", f"{ref}:{rel}"], cwd=REPO, capture_output=True, text=True)
    return r.stdout.count("\n") if r.returncode == 0 else None


def run(cfg: dict) -> list[Issue]:
    c = cfg.get("monoliths", {})
    limit = int(c.get("maxLines", 800))
    exclude = tuple(c.get("exclude", []))
    allow = {k: v for k, v in c.get("allow", {}).items() if not k.startswith("_")}
    mb = subprocess.run(["git", "merge-base", os.environ.get("BASE", "origin/main"), "HEAD"],
                        cwd=REPO, capture_output=True, text=True).stdout.strip()
    issues = []
    rows = []
    for f in repo_files(*SUFFIXES, exclude=("tests/", "tools/", *exclude)):
        n = (REPO / f).read_text(errors="replace").count("\n")
        if n > limit:
            rows.append((n, f))
    for n, f in sorted(rows, reverse=True):
        old = _base_lines(mb, f) if mb else None
        if old is None:
            growth = " (new file)"
        elif n > old:
            growth = f" (+{n - old} since BASE)"
        else:
            growth = ""
        if f in allow:
            issues.append(Issue(CHECK, INFO, f"{n} lines > {limit}{growth}; allowed: {allow[f]}", file=f, key=f))
        else:
            issues.append(Issue(CHECK, WARN, f"{n} lines > {limit}{growth}", file=f, key=f))
    return issues
