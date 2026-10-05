#!/usr/bin/env python3
"""Go backend lint: go vet (strict) + staticcheck (baselined).

Usage: golint.py [--update-baseline]
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import baseline  # noqa: E402
from common import BASELINES, REPO, fail, find_tool, ok, skip  # noqa: E402

BACKEND = REPO / "backend"
BASELINE = BASELINES / "staticcheck.json"


def vet(go: str) -> int:
    r = subprocess.run([go, "vet", "./..."], cwd=BACKEND, capture_output=True, text=True)
    if r.returncode:
        print("  " + (r.stderr or r.stdout).strip().replace("\n", "\n  "))
        fail("go vet: findings")
        return 1
    ok("go vet: clean")
    return 0


# Go's convention for machine-generated files (e.g. go-wayland-scanner
# bindings): they are regenerated, not maintained, so they are not linted.
GENERATED = re.compile(r"^// Code generated .* DO NOT EDIT\.$")


def _generated(lines: list[str]) -> bool:
    for line in lines:
        if line.startswith("package "):
            return False
        if GENERATED.match(line):
            return True
    return False


def staticcheck_findings(tool: str) -> list[baseline.Finding]:
    r = subprocess.run([tool, "-f", "json", "./..."], cwd=BACKEND, capture_output=True, text=True)
    if r.returncode not in (0, 1):
        raise RuntimeError(r.stderr.strip() or "staticcheck failed")
    findings = []
    cache: dict[str, list[str]] = {}
    for line in r.stdout.splitlines():
        if not line.strip():
            continue
        d = json.loads(line)
        if d.get("severity") == "ignored":
            continue
        loc = d.get("location", {})
        path = Path(loc.get("file", ""))
        rel = str(path.relative_to(REPO)) if path.is_absolute() and REPO in path.parents else str(path)
        if rel not in cache:
            try:
                cache[rel] = (REPO / rel).read_text(errors="replace").split("\n")
            except OSError:
                cache[rel] = []
        if _generated(cache[rel]):
            continue
        lines, ln = cache[rel], loc.get("line", 0)
        text = lines[ln - 1].strip() if 0 < ln <= len(lines) else ""
        code, msg = d.get("code", "?"), d.get("message", "")
        findings.append(baseline.Finding(file=rel, line=ln, column=loc.get("column", 0), rule=code,
                                         message=msg, fingerprint=f"{code}|{msg}|{text}"))
    return findings


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--update-baseline", action="store_true")
    args = ap.parse_args()

    go = find_tool("go")
    if not go:
        skip("lint-go: go not found")
        return 0
    rc = 0 if args.update_baseline else vet(go)
    tool = find_tool("staticcheck", "STATICCHECK")
    if not tool:
        skip("staticcheck not found (go install honnef.co/go/tools/cmd/staticcheck@latest)")
        return rc
    findings = staticcheck_findings(tool)
    if args.update_baseline:
        baseline.save(BASELINE, "staticcheck", findings)
        ok(f"staticcheck: baseline written ({len(findings)} findings)")
        return 0
    return rc | baseline.report("staticcheck", baseline.compare(findings, baseline.load(BASELINE)), BASELINE)


if __name__ == "__main__":
    sys.exit(main())
