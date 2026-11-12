"""performance.compactOsd: the OSD window sized to the OSD, not the screen.

Loads the real modules/shell/osd/OSD.qml (real styles, kit, EdgeService,
Config from the defaults) with the layer-shell window turned into an Item
placed on a screen-size stage the way a compositor places a layer surface
(anchors + margins + implicit size, clipped to its bounds), and checks, in
every visual language (tests/lib/languages.py):

* off (the default): the window covers the screen, as before;
* on: for each window style (pill, edge, island, gauge) on each edge, the
  window is a small box anchored to that edge, and the screen shows exactly
  the pixels of the full-screen window (same OSD, same screen position);
* the input region is the OSD itself in both modes; scrolling over it,
  clicking it and hovering it work in the compact window;
* the compact window never changes geometry while it shows or animates:
  a position change made meanwhile applies from the next showing.
"""
import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import headless  # noqa: E402

# The styles draw through layers and shaders (glass, shadows): GL only
headless.ensure(gl=True)
from languages import LANGUAGES  # noqa: E402
from osd_env import OSD_SERVICE_STUB, OsdEnv  # noqa: E402
from settings_env import QUICKSHELL, global_states_qml  # noqa: E402
from waits import pump, settle, wait_until  # noqa: E402

import shiboken6  # noqa: E402
from PySide6.QtCore import QPoint, QPointF, Qt  # noqa: E402
from PySide6.QtGui import QColor, QGuiApplication, QPainter, QWheelEvent  # noqa: E402
from PySide6.QtQuick import QQuickWindow  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

REPO = Path(__file__).resolve().parents[1]
W, H = 720, 480
STYLES = ["pill", "edge", "island", "gauge"]
EDGES = ["top", "bottom", "left", "right"]
# Debug: OSD_COMPACT_SHOTS=<dir> saves every grab
SHOTS = os.environ.get("OSD_COMPACT_SHOTS", "")

# A layer surface on the stage: anchored edges + margins, else its implicit
# size; clipped like a real surface (nothing may draw outside it).
PANEL_WINDOW = """Item {
    property var screen
    property color color
    property int exclusionMode: -1
    property var mask
    property WindowEdges edges: WindowEdges {}
    property WindowMargins margins: WindowMargins {}
    readonly property real sw: parent ? parent.width : 0
    readonly property real sh: parent ? parent.height : 0
    clip: true
    width: edges.left && edges.right ? sw - margins.left - margins.right : implicitWidth
    height: edges.top && edges.bottom ? sh - margins.top - margins.bottom : implicitHeight
    x: edges.left ? margins.left : (edges.right ? sw - margins.right - width : (sw - width) / 2)
    y: edges.top ? margins.top : (edges.bottom ? sh - margins.bottom - height : (sh - height) / 2)
}"""

SERVICE = OSD_SERVICE_STUB.replace("property int timeout: 2500", """property int timeout: 600000
    property string style: "pill"
    property var controls: []
    function routeForScreen(name) { return { "style": style, "window": style !== "bar-inline" } }
    function openControls(name) { controls = controls.concat([name]) }""")

ok_all = True


def check(name, ok, detail=""):
    global ok_all
    ok_all &= bool(ok)
    print(("PASS " if ok else "FAIL ") + name + (" " + detail if detail else ""))


def compare(full, compact, geom, rect):
    """Identical screens, or identical but for the rasteriser's rounding
    on antialiased edges: at most 1/255 per channel, on at most 0.5 % of
    the OSD's pixels (the two windows batch their scene graph differently;
    llvmpipe interpolates an edge's coverage a hair differently)."""
    if full.isNull() or compact.isNull():
        return False, "empty grab"
    if full == compact:
        return True, "exact"
    # Outside the compact window: must be exactly equal
    x0, y0, w, h = (int(v) for v in geom)
    a, b = full.copy(), compact.copy()
    for img in (a, b):
        p = QPainter(img)
        p.fillRect(x0, y0, w, h, QColor("magenta"))
        p.end()
    if a != b:
        return False, "differs outside the compact window"
    worst, count = 0, 0
    for y in range(y0, y0 + h):
        for x in range(x0, x0 + w):
            p, q = full.pixel(x, y), compact.pixel(x, y)
            if p != q:
                count += 1
                worst = max(worst, *(abs(((p >> s) & 255) - ((q >> s) & 255)) for s in (0, 8, 16, 24)))
    area = rect["w"] * rect["h"]
    ok = worst <= 1 and count <= area * 0.005
    return ok, f"{count} px differ by at most {worst}/255 (OSD {int(area)} px)"


