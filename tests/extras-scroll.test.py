#!/usr/bin/env python3
"""Settings > Apps & Extras scrolls steadily to the bottom.

Regression: a hovered card turns its shadow on (StyledRect layer), and the
weather overlay of StyledRect was then hoisted next to the card, into the
card Grid, where the positioner laid it out as one more cell. A full last
row grew a phantom row (+172 px), the page's contentHeight flipped back and
forth as cards passed under the pointer, and near the bottom contentY was
clamped back: the page jumped. Wheel-scrolls the real catalog with the
pointer over the cards and checks contentHeight stays put and contentY only
grows; then checks the overlay is never hoisted into a positioner (a Grid of
weather-hosting StyledRects with their shadow on) but still is next to a
plain parent.
"""
from __future__ import annotations

import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from extras_env import ExtrasEnv, full_catalog  # noqa: E402
from kit_env import KitEnv  # noqa: E402

from PySide6.QtCore import QObject, QPoint, QPointF, Qt  # noqa: E402
from PySide6.QtGui import QGuiApplication, QWheelEvent  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402
from waits import pump, settle, wait_until  # noqa: E402

failures: list[str] = []


def check(cond: bool, msg: str) -> None:
    if not cond:
        failures.append(msg)
        print("FAIL:", msg)


# --- the page ---------------------------------------------------------------
cat = full_catalog()
status = {e["id"]: {"id": e["id"], "state": "missing"} for e in cat["entries"]}
env = ExtrasEnv("extras-scroll", catalog=cat, status=status, overrides={"theme": {"animDuration": 0}})
h = env.h
W, H = 1280, 900
win = h.load(f"""
import QtQuick
import QtQuick.Window
import qs.modules.settings.extras
Window {{
    width: {W}; height: {H}; visible: true
    ExtrasPage {{ objectName: "page"; anchors.fill: parent
        category: ({{"id": "extras", "icon": "packageBox", "title": "prefs.cat.extras", "description": "prefs.cat.extras.desc"}}) }}
}}""")
page = h.find(win, "page")
flick = h.find(page, "catalogFlick")
check(wait_until(lambda: h.eval(flick, "contentHeight > height * 2")), "the catalog fills more than two screens")
settle()

pos = QPointF(W / 2 + 100, H / 2)
QTest.mouseMove(win, pos.toPoint())
settle()


def wheel(dy: int) -> None:
    gp = win.mapToGlobal(pos.toPoint())
    e = QWheelEvent(pos, QPointF(gp), QPoint(0, 0), QPoint(0, dy), Qt.NoButton, Qt.NoModifier, Qt.NoScrollPhase, False)
    e.setTimestamp(int(time.monotonic() * 1000))
    QGuiApplication.sendEvent(win, e)


def geom() -> tuple[float, float]:
    return float(flick.property("contentY")), float(flick.property("contentHeight"))


y0, height0 = geom()
heights = {height0}
prev = y0
backwards = []
for step in range(80):
    wheel(-120)
    for _ in range(4):
        pump(16)
        y, ch = geom()
        heights.add(ch)
        if y < prev - 0.5:
            backwards.append((step, prev, y))
        prev = y
for _ in range(20):
    pump(16)
    heights.add(geom()[1])

y_end, _ = geom()
max_y = float(h.eval(flick, "contentHeight - height"))
check(heights == {height0}, "contentHeight stays put while scrolling with the pointer over the cards: %s" % sorted(heights))
check(not backwards, "contentY only grows on the way down: %s" % backwards[:5])
check(abs(y_end - max_y) < 1, "the wheel reaches the bottom (%.1f of %.1f)" % (y_end, max_y))

# hovering a card (shadow on) never adds a cell to its grid
grid = h.find(page, "catalogGrid")
cards_before = h.eval(grid, "children.reduce((n, g) => n + g.children.length, 0)")
check(h.eval(grid, "children.every(g => g.children.every(c => c.objectName !== 'weatherFx'))") is True,
      "no weather overlay sits among the grid cells")
check(cards_before > 0, "the grid has cards")

# --- StyledRect: no hoisting into a positioner ------------------------------
kit = KitEnv("extras-scroll-kit", overrides={"theme": {"language": "glass"}})
kwin = kit.load("""import QtQuick
import QtQuick.Window
import qs.modules.theme
import qs.modules.components
Window {
    width: 600; height: 400; visible: true
    WeatherFxScope { condition: "snow" }
    Grid {
        objectName: "grid"
        columns: 2
        spacing: 8
        Repeater {
            model: 2
            StyledRect {
                width: 100; height: 60
                variant: "popup"; glassSurface: "popups"; enableShadow: true
            }
        }
    }
    Item {
        objectName: "plain"
        y: 200; width: 200; height: 100
        StyledRect {
            objectName: "free"
            width: 100; height: 60
            variant: "popup"; glassSurface: "popups"; enableShadow: true
        }
    }
}""")
kh = kit.h
kgrid = kh.find(kwin, "grid")
free = kh.find(kwin, "free")
check(wait_until(lambda: kh.eval(kh.find(free, "weatherFx"), "item !== null") is True), "the weather overlay loads under the scope")
check(kh.eval(kgrid, "height") == 60, "a Grid of shadowed surfaces keeps one row: height %s" % kh.eval(kgrid, "height"))
check(kh.eval(kgrid, "children.filter(c => c.objectName === 'weatherFx').length") == 0,
      "the overlay of a surface in a positioner stays inside it")
check(kh.find(kwin, "plain").findChild(QObject, "weatherFx") is not None, "the overlay of a free surface exists")
check(kh.eval(kh.find(free, "weatherFx"), "hoisted") is True, "next to a plain parent the overlay is still hoisted out of the layer")

if failures:
    print(f"{len(failures)} failure(s)")
    sys.exit(1)
print("extras-scroll: ok")
