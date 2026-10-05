#!/usr/bin/env python3
"""Run the test suites: node (tests/*.test.cjs), python (tests/*.test.py), go.

Usage: run_tests.py [js|py|go ...]   (default: all three)
Python QML tests need PySide6; they are skipped (not failed) without it.
"""
from __future__ import annotations

import os
import signal
import subprocess
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import REPO, fail, find_tool, info, ok, skip  # noqa: E402


def _tail(text: str, n: int = 30) -> str:
    return "\n".join("    " + ln for ln in text.strip().splitlines()[-n:])


def run_js() -> int:
    node = find_tool("node")
    if not node:
        skip("test-js: node not found")
        return 0
    # Explicit file list: a bare directory argument is only expanded by
    # node >= 23; older LTS releases (CI's node 22) try to load it as a module.
    files = sorted(str(p.relative_to(REPO)) for p in (REPO / "tests").glob("*.test.cjs"))
    r = subprocess.run([node, "--test", *files], cwd=REPO, capture_output=True, text=True)
    # Spec reporter ("ℹ tests 3") on a TTY / newer node, TAP ("# tests 3") otherwise.
    summary = [ln[2:] for ln in r.stdout.splitlines() if ln.startswith(("ℹ tests", "ℹ pass", "ℹ fail",
                                                                          "# tests", "# pass", "# fail"))]
    if r.returncode:
        print(_tail(r.stdout + r.stderr, 60))
        fail("test-js: node --test failed")
        return 1
    ok("test-js: " + ", ".join(s.strip() for s in summary))
    return 0


# Per-test wall clock limit. tests/lib/headless.py arms an in-process
# watchdog (YOZAKURA_TEST_TIMEOUT, default 120 s) that dumps stacks and exits;
# this one is the hard stop above it.
PY_TEST_TIMEOUT = float(os.environ.get("YOZAKURA_TEST_HARD_TIMEOUT", "240"))


def _run_test(cmd: list[str], env: dict[str, str]) -> tuple[int, str]:
    """Run one test in its own process group; kill the whole group on timeout.

    subprocess.run(timeout=) only kills the direct child and then waits for
    the output pipes, which grandchildren (Xvfb, a re-exec'd test) keep open,
    so a stuck test hung the runner forever.
    """
    proc = subprocess.Popen(cmd, cwd=REPO, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            text=True, start_new_session=True)
    try:
        out, _ = proc.communicate(timeout=PY_TEST_TIMEOUT)
        return proc.returncode, out
    except subprocess.TimeoutExpired:
        os.killpg(proc.pid, signal.SIGKILL)
        out, _ = proc.communicate()
        return 124, (out or "") + f"\nTIMEOUT: killed after {PY_TEST_TIMEOUT:.0f}s"
    finally:
        try:
            os.killpg(proc.pid, signal.SIGKILL)  # stray children (Xvfb, players)
        except ProcessLookupError:
            pass


def run_py() -> int:
    py = sys.executable
    if subprocess.run([py, "-c", "import PySide6"], capture_output=True).returncode:
        skip("test-py: PySide6 not importable (pacman -S pyside6); QML tests skipped")
        return 0
    tests = sorted((REPO / "tests").glob("*.test.py"))
    # Never let a QML test reach the live session: no Wayland/X display,
    # offscreen platform (GL tests re-run themselves under a private
    # xvfb-run via tests/lib/headless.py).
    env = {k: v for k, v in os.environ.items() if k not in ("WAYLAND_DISPLAY", "DISPLAY", "YOZAKURA_TEST_XVFB")}
    env["QT_QPA_PLATFORM"] = "offscreen"
    failed = []
    for t in tests:
        start = time.monotonic()
        rc, out = _run_test([py, str(t)], env)
        took = time.monotonic() - start
        if rc:
            failed.append(t.name)
            info(f"  FAIL {t.name} ({took:.1f}s)")
            print(_tail(out))
        else:
            info(f"  pass {t.name} ({took:.1f}s)")
    if failed:
        fail(f"test-py: {len(failed)}/{len(tests)} failed: {', '.join(failed)}")
        return 1
    ok(f"test-py: {len(tests)} test file(s) passed")
    return 0


def run_go() -> int:
    go = find_tool("go")
    if not go:
        skip("test-go: go not found")
        return 0
    r = subprocess.run([go, "test", "./..."], cwd=REPO / "backend", capture_output=True, text=True)
    if r.returncode:
        print(_tail("\n".join(ln for ln in (r.stdout + r.stderr).splitlines() if "no test files" not in ln), 60))
        fail("test-go: go test failed")
        return 1
    n = sum(1 for ln in r.stdout.splitlines() if ln.startswith("ok"))
    ok(f"test-go: {n} package(s) passed")
    return 0


SUITES = {"js": run_js, "py": run_py, "go": run_go}

if __name__ == "__main__":
    names = sys.argv[1:] or list(SUITES)
    if set(names) - set(SUITES):
        print(__doc__)
        sys.exit(2)
    sys.exit(max(SUITES[n]() for n in names))