def build(lang: str):
    env = OsdEnv(f"osd-compact-{lang}", overrides={"theme": {"language": lang, "animDuration": 0}})
    h = env.h
    h.module("Quickshell", {
        **QUICKSHELL,
        "PanelWindow": PANEL_WINDOW,
        "WindowEdges": "QtObject { property bool top; property bool bottom; property bool left; property bool right }",
        "WindowMargins": "QtObject { property int top; property int bottom; property int left; property int right }",
        "Region": "QtObject { property Item item }",
        "ExclusionMode": "QtObject { enum Mode { Normal, Ignore, Auto } }",
        "ShellScreen": "QtObject { property string name; property int width; property int height }",
    })
    h.module("Quickshell.Wayland", {
        "WlrLayer": "QtObject { enum Layer { Background, Bottom, Top, Overlay } }",
        "WlrKeyboardFocus": "QtObject { enum Focus { None, Exclusive, OnDemand } }",
    })
    gs = global_states_qml({}).replace("id: gs\n", "id: gs\n    property bool osdVisible: false\n    property string osdIndicator: \"\"\n", 1)
    h.module("qs.modules.globals", {"GlobalStates": gs})
    h.module("qs.modules.services", {"OsdService": SERVICE,
                                     "Brightness": "pragma Singleton\nQtObject { property bool syncBrightness: true }"})
    text = (REPO / "modules/shell/osd/OSD.qml").read_text()
    for old, new in {
        "    anchors.top:": "    edges.top:", "    anchors.bottom:": "    edges.bottom:",
        "    anchors.left:": "    edges.left:", "    anchors.right:": "    edges.right:",
        "WlrLayershell.layer:": "property int layerShellLayer:",
        "WlrLayershell.namespace:": "property string layerNamespace:",
        "WlrLayershell.keyboardFocus:": "property int layerKeyboardFocus:",
    }.items():
        assert old in text, old
        text = text.replace(old, new)
    (env.root / "qs/modules/shell/osd/OSD.qml").write_text(text)
    win = env.load(f"""import QtQuick
import QtQuick.Window
import Quickshell
import qs.config
import qs.modules.globals
import qs.modules.services
import qs.modules.shell.osd
Window {{
    id: win
    width: {W}; height: {H}; visible: true; color: "black"
    property alias osd: osd
    property alias stage: stage
    // A busy background: any offset or clipping shows
    Rectangle {{
        anchors.fill: parent
        gradient: Gradient {{
            orientation: Gradient.Horizontal
            GradientStop {{ position: 0; color: "#20406a" }}
            GradientStop {{ position: 0.5; color: "#c08040" }}
            GradientStop {{ position: 1; color: "#30a070" }}
        }}
        Rectangle {{ anchors.fill: parent; opacity: 0.5
            gradient: Gradient {{ GradientStop {{ position: 0; color: "white" }} GradientStop {{ position: 1; color: "black" }} }} }}
    }}
    ShellScreen {{ id: scr; name: "DP-1"; width: {W}; height: {H} }}
    Item {{
        id: stage
        anchors.fill: parent
        OSD {{ id: osd; targetScreen: scr }}
    }}
    function geometry() {{ return [osd.x, osd.y, osd.width, osd.height].join(","); }}
    function inputRect() {{
        const m = osd.mask.item;
        const p = m.mapToItem(stage, 0, 0);
        return [Math.round(p.x), Math.round(p.y), m.width, m.height].join(",");
    }}
    function osdRect() {{
        const p = osd.mask.item.mapToItem(stage, 0, 0);
        return JSON.stringify({{ x: p.x, y: p.y, w: osd.mask.item.width, h: osd.mask.item.height }});
    }}
    function showLevel() {{ OsdService.level("volume", 0.62, false, ""); }}
    function hide() {{ GlobalStates.osdVisible = false; }}
}}""")
    return env, win


