"""Bento widgets (modules/widgets/dashboard/widgets, WidgetRegistry.js) on the
real kit, offscreen (tests/lib/widgets_env.py: fixture services).

Every registry widget loads in a real BentoTile at its default and minimum
size without a QML error and fills its tile with one Group box; a narrow
calendar is a day card, a wide one a month; the player's play is the
primary action and toggles; levels write the sink volume; quick controls
toggle and open the Wi-Fi panel on right-click (the label follows, "Done"
closes); notifications activate, dismiss and toggle silent; the weather's
debug action toggles the debug mode; the Pomodoro starts, and skips a
running phase; edit mode shows the kit chrome.
"""
import json
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from widgets_env import WidgetsEnv  # noqa: E402  (first: enters the headless platform)
from PySide6.QtCore import QPoint, Qt, qInstallMessageHandler  # noqa: E402,I001
from PySide6.QtTest import QTest  # noqa: E402

errors: list[str] = []


def _capture(_mode, _ctx, msg):
    if any(s in msg for s in ("TypeError", "ReferenceError", "is not a type", "Cannot assign", "Unable to assign",
                              "Binding loop", "binding loop", "failed to load", "Error:")):
        errors.append(msg)


qInstallMessageHandler(_capture)

env = WidgetsEnv("bento-widgets", overrides={"theme": {"animDuration": 0, "language": "glass"}})
h = env.h
CELL, GAP = 132, 8
REGISTRY = env.root / "qs/modules/widgets/dashboard/widgets/WidgetRegistry.js"
REG = json.loads(subprocess.run(
    ["node", "-e", "const s=require('fs').readFileSync(process.argv[1],'utf8').replace('.pragma library','');"
     "console.log(JSON.stringify(new Function(s + ';return widgets;')()))", str(REGISTRY)],
    capture_output=True, text=True, check=True).stdout)
TILES = [{"id": w["id"], "w": w[k + "W"], "h": w[k + "H"], "name": w["id"] + "_" + k}
         for w in REG for k in ("default", "min")]

win = h.load(h.write(f"""
import QtQuick
import QtQuick.Window
import qs.config
import qs.modules.services
import "modules/widgets/dashboard/widgets"
import "modules/widgets/dashboard/widgets/WidgetRegistry.js" as Registry
Window {{
    id: win
    width: 1400; height: 2400; visible: true
    property bool editing: false
    function findItem(name, from) {{
        var item = from || win.contentItem;
        if (item.objectName === name) return item;
        var kids = item.children || [];
        for (var i = 0; i < kids.length; i++) {{ var f = findItem(name, kids[i]); if (f) return f; }}
        return null;
    }}
    Flow {{
        width: win.width
        spacing: {GAP * 2}
        Repeater {{
            model: {json.dumps(TILES)}
            Item {{
                required property var modelData
                objectName: "slot_" + modelData.name
                width: modelData.w * {CELL} + (modelData.w - 1) * {GAP}
                height: modelData.h * {CELL} + (modelData.h - 1) * {GAP}
                BentoTile {{
                    objectName: "tile_" + parent.modelData.name
                    entry: Registry.byId(parent.modelData.id)
                    cell: ({{ "x": 0, "y": 0, "w": parent.modelData.w, "h": parent.modelData.h }})
                    cellW: {CELL}; cellH: {CELL}; gap: {GAP}
                    editing: win.editing
                }}
            }}
        }}
    }}
}}""", dest="qs", name="WidgetsScene.qml"), auto_stub=False)
env.timers(win, pomodoro=False)
QTest.qWait(300)


def check(cond, what: str) -> None:
    if not cond:
        print("FAIL:", what, file=sys.stderr)
        sys.exit(1)


def tile(name: str):
    t = h.eval(win, f"findItem('tile_{name}')")
    check(t is not None, "tile " + name)
    return t


def widget(name: str):
    w = h.eval(tile(name), "item")
    check(w is not None, "widget loaded " + name)
    return w


