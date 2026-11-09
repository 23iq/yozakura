"""Event-loop waits for Qt/QML tests: wait for a condition, not for a clock.

    from lib.waits import pump, wait_until, settle

    pump(50)                                  # run the event loop for ~50 ms
    assert wait_until(lambda: h.eval(o, "ready"))   # until true (or timeout)
    settle()                                  # flush callLater/0 ms timers/frames

Prefer `wait_until(pred)` over `pump(N)` whenever the test really waits for a
state (a property value, an item becoming visible, a file written, a call
recorded): it returns as soon as the state is reached, and its timeout is
generous so a loaded CI machine (tests run in parallel) does not flake.
Keep `pump(N)` only for waits that deliberately let time pass (a debounce or
timer under test); even then, shorten the interval in the test when the code
exposes it. With `Config.animDuration = 0` (or the Motion knob) `settle()`
is enough for bindings, `Qt.callLater` and zero-length animations.

`YOZAKURA_TEST_WAIT_SCALE` (default 1) multiplies every `wait_until` timeout,
for very slow machines.
"""
from __future__ import annotations

import os
import sys
import time
from typing import Callable

from PySide6.QtCore import QCoreApplication, QEvent, QEventLoop, QThread

SCALE = float(os.environ.get("YOZAKURA_TEST_WAIT_SCALE", "1") or 1)
DEFAULT_TIMEOUT_MS = 5000
DEFAULT_STEP_MS = 5
# Like QTest.qWait, the waits run deleteLater()s (DeferredDelete), which a
# bare processEvents() outside exec() never does. Tests written against such
# a bare loop can opt out with keep_deferred_deletes().
_flush_deletes = True


def keep_deferred_deletes() -> None:
    """Never run deleteLater()s while waiting (the bare processEvents() loop):
    for scenes whose teardown crashes Qt when it really happens."""
    global _flush_deletes
    _flush_deletes = False


def _app():
    app = QCoreApplication.instance()
    if app is None:
        raise RuntimeError("waits: create the Q(Gui)Application (Harness) first")
    return app


def _spin(ms: float) -> None:
    """Process events for up to `ms`, sleeping in between (no busy loop)."""
    app = _app()
    end = time.monotonic() + ms / 1000
    while True:
        app.processEvents(QEventLoop.ProcessEventsFlag.AllEvents, 5)
        if _flush_deletes:
            QCoreApplication.sendPostedEvents(None, QEvent.Type.DeferredDelete)
        left = end - time.monotonic()
        if left <= 0:
            return
        QThread.msleep(max(1, min(2, int(left * 1000))))


def pump(ms: float = 50) -> None:
    """Run the event loop for `ms` milliseconds (a deliberate fixed wait)."""
    _spin(ms)


def wait_until(pred: Callable[[], object], timeout_ms: float = DEFAULT_TIMEOUT_MS,
               step_ms: float = DEFAULT_STEP_MS) -> bool:
    """Process events until `pred()` is truthy; False after `timeout_ms`.

    `pred` is checked first, so an already-true state costs no time. An
    exception from `pred` (an item not created yet) counts as "not yet".
    """
    end = time.monotonic() + timeout_ms * SCALE / 1000
    while True:
        if _holds(pred):
            return True
        if time.monotonic() >= end:
            _report("wait_until", timeout_ms)
            return False
        _spin(step_ms)


def _report(what: str, timeout_ms: float) -> None:
    """A timed-out wait is usually the reason of the failure that follows: say where."""
    caller = sys._getframe(2)
    print(f"waits: {what} timed out after {timeout_ms * SCALE:.0f} ms at "
          f"{os.path.basename(caller.f_code.co_filename)}:{caller.f_lineno}", file=sys.stderr)


def _holds(pred: Callable[[], object]) -> bool:
    try:
        return bool(pred())
    except Exception:  # noqa: BLE001  (not there yet: keep waiting)
        return False


def wait_stable(value: Callable[[], object], stable_ms: float = 80,
                timeout_ms: float = DEFAULT_TIMEOUT_MS) -> bool:
    """Process events until `value()` has not changed for `stable_ms`
    (an animation or scroll came to rest); False after `timeout_ms`."""
    end = time.monotonic() + timeout_ms * SCALE / 1000
    last = value()
    since = time.monotonic()
    while time.monotonic() < end:
        _spin(DEFAULT_STEP_MS)
        cur = value()
        now = time.monotonic()
        if cur != last:
            last, since = cur, now
        elif (now - since) * 1000 >= stable_ms:
            return True
    _report("wait_stable", timeout_ms)
    return False


def settle(frames: int = 2, frame_ms: float = 16) -> None:
    """Let bindings, `Qt.callLater`, 0 ms timers and a few frames run.

    For scenes with animations disabled (`animDuration: 0`): flushes posted
    events and lets the animation driver tick `frames` times.
    """
    _spin(0)
    for _ in range(max(0, frames)):
        _spin(frame_ms)
