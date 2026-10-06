"""Bar clock faces, Pomodoro indicators and the clock panel
(modules/bar/clock/{ClockFace,PomodoroIndicator,ClockPanel}.qml), offscreen.

A vertical bar draws digital as stacked; kanji reads 十時 二十五分; every
Pomodoro style shows the phase progress (island leaves the bar empty); the
panel lays out the default bento cards (weather, pomodoro, agenda, world
clocks) with the real time widgets, and saving the grid writes a copy of
bar.moduleOptions.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib import timers_stubs  # noqa: E402
from lib.qmlharness import Harness  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

h = Harness("clock-panel")
h.singleton("qs.config", "Config", """QtObject {
    property int animDuration: 0
    property QtObject theme: QtObject { property string font: "Sans"; property string monoFont: "Mono"; property int fontSize: 14 }
    property QtObject bar: QtObject {
        property bool use12hFormat: false
        property var moduleOptions: ({ "clock": { "face": "digital" }, "worldClocks": { "zones": [{ "label": "Tokyo", "zone": "Asia/Tokyo" }] } })
    }
    property QtObject system: QtObject {
        property var pomodoro: ({ "workTime": 1500, "restTime": 300, "autoStart": false, "syncSpotify": false })
    }
}""")
TOKEN = "QtObject { property int duration: 0; property int easing: 0 }"
h.singleton("qs.modules.theme", "Motion", f"""QtObject {{
    property QtObject enter: {TOKEN}
    property QtObject exit: {TOKEN}
    property QtObject morph: {TOKEN}
    property QtObject emphasis: {TOKEN}
}}""")
h.singleton("qs.modules.theme", "Metrics", """QtObject {
    property int bentoCell: 132; property int spacing: 8; property int padding: 16
    property int rowHeight: 48; property int badgeHeight: 22; property int iconSize: 32
}""")
h.singleton("qs.modules.theme", "Colors", """QtObject {
    property color overBackground: "white"; property color primary: "pink"; property color tertiary: "gold"
    property color error: "red"; property color outline: "gray"; property color overSurface: "white"
}""")
h.singleton("qs.modules.theme", "Styling", """QtObject {
    function radius(n) { return 8 }
    function fontSize(n) { return 14 + n }
    function srItem(v) { return "black" }
}""")
icons = " ".join(f'property string {n}: "{n}";' for n in [
    "plus", "cancel", "check", "arrowCounterClockwise", "arrowsOutSimple", "sun", "pencil", "clock",
    "countdown", "globe", "listChecks", "calendar", "alarm", "timer", "thermometer"])
h.singleton("qs.modules.theme", "Icons", f'QtObject {{ property string font: "Sans"; {icons} }}')
h.module("qs.modules.services", {
    **timers_stubs.services(),
    "I18n": "pragma Singleton\nQtObject { function t(k) { return k } }",
    "WeatherService": "pragma Singleton\nQtObject { property bool debugMode: false; property bool dataAvailable: false }",
})
h.module("qs.modules.components", {
    "StyledRect": 'Rectangle { property string variant; property bool enableShadow; property real backgroundOpacity: -1; property color item: "white" }',
    "StyledToolTip": "Item { property string tooltipText }",
    "StyledSlider": "Item { property string icon; property real value; property string tooltipText }",
})
h.module("Quickshell.Io", {
    "Process": "QtObject { property var command; property bool running; property QtObject stdout }",
    "StdioCollector": "QtObject { property string text; signal streamFinished }",
})
W = "modules/widgets/dashboard/widgets"
h.copy(f"{W}/BentoView.qml", dest=W)
for name in ("PomodoroWidget", "WorldClocksWidget", "AgendaWidget"):
    h.copy(f"{W}/time/{name}.qml", dest=f"{W}/time")
h.stub("Calendar", "Item {}", dest=f"{W}/calendar")
h.stub("WeatherWidget", 'Item { objectName: "weatherStub"; property real cellW; property real cellH; property bool compact }', dest=W)
for f in ("ClockPanel.qml", "ClockFace.qml", "PomodoroIndicator.qml"):
    h.copy(f"modules/bar/clock/{f}", dest="modules/bar/clock")
for f in ("faces/Digital.qml", "faces/Stacked.qml", "faces/DotMatrix.qml", "faces/Kanji.qml",
          "indicators/Ring.qml", "indicators/Underline.qml", "indicators/Countdown.qml"):
    h.copy(f"modules/bar/clock/{f}", dest="modules/bar/clock/" + f.split("/")[0])

POMO = {"id": "p", "leftMs": 754000, "progress": 0.5, "state": "running", "ringing": False, "pomodoro": {"phase": "work", "round": 1}}

scene = h.write(f"""
import QtQuick
import QtQuick.Window
import qs.config
import qs.modules.services
import "modules/bar/clock"
Window {{
    id: win
    width: 600; height: 900; visible: true
    function findItem(name, from) {{
        var item = from || win.contentItem;
        if (item.objectName === name) return item;
        var kids = item.children || [];
        for (var i = 0; i < kids.length; i++) {{ var f = findItem(name, kids[i]); if (f) return f; }}
        return null;
    }}
    function count(name, from) {{
        var item = from || win.contentItem, n = item.objectName === name ? 1 : 0;
        var kids = item.children || [];
        for (var i = 0; i < kids.length; i++) n += count(name, kids[i]);
        return n;
    }}
    Row {{
        ClockFace {{ objectName: "hFace"; face: "digital"; now: new Date(2026, 9, 6, 10, 25) }}
        ClockFace {{ objectName: "vFace"; face: "digital"; vertical: true; now: new Date(2026, 9, 6, 10, 25) }}
        ClockFace {{ objectName: "kFace"; face: "kanji"; now: new Date(2026, 9, 6, 10, 25) }}
        ClockFace {{ objectName: "dFace"; face: "dotMatrix"; now: new Date(2026, 9, 6, 10, 25) }}
        Item {{ width: 120; height: 36; PomodoroIndicator {{ objectName: "ring"; style: "ring"; pomodoro: {json.dumps(POMO)} }} }}
        Item {{ width: 120; height: 36; PomodoroIndicator {{ objectName: "underline"; anchors.fill: parent; slot: "overlay"; style: "underline"; pomodoro: {json.dumps(POMO)} }} }}
        Item {{ width: 120; height: 36; PomodoroIndicator {{ objectName: "countdown"; style: "countdown"; pomodoro: {json.dumps(POMO)} }} }}
        Item {{ width: 120; height: 36; PomodoroIndicator {{ objectName: "island"; style: "island"; pomodoro: {json.dumps(POMO)} }} }}
        Item {{ width: 120; height: 36; PomodoroIndicator {{ objectName: "idle"; style: "ring"; pomodoro: null }} }}
    }}
    ClockPanel {{ objectName: "panel"; y: 60; width: implicitWidth; height: implicitHeight; now: new Date(2026, 9, 6, 10, 25) }}
}}""", dest=".")
win = h.load(scene, auto_stub=False)
QTest.qWait(50)


def check(cond, what: str) -> None:
    if not cond:
        print("FAIL:", what, file=sys.stderr)
        sys.exit(1)


def item(name: str):
    found = h.eval(win, f"findItem('{name}')")
    check(found is not None, "item " + name)
    return found


# Faces: digital on a horizontal bar, stacked on a vertical one, kanji, dots.
check(h.eval(item("hFace"), "faceId") == "digital", "horizontal digital face")
check(h.eval(item("faceDigital"), "text") == "10:25", "digital text")
check(h.eval(item("vFace"), "faceId") == "stacked", "vertical bar uses stacked")
check(h.eval(win, "findItem('faceStacked', findItem('vFace')) !== null"), "stacked face loaded")
check(h.eval(item("faceKanji"), "text") == "十時 二十五分", "kanji 10:25")
check(h.eval(item("faceDotMatrix"), "implicitWidth") > 0, "dot matrix has a size")
for name in ("hFace", "vFace", "kFace", "dFace"):
    check(h.eval(item(name), "implicitWidth") > 0, name + " sized")

# Pomodoro styles: each shows the phase progress; island and idle show nothing.
check(abs(h.eval(item("pomodoroRing"), "progress") - 0.5) < 1e-6, "ring progress")
check(h.eval(item("ring"), "implicitWidth") > 0, "ring takes space inline")
fill = item("pomodoroUnderlineFill")
check(abs(h.eval(fill, "width") - (120 - 16) * 0.5) < 1, "underline fill is half the track")
check(h.eval(item("pomodoroCountdownText"), "text") == "12:34", "countdown label")
cw = h.eval(item("pomodoroCountdown"), "implicitWidth")
h.eval(item("countdown"), "pomodoro = Object.assign({}, pomodoro, { leftMs: 71000 })")
check(h.eval(item("pomodoroCountdownText"), "text") == "01:11", "countdown ticks")
check(h.eval(item("pomodoroCountdown"), "implicitWidth") == cw, "countdown width is stable")
check(not h.eval(item("island"), "visible") and h.eval(item("island"), "implicitWidth") == 0, "island leaves the bar empty")
check(not h.eval(item("idle"), "visible"), "no Pomodoro, no indicator")

# Panel: the default cards with the real time widgets.
panel = item("panel")
for wid in ("weather", "pomodoro", "agenda", "worldClocks"):
    check(h.eval(item("bentoTile_" + wid), "visible"), "default card " + wid)
check(h.eval(win, "count('bentoTile_calendar')") == 0 or not h.eval(item("bentoTile_calendar"), "visible"), "calendar not placed by default")
check(h.eval(item("pomodoroTime"), "text") == "25:00", "pomodoro widget idle shows the work length")
check(h.eval(item("agendaEmpty"), "visible"), "agenda empty state")
check(h.eval(item("clockPanelTime"), "text") == "10:25", "panel header time")
check(h.eval(item("clockPanelDate"), "text") == "calendar.day_full.tuesday, calendar.month.october 6", "panel header date")

# Agenda lists reminders and timers soonest first.
h.eval(panel, "TimersService.timers = [{ id: 't', name: 'Tea', leftMs: 60000, state: 'running', ringing: false }]")
h.eval(panel, "TimersService.reminders = [{ id: 'r', message: 'Call', at: TimersService.now + 600000, leftMs: 600000 }]")
QTest.qWait(20)
check(h.eval(win, "count('agendaRow')") == 2, "agenda rows")
check(not h.eval(item("agendaEmpty"), "visible"), "agenda not empty")

# Saving the grid writes a copy of moduleOptions (other options kept).
h.eval(panel, "editing = true")
QTest.qWait(20)
h.eval(item("clockPanelBento"), "addWidget('calendar')")
h.eval(panel, "editing = false")
QTest.qWait(20)
opts = json.loads(h.eval(panel, "JSON.stringify(Config.bar.moduleOptions)"))
check(opts["clock"]["face"] == "digital" and len(opts["clock"]["panel"]["cells"]) == 5, "cells saved into moduleOptions")
check(opts["worldClocks"]["zones"][0]["zone"] == "Asia/Tokyo", "other options kept")

print("clock-panel: ok")
h.exit(0)
