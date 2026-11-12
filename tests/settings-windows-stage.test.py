"""The Windows page (modules/settings/stages/WindowsStage.qml), offscreen.

* The stage tiles the windows from the live values: a gap change moves them.
* Direct manipulation: dragging the gap grip changes compositor.gapsIn, the
  edge grip compositor.gapsOut, the corner knob compositor.rounding (and
  stops following the shell's roundness); each drag is ONE undo step and
  one undo puts every key it wrote back.
* The row's pickers: a corner step and a border width are one step each.
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

env = SettingsEnv("settings-windows-stage")
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
    SettingsShell { objectName: "shell"; anchors.fill: parent }
}""")
shell = h.find(win, "shell")


def ev(expr):
    return h.eval(win, expr)


def centre(name):
    item = ev(f'w.findItem("{name}")')
    p = h.eval(item, "mapToItem(null, width / 2, height / 2)")
    return QPoint(int(p.x()), int(p.y()))


def drag(name, dx, dy):
    a = centre(name)
    QTest.mouseMove(win, a)
    QTest.mousePress(win, Qt.LeftButton, Qt.NoModifier, a)
    for i in range(1, 7):
        QTest.mouseMove(win, QPoint(a.x() + dx * i // 6, a.y() + dy * i // 6))
        QTest.qWait(16)
    QTest.mouseRelease(win, Qt.LeftButton, Qt.NoModifier, QPoint(a.x() + dx, a.y() + dy))
    QTest.qWait(50)


h.eval(shell, 'select("windows")')
check(env.wait_page(win), "windows: page built")
QTest.qWait(300)
check(ev('w.findItem("windowsStage") !== null'), "the page has the windows stage")
area = ev('w.findItem("windowsArea")')
first = lambda: h.eval(area, "children.filter(c => c.objectName === 'stageWindow')[0].x")  # noqa: E731
x0 = first()
ev("SettingsStore.set('compositor.gapsOut', 20)")
QTest.qWait(400)
check(first() > x0 + 10, f"the stage follows the edge gap ({x0} -> {first()})")
ev("SettingsStore.set('compositor.gapsOut', 4)")
QTest.qWait(300)

# the gap grip: a drag of 20 px widens the gap by 10 px per side, one step
steps = ev("SettingsStore.undoStack.length")
before = ev("Config.compositor.gapsIn")
drag("windowsGapGripArea", 20, 0)
check(ev("Config.compositor.gapsIn") == before + 10, f"the gap grip sets gapsIn ({before} -> {ev('Config.compositor.gapsIn')})")
check(ev("SettingsStore.undoStack.length") == steps + 1, "...as one undo step")
ev("SettingsStore.undo()")
check(ev("Config.compositor.gapsIn") == before, "one undo puts the gap back")

# the edge grip
drag("windowsEdgeGripArea", 16, 0)
check(ev("Config.compositor.gapsOut") == 20, f"the edge grip sets gapsOut ({ev('Config.compositor.gapsOut')})")
ev("SettingsStore.undo()")

# the corner knob: rounding + no longer the shell's, one step
check(ev("Config.compositor.syncRoundness") is True, "windows follow the shell's roundness by default")
steps = ev("SettingsStore.undoStack.length")
drag("windowsCornerGripArea", 10, -10)
check(ev("Config.compositor.syncRoundness") is False, "the corner knob stops following the shell")
check(ev("Config.compositor.rounding") == 26, f"...and sets the rounding (16 + 10 = {ev('Config.compositor.rounding')})")
check(ev("SettingsStore.undoStack.length") == steps + 1, "...as one undo step")
ev("SettingsStore.undo()")
check(ev("Config.compositor.syncRoundness") is True and ev("Config.compositor.rounding") == 16, "one undo puts both back")

# the row pickers
h.eval(ev('w.findItem("cornerStep:8")'), "clicked()")
check(ev("Config.compositor.rounding") == 8 and ev("Config.compositor.syncRoundness") is False, "a corner step sets the rounding")
h.eval(ev('w.findItem("cornersFollowShell")'), "clicked()")
check(ev("Config.compositor.syncRoundness") is True, "Like the shell follows the shell again")
steps = ev("SettingsStore.undoStack.length")
h.eval(ev('w.findItem("borderWidth:5")'), "clicked()")
check(ev("Config.compositor.borderSize") == 5, "a border width tile sets the width")
check(ev("SettingsStore.undoStack.length") == steps + 1, "...as one undo step")

if failures:
    print(f"settings-windows-stage: {len(failures)} failure(s)")
    h.exit(1)
print("settings-windows-stage: ok")
h.exit(0)
