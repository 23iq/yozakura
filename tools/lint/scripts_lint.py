#!/usr/bin/env python3
"""Strict linters for helper scripts: shellcheck (sh) and ruff (py).

Both are clean today, so there is no baseline: any finding fails.
Usage: scripts_lint.py sh|py
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import REPO, fail, find_tool, ok, skip, tracked_files  # noqa: E402

SHELL_EXTRA = ["install.sh", "tools/hooks/pre-commit", "tools/check.sh"]


def shell_files() -> list[str]:
    files = [f for f in tracked_files("*.sh", "*.bash") if not f.startswith("backend/")]
    files += [f for f in SHELL_EXTRA if (REPO / f).exists()]
    return sorted(set(files))


def lint_sh() -> int:
    tool = find_tool("shellcheck", "SHELLCHECK")
    if not tool:
        skip("lint-sh: shellcheck not found (uv tool install shellcheck-py)")
        return 0
    files = shell_files()
    r = subprocess.run([tool, "-f", "gcc", "-x", *files], cwd=REPO, capture_output=True, text=True)
    if r.returncode:
        print("  " + (r.stdout + r.stderr).strip().replace("\n", "\n  "))
        fail(f"lint-sh: shellcheck findings in {len(files)} script(s)")
        return 1
    ok(f"lint-sh: {len(files)} script(s) shellcheck-clean")
    return 0


def lint_py() -> int:
    tool = find_tool("ruff", "RUFF")
    if not tool:
        skip("lint-py: ruff not found (uv tool install ruff)")
        return 0
    targets = [d for d in ("scripts", "tests", "tools") if (REPO / d).exists()]
    r = subprocess.run([tool, "check", "--output-format", "concise", *targets], cwd=REPO,
                       capture_output=True, text=True)
    if r.returncode:
        print("  " + (r.stdout + r.stderr).strip().replace("\n", "\n  "))
        fail("lint-py: ruff findings (config: ruff.toml)")
        return 1
    ok(f"lint-py: ruff clean ({', '.join(targets)})")
    return 0


if __name__ == "__main__":
    which = sys.argv[1] if len(sys.argv) > 1 else ""
    if which not in ("sh", "py"):
        print(__doc__)
        sys.exit(2)
    sys.exit(lint_sh() if which == "sh" else lint_py())
