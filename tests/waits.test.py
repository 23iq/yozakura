#!/usr/bin/env python3
"""tests/lib/waits.py: pump runs the loop, wait_until returns on the state, settle flushes."""
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402
from lib.waits import pump, settle, wait_until  # noqa: E402

h = Harness("waits")
root = h.load("""
import QtQuick
Item {
    property int ticks: 0
    property bool later: false
    property real x2: 0
    Behavior on x2 { NumberAnimation { duration: 0 } }
    Timer { id: t; interval: 30; repeat: true; running: true; onTriggered: parent.ticks++ }
    Component.onCompleted: Qt.callLater(() => later = true)
}
""")

failures = []


def check(cond, msg):
    if not cond:
        failures.append(msg)
        print("FAIL:", msg)


# settle flushes Qt.callLater and finishes a zero-length animation.
h.eval(root, "x2 = 40")
settle()
check(h.eval(root, "later") is True, "settle ran Qt.callLater")
check(h.eval(root, "x2") == 40, "settle finished a 0 ms Behavior")

# pump lets a timer fire; it waits about as long as asked.
t0 = time.monotonic()
pump(200)
dt = (time.monotonic() - t0) * 1000
check(190 <= dt < 1500, f"pump(200) took {dt:.0f} ms")
check(h.eval(root, "ticks") >= 2, f"timer ran during pump ({h.eval(root, 'ticks')} ticks)")

# wait_until returns as soon as the state holds, and at once when it already does.
start = h.eval(root, "ticks")
t0 = time.monotonic()
check(wait_until(lambda: h.eval(root, "ticks") >= start + 2), "wait_until saw the timer")
dt = (time.monotonic() - t0) * 1000
check(dt < 1000, f"wait_until returned early ({dt:.0f} ms)")
t0 = time.monotonic()
check(wait_until(lambda: True, timeout_ms=5000), "true predicate")
check(time.monotonic() - t0 < 0.05, "true predicate costs nothing")

# ...and gives up with False after the timeout.
t0 = time.monotonic()
check(wait_until(lambda: False, timeout_ms=120) is False, "false predicate times out")
dt = (time.monotonic() - t0) * 1000
check(110 <= dt < 1500, f"timeout honoured ({dt:.0f} ms)")

print("waits: FAIL" if failures else "waits: ok")
sys.exit(1 if failures else 0)