def run(lang: str) -> None:
    env, win = build(lang)
    h = env.h

    def ev(expr):
        return h.eval(win, expr)

    window = shiboken6.wrapInstance(shiboken6.getCppPointer(win)[0], QQuickWindow)

    def show_and_grab():
        ev("showLevel()")
        wait_until(lambda: ev("osd.visible") is True)
        settle()
        return window.grabWindow()

    def hide():
        ev("hide()")
        return wait_until(lambda: ev("osd.visible") is False)

    check(f"{lang}: off by default", ev("Config.performance.compactOsd") is False)
    ev("hide()")
    settle()
    background = window.grabWindow()
    for style in STYLES:
        for edge in EDGES:
            label = f"{lang} {style} {edge}"
            ev(f"OsdService.style = '{style}'; Config.layout.osd = Object.assign({{}}, Config.layout.osd, {{position: '{edge}'}})")
            ev("Config.performance.compactOsd = false")
            settle()
            full = show_and_grab()
            full_geom = ev("geometry()")
            full_input = ev("inputRect()")
            rect = json.loads(ev("osdRect()"))
            hide()
            ev("Config.performance.compactOsd = true")
            settle()
            compact = show_and_grab()
            geom = [float(v) for v in ev("geometry()").split(",")]
            if style == STYLES[0] and edge == EDGES[0]:
                check(f"{lang}: full-screen window while off", full_geom == f"0,0,{W},{H}", full_geom)
            # the OSD, its 14 px slide and a shadow's reach around it, no more
            small = geom[2] <= rect["w"] + 100 and geom[3] <= rect["h"] + 100
            at_edge = {"top": geom[1] == 0 or geom[1] <= rect["y"],
                       "bottom": geom[1] + geom[3] >= rect["y"] + rect["h"],
                       "left": geom[0] <= rect["x"], "right": geom[0] + geom[2] >= rect["x"] + rect["w"]}[edge]
            edges = ev("[osd.edges.top, osd.edges.bottom, osd.edges.left, osd.edges.right].join(',')").split(",")
            anchored = edges[EDGES.index(edge)] == "true" and edges.count("true") == 2
            check(f"{label}: compact window anchored to its edge, small", small and at_edge and anchored,
                  f"{geom} {edges} osd={rect}")
            check(f"{label}: same input region", ev("inputRect()") == full_input, f"{ev('inputRect()')} vs {full_input}")
            same, detail = compare(full, compact, geom, rect)
            check(f"{label}: pixels of the full-screen window", same, detail)
            # something was drawn where the OSD sits
            xs = range(int(rect["x"]), int(rect["x"] + rect["w"]), 3)
            ys = range(int(rect["y"]), int(rect["y"] + rect["h"]), 3)
            changed = sum(1 for y in ys for x in xs if compact.pixel(x, y) != background.pixel(x, y))
            check(f"{label}: OSD drawn", changed > len(xs) * len(ys) // 2, f"{changed}/{len(xs) * len(ys)}")
            if SHOTS:
                full.save(f"{SHOTS}/{lang}-{style}-{edge}-full.png")
                compact.save(f"{SHOTS}/{lang}-{style}-{edge}-compact.png")
                background.save(f"{SHOTS}/{lang}-background.png")
            hide()
    # Input in the compact window: wheel, hover, click
    ev("OsdService.style = 'pill'; Config.layout.osd = Object.assign({}, Config.layout.osd, {position: 'bottom'}); Config.performance.compactOsd = true")
    settle()
    show_and_grab()
    rect = json.loads(ev("osdRect()"))
    centre = QPoint(int(rect["x"] + rect["w"] / 2), int(rect["y"] + rect["h"] / 2))
    wheel = QWheelEvent(QPointF(centre), QPointF(window.mapToGlobal(centre)), QPoint(0, 0), QPoint(0, 120),
                        Qt.NoButton, Qt.NoModifier, Qt.NoScrollPhase, False)
    QGuiApplication.sendEvent(window, wheel)
    settle()
    check(f"{lang}: wheel over the compact OSD changes the level", ev("JSON.stringify(OsdService.adjusted)") == '[["volume",0.05]]',
          ev("JSON.stringify(OsdService.adjusted)"))
    QTest.mouseMove(window, centre)
    settle()
    ev("OsdService.timeout = 50")
    ev("showLevel()")
    pump(250)
    check(f"{lang}: hovering keeps the compact OSD up", ev("GlobalStates.osdVisible") is True)
    QTest.mouseClick(window, Qt.LeftButton, Qt.NoModifier, centre)
    settle()
    check(f"{lang}: clicking opens the bar controls and hides it",
          ev("OsdService.controls.length") == 1 and ev("GlobalStates.osdVisible") is False)
    QTest.mouseMove(window, QPoint(2, 2))
    ev("OsdService.timeout = 600000")
    hide()
    # Geometry is fixed while it shows and while it animates out
    ev("Config.animDuration = 200")
    ev("Config.layout.osd = Object.assign({}, Config.layout.osd, {position: 'bottom'})")
    settle()
    ev("showLevel()")
    wait_until(lambda: ev("osd.visible") is True)
    shown_geom = ev("geometry()")
    ev("Config.layout.osd = Object.assign({}, Config.layout.osd, {position: 'top'})")
    settle()
    held = ev("geometry()") == shown_geom
    ev("hide()")
    leaving = ev("osd.visible") is True and ev("geometry()") == shown_geom
    check(f"{lang}: geometry fixed while shown and while animating out", held and leaving, f"{shown_geom} -> {ev('geometry()')}")
    hide()
    settle()
    moved = ev("geometry()") != shown_geom and float(ev("geometry()").split(",")[1]) < H / 2
    check(f"{lang}: the new position applies from the next showing", moved, ev("geometry()"))
    ev("Config.animDuration = 0")
    win.close()



for language in LANGUAGES:
    run(language)

sys.exit(0 if ok_all else 1)
