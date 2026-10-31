"""theme.weatherFx (modules/theme/WeatherFx.qml): with mode "off" no weather
overlay exists on any surface; with a mode on, a surface root (only roots of
shell hosts) loads one overlay drawing what the weather asks for, its timers
run only while motion is on, a WeatherFxScope forces a condition even while
the mode is off, and petals / heat stay on the bar."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from lib.kit_env import KitEnv  # noqa: E402

from PySide6.QtTest import QTest  # noqa: E402

SCENE = """import QtQuick
import QtQuick.Window
import qs.config
import qs.modules.theme
import qs.modules.components
Window {
    width: 500; height: 400; visible: true
    property alias scoped: scopeLoader.active
    function setFx(mode, extra) {
        Config.theme.weatherFx = Object.assign({}, Config.theme.weatherFx, { mode: mode }, extra || {});
    }
    function weather(code, temp) {
        WeatherFx.weatherCode = code;
        WeatherFx.temperature = temp;
        WeatherFx.known = true;
    }
    StyledRect {
        objectName: "bar"
        x: 10; y: 10; width: 480; height: 40
        variant: "bg"
        glassSurface: "bar"
    }
    StyledRect {
        objectName: "panel"
        x: 200; y: 70; width: 280; height: 200
        variant: "popup"
        glassSurface: "popups"
    }
    StyledRect {
        objectName: "inner"
        x: 20; y: 70; width: 120; height: 80
        variant: "pane"
    }
    StyledRect {
        objectName: "widget"
        x: 20; y: 200; width: 120; height: 80
        variant: "pane"
        glassSurface: "widgets"
    }
    Loader {
        id: scopeLoader
        active: false
        sourceComponent: Item {
            width: 300; height: 120
            WeatherFxScope { condition: "snow" }
            StyledRect {
                objectName: "previewPanel"
                anchors.fill: parent
                variant: "popup"
                glassSurface: "popups"
            }
        }
    }
}
"""

env = KitEnv("weatherfx", overrides={"theme": {"language": "glass"}})
h = env.h
win = env.load(SCENE)
bar, panel, inner, widget = (h.find(win, n) for n in ("bar", "panel", "inner", "widget"))
surfaces = {"bar": bar, "panel": panel, "inner": inner, "widget": widget}
fx = {n: h.find(o, "weatherFx") for n, o in surfaces.items()}


def loaded(name: str) -> bool:
    return fx[name].property("active") is True and h.eval(fx[name], "item !== null") is True


def effect(name: str, which: str):
    # (never hold a Loader's item through property("item"): PySide would
    # own and delete it)
    return h.find(surfaces[name], which)


# Off (default): heavy rain changes nothing, nothing is created
h.eval(win, "weather(65, 8)")
assert h.eval(win, "WeatherFx.mode") == "off"
assert h.eval(win, "WeatherFx.active") is False
assert not any(loaded(n) for n in fx), "no overlay while off"
assert h.eval(win, "WeatherFx.clock.running") is False

# Subtle rain: one overlay on each shell host root, none on inner rects or widgets
h.eval(win, "setFx('subtle')")
QTest.qWait(50)
assert h.eval(win, "WeatherFx.active") is True
assert loaded("bar") and loaded("panel")
assert not loaded("inner") and not loaded("widget")
rain = effect("panel", "weatherRain")
assert rain.property("active") is True
assert effect("panel", "weatherFrost").property("active") is False
assert h.eval(rain, "item.spots.length") >= 2
timer = h.find(panel, "rainTimer")
assert timer.property("running") is True

# A fullscreen window on this screen (reported by the bar) pauses everything:
# the surface timer and the shared frame clock stop, and resume afterwards
screen_name = h.eval(win, "Qt.application.screens[0].name")
assert h.eval(fx["panel"], "item.animate") is True
h.eval(win, "WeatherFx.setCovered(%r, true)" % screen_name)
QTest.qWait(30)
assert h.eval(fx["panel"], "item.animate") is False
assert timer.property("running") is False
h.eval(win, "WeatherFx.setCovered(%r, false)" % screen_name)
QTest.qWait(30)
assert h.eval(fx["panel"], "item.animate") is True
assert timer.property("running") is True

# Hidden window: the overlay rests too
win.setProperty("visible", False)
QTest.qWait(30)
assert h.eval(fx["panel"], "item.animate") is False
assert h.eval(win, "WeatherFx.frame.running") is False
win.setProperty("visible", True)
QTest.qWait(30)
assert h.eval(fx["panel"], "item.animate") is True

# Snow, frost and fog load (they step on the shared clock, see FrameUse)
h.eval(win, "weather(73, -4)")
QTest.qWait(30)
for n in ("weatherSnow", "weatherFrost"):
    assert effect("panel", n).property("active") is True
h.eval(win, "weather(45, 8)")
QTest.qWait(30)
assert effect("panel", "weatherFog").property("active") is True
h.eval(win, "weather(65, 8)")
QTest.qWait(30)
timer = h.find(panel, "rainTimer")

# Motion off: drops rest, no timer runs
h.eval(win, "Config.animDuration = 0")
QTest.qWait(30)
assert timer.property("running") is False
h.eval(win, "Config.animDuration = 300")

# Rain toggle off: rain gone, overlay unloads (nothing else to draw)
h.eval(win, "setFx('subtle', { rain: false })")
QTest.qWait(30)
assert h.eval(win, "WeatherFx.active") is False and not loaded("panel")

# Cold snow: frost on every root, flakes settle; heat and petals only on the bar
h.eval(win, "setFx('vivid', { rain: true, heat: true, seasonal: true })")
h.eval(win, "weather(73, -4)")
QTest.qWait(50)
assert effect("panel", "weatherFrost").property("active") is True
assert effect("bar", "weatherSnow").property("active") is True
h.eval(win, "weather(0, 36)")
QTest.qWait(30)
assert effect("bar", "weatherHeat").property("active") is True
assert effect("panel", "weatherHeat").property("active") is False

# Preview scope: forces its condition while the mode is off
h.eval(win, "setFx('off')")
QTest.qWait(30)
assert not loaded("bar")
win.setProperty("scoped", True)
QTest.qWait(80)
assert h.eval(win, "WeatherFx.scopes") == 1
preview = h.find(win, "previewPanel")
pfx = h.find(preview, "weatherFx")
assert h.eval(pfx, "item !== null") is True
assert h.find(preview, "weatherSnow").property("active") is True
# Live surfaces load an overlay meanwhile but draw nothing
assert all(h.find(bar, n).property("active") is False
           for n in ("weatherRain", "weatherSnow", "weatherFrost", "weatherFog", "weatherHeat", "weatherSeasonal"))
win.setProperty("scoped", False)
QTest.qWait(80)
assert h.eval(win, "WeatherFx.scopes") == 0
assert not loaded("bar")

print("weather-fx: ok")
h.exit(0)
