"""The reorderable lists of the settings editors (modules/settings/editors/
ReorderList.qml), offscreen in the real settings window:

* Dashboard tabs: the grip is a Tab stop; Up / Down move the tab, one undo
  step each; the move arrows show while the grip has the keyboard focus.
* Island activities: the focus stays on a row moved with the keys (rows
  are keyed, never rebuilt).
* Island activities (a scrolling card): dragging a row's grip reorders it,
  the card does not take the drag over to scroll.
* Launcher providers: the tabs after the inline providers do not move.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import headless  # noqa: E402

headless.ensure(gl=True)

from PySide6.QtCore import QPoint, Qt  # noqa: E402
from PySide6.QtQuick import QQuickWindow  # noqa: E402,F401
from PySide6.QtTest import QTest  # noqa: E402
from settings_env import SettingsEnv  # noqa: E402
from waits import wait_until  # noqa: E402

env = SettingsEnv("settings-reorder")
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
    width: 1180; height: 1500; visible: true
    function findItem(name, from) {
        var item = from || w.contentItem;
        if (item.objectName === name) return item;
        var kids = item.children || [];
        for (var i = 0; i < kids.length; i++) { var f = findItem(name, kids[i]); if (f) return f; }
        return null;
    }
    SettingsShell { objectName: "shell"; anchors.fill: parent }
}""")
shell = h.find(win, "shell")


def ev(expr):
    return h.eval(win, expr)


def item(name):
    return ev(f'w.findItem("{name}")')


def keys(list_name):
    return json.loads(h.eval(item(list_name), "JSON.stringify(parent.keys)"))


def centre(obj):
    p = h.eval(obj, "mapToItem(null, width / 2, height / 2)")
    return QPoint(int(p.x()), int(p.y()))


# ---- Dashboard tabs: the keyboard ---------------------------------------------
h.eval(shell, 'select("dashboard")')
check(env.wait_page(win), "dashboard: page built")
check(wait_until(lambda: item("dashboardTabList") is not None), "dashboard: the tab list is a ReorderList")
tabs = keys("dashboardTabList")
first = tabs[0]
grip = item(f"dashboardTabHandle:{first}")
# the live dashboard on the stage focuses its own first control once it is up
check(wait_until(lambda: h.eval(item("dashboardLive"), "ready") is True, timeout_ms=10000), "dashboard: the live stage is up")
QTest.qWait(500)
check(h.eval(grip, "activeFocusOnTab") is True, "the grip is a Tab stop")
check(h.eval(item(f"dashboardTabMove:{first}:down"), "visible") is False, "the move arrows are hidden at rest")
h.eval(grip, "forceActiveFocus()")
QTest.qWait(200)
check(ev("w.activeFocusItem === w.findItem('dashboardTabHandle:" + first + "')"), "the grip has the focus")
check(h.eval(item(f"dashboardTabMove:{first}:down"), "visible") is True, "...and show while the grip has the keyboard focus")
n = ev("SettingsStore.undoStack.length")
QTest.keyClick(win, Qt.Key_Down)
QTest.qWait(50)
check(keys("dashboardTabList")[1] == first, f"Down moves the tab one place ({keys('dashboardTabList')[:3]})")
check(ev("SettingsStore.undoStack.length") == n + 1, "...as one undo step")
ev("SettingsStore.undo()")
check(keys("dashboardTabList") == tabs, "undo puts it back")
h.eval(item(f"dashboardTabMove:{tabs[1]}:up"), "clicked()")
check(keys("dashboardTabList")[0] == tabs[1], "an arrow button moves a tab too")
ev("SettingsStore.undo()")

# ---- Launcher: only the inline providers move ---------------------------------
h.eval(shell, 'select("launcher")')
check(env.wait_page(win), "launcher: page built")
check(wait_until(lambda: item("launcherList") is not None), "launcher: the provider list is a ReorderList")
lk = keys("launcherList")
movable = h.eval(item("launcherList"), "parent.movable")
check(0 < movable < len(lk), f"inline providers move, the tabs after them do not ({movable} of {len(lk)})")
check(h.eval(item(f"launcherHandle:{lk[-1]}"), "activeFocusOnTab") is False, "a tab row has no grip stop")
h.eval(item(f"launcherHandle:{lk[movable - 1]}"), "forceActiveFocus()")
QTest.keyClick(win, Qt.Key_Down)
QTest.qWait(50)
check(keys("launcherList") == lk, "the last provider does not move into the tabs")

# ---- Island activities: drag in a scrolling card ------------------------------
h.eval(shell, 'select("notch")')
check(env.wait_page(win), "island: page built")
check(wait_until(lambda: item("activityList") is not None), "island: the activities are a ReorderList")
ak = keys("activityList")
row_h = h.eval(item("activityList"), "parent.rowHeight")
handle = item(f"activityHandle:{ak[0]}")
a = centre(handle)
QTest.mouseMove(win, a)
QTest.mousePress(win, Qt.LeftButton, Qt.NoModifier, a)
for i in range(1, 11):
    QTest.mouseMove(win, QPoint(a.x(), a.y() + int(row_h * 2.2 * i / 10)))
    QTest.qWait(16)
check(h.eval(item("activityList"), "contentY") == 0, "the card does not scroll while the grip is dragged")
QTest.mouseRelease(win, Qt.LeftButton, Qt.NoModifier, QPoint(a.x(), a.y() + int(row_h * 2.2)))
QTest.qWait(50)
now = keys("activityList")
check(now.index(ak[0]) == 2, f"dragging a grip two rows down moves the activity there ({now[:4]})")
stored = [e["id"] for e in json.loads(ev("JSON.stringify(Config.notch.activities)"))]
check(stored[:3] == now[:3], "...and stores the order")
ev("SettingsStore.undo()")
QTest.qWait(100)

# the keyboard on the island list: the focus stays on the moved row
ak = keys("activityList")
grip = item(f"activityHandle:{ak[1]}")
h.eval(grip, "forceActiveFocus()")
QTest.qWait(100)
QTest.keyClick(win, Qt.Key_Down)
QTest.qWait(50)
check(keys("activityList")[2] == ak[1], f"Down moves the activity one place ({keys('activityList')[:4]})")
check(h.eval(item(f"activityHandle:{ak[1]}"), "activeFocus") is True, "the focus stays on the moved row")
QTest.keyClick(win, Qt.Key_Down)
QTest.qWait(50)
check(keys("activityList")[3] == ak[1], "a second Down moves it again")
QTest.keyClick(win, Qt.Key_Up)
QTest.keyClick(win, Qt.Key_Up)
QTest.qWait(50)
check(keys("activityList") == ak, "Up twice puts it back")
check(h.eval(item(f"activityMove:{ak[1]}:up"), "visible") is True, "the arrows show beside the focused grip")

if failures:
    print(f"settings-reorder: {len(failures)} failure(s)")
    h.exit(1)
print("settings-reorder: ok")
h.exit(0)
