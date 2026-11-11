"""Clicking a window in the overview (grid, strip and scrolling views).

One left click on a preview closes the overview and activates that window
(OverviewActivation: the request at once and again after the unmap); there
is no double click. A middle click closes the window instead, and a press
that turns into a drag activates nothing (a drop on another workspace still
moves the window). The compositor pushes the whole window list on every
event (a terminal title spinner: several per second); the preview under a
pressed button outlives such an update, so the click is not lost.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from lib.kit_env import KitEnv  # noqa: E402
from lib.settings_env import global_states_qml  # noqa: E402
from lib.waits import settle  # noqa: E402

from PySide6.QtCore import QPoint, Qt  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

REPO = Path(__file__).resolve().parents[1]
FAILED = []


def check(cond, msg):
    if not cond:
        print("FAIL:", msg)
        FAILED.append(msg)


env = KitEnv("overview-click", overrides={"theme": {"animDuration": 0}})
h = env.h
h.module("qs.modules.globals", {"GlobalStates": global_states_qml({})
         .replace("property bool themeHasChanges", "property bool overviewOpen: true\n    property bool themeHasChanges")
         .replace("function nextWallpaper() {}", "function nextWallpaper() {}\n        property bool tintEnabled: false\n"
                  "        function getLockscreenFramePath(p) { return '' }")})
h.module("Quickshell.Wayland", {
    "ScreencopyView": "Item { property var captureSource: null; property bool live: false; property bool hasContent: false }",
    "ToplevelManager": "pragma Singleton\nQtObject { property QtObject toplevels: QtObject { property var values: [] } }",
})
h.module("qs.modules.components", {"TintedWallpaper": "Item { property real radius; property bool tintEnabled; property string source }"})
h.module("qs.modules.services", {
    "YozdService": """pragma Singleton
QtObject {
    property string compositorName: "hyprland"
    property var focusedMonitor: ({ id: 0, name: "A", width: 1920, height: 1080, activeWorkspace: { id: 1 } })
    property QtObject clients: QtObject { property var values: [] }
    property var log: []
    function monitorFor(screen) { return focusedMonitor }
    function dispatch(command) { log = log.concat([command]) }
    function switchWorkspaceKeepCursor(w) { log = log.concat(["workspace " + w + " keep-cursor"]) }
}""",
    "Visibilities": """pragma Singleton
