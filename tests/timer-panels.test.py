"""Timer notch panels offscreen (real files, stubbed TimersService /
FocusMode / QuickNote from tests/lib/timers_stubs.py):

* TimerHubPanel + QuickInputField: live preview from timers.parse while
  typing, Enter runs timers.quick and closes the hub; "focus 30" starts
  focus mode; note mode appends to the notes inbox; errors are shown.
* TimerPanel + TimerList rows: timers, stopwatch, reminders, buttons.
* AlarmPanel: ringing timers, Stop / +5 min.
Set TIMER_RENDER_DIR=<dir> to keep PNGs of the panels.
"""
import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import REPO, Harness  # noqa: E402
from lib import timers_stubs  # noqa: E402
from PySide6.QtCore import Qt  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402
from PySide6.QtQuick import QQuickItem  # noqa: E402
import shiboken6  # noqa: E402

ok_all = True


def check(name, ok, detail=""):
    global ok_all
    ok_all &= bool(ok)
    print(("PASS " if ok else "FAIL ") + name + (" " + str(detail) if detail else ""))


h = Harness("timer-panels")
EN = json.loads((REPO / "translations/en.json").read_text())
h.singleton("qs.config", "Config", """QtObject {
    property int animDuration: 0
    property var theme: ({ font: "Sans", monoFont: "Monospace", fontSize: 14 })
    property var system: ({ timers: { pulseOnFinish: true } })
}""")
h.module("qs.modules.theme", {
    "Styling": "pragma Singleton\nQtObject { function fontSize(o) { return 14 + o } function radius(o) { return 12 + o } function srItem(v) { return 'white' } }",
    "Colors": "pragma Singleton\nQtObject { property color overBackground: 'white'; property color overSurfaceVariant: 'silver'; property color primary: 'pink'; property color overPrimary: 'black'; property color secondary: 'plum'; property color outline: 'gray'; property color error: 'red'; property color red: 'red' }",
    "Icons": "pragma Singleton\nQtObject { property string font: 'Sans'; property string timer: 'T'; property string alarm: 'A'; property string countdown: 'C'; property string watch: 'W'; property string notePencil: 'N'; property string brain: 'B'; property string plus: '+'; property string pause: 'p'; property string play: 'P'; property string stop: 'S'; property string cancel: 'x'; property string arrowCounterClockwise: 'r'; property string clockCounterClockwise: 'z'; property string listChecks: 'L'; property string warning: '!'; property string info: 'i' }",
})
h.module("qs.modules.components", {
    "StyledRect": "Rectangle { property string variant; property bool enableBorder; property bool enableShadow; property color item: 'white' }",
    "StyledToolTip": "Item { property string tooltipText; property bool show }",
})
h.module("Quickshell.Widgets", {"IconImage": "Image { property real implicitSize }"})
h.module("qs.modules.services", {
    "I18n": "pragma Singleton\nQtObject { property var strings: (" + json.dumps(EN) + ")\n"
            "  function t(k) { var s = strings[k] || k; for (var i = 1; i < arguments.length; i++) s = s.replace('%' + i, arguments[i]); return s; } }",
    **timers_stubs.services(),
})
h.module("qs.modules.bar.activities", {n: (REPO / f"modules/bar/activities/{n}.qml").read_text() for n in ["ActivityIndicator", "ActivityRing"]})
h.module("qs.modules.widgets.defaultview.activities", {"NotchIconButton": (REPO / "modules/widgets/defaultview/activities/NotchIconButton.qml").read_text()})
panels = "qs/modules/widgets/defaultview/panels"
for n in ["TimerHubPanel", "TimerPanel", "AlarmPanel"]:
    h.copy(f"modules/widgets/defaultview/panels/{n}.qml", dest=panels)

