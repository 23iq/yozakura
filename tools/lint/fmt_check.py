#!/usr/bin/env python3
"""Formatting gate: qmlformat for QML, gofmt for Go, with a known-dirty ratchet.

Upstream is not uniformly formatted and mass-reformatting would make upstream
merges painful, so files that were already unformatted when the gate was
introduced are listed in tools/lint/baselines/fmt-dirty.txt. Rules:

  file NOT in the dirty list  -> must be formatted (fail). Covers every new file.
  file in the dirty list      -> tolerated; a warning is printed when it was
                                 changed vs $BASE (default origin/main) so you
                                 can format it if you own it (FMT_STRICT=1
                                 turns these warnings into failures).
  qmlformat cannot parse      -> fail if it is a real syntax error, warning if
                                 qmllint parses it (qmlformat rejects e.g. a
                                 `required property int id`).

When a dirty file becomes clean the run says so; `make baseline` drops it.

Usage: fmt_check.py [--lang qml|go|all] [--staged] [--fix [FILE...]] [--update-baseline]
"""
from __future__ import annotations

import argparse
import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import (  # noqa: E402
    BASELINES, REPO, changed_files, fail, find_qt6_tool, find_tool, info, ok, skip, staged_files, tracked_files, warn,
)

DIRTY = BASELINES / "fmt-dirty.txt"
GO_EXCLUDE = ("backend/vendor/",)


def load_dirty() -> set[str]:
    if not DIRTY.exists():
        return set()
    return {ln.strip() for ln in DIRTY.read_text().splitlines() if ln.strip() and not ln.startswith("#")}


def qml_status(tool: str, rel: str) -> str:
    """'clean' | 'dirty' | 'unsupported' | 'syntax'."""
    path = REPO / rel
    r = subprocess.run([tool, rel], cwd=REPO, capture_output=True, text=True)
    if r.returncode != 0:
        p = subprocess.run([sys.executable, str(REPO / "tools/lint/qmllint.py"), "--parse", rel],
                           cwd=REPO, capture_output=True, text=True)
        return "unsupported" if p.returncode == 0 else "syntax"
    return "clean" if r.stdout == path.read_text() else "dirty"


def go_dirty(gofmt: str, files: list[str]) -> set[str]:
    if not files:
        return set()
    r = subprocess.run([gofmt, "-l", *files], cwd=REPO, capture_output=True, text=True)
    return {f for f in r.stdout.splitlines() if f}


def collect(lang: str, files: list[str] | None) -> tuple[dict[str, str], list[str]]:
    """Return ({file: status}, skipped-tool messages)."""
    status: dict[str, str] = {}
    skipped = []
    if lang in ("qml", "all"):
        tool = find_qt6_tool("qmlformat", "QMLFORMAT")
        qml = [f for f in (files if files is not None else tracked_files("*.qml")) if f.endswith(".qml")]
        if not tool:
            skipped.append("fmt-qml: qmlformat (Qt 6) not found; install qt6-declarative or set QMLFORMAT")
        else:
            with ThreadPoolExecutor(max_workers=os.cpu_count() or 4) as ex:
                for rel, st in zip(qml, ex.map(lambda f: qml_status(tool, f), qml), strict=True):
                    status[rel] = st
    if lang in ("go", "all"):
        gofmt = find_tool("gofmt")
        go = [f for f in (files if files is not None else tracked_files("*.go"))
              if f.endswith(".go") and not f.startswith(GO_EXCLUDE)]
        if not gofmt:
            skipped.append("fmt-go: gofmt not found")
        else:
            dirty = go_dirty(gofmt, go)
            status.update({f: ("dirty" if f in dirty else "clean") for f in go})
    return status, skipped


def fix(files: list[str]) -> int:
    qmlformat = find_qt6_tool("qmlformat", "QMLFORMAT")
    gofmt = find_tool("gofmt")
    for f in files:
        if f.endswith(".qml") and qmlformat:
            subprocess.run([qmlformat, "-i", f], cwd=REPO, check=False)
        elif f.endswith(".go") and gofmt:
            subprocess.run([gofmt, "-w", f], cwd=REPO, check=False)
        info(f"  formatted {f}")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--lang", choices=["qml", "go", "all"], default="all")
    ap.add_argument("--staged", action="store_true", help="check only staged files (pre-commit)")
    ap.add_argument("--fix", nargs="*", metavar="FILE",
                    help="format the given files, or every changed non-dirty file when none given")
    ap.add_argument("--update-baseline", action="store_true", help="rewrite the known-dirty list")
    args = ap.parse_args()

    files = staged_files("*.qml", "*.go") if args.staged else None
    status, skipped = collect(args.lang, files)
    for s in skipped:
        skip(s)

    if args.update_baseline:
        keep = {f for f in load_dirty() if f not in status and (REPO / f).exists()}
        dirty = sorted(keep | {f for f, st in status.items() if st in ("dirty", "unsupported")})
        DIRTY.parent.mkdir(parents=True, exist_ok=True)
        DIRTY.write_text("# Files that were not qmlformat/gofmt-clean when the gate was introduced.\n"
                         "# Generated by `make baseline`; only ever shrink this list.\n" + "\n".join(dirty) + "\n")
        ok(f"fmt: known-dirty list written ({len(dirty)} files)")
        return 0

    if args.fix is not None:
        targets = args.fix or [f for f, st in status.items() if st == "dirty" and f not in load_dirty()]
        return fix(targets)

    dirty_list = load_dirty()
    ch = changed_files("*.qml", "*.go")
    changed = set(ch[0] + ch[1]) if ch else set()
    errors, warnings, now_clean = [], [], []
    for f, st in sorted(status.items()):
        if st == "syntax":
            errors.append(f"{f}: does not parse (see `make parse-qml`)")
        elif st == "unsupported":
            if f in changed and f not in dirty_list:
                warnings.append(f"{f}: qmlformat cannot process this file (tool limitation, qmllint parses it)")
        elif f in dirty_list:
            if st == "clean":
                now_clean.append(f)
            elif f in changed:
                warnings.append(f"{f}: changed but not formatted (known-dirty upstream file)")
        elif st == "dirty":
            errors.append(f"{f}: not formatted")
    if os.environ.get("FMT_STRICT") == "1":
        errors += [w for w in warnings if "known-dirty" in w]
        warnings = [w for w in warnings if "known-dirty" not in w]
    dirty_changed = [w.split(":", 1)[0] for w in warnings if "known-dirty" in w]
    for w in warnings:
        if "known-dirty" not in w or os.environ.get("VERBOSE") == "1":
            warn(w)
    if dirty_changed and os.environ.get("VERBOSE") != "1":
        shown = ", ".join(dirty_changed[:4]) + (", ..." if len(dirty_changed) > 4 else "")
        warn(f"{len(dirty_changed)} changed known-dirty file(s) still unformatted ({shown}); "
             "format them if you own them (VERBOSE=1 lists all)")
    for e in errors:
        print(f"  {e}")
    if now_clean:
        info(f"  {len(now_clean)} known-dirty file(s) are now formatted; run `make baseline` to ratchet")
    if errors:
        fail(f"fmt: {len(errors)} file(s) need formatting. Fix: `make fmt` "
             "(qmlformat -i / gofmt -w), or see `make parse-qml` for syntax errors")
        return 1
    ok(f"fmt: {len(status)} file(s) checked, {len(dirty_list)} known-dirty tolerated, "
       f"{len(warnings)} warning(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
