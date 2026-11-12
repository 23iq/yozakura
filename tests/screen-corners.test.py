"""Screen corners: four corner-sized layer windows instead of one full-screen one.

Loads the real modules/corners/ScreenCorners.qml (+ ScreenCornerWindow,
RoundCorner) with the layer-shell boundary turned into plain properties, and
checks each window's anchors, size, layer, namespace and empty input mask
with the frame on and off, that nothing is shown under a fullscreen window
or with corners disabled once the state has settled, that a quick
fullscreen on/off inside the settle interval flips no window at all, and that the four windows placed at their anchors
draw exactly the pixels of the former full-screen layout (four RoundCorners
anchored to the corners of a screen-size item).
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402
from lib.waits import pump, settle, wait_until  # noqa: E402

import shiboken6  # noqa: E402
from PySide6.QtQuick import QQuickWindow  # noqa: E402

W, H = 640, 400

h = Harness("screen-corners")
h.module("Quickshell", {
    # A layer surface, placed on the test stage like the compositor would:
    # at the edges it is anchored to, at its implicit size.
    "PanelWindow": """Item {
        property var screen
        property color color
        property int exclusionMode: -1
        property var mask
        property WindowEdges edges: WindowEdges {}
        width: implicitWidth
        height: implicitHeight
        x: edges.right && !edges.left && parent ? parent.width - width : 0
        y: edges.bottom && !edges.top && parent ? parent.height - height : 0
    }""",
    "WindowEdges": "QtObject { property bool top; property bool bottom; property bool left; property bool right }",
    "Region": "QtObject { property Item item: Item {} }",
    "ExclusionMode": "QtObject { enum Mode { Normal, Ignore, Auto } }",
    "ShellScreen": "QtObject { property string name }",
})
h.module("Quickshell.Wayland", {"WlrLayer": "QtObject { enum Layer { Background, Bottom, Top, Overlay } }"})
h.singleton("qs.config", "Config", """QtObject {
    property int roundness: 16
    property QtObject theme: QtObject { property bool enableCorners: true }
    property QtObject bar: QtObject { property bool frameEnabled: false; property var frameThickness: 6 }
}""")
# Styling.radius as in modules/theme/Styling.qml.
h.singleton("qs.modules.theme", "Styling", """import QtQuick
import qs.config
QtObject {
    function radius(offset) { return Config.roundness > 0 ? Math.max(Config.roundness + offset, 0) : 0; }
}""")
h.module("qs.modules.globals", {})
h.singleton("qs.modules.services", "YozdService", """QtObject {
    property QtObject monitors: QtObject { signal valuesChanged() }
    function monitorFor(screen) { return {name: "TEST-1"}; }
}""")
h.singleton("qs.modules.bar.workspaces", "CompositorData", """QtObject {
    property bool fullscreen: false
    signal windowListChanged()
    function monitorHasFullscreen(monitor) { return fullscreen && !!monitor; }
}""")
h.copy("modules/corners/ScreenCornerWindow.qml", replace={
    "    anchors {\n": "    edges {\n",
    "WlrLayershell.namespace:": "property string layerNamespace:",
    "WlrLayershell.layer:": "property int layerShellLayer:",
})
h.copy("modules/components/SettleGate.qml", "qs/modules/components")
h.module("qs.modules.components", {})
h.copy("modules/corners/ScreenCorners.qml")

root = h.load(f"""import QtQuick
import QtQuick.Window
import qs.config
import qs.modules.bar.workspaces
import qs.modules.globals
import Quickshell
Window {{
    id: win
    width: {W}; height: {H}; visible: true; color: "white"
    property alias corners: corners
    property alias stage: stage
    property alias reference: reference
    // The four layer windows, placed at their anchors.
    Item {{
        id: stage
        anchors.fill: parent
        ScreenCorners {{ id: corners; anchors.fill: parent }}
    }}
    // The former layout: one full-screen surface, a RoundCorner per corner.
    Item {{
        id: reference
        anchors.fill: parent
        visible: false
        RoundCorner {{ size: corners.cornerSize; anchors.left: parent.left; anchors.top: parent.top; corner: RoundCorner.CornerEnum.TopLeft }}
        RoundCorner {{ size: corners.cornerSize; anchors.right: parent.right; anchors.top: parent.top; corner: RoundCorner.CornerEnum.TopRight }}
        RoundCorner {{ size: corners.cornerSize; anchors.left: parent.left; anchors.bottom: parent.bottom; corner: RoundCorner.CornerEnum.BottomLeft }}
        RoundCorner {{ size: corners.cornerSize; anchors.right: parent.right; anchors.bottom: parent.bottom; corner: RoundCorner.CornerEnum.BottomRight }}
    }}
    function windows() {{
        const out = [];
        for (const c of corners.children)
            if (c.edges !== undefined)
                out.push(c);
        return out;
    }}
    function describe() {{
        return JSON.stringify(windows().map(w => ({{
            corner: w.corner, visible: w.visible, w: w.width, h: w.height, x: w.x, y: w.y,
            top: w.edges.top, bottom: w.edges.bottom, left: w.edges.left, right: w.edges.right,
            layer: w.layerShellLayer, ns: w.layerNamespace, ignore: w.exclusionMode === ExclusionMode.Ignore,
            maskItem: w.mask ? w.mask.item : "none", transparent: w.color.a === 0
        }})));
    }}
    function setFullscreen(on) {{ CompositorData.fullscreen = on; CompositorData.windowListChanged(); }}
    // Every visibility change of any corner window (a map or unmap).
    property int flips: 0
    Component.onCompleted: {{
        for (const w of windows())
            w.visibleChanged.connect(() => win.flips++);
    }}
}}""", auto_stub=False)

ok_all = True


def check(name, ok, detail=""):
    global ok_all
    ok_all &= bool(ok)
    print(("PASS " if ok else "FAIL ") + name + (" " + detail if detail else ""))


def ev(expr):
    return h.eval(root, expr)


def windows():
    import json
    return json.loads(ev("describe()"))


# TopLeft, TopRight, BottomLeft, BottomRight
EDGES = {0: (True, False, True, False), 1: (True, False, False, True),
         2: (False, True, True, False), 3: (False, True, False, True)}
NAMESPACE = ev('Brand.namespace("screenCorners")')


def check_layout(label, size):
    ws = windows()
    check(f"{label}: four windows", len(ws) == 4 and sorted(w["corner"] for w in ws) == [0, 1, 2, 3])
    for w in ws:
        c = w["corner"]
        top, bottom, left, right = EDGES[c]
        check(f"{label}: corner {c} anchored to its two edges",
              (w["top"], w["bottom"], w["left"], w["right"]) == (top, bottom, left, right))
        check(f"{label}: corner {c} is {size}x{size}", (w["w"], w["h"]) == (size, size), str((w["w"], w["h"])))
        check(f"{label}: corner {c} overlay layer, own namespace, no zone, no input, transparent",
              w["layer"] == 3 and w["ns"] == NAMESPACE and w["ignore"] and w["maskItem"] is None and w["transparent"])
        check(f"{label}: corner {c} shown", w["visible"] is True)


window = shiboken6.wrapInstance(shiboken6.getCppPointer(root)[0], QQuickWindow)


def same_pixels(label):
    ev("reference.visible = false; stage.visible = true")
    settle()
    a = window.grabWindow()
    ev("reference.visible = true; stage.visible = false")
    settle()
    b = window.grabWindow()
    ev("reference.visible = false; stage.visible = true")
    check(f"{label}: pixels identical to the full-screen layout", a == b and not a.isNull())
    # And something was drawn (dark corner pixel on white).
    check(f"{label}: corner drawn", a.pixelColor(0, 0).lightness() < 128 and a.pixelColor(W // 2, H // 2).lightness() > 200)


check_layout("frame off", 20)
same_pixels("frame off")

ev("Config.bar.frameEnabled = true; Config.bar.frameThickness = 10")
check_layout("frame on", 30)
same_pixels("frame on")
ev("Config.bar.frameThickness = 400")
check("frame thickness clamped as before", all(w["w"] == 60 for w in windows()))
ev("Config.bar.frameThickness = 'x'")
check("non-numeric thickness uses 6", all(w["w"] == 26 for w in windows()))
ev("Config.bar.frameEnabled = false; Config.bar.frameThickness = 6")

SETTLE = ev("corners.settleInterval")
check("settle interval in the 150-300 ms range", 150 <= SETTLE <= 300, str(SETTLE))


def all_visible(v):
    return all(w["visible"] is v for w in windows())


ev("flips = 0")
ev("setFullscreen(true)")
check("fullscreen window: still shown before the state settles", all_visible(True))
check("fullscreen window: nothing shown once settled", wait_until(lambda: all_visible(False)))
check("fullscreen window: the four windows flipped once each", ev("flips") == 4, str(ev("flips")))
ev("setFullscreen(false)")
check("fullscreen gone: shown again once settled", wait_until(lambda: all_visible(True)))

# A quick fullscreen on/off inside the interval: no window is unmapped.
ev("flips = 0")
ev("setFullscreen(true)")
pump(SETTLE // 3)
ev("setFullscreen(false)")
pump(SETTLE * 2)
check("quick fullscreen on/off: no visibility change", ev("flips") == 0 and all_visible(True), str(ev("flips")))

ev("Config.theme.enableCorners = false")
check("corners disabled: nothing shown", wait_until(lambda: all_visible(False)))
ev("Config.theme.enableCorners = true")
check("corners enabled: shown again", wait_until(lambda: all_visible(True)))
ev("Config.roundness = 0")
check("roundness 0: nothing shown, no 0 px surface",
      wait_until(lambda: all_visible(False)) and all(w["w"] >= 1 and w["h"] >= 1 for w in windows()))

sys.exit(0 if ok_all else 1)