# QtQuick.Controls up front (ScrollIndicator in TimerList), see notch-activities
h.load("import QtQuick\nimport QtQuick.Controls\nItem { ScrollIndicator {} }")
win = h.load(f"""
import QtQuick
import QtQuick.Window
import qs.modules.services
import "../{panels}"
Window {{
    width: 520; height: 900; visible: true; color: "#202020"
    Column {{
        width: 460
        spacing: 8
        TimerHubPanel {{ objectName: "hub"; width: 460; height: implicitHeight; maxRows: 5 }}
        TimerPanel {{ objectName: "panel"; width: 460; height: implicitHeight; maxRows: 5 }}
        AlarmPanel {{ objectName: "alarm"; width: 460; height: implicitHeight }}
    }}
}}
""")
hub = h.find(win, "hub")
inp = h.find(win, "quickInput")


def ev(expr, obj=None):
    return h.eval(obj or win, expr)


def calls():
    return json.loads(ev("JSON.stringify(TimersService.calls)"))


def preview():
    return h.eval(h.find(win, "quickPreviewText"), "text")


ev("TimersService.intents = ({ '10m tea': { kind: 'timer', seconds: 600, name: 'tea', label: 'Timer 10m: tea' }, 'sw': { kind: 'stopwatch' } })")
ev("TimersService.hubOpen = true")
check("hint while empty", preview() == EN["timers.input.examples"])
h.eval(inp, "forceActiveFocus()")
h.eval(inp, "text = '10m tea'")
QTest.qWait(200)
check("live preview of the parsed intent", preview() == "Timer 10m · tea", preview())
QTest.keyClick(win, Qt.Key_Return)
QTest.qWait(10)
c = calls()
check("Enter runs timers.quick", {"method": "quick", "params": {"text": "10m tea"}} in c, c)
check("then closes the hub and clears", c[-1]["method"] == "closeHub" and h.eval(inp, "text") == "")

h.eval(inp, "text = 'zzz'")
QTest.qWait(200)
check("parse errors are shown", preview() == "not a time", preview())
ev("TimersService.quickError = ({ message: 'no such time' })")
QTest.keyClick(win, Qt.Key_Return)
QTest.qWait(10)
check("a failed start stays open with the error", preview() == "no such time" and h.eval(inp, "text") == "zzz", preview())
ev("TimersService.quickError = null")

h.eval(inp, "text = 'focus 30'")
QTest.qWait(10)
check("focus preview", preview() == EN["focus.start_for"].replace("%1", "30"), preview())
QTest.keyClick(win, Qt.Key_Return)
check("focus 30 starts focus mode", json.loads(ev("JSON.stringify(FocusMode.calls)")) == [["start", 30]])

ev("TimersService.hubMode = 'note'")
QTest.qWait(10)
check("note mode", h.eval(hub, "noteMode") is True)
h.eval(inp, "text = 'buy milk'")
QTest.qWait(10)
check("note preview", preview() == EN["quicknote.add_to"].replace("%1", "Inbox"), preview())
QTest.keyClick(win, Qt.Key_Return)
check("note mode appends to the inbox", json.loads(ev("JSON.stringify(QuickNote.added)")) == ["buy milk"])
ev("TimersService.hubMode = 'timer'")
h.eval(inp, "text = 'note call bob'")
QTest.qWait(10)
QTest.keyClick(win, Qt.Key_Return)
check("'note …' in timer mode is a note too", json.loads(ev("JSON.stringify(QuickNote.added)")) == ["buy milk", "call bob"])

