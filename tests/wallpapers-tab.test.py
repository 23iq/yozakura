"""Wallpapers tab, offscreen: the real WallpapersTab with its grid cell,
highlight and toggle components on a stub wallpaper manager.

Checks the filtered grid, the "current" label, search, click-to-apply (global
and per screen), the per-screen/OLED/tint toggles by mouse and keyboard and
the Tab cycle through the top bar.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402
from PySide6.QtCore import QPoint, Qt  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

WP = "modules/widgets/dashboard/wallpapers"
h = Harness("wallpapers-tab")
h.singleton("qs.config", "Config", """QtObject {
    property int animDuration: 0
    property QtObject theme: QtObject { property string font: "Sans"; property int fontSize: 12
        property bool oledMode: false; property bool lightMode: false }
}""")
h.module("qs.modules.theme", {
    "Colors": "pragma Singleton\nimport QtQuick\nQtObject { property color background: 'black'; property color overSurface: 'white'; "
              "property color surface: 'gray'; property color overSurfaceVariant: 'white'; property color overBackground: 'white' }",
    "Styling": "pragma Singleton\nimport QtQuick\nQtObject { function radius(x) { return x; } function srItem(x) { return 'red'; } }",
    "Metrics": "pragma Singleton\nimport QtQuick\nQtObject { property int bentoCell: 132 }",
    "Icons": "pragma Singleton\nimport QtQuick\nQtObject { property string accept: 'v'; property string circleNotch: 'o'; property string font: 'Sans' }",
})
h.module("qs.modules.components", {
    "StyledRect": "import QtQuick\nRectangle { property string variant }",
    "SearchInput": """import QtQuick
