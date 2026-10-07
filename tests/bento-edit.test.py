"""Bento dashboard grid (modules/widgets/dashboard/widgets/BentoView.qml),
offscreen with a test widget registry.

Normal mode lays out the normalized grid and hands widgets their cell size;
a corrupt grid falls back to the default one; edit mode shows the chrome and
toolbar and blocks widget input; dragging a tile with the mouse snaps it to
the grid; leaving edit mode saves the cells; keyboard move/remove/add work;
reset asks inline before restoring the default grid.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402
from PySide6.QtCore import QPoint, Qt  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

h = Harness("bento-edit")
h.singleton("qs.config", "Config", """QtObject {
    property int animDuration: 0
    property QtObject theme: QtObject { property string font: "Sans"; property string monoFont: "Mono"; property int fontSize: 14 }
    property QtObject layout: QtObject {
        property QtObject dashboard: QtObject {
            property QtObject grid: QtObject { property int cols: 4; property var cells: [] }
        }
    }
}""")
h.singleton("qs.modules.theme", "Metrics", """QtObject {
    property int bentoCell: 100; property int spacing: 8; property int padding: 16
    property int rowHeight: 48; property int badgeHeight: 22; property int iconSize: 32
}""")
TOKEN = "QtObject { property int duration: 0; property int easing: 0 }"
h.singleton("qs.modules.theme", "Motion", f"""QtObject {{
    property QtObject enter: {TOKEN}
    property QtObject exit: {TOKEN}
    property QtObject morph: {TOKEN}
    property QtObject emphasis: {TOKEN}
}}""")
h.singleton("qs.modules.theme", "Colors", """QtObject {
    property color overBackground: "white"; property color primary: "pink"
    property color outline: "gray"; property color overSurface: "white"
}""")
h.singleton("qs.modules.theme", "Styling", """QtObject {
    function radius(n) { return 8 }
    function fontSize(n) { return 14 + n }
    function srItem(v) { return "black" }
}""")
h.singleton("qs.modules.theme", "Icons", """QtObject {
    property string font: "Sans"; property string plus: "+"; property string cancel: "x"
    property string check: "v"; property string arrowCounterClockwise: "r"; property string arrowsOutSimple: "s"
    property string sun: "o"; property string dotsSix: "d"
}""")
h.singleton("qs.modules.services", "I18n", "QtObject { function t(k) { return k } }")
h.module("qs.modules.components", {
    "StyledRect": "Rectangle { property string variant; property bool enableShadow; property real backgroundOpacity: -1 }"
})
# The tile chrome buttons (kit IconButton) and the spacing they use.
h.module("qs.modules.components.kit", {
    "IconButton": "Item { property string icon; property string size; property bool active; property bool primary; "
                  "property bool highlighted; signal clicked; implicitWidth: 36; implicitHeight: 36; "
                  "MouseArea { anchors.fill: parent; onClicked: parent.clicked() } }",
    "Space": "pragma Singleton\nQtObject { property int xs: 4 }",
})
widget = h.write("""Item {
    property real cellW: 0
    property real cellH: 0
    property bool compact: false
    property int clicks: 0
    MouseArea { anchors.fill: parent; onClicked: parent.clicks++ }
}""", name="TestWidget.qml")
view_path = h.copy("modules/widgets/dashboard/widgets/BentoView.qml")
url = widget.as_uri()

win = h.load(f"""
import QtQuick
import QtQuick.Window
import qs.config
Window {{
    id: win
    width: 432; height: 400; visible: true
    property int commits: 0
    function findItem(name, from) {{
        var item = from || win.contentItem;
        if (item.objectName === name) return item;
        var kids = item.children || [];
        for (var i = 0; i < kids.length; i++) {{ var f = findItem(name, kids[i]); if (f) return f; }}
        return null;
    }}
    readonly property var defs: ({{
        "a": {{ "id": "a", "url": "{url}", "labelKey": "a", "icon": "sun", "minW": 1, "minH": 1, "maxW": 2, "maxH": 2, "defaultW": 1, "defaultH": 1 }},
        "b": {{ "id": "b", "url": "{url}", "labelKey": "b", "icon": "sun", "minW": 1, "minH": 1, "maxW": 4, "maxH": 2, "defaultW": 2, "defaultH": 1 }},
        "c": {{ "id": "c", "url": "{url}", "labelKey": "c", "icon": "sun", "minW": 1, "minH": 1, "maxW": 2, "maxH": 3, "defaultW": 1, "defaultH": 2 }}
    }})
    BentoView {{
        id: view
        objectName: "view"
        anchors.fill: parent
        registry: ({{
            "ids": () => ["a", "b", "c"],
            "byId": id => win.defs[id] || null,
            "defaultGrid": cols => [{{ "widget": "a", "x": 0, "y": 0, "w": 1, "h": 1 }}, {{ "widget": "b", "x": 1, "y": 0, "w": 2, "h": 1 }}]
        }})
        cols: Config.layout.dashboard.grid.cols
        cells: Config.layout.dashboard.grid.cells
        onEditingRequested: on => view.editing = on
        onCommit: cells => {{ Config.layout.dashboard.grid.cells = cells; win.commits++; }}
    }}
}}""", auto_stub=False)
view = h.find(win, "view")


def ev(expr: str):
    return h.eval(view, expr)


def check(cond, what: str) -> None:
    if not cond:
        print("FAIL:", what, file=sys.stderr)
        sys.exit(1)


def item(name: str):
    found = h.eval(win, f"findItem('{name}')")
    check(found is not None, "item " + name)
    return found


def tile(wid: str):
    return item("bentoTile_" + wid)


def saved() -> list:
    return json.loads(ev("JSON.stringify(Config.layout.dashboard.grid.cells)"))


def key(k, mod=Qt.NoModifier) -> None:
    QTest.keyClick(win, k, mod)
    QTest.qWait(20)


QTest.qWait(50)
CW = (432 - 3 * 8) / 4  # 102 px cells, 110 px steps; rows are 100 + 8

# Normal mode: default grid, widgets get their cell size, unplaced hidden.
check(h.eval(tile("a"), "visible") and h.eval(tile("b"), "visible"), "placed tiles shown")
check(not h.eval(tile("c"), "visible"), "unplaced widget hidden")
check(h.eval(tile("b"), "x") == 110 and h.eval(tile("b"), "width") == 2 * CW + 8, "b geometry")
check(h.eval(tile("a"), "item.cellW") == CW and h.eval(tile("a"), "item.cellH") == 100, "cell size reaches the widget")
check(h.eval(tile("a"), "item.compact") is True, "1x1 tile is compact")
check(not h.eval(item("bentoToolbar"), "visible"), "no toolbar outside edit mode")

# Corrupt grid falls back to the default grid.
ev('Config.layout.dashboard.grid.cells = [{"widget": "ghost", "x": 0}, 42, "x"]')
QTest.qWait(20)
check(h.eval(tile("a"), "x") == 0 and h.eval(tile("b"), "x") == 110, "corrupt grid -> default")
ev("Config.layout.dashboard.grid.cells = []")

# Overlapping saved grid is compacted.
ev('Config.layout.dashboard.grid.cells = [{"widget": "a", "x": 0, "y": 0, "w": 2, "h": 1}, {"widget": "b", "x": 1, "y": 0, "w": 2, "h": 1}]')
QTest.qWait(20)
check(h.eval(tile("b"), "y") == 108, "overlap pushed down")
ev("Config.layout.dashboard.grid.cells = []")
QTest.qWait(20)

# Edit mode: chrome + toolbar, widget input blocked; leaving without changes saves nothing.
ev("editing = true")
QTest.qWait(20)
check(h.eval(item("bentoToolbar"), "visible"), "toolbar in edit mode")
check(h.eval(tile("a"), "editing") and not h.eval(tile("a"), "item.parent.enabled"), "widget input blocked")
ev("editing = false")
check(h.eval(win, "commits") == 0, "unchanged layout is not written")

# Drag tile a by (+220, +108) with the mouse: snaps to (2, 1).
ev("editing = true")
QTest.qWait(20)
p0 = QPoint(40, 40)
p1 = QPoint(40 + 220, 40 + 108)
QTest.mousePress(win, Qt.LeftButton, Qt.NoModifier, p0)
for i in range(1, 11):
    QTest.mouseMove(win, QPoint(p0.x() + (p1.x() - p0.x()) * i // 10, p0.y() + (p1.y() - p0.y()) * i // 10))
    QTest.qWait(10)
check(h.eval(item("bentoGhost"), "visible"), "snap ghost while dragging")
QTest.mouseRelease(win, Qt.LeftButton, Qt.NoModifier, p1)
QTest.qWait(30)
check(json.loads(ev("JSON.stringify(cellOf(working, 'a'))")) == {"widget": "a", "x": 2, "y": 1, "w": 1, "h": 1},
      "drag moved a to (2, 1): " + ev("JSON.stringify(working)"))
check(not h.eval(item("bentoGhost"), "visible"), "ghost gone after drop")

# Leaving edit mode (Escape) saves the grid.
ev("forceActiveFocus()")
key(Qt.Key_Escape)
check(ev("editing") is False, "Escape leaves edit mode")
check(h.eval(win, "commits") == 1, "saved once")
check({"widget": "a", "x": 2, "y": 1, "w": 1, "h": 1} in saved(), "saved cells hold the move")
check(h.eval(tile("a"), "x") == 220 and h.eval(tile("a"), "y") == 108, "tile at saved spot")

# Keyboard: Tab selects, arrows move, Shift+arrow resizes, Delete removes.
ev("editing = true")
QTest.qWait(20)
key(Qt.Key_Tab)
sel = ev("selectedId")
check(sel in ("a", "b"), "Tab selects a tile")
ev("selectedId = 'a'")
key(Qt.Key_Left)
check(ev("cellOf(working, 'a').x") == 1, "Left moves the tile")
key(Qt.Key_Right, Qt.ShiftModifier)
check(ev("cellOf(working, 'a').w") == 2, "Shift+Right widens the tile")
key(Qt.Key_Delete)
check(ev("cellOf(working, 'a')") is None, "Delete removes the tile")

# Picker: Insert opens it, Enter adds the first available widget.
key(Qt.Key_Insert)
picker = item("bentoPicker")
check(h.eval(picker, "visible") and h.eval(picker, "ids.length") == 2, "picker lists a and c")
key(Qt.Key_Return)
check(not h.eval(picker, "visible") and ev("cellOf(working, 'a') !== null"), "Enter adds the widget")

# Reset asks inline first.
h.eval(item("bentoReset"), "activated()")
check(h.eval(item("bentoToolbar"), "confirming") is True, "reset asks for confirmation")
h.eval(item("bentoResetCancel"), "activated()")
check(h.eval(item("bentoToolbar"), "confirming") is False, "cancel keeps the layout")
h.eval(item("bentoReset"), "activated()")
h.eval(item("bentoResetConfirm"), "activated()")
check(json.loads(ev("JSON.stringify(working)")) == [{"widget": "a", "x": 0, "y": 0, "w": 1, "h": 1},
                                                     {"widget": "b", "x": 1, "y": 0, "w": 2, "h": 1}], "reset to default")
h.eval(item("bentoDone"), "activated()")
check(ev("editing") is False and h.eval(win, "commits") == 2, "Done saves")

print("bento-edit: ok")
