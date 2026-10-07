"""Bar clock faces, Pomodoro indicators and the clock popup
(modules/bar/clock/{ClockFace,PomodoroIndicator,ClockPanel*}.qml), offscreen
on the real kit (tests/lib/widgets_env.py).

A vertical bar draws digital as stacked; kanji reads 十時 二十五分; every
Pomodoro style shows the phase progress (island leaves the bar empty). The
popup follows bar.moduleOptions.clock.panelStyle: "column" (time, date,
weather details, the Pomodoro row with Start / Edit, world rows, the agenda
only when something is coming up), "wide" (kanji weekday, a large ring with
reset / main / skip, world clocks inline) and "bento" (the default cards
with the real time widgets; saving the grid writes a copy of
bar.moduleOptions).
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from widgets_env import POMODORO, WidgetsEnv  # noqa: E402  (first: enters the headless platform)
from PySide6.QtTest import QTest  # noqa: E402,I001

ZONES = [{"label": "Tokyo", "zone": "Asia/Tokyo"}]
env = WidgetsEnv("clock-panel", overrides={
    "theme": {"animDuration": 0},
    "bar": {"use12hFormat": False, "moduleOptions": {"clock": {"face": "digital", "panelStyle": "column"},
                                                     "worldClocks": {"zones": ZONES}}}})
h = env.h

scene = h.write(f"""
import QtQuick
import QtQuick.Window
import qs.config
import qs.modules.services
import "modules/bar/clock"
Window {{
    id: win
    width: 900; height: 1000; visible: true
    function findItem(name, from) {{
        var item = from || win.contentItem;
        if (item.objectName === name) return item;
        var kids = item.children || [];
        for (var i = 0; i < kids.length; i++) {{ var f = findItem(name, kids[i]); if (f) return f; }}
        return null;
    }}
    function count(name, from) {{
        var item = from || win.contentItem, n = item.objectName === name && item.visible ? 1 : 0;
        var kids = item.children || [];
        for (var i = 0; i < kids.length; i++) n += count(name, kids[i]);
        return n;
    }}
    Row {{
        ClockFace {{ objectName: "hFace"; face: "digital"; now: new Date(2026, 9, 6, 10, 25) }}
        ClockFace {{ objectName: "vFace"; face: "digital"; vertical: true; now: new Date(2026, 9, 6, 10, 25) }}
        ClockFace {{ objectName: "kFace"; face: "kanji"; now: new Date(2026, 9, 6, 10, 25) }}
        ClockFace {{ objectName: "dFace"; face: "dotMatrix"; now: new Date(2026, 9, 6, 10, 25) }}
        Item {{ width: 120; height: 36; PomodoroIndicator {{ objectName: "ring"; style: "ring"; pomodoro: {json.dumps(POMODORO)} }} }}
        Item {{ width: 120; height: 36; PomodoroIndicator {{ objectName: "underline"; anchors.fill: parent; slot: "overlay"; style: "underline"; pomodoro: {json.dumps(POMODORO)} }} }}
        Item {{ width: 120; height: 36; PomodoroIndicator {{ objectName: "countdown"; style: "countdown"; pomodoro: {json.dumps(POMODORO)} }} }}
        Item {{ width: 120; height: 36; PomodoroIndicator {{ objectName: "island"; style: "island"; pomodoro: {json.dumps(POMODORO)} }} }}
        Item {{ width: 120; height: 36; PomodoroIndicator {{ objectName: "idle"; style: "ring"; pomodoro: null }} }}
    }}
    ClockPanel {{ objectName: "panel"; y: 60; width: implicitWidth; height: implicitHeight; now: new Date(2026, 9, 6, 10, 25) }}
}}""", dest="qs", name="ClockScene.qml")
win = h.load(scene, auto_stub=False)
QTest.qWait(80)


def check(cond, what: str) -> None:
    if not cond:
        print("FAIL:", what, file=sys.stderr)
        sys.exit(1)


def item(name: str):
    found = h.eval(win, f"findItem('{name}')")
    check(found is not None, "item " + name)
    return found


def count(name: str) -> int:
    return h.eval(win, f"count('{name}')")


def style(name: str) -> None:
    h.eval(win, f"Config.bar.moduleOptions = Object.assign({{}}, Config.bar.moduleOptions, "
                f"{{ clock: Object.assign({{}}, Config.bar.moduleOptions.clock, {{ panelStyle: '{name}' }}) }})")
    QTest.qWait(60)


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

# Column (the default): header, details, Pomodoro row, world, agenda.
panel = item("panel")
check(h.eval(panel, "panelStyle") == "column", "column by default")
check(h.eval(item("clockPanelTime"), "text") == "10:25", "panel header time")
check(h.eval(item("clockPanelDate"), "text") == "Tuesday, October 6", "panel header date")
check(h.eval(item("clockPanelTemp"), "text") == "18°", "weather on the right")
check(h.eval(item("clockPanelDetails"), "text") == "H 21° · L 12° · Rain 40% · Wind 12 km/h", "weather details line")
check(h.eval(item("pomodoroTime"), "text") == "25:00", "idle Pomodoro shows the work length")
check(h.eval(item("pomodoroLabel"), "text") == "Focus · 1 of 4", "phase label")
check(h.eval(item("pomodoroMain"), "text") == "Start", "Start chip")
h.eval(item("pomodoroMain"), "clicked()")
calls = json.loads(h.eval(panel, "JSON.stringify(TimersService.calls)"))
check(calls[-1]["method"] == "pomodoro" and calls[-1]["params"]["work"] == 1500, "Start starts the Pomodoro")
check(h.eval(item("clockPanelWorld"), "visible") and count("worldClockTime") == 1, "world rows")
QTest.qWait(50)
check(h.eval(item("worldClockTime"), "text") != "--:--", "world time from the tz offset")
check(not h.eval(item("clockPanelAgenda"), "visible"), "agenda hidden when empty")
env.timers(panel, pomodoro=True)
QTest.qWait(30)
check(h.eval(item("clockPanelAgenda"), "visible") and count("agendaRow") == 2, "agenda with a timer and a reminder")
check(h.eval(item("pomodoroTime"), "text") == "12:34" and h.eval(item("pomodoroMain"), "text") == "Pause",
      "running Pomodoro: time left, Pause")

# Wide: kanji weekday, the ring's main button toggles.
style("wide")
check(h.eval(panel, "panelStyle") == "wide", "wide style")
check(h.eval(item("clockPanelKanji"), "text") == "火曜日", "kanji weekday")
check(h.eval(item("pomodoroTime"), "text") == "12:34", "wide ring time")
h.eval(item("pomodoroMain"), "clicked()")
calls = json.loads(h.eval(panel, "JSON.stringify(TimersService.calls)"))
check(calls[-1] == {"method": "toggle", "params": {"id": "p"}}, "pause toggles the Pomodoro")
check(h.eval(item("clockPanelWorld"), "visible"), "wide world clocks")

# Bento: missing saved layout uses default cards, edited into moduleOptions.
h.eval(win, "var opts = JSON.parse(JSON.stringify(Config.bar.moduleOptions)); delete opts.clock.panel; Config.bar.moduleOptions = opts")
style("bento")
check(h.eval(panel, "panelStyle") == "bento", "bento style")
for wid in ("weather", "pomodoro", "agenda", "worldClocks"):
    check(h.eval(item("bentoTile_" + wid), "visible"), "default card " + wid)
check(count("bentoTile_calendar") == 0, "calendar not placed by default")
check(h.eval(item("weatherTemp"), "text") == "18°", "weather widget")
h.eval(item("clockPanelEdit"), "clicked()")
QTest.qWait(20)
h.eval(item("clockPanelBento"), "addWidget('calendar')")
h.eval(item("clockPanelEdit"), "clicked()")
QTest.qWait(20)
opts = json.loads(h.eval(panel, "JSON.stringify(Config.bar.moduleOptions)"))
check(opts["clock"]["face"] == "digital" and len(opts["clock"]["panel"]["cells"]) == 5, "cells saved into moduleOptions")
check(opts["clock"]["panelStyle"] == "bento" and opts["worldClocks"]["zones"][0]["zone"] == "Asia/Tokyo", "other options kept")

# Removing every clock tile is an intentional empty grid, including after
# rebuilding the popup. Adding from it must not restore the defaults.
bento = item("clockPanelBento")
h.eval(item("clockPanelEdit"), "clicked()")
h.eval(bento, "working.slice().forEach(c => removeTile(c.widget))")
h.eval(item("clockPanelEdit"), "clicked()")
QTest.qWait(20)
opts = json.loads(h.eval(panel, "JSON.stringify(Config.bar.moduleOptions)"))
check(opts["clock"]["panel"]["cells"] == [], "empty clock grid saved")
check(h.eval(bento, "shown.length") == 0, "empty clock grid stays empty after Done")
style("column")
style("bento")
bento = item("clockPanelBento")
check(h.eval(bento, "shown.length") == 0, "empty clock grid survives popup rebuild")
h.eval(item("clockPanelEdit"), "clicked()")
h.eval(bento, "addWidget('calendar')")
check(json.loads(h.eval(bento, "JSON.stringify(working.map(c => c.widget))")) == ["calendar"], "clock add creates only chosen tile")
h.eval(bento, "resetLayout()")
check(h.eval(bento, "working.length") == 4, "clock reset restores useful default grid")
h.eval(item("clockPanelEdit"), "clicked()")

print("clock-panel: ok")
h.exit(0)
