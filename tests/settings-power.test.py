"""The Power page (modules/settings/stages/PowerStage.qml, editors/IdleTimeline.qml),
offscreen with the device fixtures (tests/lib/device_fixtures.py).

* The stage shows the battery charge and the current profile; a click on a
  profile tile switches it through PowerProfileClient.
* The idle timeline: dragging the Sleep knob changes its listener's timeout
  as ONE undo step on release (nothing is written mid-drag); dragging it
  into "never" removes the listener; the order dim -> lock -> off -> sleep
  holds (Lock cannot pass Screen off).
* The sleep switches write / clear the sleep commands.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import headless  # noqa: E402

headless.ensure(gl=True)

from PySide6.QtCore import QPoint, Qt  # noqa: E402
from PySide6.QtQuick import QQuickWindow  # noqa: E402,F401
from PySide6.QtTest import QTest  # noqa: E402
from settings_env import SettingsEnv  # noqa: E402

env = SettingsEnv("settings-power", devices=True)
h = env.h
failures: list[str] = []


def check(ok, what):
    print(("PASS " if ok else "FAIL ") + what)
    if not ok:
        failures.append(what)


win = env.load("""
import QtQuick
import QtQuick.Window
import qs.config
import qs.modules.services
import qs.modules.settings
import qs.modules.settings.store
Window {
    id: w
    width: 1180; height: 780; visible: true
    function findItem(name, from) {
        var item = from || w.contentItem;
        if (item.objectName === name) return item;
        var kids = item.children || [];
        for (var i = 0; i < kids.length; i++) { var f = findItem(name, kids[i]); if (f) return f; }
        return null;
    }
    function timeouts() { return JSON.stringify(Config.system.idle.listeners.map(l => [l.onTimeout, l.timeout])) }
    SettingsShell { objectName: "shell"; anchors.fill: parent }
}""")
shell = h.find(win, "shell")


def ev(expr):
    return h.eval(win, expr)


def centre(name):
    item = ev(f'w.findItem("{name}")')
    p = h.eval(item, "mapToItem(null, width / 2, height / 2)")
    return QPoint(int(p.x()), int(p.y()))


def drag(name, dx, check_mid=None):
    a = centre(name)
    QTest.mouseMove(win, a)
    QTest.mousePress(win, Qt.LeftButton, Qt.NoModifier, a)
    for i in range(1, 9):
        QTest.mouseMove(win, QPoint(a.x() + dx * i // 8, a.y()))
        QTest.qWait(16)
    if check_mid:
        check_mid()
    QTest.mouseRelease(win, Qt.LeftButton, Qt.NoModifier, QPoint(a.x() + dx, a.y()))
    QTest.qWait(50)


def sleep_timeout():
    for cmd, t in __import__("json").loads(ev("w.timeouts()")):
        if "suspend" in cmd:
            return t
    return None


h.eval(shell, 'select("power")')
check(env.wait_page(win), "power: page built")
QTest.qWait(300)
check(ev('w.findItem("powerPercent").text') == "76%", "the stage shows the battery charge")
check(ev('w.findItem("powerProfile:balanced").active') is True, "...and the current profile lit")
h.eval(ev('w.findItem("powerProfile:performance")'), "clicked()")
check(ev("PowerProfileClient.calls.indexOf('performance') >= 0"), "a profile tile switches the profile")
check(ev('w.findItem("powerProfile:performance").active') is True, "...and lights at once")

# idle timeline: Sleep left by ~60 px -> an earlier time, one step on release
steps = ev("SettingsStore.undoStack.length")
t0 = sleep_timeout()
drag("idleKnob:sleep", -60, lambda: check(sleep_timeout() == t0, "nothing is written mid-drag"))
t1 = sleep_timeout()
check(t1 is not None and t1 < t0, f"dragging Sleep left makes it sooner ({t0} -> {t1})")
check(ev("SettingsStore.undoStack.length") == steps + 1, "...as one undo step")
check(ev('w.findItem("idleTime:sleep").text') != "", "the legend shows its time")
ev("SettingsStore.undo()")
check(sleep_timeout() == t0, "one undo puts it back")

# into never: the listener goes
drag("idleKnob:sleep", 600)
check(sleep_timeout() is None, "dragging Sleep to the end removes it (never)")
check(ev('w.findItem("idleTime:sleep").text') == "Never", "...and the legend says Never")
ev("SettingsStore.undo()")

# Lock cannot pass Screen off
drag("idleKnob:lock", 300)
lock = [t for c, t in __import__("json").loads(ev("w.timeouts()")) if "lock" in c][0]
off = [t for c, t in __import__("json").loads(ev("w.timeouts()")) if "screen off" in c][0]
check(lock <= off, f"Lock stays before Screen off ({lock} <= {off})")

# sleep switches
h.eval(ev('w.findItem("sleepToggle:system.idle.general.before_sleep_cmd")'), "toggled(false)")
check(ev("Config.system.idle.general.before_sleep_cmd") == "", "Lock before sleep off clears the command")
h.eval(ev('w.findItem("sleepToggle:system.idle.general.before_sleep_cmd")'), "toggled(true)")
check(ev("Config.system.idle.general.before_sleep_cmd") == "loginctl lock-session", "...on writes the default")

if failures:
    print(f"settings-power: {len(failures)} failure(s)")
    h.exit(1)
print("settings-power: ok")
h.exit(0)