Item {
    property string text; property string placeholderText; property string iconText; property bool clearOnEscape
    property bool handleTabNavigation; property bool disableCursorNavigation; property real radius
    property int focusCalls: 0
    signal searchTextChanged(string text)
    signal escapePressed(); signal tabPressed(); signal shiftTabPressed()
    signal downPressed(); signal upPressed(); signal leftPressed(); signal rightPressed(); signal accepted()
    function focusInput() { focusCalls++; }
}""",
})
h.module("qs.modules.globals", {"GlobalStates": """pragma Singleton
import QtQuick
QtObject {
    property int wallpaperSelectedIndex: -1
    property var wallpaperManager: null
    property bool dashboardOpen: true
    property var origins: []
    function setWallpaperTransitionOrigin(item, x, y, screen) { origins = origins.concat([screen]); }
}"""})
h.module("qs.modules.services", {
    "YozdService": "pragma Singleton\nimport QtQuick\nQtObject { property var focusedMonitor: ({ name: 'DP-1' }) }",
    "I18n": "pragma Singleton\nimport QtQuick\nQtObject { function t(k) { return k; } }",
    "Visibilities": "pragma Singleton\nimport QtQuick\nQtObject { property string active: 'x'; function setActiveModule(m) { active = m; } }",
})
h.module("Quickshell.Widgets", {"ClippingRectangle": "import QtQuick\nRectangle {}"})

h.copy(f"{WP}/WallpapersTab.qml", siblings=False)
for f in ["WallpaperToggle", "WallpaperGridCell", "WallpaperGridHighlight"]:
    h.copy(f"{WP}/{f}.qml", siblings=False)
h.stub("FilterBar", """Item { property var activeFilters: []; implicitWidth: 300; height: 32
    signal escapePressedOnFilters(); signal tabPressed(); signal shiftTabPressed()
    function focusFilters() {} }""")
h.stub("SchemeSelector", """Item { implicitHeight: 48; property int opens: 0
    signal schemeSelectorClosed(); signal escapePressedOnScheme(); signal tabPressed(); signal shiftTabPressed()
    function openAndFocus() { opens++; } }""")

win = h.load("""import QtQuick
import QtQuick.Window
import qs.modules.globals
import qs.config
Window {
    id: w
    width: 1000; height: 700; visible: true
    property alias tab: tab
    QtObject {
        id: manager
        property var wallpaperPaths: ["/w/a.jpg", "/w/b.jpg", "/w/c.png", "/w/d.mp4", "/w/e.jpg", "/w/f.jpg", "/w/g.jpg", "/w/h.jpg"]
        property string currentWallpaper: "/w/c.png"
        property var perScreenWallpapers: ({})
        property bool tintEnabled: false
        property int thumbnailsVersion: 0
        property var calls: []
        function setWallpaper(p, screen) { calls = calls.concat([[p, screen || ""]]);
            if (screen) { var s = Object.assign({}, perScreenWallpapers); s[screen] = p; perScreenWallpapers = s; } }
        function clearPerScreenWallpaper(screen) { var s = Object.assign({}, perScreenWallpapers); delete s[screen]; perScreenWallpapers = s; }
        function getFileType(p) { return p.endsWith(".mp4") ? "video" : "image"; }
        function getSubfolderFromPath(p) { return ""; }
        function getThumbnailPath(p) { return "/nonexistent" + p; }
        function scanSubfolders() {}
    }
    Component.onCompleted: GlobalStates.wallpaperManager = manager
    WallpapersTab { id: tab; anchors.fill: parent }
}""")
ok = True


def check(name, cond, detail=""):
    global ok
    ok &= bool(cond)
    print(("PASS " if cond else "FAIL ") + name + (" " + detail if detail else ""))


def ev(expr):
    return h.eval(win, expr)


def js(expr):
    return json.loads(ev("JSON.stringify(" + expr + ")"))


WALK = """function walk(it) {{ if (({pred})) return it; var c = it.children || [];
    for (var i = 0; i < c.length; i++) {{ var r = walk(c[i]); if (r) return r; }} return null; }}"""


def find(pred_js):
    """First item under the window matching a JS predicate on `it`."""
    return ev(f"(function () {{ {WALK.format(pred=pred_js)} return walk(w.contentItem); }})()")


def center(pred_js):
    """Window coordinates of the centre of the first matching item."""
    p = js(f"""(function () {{ {WALK.format(pred=pred_js)} var it = walk(w.contentItem);
        var p = it.mapToItem(null, it.width / 2, it.height / 2); return [p.x, p.y]; }})()""")
    return QPoint(int(p[0]), int(p[1]))


QTest.qWait(150)  # centerTimer (50 ms) + layout
check("grid lists every wallpaper", js("tab.filteredWallpapers") == js("GlobalStates.wallpaperManager.wallpaperPaths"))
check("current wallpaper is selected on open", ev("tab.selectedIndex") == 2, str(ev("tab.selectedIndex")))
check("highlight label says current",
      find("it.text === 'wallpapers.current' && it.visible") is not None)

CELL = "it.isInViewport !== undefined && it.modelData === "
check("grid cell exists for each path", all(find(CELL + f"'{p}'") is not None for p in js("tab.filteredWallpapers")))
QTest.mouseClick(win, Qt.LeftButton, Qt.NoModifier, center(CELL + "'/w/e.jpg'"))
QTest.qWait(20)
check("click applies the wallpaper globally", js("GlobalStates.wallpaperManager.calls")[-1] == ["/w/e.jpg", ""])
check("click publishes the transition origin", js("GlobalStates.origins")[-1] == "DP-1")

# Per-screen toggle: label is the monitor name; toggling applies the current
# wallpaper to that screen, then clicks target the screen.
per_screen = find("it.label === 'DP-1' && it.toggleEnabled !== undefined")
check("per-screen toggle shows the monitor", per_screen is not None)
ev("tab.togglePerScreenMode()")
check("per-screen on applies the current wallpaper to the screen",
      js("GlobalStates.wallpaperManager.calls")[-1] == ["/w/c.png", "DP-1"] and ev("tab.isPerScreen") is True)
QTest.mouseClick(win, Qt.LeftButton, Qt.NoModifier, center(CELL + "'/w/f.jpg'"))
QTest.qWait(20)
check("click targets the screen in per-screen mode", js("GlobalStates.wallpaperManager.calls")[-1] == ["/w/f.jpg", "DP-1"])
check("current label follows the screen's wallpaper", ev("tab.screenWallpaper") == "/w/f.jpg")

# Keyboard: Tab cycles per-screen -> OLED -> tint -> scheme -> filters -> search.
ev("tab.focusNextElement()")
check("Tab focuses the per-screen toggle", ev("tab.currentFocusIndex") == 0)
QTest.keyClick(win, Qt.Key_Space)
check("Space toggles per-screen off", ev("tab.isPerScreen") is False)
QTest.keyClick(win, Qt.Key_Tab)
check("Tab moves to OLED", ev("tab.currentFocusIndex") == 1)
QTest.keyClick(win, Qt.Key_Return)
check("Enter toggles OLED", ev("Config.theme.oledMode") is True)
ev("Config.theme.lightMode = true")
QTest.keyClick(win, Qt.Key_Space)
check("OLED is locked in light mode", ev("Config.theme.oledMode") is True)
QTest.keyClick(win, Qt.Key_Tab)
QTest.keyClick(win, Qt.Key_Space)
check("Tab + Space toggles tint", ev("GlobalStates.wallpaperManager.tintEnabled") is True)
# Mouse on the tint box (the 40x40 check box at the right end of the toggle).
tint_box = js("""(function () { %s var t = walk(w.contentItem);
    var p = t.mapToItem(null, t.width - 24, t.height / 2); return [p.x, p.y]; })()""" % WALK.format(pred="it.label === 'wallpapers.tint'"))
QTest.mouseClick(win, Qt.LeftButton, Qt.NoModifier, QPoint(int(tint_box[0]), int(tint_box[1])))
check("clicking the tint box toggles it back", ev("GlobalStates.wallpaperManager.tintEnabled") is False)
ev("tab.focusPreviousElement(); tab.focusNextElement()")  # back to the tint toggle via keyboard
QTest.keyClick(win, Qt.Key_Tab, Qt.ShiftModifier)
check("Shift+Tab goes back to OLED", ev("tab.currentFocusIndex") == 1)
QTest.keyClick(win, Qt.Key_Escape)
check("Escape returns to search", ev("tab.currentFocusIndex") == -1)

# Search narrows the grid and selects the first hit.
ev("""(function () { function walk(it) { if (it.placeholderText === 'wallpapers.search') return it;
    var c = it.children || []; for (var i = 0; i < c.length; i++) { var r = walk(c[i]); if (r) return r; } return null; }
    walk(w.contentItem).searchTextChanged('d.mp'); })()""")
check("search filters by file name", js("tab.filteredWallpapers") == ["/w/d.mp4"] and ev("tab.selectedIndex") == 0)
h.exit(0 if ok else 1)
