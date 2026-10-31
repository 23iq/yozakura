#!/usr/bin/env python3
"""Guard: no bare exec.Command in the Go backend.

A child started with exec.Command cannot be cancelled: it outlives a service
shutdown or a hung tool. Use backend/pkg/proc (Run/Do/Combined/Start/Command)
or exec.CommandContext. Tests, vendored and generated code are skipped.

Exceptions go in ALLOW as {"relative/path.go": "reason"}.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import REPO, fail, ok  # noqa: E402

BACKEND = REPO / "backend"

# path (relative to backend/) -> why a bare exec.Command is acceptable there
ALLOW: dict[str, str] = {}

BARE = re.compile(r"\bexec\.Command\(")
GENERATED = re.compile(r"^// Code generated .* DO NOT EDIT\.$", re.M)


def strip_comment(line: str) -> str:
    i = line.find("//")
    return line if i < 0 else line[:i]


def scan(backend: Path = BACKEND, allow: dict[str, str] | None = None) -> list[str]:
    allow = ALLOW if allow is None else allow
    bad = []
    for p in sorted(backend.rglob("*.go")):
        rel = p.relative_to(backend).as_posix()
        if rel.startswith("vendor/") or rel.endswith("_test.go") or rel in allow:
            continue
        text = p.read_text(errors="replace")
        if GENERATED.search(text):
            continue
        for n, line in enumerate(text.split("\n"), 1):
            if BARE.search(strip_comment(line)):
                bad.append(f"backend/{rel}:{n}: {line.strip()}")
    return bad


def main() -> int:
    bad = scan()
    if bad:
        print("  " + "\n  ".join(bad))
        fail("exec-guard: bare exec.Command (use pkg/proc or exec.CommandContext)")
        return 1
    ok("exec-guard: no bare exec.Command")
    return 0


if __name__ == "__main__":
    sys.exit(main())
