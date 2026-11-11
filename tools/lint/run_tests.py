#!/usr/bin/env python3
"""Run the test suites: node (tests/*.test.cjs), python (tests/*.test.py), go.

Usage: run_tests.py [--timings] [js|py|go ...]   (default: all three)
Python QML tests need PySide6; they are skipped (not failed) without it.

Python tests run in parallel, longest first (times from tests/timings.json):
  YOZAKURA_TEST_JOBS=N        workers (default: CPU count; 1 = serial)
  YOZAKURA_TEST_SHARD=i/N     run only shard i of N (timing-balanced, deterministic)
  YOZAKURA_TEST_RETRY=1       re-run failures once, serially; a pass there is
                              reported as "flaky (passed on retry)", not a failure
  YOZAKURA_TEST_HARD_TIMEOUT  per-test kill timeout in seconds (default 90)
--timings re-records tests/timings.json from this run (every test, no shard).
"""
from __future__ import annotations

import concurrent.futures
import json
import os
import shutil
import signal
import subprocess
import sys
import tempfile
import threading
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
# watchdog (YOZAKURA_TEST_TIMEOUT, default 45 s) that dumps stacks and exits;
# this one is the hard stop above it.
PY_TEST_TIMEOUT = float(os.environ.get("YOZAKURA_TEST_HARD_TIMEOUT", "90"))

# Seconds per test file from a reference run (`make test-timings`). It orders
# the run longest-first and balances YOZAKURA_TEST_SHARD. Tests missing from
# it are ordered by this machine's previous runs (LOCAL_TIMES), else first.
TIMINGS = REPO / "tests" / "timings.json"
LOCAL_TIMES = REPO / ".cache" / "test-py-times.json"
UNKNOWN_WEIGHT = 2.0  # shard weight of a test without a recorded time

_running: set[subprocess.Popen] = set()
_running_lock = threading.Lock()


def _killpg(proc: subprocess.Popen) -> None:
    try:
        os.killpg(proc.pid, signal.SIGKILL)  # stray children (Xvfb, players)
    except ProcessLookupError:
        pass


def _run_test(cmd: list[str], env: dict[str, str]) -> tuple[int, str]:
    """Run one test in its own process group; kill the whole group on timeout.

    subprocess.run(timeout=) only kills the direct child and then waits for
    the output pipes, which grandchildren (Xvfb, a re-exec'd test) keep open,
    so a stuck test hung the runner forever.
    """
    proc = subprocess.Popen(cmd, cwd=REPO, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            text=True, start_new_session=True)
    with _running_lock:
        _running.add(proc)
    try:
        out, _ = proc.communicate(timeout=PY_TEST_TIMEOUT)
        return proc.returncode, out
    except subprocess.TimeoutExpired:
        _killpg(proc)
        out, _ = proc.communicate()
        return 124, (out or "") + f"\nTIMEOUT: killed after {PY_TEST_TIMEOUT:.0f}s"
    finally:
        _killpg(proc)
        with _running_lock:
            _running.discard(proc)


def read_times(path: Path) -> dict[str, float]:
    try:
        data = json.loads(path.read_text())
    except (OSError, ValueError):
        return {}
    if not isinstance(data, dict):
        return {}
    return {k: float(v) for k, v in data.items() if isinstance(v, (int, float))}


def jobs_for(n_tests: int) -> int:
    raw = os.environ.get("YOZAKURA_TEST_JOBS", "").strip()
    jobs = int(raw) if raw.isdigit() else 0
    if jobs <= 0:
        try:
            jobs = len(os.sched_getaffinity(0))
        except AttributeError:
            jobs = os.cpu_count() or 2
    return max(1, min(jobs, n_tests or 1))


def parse_shard(spec: str) -> tuple[int, int] | None:
    try:
        i, n = (int(x) for x in spec.split("/"))
    except ValueError:
        return None
    return (i, n) if 1 <= i <= n else None


def shard(tests: list[Path], index: int, count: int, timings: dict[str, float]) -> list[Path]:
    """Shard `index` (1-based) of `count`: greedy longest-first bin packing over
    the committed timings, so every machine computes the same split."""
    bins: list[list[Path]] = [[] for _ in range(count)]
    load = [0.0] * count
    for t in sorted(tests, key=lambda p: (-timings.get(p.name, UNKNOWN_WEIGHT), p.name)):
        b = min(range(count), key=lambda k: (load[k], k))
        bins[b].append(t)
        load[b] += timings.get(t.name, UNKNOWN_WEIGHT)
    return bins[index - 1]


def order(tests: list[Path], committed: dict[str, float], local: dict[str, float]) -> list[Path]:
    """Longest first (the slowest start right away, short ones fill the gaps);
    tests without any known time go first of all; ties alphabetical."""
    def key(p: Path) -> tuple[float, str]:
        t = committed.get(p.name, local.get(p.name))
        return (-(t if t is not None else float("inf")), p.name)
    return sorted(tests, key=key)