# ── lists ──
check("empty list hint", h.eval(h.find(h.find(win, "panel"), "timerListEmpty"), "visible") is True)
ev("""TimersService.timers = [
    { id: 't1', name: 'tea', state: 'running', ringing: false, running: true, leftMs: 65000, totalMs: 130000, progress: 0.5, createdAt: 1 },
    { id: 't2', name: '', state: 'paused', ringing: false, leftMs: 30000, totalMs: 60000, progress: 0.5, createdAt: 2, pomodoro: { phase: 'break', round: 2 } }
]""")
ev("TimersService.stopwatch = ({ state: 'running', startedAt: Date.now() - 5000, laps: [{ n: 1, splitMs: 2000, totalMs: 2000 }] })")
ev("TimersService.stopwatchActive = true")
ev("TimersService.stopwatchMs = 5000")
ev("TimersService.reminders = [{ id: 'r1', message: 'call mom', at: Date.now() + 600000, leftMs: 600000 }]")
QTest.qWait(50)
panel = h.find(win, "panel")


def items(item, name):
    """Visual descendants named `name` (list delegates are not QObject children)."""
    if not isinstance(item, QQuickItem):
        item = shiboken6.wrapInstance(shiboken6.getCppPointer(item)[0], QQuickItem)
    out = [item] if item.objectName() == name else []
    for child in item.childItems():
        out += items(child, name)
    return out


def item(root_item, name):
    found = items(root_item, name)
    assert found, f"no item {name!r}"
    return found[0]


check("a toggle button per timer row (both lists)", len(items(hub, "timerToggle") + items(panel, "timerToggle")) == 4)
ev("TimersService.calls = []")
for name in ["timerToggle", "timerPlus", "timerReset", "timerCancel", "stopwatchLap", "stopwatchToggle", "stopwatchReset", "reminderCancel"]:
    h.eval(item(panel, name), "clicked()")
got = [(c["method"], c["params"]) for c in calls()]
check("row buttons call the service", got == [
    ("toggle", {"id": "t1"}), ("add", {"id": "t1", "spec": "+1m"}), ("reset", {"id": "t1"}), ("cancel", {"id": "t1"}),
    ("stopwatch", {"action": "lap"}), ("stopwatch", {"action": "toggle"}), ("stopwatch", {"action": "reset"}),
    ("reminderCancel", {"id": "r1"})], got)
check("stopwatch elapsed shown", h.eval(item(panel, "stopwatchElapsed"), "text") == "00:05")
h.eval(h.find(panel, "focusToggle"), "clicked()")
check("focus button toggles focus mode", json.loads(ev("JSON.stringify(FocusMode.calls)"))[-1] == ["toggle", 0])
h.eval(h.find(panel, "timerNew"), "clicked()")
check("+ opens the hub input", calls()[-1]["method"] == "openHub")

# ── alarm ──
ev("TimersService.timers = [{ id: 't1', name: 'tea', state: 'ringing', ringing: true, leftMs: 0, totalMs: 60000, progress: 0, createdAt: 1 }]")
QTest.qWait(20)
alarm = h.find(win, "alarm")
check("alarm names what finished", h.eval(h.find(alarm, "alarmNames"), "text") == "tea")
ev("TimersService.calls = []")
h.eval(h.find(alarm, "alarmSnooze"), "clicked()")
h.eval(h.find(alarm, "alarmStop"), "clicked()")
check("+5 min snoozes, Stop dismisses", [(c["method"], c["params"]) for c in calls()] == [("add", {"id": "t1", "spec": "5m"}), ("dismiss", {"id": "t1"})])
ev("TimersService.timers = TimersService.timers.concat([{ id: 't3', name: '', state: 'ringing', ringing: true, leftMs: 0, totalMs: 1, createdAt: 3 }])")
QTest.qWait(10)
ev("TimersService.calls = []")
h.eval(h.find(alarm, "alarmStop"), "clicked()")
check("several ringing: Stop stops all", calls() == [{"method": "dismiss", "params": {"id": ""}}])

out = os.environ.get("TIMER_RENDER_DIR")
if out:
    Path(out).mkdir(parents=True, exist_ok=True)
    win.grabWindow().save(str(Path(out) / "timer-panels.png"))

print("timer panels: quick input, lists, buttons and alarm " + ("passed" if ok_all else "FAILED"))
sys.exit(0 if ok_all else 1)
