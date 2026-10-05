#!/usr/bin/env python3
"""qmllint with Quickshell import resolution, noise filtering and a baseline.

Usage:
  qmllint.py                    lint every QML file, fail on findings not in the baseline
  qmllint.py FILE...            lint only these files (baseline-scoped to them)
  qmllint.py --update-baseline  record the current findings as the baseline
  qmllint.py --parse [FILE...]  syntax-only check (QML via qmllint --bare, JS via node);
                                fails on ANY parse error, no baseline involved
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import baseline  # noqa: E402
import qmltree  # noqa: E402
from common import BASELINES, REPO, fail, find_qt6_tool, find_tool, info, ok, skip, tracked_files  # noqa: E402

BASELINE = BASELINES / "qmllint.json"
# Not Quickshell QML (SDDM greeter theme): parse-checked only.
LINT_EXCLUDE = ("assets/sddm/",)
# Only these qmllint levels gate; "info" (e.g. unused-imports) is advisory.
GATING = {"warning", "critical"}

# Toolchain noise: findings caused by gaps in Quickshell's qmltypes or by
# qmllint limitations, not by our code. Each entry: (rule id, message regex, why).
NOISE = [
    ("unresolved-type", r'"(FileViewAdapter|PopupAnchor|qs::dbus::dbusmenu::DBusMenuHandle)"',
     "Quickshell qmltypes reference types they do not export"),
    ("signal-handler-parameters", r"was not found, but is required to compile",
     "Qt enum parameter types (QProcess::ExitStatus, ...) missing from qmltypes"),
    ("uncreatable-type", r"Type (PanelWindow|FloatingWindow|PopupWindow) is not creatable",
     "qmllint ignores Quickshell's `default import Quickshell._Window`"),
    ("import", r"not declared as singleton in qmldir but using pragma Singleton",
     "qmllint import-cycle artefact (qs.config <-> qs.modules.services)"),
    ("import", r"^Type warnings occurred while evaluating file",
     "header line of the import-cycle artefact above"),
]
_NOISE = [(rid, re.compile(rx)) for rid, rx, _ in NOISE]


def _is_noise(rule: str, message: str) -> bool:
    return any(rule == rid and rx.search(message) for rid, rx in _NOISE)


def _lint_one(qmllint: str, tree: Path, rel: str, extra: list[str]) -> list[dict]:
    r = subprocess.run([qmllint, "-I", str(tree), *extra, "--json", "-", rel],
                       cwd=qmltree.ROOT, capture_output=True, text=True)
    try:
        data = json.loads(r.stdout)
    except json.JSONDecodeError:
        return [{"line": 0, "column": 0, "id": "tool-error", "type": "critical",
                 "message": f"qmllint produced no JSON: {r.stderr.strip()[:300]}"}]
    return [w for f in data.get("files", []) for w in f.get("warnings", [])]


def _fingerprint(rel: str, w: dict, lines: list[str]) -> str:
    line = w.get("line") or 0
    text = lines[line - 1].strip() if 0 < line <= len(lines) else ""
    col = (w.get("column") or 1) - 1
    raw = lines[line - 1] if 0 < line <= len(lines) else ""
    token = raw[col:col + (w.get("length") or 0)]
    msg = w.get("message", "").split("\n", 1)[0]
    return f"{w.get('id')}|{msg}|{token}|{text}"


def collect(files: list[str]) -> list[baseline.Finding]:
    qmllint = find_qt6_tool("qmllint", "QMLLINT")
    tree = qmltree.build()
    findings: list[baseline.Finding] = []

    def work(rel: str):
        return rel, _lint_one(qmllint, tree, rel, [])

    with ThreadPoolExecutor(max_workers=os.cpu_count() or 4) as ex:
        results = list(ex.map(work, files))
    for rel, warnings in results:
        lines = (REPO / rel).read_text(errors="replace").split("\n")
        for w in warnings:
            rule, msg = w.get("id", "?"), w.get("message", "")
            if w.get("type") not in GATING or _is_noise(rule, msg):
                continue
            findings.append(baseline.Finding(
                file=rel, line=w.get("line") or 0, column=w.get("column") or 0, rule=rule,
                message=msg.split("\n", 1)[0], fingerprint=_fingerprint(rel, w, lines),
                severity=w.get("type", "warning")))
    return findings


def lint_files(explicit: list[str]) -> list[str]:
    files = explicit or tracked_files("*.qml")
    return [f for f in files if f.endswith(".qml") and not f.startswith(LINT_EXCLUDE) and (REPO / f).exists()]


# ---------------------------------------------------------------- parse check

_NODE_CHECK = r"""
const fs = require('fs'), vm = require('vm');
let bad = 0;
for (const f of process.argv.slice(1)) {
  const src = fs.readFileSync(f, 'utf8').replace(/^\s*\.(pragma|import)\b.*$/gm, '');
  try { new vm.Script(src, { filename: f }); }
  catch (e) { bad++; const m = (e.stack || '').split('\n'); console.log(m[0] + ': ' + e.message); }
}
process.exit(bad ? 1 : 0);
"""


def parse_check(explicit: list[str]) -> int:
    qmllint = find_qt6_tool("qmllint", "QMLLINT")
    files = explicit or tracked_files("*.qml", "*.js")
    qml = [f for f in files if f.endswith(".qml")]
    js = [f for f in files if f.endswith(".js") and not f.startswith("backend/")]
    errors = 0
    if qml:
        if not qmllint:
            skip("parse: qmllint not found (install qt6-declarative); QML syntax not checked")
        else:
            r = subprocess.run([qmllint, "--bare", "--json", "-", *qml], cwd=REPO, capture_output=True, text=True)
            data = json.loads(r.stdout or '{"files": []}')
            for f in data["files"]:
                for w in f.get("warnings", []):
                    if str(w.get("id", "")).startswith("syntax"):
                        errors += 1
                        print(f"  {f['filename']}:{w.get('line')}:{w.get('column')}: {w.get('message')}")
    if js:
        node = find_tool("node")
        if not node:
            skip("parse: node not found; JS syntax not checked")
        else:
            r = subprocess.run([node, "-e", _NODE_CHECK, *js], cwd=REPO, capture_output=True, text=True)
            if r.returncode:
                errors += max(1, r.stdout.count("\n"))
                print("  " + r.stdout.strip().replace("\n", "\n  "))
    if errors:
        fail(f"parse: {errors} syntax error(s) in {len(qml)} QML / {len(js)} JS file(s)")
        return 1
    ok(f"parse: {len(qml)} QML and {len(js)} JS file(s) parse cleanly")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("files", nargs="*")
    ap.add_argument("--update-baseline", action="store_true")
    ap.add_argument("--parse", action="store_true", help="syntax-only check")
    args = ap.parse_args()
    files = [os.path.relpath(Path(f).resolve(), REPO) for f in args.files]

    if args.parse:
        return parse_check(files)

    if not find_qt6_tool("qmllint", "QMLLINT"):
        skip("lint-qml: qmllint not found (Arch: qt6-declarative; or set QMLLINT=/path)")
        return 0
    targets = lint_files(files)
    findings = collect(targets)
    if args.update_baseline:
        keep = {} if not files else {f: c for f, c in baseline.load(BASELINE).items() if f not in targets}
        baseline.save(BASELINE, "qmllint", findings, keep)
        ok(f"lint-qml: baseline written ({len(findings)} findings in {len(set(f.file for f in findings))} files)")
        return 0
    syntax = [f for f in findings if f.rule.startswith("syntax")]
    if syntax:
        for f in syntax:
            print(f"  {f.render()}")
        fail(f"lint-qml: {len(syntax)} syntax error(s); semantic findings suppressed "
             "(a broken file cascades into every importer). Fix syntax first.")
        return 1
    res = baseline.compare(findings, baseline.load(BASELINE), set(targets) if files else None)
    info(f"lint-qml: {len(targets)} file(s) linted, {len(NOISE)} toolchain-noise rules applied")
    return baseline.report("lint-qml", res, BASELINE)


if __name__ == "__main__":
    sys.exit(main())
