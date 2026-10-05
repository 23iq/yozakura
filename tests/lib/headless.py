"""Make Qt tests headless by construction. Import this BEFORE PySide6.

Never lets a test window reach the user's live session, whatever the
caller's environment:
  * WAYLAND_DISPLAY is always removed;
  * without GL needs: QT_QPA_PLATFORM=offscreen, DISPLAY removed;
  * with GL needs (`ensure(gl=True)`): the test re-runs itself as a child
    of a private Xvfb (marked by YOZAKURA_TEST_XVFB=1) and uses xcb there;
    without Xvfb it falls back to offscreen.
An inherited DISPLAY (e.g. Xwayland :0) is never used for xcb.

The private server is started with `Xvfb -displayfd`, so the server itself
picks a free display atomically. (`xvfb-run -a` guesses a number from
/tmp/.X*-lock and races with every other test run on the machine: two
runs end up on one server, and the loser's tests die or hang when the
winner's server goes away.)

Every test also gets a watchdog: after YOZAKURA_TEST_TIMEOUT seconds
(default 120) all thread stacks are dumped to stderr and the process exits,
so a stuck event loop, GL grab or media teardown can never hang a run.
"""
from __future__ import annotations

import faulthandler
import os
import random
import select
import shutil
import signal
import subprocess
import sys

_MARK = "YOZAKURA_TEST_XVFB"
TIMEOUT = float(os.environ.get("YOZAKURA_TEST_TIMEOUT", "120"))

if TIMEOUT > 0:
    faulthandler.dump_traceback_later(TIMEOUT, exit=True)

# Harness trees live in fresh temp dirs, so a QML disk cache never hits and
# only piles up (~/.cache/<test>.test.py/qmlcache grew by ~180 files per run).
os.environ.setdefault("QML_DISABLE_DISK_CACHE", "1")


# Private displays live far above anything a desktop session uses. Letting
# Xvfb pick (-displayfd alone) starts at :0 and can claim the live Xwayland
# display: Xvfb then unlinks /tmp/.X11-unix/X<n> on exit and every X11 app
# of the session loses its socket.
_FIRST_DISPLAY = 140
_LAST_DISPLAY = 400


def _display_taken(n: int) -> bool:
    return os.path.lexists(f"/tmp/.X11-unix/X{n}") or os.path.lexists(f"/tmp/.X{n}-lock")


def _start_xvfb_on(xvfb: str, n: int) -> subprocess.Popen | None:
    r, w = os.pipe()
    proc = subprocess.Popen(
        [xvfb, f":{n}", "-displayfd", str(w), "-screen", "0", "1920x1080x24", "-nolisten", "tcp", "-noreset"],
        pass_fds=(w,), stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    os.close(w)
    data = b""
    try:
        while not data.endswith(b"\n"):
            ready, _, _ = select.select([r], [], [], 15)
            chunk = os.read(r, 64) if ready else b""
            if not chunk:
                break
            data += chunk
    finally:
        os.close(r)
    if data.strip() != str(n).encode():
        proc.kill()
        proc.wait()
        return None
    return proc


def _start_xvfb() -> tuple[subprocess.Popen, str] | None:
    xvfb = shutil.which("Xvfb")
    if not xvfb:
        return None
    for n in range(_FIRST_DISPLAY + random.randrange(100), _LAST_DISPLAY):
        if _display_taken(n):
            continue
        proc = _start_xvfb_on(xvfb, n)
        if proc:
            return proc, f":{n}"
    return None


def _run_under_xvfb() -> None:
    """Re-run this test under a private Xvfb and exit with its status."""
    started = _start_xvfb()
    if started is None:
        return
    faulthandler.cancel_dump_traceback_later()  # the child has its own
    server, display = started
    env = dict(os.environ)
    env[_MARK] = "1"
    env["DISPLAY"] = display
    env.pop("WAYLAND_DISPLAY", None)
    sys.stdout.flush()
    sys.stderr.flush()
    child = subprocess.Popen([sys.executable, *sys.argv], env=env)
    try:
        # The child has its own watchdog; this one only covers the case
        # where it is stuck in native code and ignores the signal.
        rc = child.wait(timeout=TIMEOUT + 30 if TIMEOUT > 0 else None)
    except subprocess.TimeoutExpired:
        child.kill()
        child.wait()
        print(f"headless: test killed after {TIMEOUT + 30:.0f}s", file=sys.stderr)
        rc = 124
    except KeyboardInterrupt:
        child.send_signal(signal.SIGINT)
        rc = child.wait()
    finally:
        server.terminate()
        try:
            server.wait(5)
        except subprocess.TimeoutExpired:
            server.kill()
            server.wait()
    sys.stdout.flush()
    sys.stderr.flush()
    os._exit(rc if rc >= 0 else 128 - rc)


def ensure(gl: bool = False) -> str:
    """Configure the environment; returns the QPA platform in use."""
    if "PySide6.QtGui" in sys.modules and os.environ.get("QT_QPA_PLATFORM") not in ("offscreen", "xcb"):
        raise RuntimeError("tests/lib/headless.py must be imported before PySide6")
    os.environ.pop("WAYLAND_DISPLAY", None)
    in_xvfb = os.environ.get(_MARK) == "1" and bool(os.environ.get("DISPLAY"))
    if in_xvfb and os.environ.get("QT_QPA_PLATFORM") == "xcb":
        return "xcb"  # already set up by ensure(gl=True)
    if gl and in_xvfb:
        os.environ["QT_QPA_PLATFORM"] = "xcb"
        # The threaded render loop deadlocks grabWindow() with video on
        # Xvfb's software GL.
        os.environ.setdefault("QSG_RENDER_LOOP", "basic")
        return "xcb"
    if gl and os.environ.get(_MARK) != "1":
        os.environ[_MARK] = "1"
        os.environ.pop("DISPLAY", None)
        _run_under_xvfb()  # exits when Xvfb is available
    if os.environ.get(_MARK) != "1":
        os.environ.pop("DISPLAY", None)  # only our own Xvfb display is kept
    os.environ["QT_QPA_PLATFORM"] = "offscreen"
    return "offscreen"


# Importing alone already makes the process safe (offscreen); tests that
# need GL call ensure(gl=True) right after.
ensure()