QtObject {
    property string currentActiveModule: "overview"
    property var calls: []
    function setActiveModule(moduleName) {
        calls = calls.concat([[moduleName, arguments.length]]);
        currentActiveModule = moduleName;
    }
    function getBarPanelForScreen(name) { return null }
}""",
    "AppSearch": "pragma Singleton\nQtObject { function guessIcon(c) { return '' } }",
})
h.module("qs.modules.bar.workspaces", {"CompositorData": """pragma Singleton
QtObject {
    property var monitors: [{ id: 0, x: 0, y: 0, scale: 1, transform: 0, width: 1920, height: 1080 }]
    property var windowList: []
    readonly property var windowByAddress: {
        const map = {};
        windowList.forEach(w => map[w.address] = w);
        return map;
    }
    function updateWindowList() {}
}"""})
h.module("qs.modules.bar.panels", {"Panels": 'pragma Singleton\nQtObject { property string primaryEdge: "top" }'})
h.module("qs.modules.desktop.panorama", {
    "PanoramaSlice": "Item { property string sourceFile; property int slotIndex; property int slotCount; property real screenW; property real screenH }"})
OVERVIEW = "modules/widgets/overview"
for f in sorted((REPO / OVERVIEW).glob("*.qml")) + sorted((REPO / OVERVIEW).glob("*.js")):
    if f.name != "OverviewPopup.qml":
        h.copy(f"{OVERVIEW}/{f.name}", "qs/modules/widgets/overview", siblings=False)
h.module("qs.modules.widgets.overview", {})

SCENE = """import QtQuick
import QtQuick.Window
import qs.modules.services
import qs.modules.bar.workspaces
import qs.modules.widgets.overview
Window {
    id: win
    width: 1700; height: 640; visible: true
    property var yozd: YozdService
    property var vis: Visibilities

    function setWindows(list) {
        YozdService.clients.values = list;
        CompositorData.windowList = list;
    }
    // The preview of a window: the outermost item showing it.
    function preview(item, address) {
        if (item.windowData && item.windowData.address === address && item.hovered !== undefined)
            return item;
        for (let i = 0; i < item.children.length; i++) {
            const found = preview(item.children[i], address);
            if (found)
                return found;
        }
        return null;
    }
    function centre(address) {
        const p = preview(win.contentItem, address);
        return p ? p.mapToItem(null, p.width / 2, p.height / 2) : null;
    }
    // The open overview's layer surface, as OverviewPopup reports it.
    function mapSurface(mapped) {
        OverviewActivation.setMapped(surface, mapped);
    }
    Item { id: surface }
    property var view: view
    %s
}"""
VIEWS = {
    "grid": 'Overview { id: view; anchors.centerIn: parent; currentScreen: ({ name: "A" }) }',
    "strip": 'OverviewStrip { id: view; anchors.centerIn: parent; currentScreen: ({ name: "A" }) }',
    "scrolling": 'ScrollingOverview { id: view; anchors.centerIn: parent; currentScreen: ({ name: "A" }) }',
}
FOCUS_A = "focuswindow address:0xa"


def windows(title_a="Terminal", title_b="Browser"):
    return [
        {"address": "0xa", "title": title_a, "class": "kitty", "monitor": 0, "workspace": {"id": 1, "name": "1"},
         "at": [100, 100], "size": [800, 600], "floating": False},
        {"address": "0xb", "title": title_b, "class": "firefox", "monitor": 0, "workspace": {"id": 1, "name": "1"},
         "at": [1000, 100], "size": [800, 600], "floating": False},
    ]


def exercise(name, view):
    """Every click scenario against one overview view."""
    win = env.load(SCENE % view)

    def ev(expr):
        return h.eval(win, expr)

    def log():
        return json.loads(ev("JSON.stringify(yozd.log)"))

    def closes():
        return json.loads(ev("JSON.stringify(vis.calls)"))

    def set_windows(list_):
        ev(f"setWindows(JSON.parse({json.dumps(json.dumps(list_))}))")
        settle()

    def fresh():
        """The overview open over two windows, its surface mapped, nothing logged."""
        ev("vis.currentActiveModule = 'overview'")
        set_windows(windows())
        ev("mapSurface(true)")
        ev("yozd.log = []; vis.calls = []")

    def at(address):
        p = ev(f"centre('{address}')")
        assert p is not None, f"{name}: no preview of {address}"
        return QPoint(round(p.x()), round(p.y()))

    def tag(msg):
        return f"{name}: {msg}"

    # One left click: the overview closes and the window is activated, once.
    fresh()
    QTest.mouseClick(win, Qt.LeftButton, Qt.NoModifier, at("0xa"))
    settle()
    check(closes() == [["", 1]], tag(f"one click closes the overview once: {closes()}"))
    check(log() == [FOCUS_A], tag(f"one click asks for the window once, at once: {log()}"))
    ev("mapSurface(false)")
    settle()
    check(log() == [FOCUS_A, FOCUS_A], tag(f"and once more after the overview unmapped: {log()}"))

    # A double click out of habit: two clicks, and still one request after the unmap.
    fresh()
    QTest.mouseDClick(win, Qt.LeftButton, Qt.NoModifier, at("0xa"))
    settle()
    check(log() == [FOCUS_A, FOCUS_A], tag(f"each click of a double click asks at once: {log()}"))
    ev("mapSurface(false)")
    settle()
    check(log() == [FOCUS_A, FOCUS_A, FOCUS_A], tag(f"a double click is confirmed once: {log()}"))

    # Middle click closes the window; the overview stays.
    fresh()
    QTest.mouseClick(win, Qt.MiddleButton, Qt.NoModifier, at("0xa"))
    settle()
    check(log() == ["closewindow address:0xa"], tag(f"middle click closes the window: {log()}"))
    check(closes() == [], tag("middle click leaves the overview open"))

    # Press, drag past the threshold, release: a drag, not a click.
    fresh()
    start = at("0xa")
    QTest.mousePress(win, Qt.LeftButton, Qt.NoModifier, start)
    for dx in (6, 12, 18, 24, 30):
        QTest.mouseMove(win, start + QPoint(dx, 2))
    QTest.mouseRelease(win, Qt.LeftButton, Qt.NoModifier, start + QPoint(30, 2))
    settle()
    check(closes() == [] and not any(c.startswith("focuswindow") for c in log()),
          tag(f"a drag activates nothing: {closes()} {log()}"))
    check(at("0xa") == start, tag(f"a tiled window dropped on its own workspace goes back: {at('0xa')} != {start}"))
    # ... and still follows the layout afterwards (the preview is not rebuilt).
    moved = windows()
    moved[0]["at"] = [300, 100]
    set_windows(moved)
    check(at("0xa").x() - start.x() == 30, tag(f"a dragged preview follows its window again: {at('0xa')} from {start}"))

    # The window list is pushed again between press and release (another
    # window's title, then this one's): the click still lands.
    fresh()
    spot = at("0xa")
    QTest.mousePress(win, Qt.LeftButton, Qt.NoModifier, spot)
    set_windows(windows(title_b="Browser - loading"))
    set_windows(windows(title_a="Terminal - make", title_b="Browser - loading"))
    QTest.mouseRelease(win, Qt.LeftButton, Qt.NoModifier, spot)
    settle()
    check(closes() == [["", 1]] and log() == [FOCUS_A],
          tag(f"the click survives a window list update: {closes()} {log()}"))

    # Enter on a search match takes the same path.
    fresh()
    ev("view.searchQuery = 'term'")
    ev("view.navigateToSelectedWindow()")
    check(closes() == [["", 1]] and log() == [FOCUS_A], tag(f"Enter on a match closes and asks once: {closes()} {log()}"))
    ev("view.searchQuery = ''")

    # A window that closed takes its preview with it, the rest stay.
    fresh()
    set_windows(windows()[1:])
    check(ev("centre('0xa')") is None and ev("centre('0xb')") is not None, tag("a closed window loses its preview"))

    if name == "grid":
        # A drop on another workspace still moves the window (workspace 2 is the next cell).
        fresh()
        start = at("0xa")
        step = round(ev("view.workspaceImplicitWidth + view.workspacePadding + view.workspaceSpacing"))
        QTest.mousePress(win, Qt.LeftButton, Qt.NoModifier, start)
        for i in range(1, 11):
            QTest.mouseMove(win, start + QPoint(step * i // 10, 0))
        QTest.mouseRelease(win, Qt.LeftButton, Qt.NoModifier, start + QPoint(step, 0))
        settle()
        check("movetoworkspacesilent 2, address:0xa" in log(), tag(f"a drop on workspace 2 moves the window: {log()}"))
        check(closes() == [] and FOCUS_A not in log(), tag("a drop does not activate the window"))
        check(at("0xa") == start, tag(f"the preview waits in its cell for the compositor: {at('0xa')} != {start}"))
        moved = windows()
        moved[0]["workspace"] = {"id": 2, "name": "2"}
        set_windows(moved)
        check(at("0xa") == start + QPoint(step, 0), tag(f"the preview moves to the new workspace: {at('0xa')} from {start}"))
    ev("mapSurface(false)")
    win.close()


for view_name, view_qml in VIEWS.items():
    exercise(view_name, view_qml)

if FAILED:
    print(f"overview-click: {len(FAILED)} failed")
    h.exit(1)
print("overview-click: ok")
h.exit(0)