def click(item, button=Qt.LeftButton) -> None:
    p = h.eval(item, "mapToItem(null, width / 2, height / 2)")
    QTest.mouseClick(win, button, Qt.NoModifier, QPoint(int(p.x()), int(p.y())))
    QTest.qWait(30)


# Every widget at both sizes: loaded, its Group box fills the tile.
for t in TILES:
    w = widget(t["name"])
    box = h.find(w, "groupBox")
    check(box is not None, "group box " + t["name"])
    th = h.eval(tile(t["name"]), "height")
    check(abs(h.eval(box, "height") - th) < 1.5, f"{t['name']}: the box fills the tile ({h.eval(box, 'height')} vs {th})")
check(not errors, "no QML errors:\n" + "\n".join(errors[:8]))

def at(tile_name: str, obj: str) -> str:
    """JS expression of the item `obj` inside the tile `tile_name`."""
    return f"findItem('{obj}', findItem('tile_{tile_name}'))"


def q(expr: str):
    return h.eval(win, expr)


# Calendar: a 1-column tile is a day card, a 2-column one a month.
check(q(at("calendar_default", "calendarDay") + ".visible") is True, "narrow calendar: day card")
q("findItem('slot_calendar_default').modelData = Object.assign({}, findItem('slot_calendar_default').modelData, { w: 2 })")
QTest.qWait(30)
check(q(at("calendar_default", "calendarDay") + ".visible") is False, "wide calendar: month grid")

# Player: play is the primary action and toggles playback.
check(q(at("player_default", "playerPlay") + ".primary") is True, "play is primary")
check(q(at("player_default", "playerTitle") + ".text") == "Midnight City", "track title")
click(q(at("player_default", "playerPlay")))
check(q("MprisController.toggles") == 1, "play toggles")

# Levels: moving the volume line writes the sink.
q(at("levels_default", "volumeLevel") + ".moved(0.25)")
check(abs(q("Audio.sink.audio.volume") - 0.25) < 1e-6, "volume written")

# Quick controls: the Wi-Fi panel takes the tile, its label follows.
q("findItem('tile_quickControls_default').item.togglePanel(0)")
QTest.qWait(30)
check(q(at("quickControls_default", "groupLabel") + ".text") == "Wi-Fi", "panel label")
q("findItem('tile_quickControls_default').item.expandedPanel = -1")

# Notifications: a narrow tile uses the short label; two groups.
check(q(at("notifications_default", "groupLabel") + ".text") == "Inbox", "narrow notifications use the short label")
check(q(at("notifications_default", "notifList") + ".count") == 2, "two groups")

# Weather: the debug action toggles WeatherService.debugMode.
check(q(at("weather_default", "weatherTemp") + ".text") == "18°", "temperature")
q(at("weather_default", "groupLabel") + ".triggered()")
check(q("WeatherService.debugMode") is True, "debug toggled")
q("WeatherService.debugMode = false")

# Pomodoro: idle Start starts; running, skip ends the phase.
check(q(at("pomodoro_default", "pomodoroMain") + ".primary") is True, "start is primary")
click(q(at("pomodoro_default", "pomodoroMain")))
calls = json.loads(q("JSON.stringify(TimersService.calls)"))
check(calls[-1]["method"] == "pomodoro", "Start starts the Pomodoro")
env.timers(win, pomodoro=True, extra=False)
QTest.qWait(30)
check(q(at("pomodoro_default", "pomodoroTime") + ".text") == "12:34", "running time")
click(q(at("pomodoro_default", "pomodoroSkip")))
calls = json.loads(q("JSON.stringify(TimersService.calls)"))
check(calls[-1] == {"method": "add", "params": {"id": "p", "spec": "-754s"}}, "skip ends the phase")

# Edit mode: the tile chrome is kit IconButtons.
h.eval(win, "editing = true")
QTest.qWait(30)
check(q(at("agenda_default", "bentoRemove") + ".visible") is True, "remove button")
check(q(at("agenda_default", "bentoResize") + ".visible") is True, "resize button")
check(not errors, "no QML errors:\n" + "\n".join(errors[:8]))

print("bento-widgets: ok")
h.exit(0)