def run_py(write_timings: bool = False) -> int:
    py = sys.executable
    if subprocess.run([py, "-c", "import PySide6"], capture_output=True).returncode:
        skip("test-py: PySide6 not importable (pacman -S pyside6); QML tests skipped")
        return 0
    tests = sorted((REPO / "tests").glob("*.test.py"))
    committed = read_times(TIMINGS)
    local = read_times(LOCAL_TIMES)
    spec = os.environ.get("YOZAKURA_TEST_SHARD", "").strip()
    if spec and not write_timings:
        parsed = parse_shard(spec)
        if parsed is None:
            fail(f"test-py: bad YOZAKURA_TEST_SHARD={spec!r} (want i/N with 1 <= i <= N)")
            return 2
        total = len(tests)
        tests = shard(tests, *parsed, committed)
        est = sum(committed.get(t.name, UNKNOWN_WEIGHT) for t in tests)
        info(f"  shard {spec}: {len(tests)} of {total} test file(s), ~{est:.0f}s of recorded time")
    tests = order(tests, committed, local)
    jobs = jobs_for(len(tests))
    retry = os.environ.get("YOZAKURA_TEST_RETRY", "") == "1"
    # Never let a QML test reach the live session: no Wayland/X display,
    # offscreen platform (GL tests re-run themselves under a private
    # Xvfb via tests/lib/headless.py).
    env = {k: v for k, v in os.environ.items() if k not in ("WAYLAND_DISPLAY", "DISPLAY", "YOZAKURA_TEST_XVFB")}
    env["QT_QPA_PLATFORM"] = "offscreen"
    run_tmp = Path(tempfile.mkdtemp(prefix="yozakura-tests-"))

    def one(t: Path) -> tuple[Path, int, str, float]:
        # Each test gets its own fake $HOME (qmlharness.HARNESS_HOME), so
        # parallel tests never share, or wipe, one another's files.
        home = run_tmp / t.stem
        tenv = dict(env, YOZAKURA_HARNESS_HOME=str(home))
        start = time.monotonic()
        try:
            rc, out = _run_test([py, str(t)], tenv)
        finally:
            shutil.rmtree(home, ignore_errors=True)
        return t, rc, out, time.monotonic() - start

    if jobs > 1:
        info(f"  {len(tests)} test file(s) on {jobs} workers (YOZAKURA_TEST_JOBS=1 runs them serially)")
    failed: list[str] = []
    flaky: list[str] = []
    times: dict[str, float] = {}
    pool = concurrent.futures.ThreadPoolExecutor(jobs)
    try:
        futures = [pool.submit(one, t) for t in tests]
        for fut in concurrent.futures.as_completed(futures):
            t, rc, out, took = fut.result()
            times[t.name] = took
            if rc:
                failed.append(t.name)
                info(f"  FAIL {t.name} ({took:.1f}s)")
                print(_tail(out), flush=True)
            else:
                info(f"  pass {t.name} ({took:.1f}s)")
        if retry and failed:
            info(f"  retrying {len(failed)} failed test file(s) serially")
            for name in list(failed):
                _, rc, out, took = one(REPO / "tests" / name)
                if rc:
                    info(f"  FAIL {name} again ({took:.1f}s)")
                    print(_tail(out), flush=True)
                else:
                    failed.remove(name)
                    flaky.append(name)
                    info(f"  flaky {name} (passed on retry, {took:.1f}s)")
    except KeyboardInterrupt:
        pool.shutdown(wait=False, cancel_futures=True)
        with _running_lock:
            for proc in list(_running):
                _killpg(proc)
        raise
    finally:
        pool.shutdown(wait=True, cancel_futures=True)
        shutil.rmtree(run_tmp, ignore_errors=True)
    try:
        LOCAL_TIMES.parent.mkdir(parents=True, exist_ok=True)
        merged = {**local, **{k: round(v, 2) for k, v in times.items()}}
        LOCAL_TIMES.write_text(json.dumps(merged, indent=1, sort_keys=True) + "\n")
    except OSError:
        pass
    if write_timings:
        TIMINGS.write_text(json.dumps({k: round(v, 1) for k, v in times.items()}, indent=1, sort_keys=True) + "\n")
        info(f"  wrote {TIMINGS.relative_to(REPO)} ({len(times)} test file(s), {jobs} worker(s))")
    if failed:
        fail(f"test-py: {len(failed)}/{len(tests)} failed: {', '.join(sorted(failed))}")
        return 1
    note = f" ({len(flaky)} flaky, passed on retry: {', '.join(sorted(flaky))})" if flaky else ""
    ok(f"test-py: {len(tests)} test file(s) passed{note}")
    return 0


def run_go() -> int:
    go = find_tool("go")
    if not go:
        skip("test-go: go not found")
        return 0
    r = subprocess.run([go, "test", "./..."], cwd=REPO / "backend", capture_output=True, text=True)
    if r.returncode:
        # Passing packages are dropped: with ~80 of them the tail would hide
        # the failing one.
        lines = (r.stdout + r.stderr).splitlines()
        print(_tail("\n".join(ln for ln in lines if "no test files" not in ln and not ln.startswith("ok ")), 60))
        fail("test-go: go test failed")
        return 1
    n = sum(1 for ln in r.stdout.splitlines() if ln.startswith("ok"))
    ok(f"test-go: {n} package(s) passed")
    return 0


SUITES = {"js": run_js, "py": run_py, "go": run_go}

if __name__ == "__main__":
    args = sys.argv[1:]
    write = "--timings" in args
    names = [a for a in args if a != "--timings"] or (["py"] if write else list(SUITES))
    if set(names) - set(SUITES):
        print(__doc__)
        sys.exit(2)
    try:
        sys.exit(max((run_py(write) if n == "py" else SUITES[n]()) for n in names))
    except KeyboardInterrupt:
        sys.exit(130)
