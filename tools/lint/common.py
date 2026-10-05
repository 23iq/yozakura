"""Shared helpers for the lint wrappers: repo paths, tool discovery, git diffs.

Every wrapper follows the same contract so `make check` can summarise them:
  * exit 0  -> clean (or skipped: an optional tool is missing; a line starting
               with "[skip]" is printed so the summary can report it)
  * exit 1  -> real findings
  * exit 2  -> the wrapper itself failed (bad usage, broken tool)
"""
from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
CACHE = REPO / ".cache" / "lint"
BASELINES = REPO / "tools" / "lint" / "baselines"

# Default diff base for "changed files" checks; override with BASE=<ref>.
DEFAULT_BASE = "origin/main"

# Extra places user-local installs land (uv tool, go install, Qt tooling).
EXTRA_BIN_DIRS = [
    Path.home() / ".local" / "bin",
    Path(os.environ.get("GOBIN", "")) if os.environ.get("GOBIN") else None,
    Path(os.environ.get("GOPATH", str(Path.home() / "go"))) / "bin",
]

_COLOR = sys.stdout.isatty() and os.environ.get("NO_COLOR") is None


def _c(code: str, text: str) -> str:
    return f"\033[{code}m{text}\033[0m" if _COLOR else text


def info(msg: str) -> None:
    print(msg, flush=True)


def ok(msg: str) -> None:
    print(_c("32", "[ok] ") + msg, flush=True)


def warn(msg: str) -> None:
    print(_c("33", "[warn] ") + msg, flush=True)


def fail(msg: str) -> None:
    print(_c("31", "[fail] ") + msg, flush=True)


def skip(msg: str) -> None:
    print(_c("36", "[skip] ") + msg, flush=True)


def find_tool(name: str, env_var: str | None = None) -> str | None:
    """Locate an executable on PATH or in the usual user-local bin dirs."""
    if env_var and os.environ.get(env_var):
        return os.environ[env_var]
    found = shutil.which(name)
    if found:
        return found
    for d in EXTRA_BIN_DIRS:
        if d and (d / name).is_file() and os.access(d / name, os.X_OK):
            return str(d / name)
    return None


QT6_BIN_DIRS = [Path("/usr/lib/qt6/bin"), Path("/usr/lib64/qt6/bin"), Path("/usr/libexec/qt6")]


def find_qt6_tool(name: str, env_var: str) -> str | None:
    """Locate a Qt 6 tool. /usr/bin/qmllint is often the Qt 5 one (qt5-declarative)."""
    if os.environ.get(env_var):
        return os.environ[env_var]
    for d in QT6_BIN_DIRS:
        if (d / name).is_file():
            return str(d / name)
    for candidate in (f"{name}6", f"{name}-qt6", name):
        path = shutil.which(candidate)
        if not path:
            continue
        r = subprocess.run([path, "--version"], capture_output=True, text=True)
        if re.search(r"\b6\.\d+", r.stdout + r.stderr):
            return path
    return None


def run(cmd: list[str], **kw) -> subprocess.CompletedProcess:
    kw.setdefault("cwd", REPO)
    kw.setdefault("text", True)
    kw.setdefault("capture_output", True)
    return subprocess.run(cmd, **kw)


def git(*args: str) -> str:
    r = run(["git", *args])
    if r.returncode != 0:
        raise RuntimeError(f"git {' '.join(args)} failed: {r.stderr.strip()}")
    return r.stdout


def base_ref() -> str:
    return os.environ.get("BASE") or DEFAULT_BASE


def merge_base(ref: str | None = None) -> str | None:
    ref = ref or base_ref()
    try:
        return git("merge-base", ref, "HEAD").strip()
    except RuntimeError:
        return None


def tracked_files(*patterns: str) -> list[str]:
    """Tracked plus untracked-but-not-ignored files (new files are checked too)."""
    out = git("ls-files", "--cached", "--others", "--exclude-standard", "--", *patterns)
    return sorted({f for f in out.splitlines() if f and (REPO / f).exists()})


def changed_files(*patterns: str, ref: str | None = None) -> tuple[list[str], list[str]] | None:
    """Return (added, modified) paths vs the merge-base with BASE.

    Includes committed, staged, unstaged and untracked (non-ignored) changes so
    the check works both in CI-like runs and on a dirty working tree.
    Returns None when no merge-base can be found.
    """
    mb = merge_base(ref)
    if mb is None:
        return None
    added: set[str] = set()
    modified: set[str] = set()
    out = git("diff", "--name-status", "--no-renames", mb, "--", *patterns)
    for line in out.splitlines():
        status, _, path = line.partition("\t")
        if not (REPO / path).exists():
            continue
        (added if status.startswith("A") else modified).add(path)
    for path in git("ls-files", "--others", "--exclude-standard", "--", *patterns).splitlines():
        if path:
            added.add(path)
    return sorted(added), sorted(modified - added)


def staged_files(*patterns: str) -> list[str]:
    out = git("diff", "--cached", "--name-only", "--diff-filter=ACM", "--", *patterns)
    return [f for f in out.splitlines() if f]
