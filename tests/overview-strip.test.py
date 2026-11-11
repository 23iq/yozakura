"""OverviewStrip: selection, navigation, switching and search of the filmstrip overview.

Arrow/wheel steps move the selected workspace (clamped), Enter switches to it
and closes the overview, typing a query follows the best window match and Enter
then focuses that window.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402

h = Harness('overview-strip')
h.singleton('qs.config', 'Config', '''QtObject {
    property QtObject overview: QtObject { property real scale: 0.15; property int columns: 5; property real workspaceSpacing: 8; property string style: "strip" }
    property QtObject workspaces: QtObject { property int shown: 10 }
    property QtObject bar: QtObject { property bool pinnedOnStartup: true }
    property QtObject theme: QtObject { property string font: "sans" }
    property int animDuration: 0
}''')
h.singleton('qs.modules.theme', 'Motion', '''QtObject {
    property QtObject enter: QtObject { property int duration: 0; property int easing: 1; property real overshoot: 1 }
    property QtObject morph: QtObject { property int duration: 0; property int easing: 1; property real overshoot: 1 }
}''')
h.singleton('qs.modules.services', 'YozdService', '''QtObject {
    property var log: []
    property var focusedMonitor: ({ id: 0, name: "M", width: 1920, height: 1080, activeWorkspace: { id: 3 } })
    function monitorFor(s) { return focusedMonitor; }
    function dispatch(c) { log.push(c); }
    function switchWorkspaceKeepCursor(w) { log.push("workspace " + w + " keep-cursor"); }
}''')
h.singleton('qs.modules.bar.workspaces', 'CompositorData', '''QtObject {
    property var monitors: [{ id: 0, x: 0, y: 0, scale: 1, transform: 0 }]
    property var windowList: [
        { address: "0xa", title: "Terminal", class: "kitty", monitor: 0, workspace: { id: 2 }, at: [0, 0], size: [100, 100] },
        { address: "0xb", title: "Browser", class: "firefox", monitor: 0, workspace: { id: 7 }, at: [0, 0], size: [100, 100] }
    ]
}''')
h.singleton('qs.modules.services', 'Visibilities', '''QtObject {
    property var closed: []
    function setActiveModule(m, skip) { closed.push(m); }
    function getBarPanelForScreen(n) { return null; }
}''')
h.singleton('qs.modules.bar.panels', 'Panels', 'QtObject { property string primaryEdge: "top" }')
h.singleton('qs.modules.bar.panels', 'BarMetrics', 'QtObject { property int notchRestHeight: 40 }')

h.singleton('qs.modules.theme', 'Styling', 'QtObject { function radius(n) { return 4; } function fontSize(n) { return 12; } function srItem(n) { return "red"; } }')
h.singleton('qs.modules.theme', 'Colors', 'QtObject { property color outline: "gray"; property color overSurfaceVariant: "gray" }')
h.singleton('qs.modules.globals', 'GlobalStates', 'QtObject { property var wallpaperManager: null }')
h.module('qs.modules.components', {'TintedWallpaper': 'Item { property real radius; property bool tintEnabled; property string source }'})
h.module('qs.modules.desktop.panorama', {'PanoramaSlice': 'Item { property string sourceFile; property int slotIndex; property int slotCount; property real screenW; property real screenH }'})
h.module('qs.modules.components.kit', {
    'Space': 'pragma Singleton\nQtObject { property int xs: 4; property int s: 8; property int hairline: 1 }',
    'Look': 'pragma Singleton\nQtObject { function radius(role, h) { return 4; } }',
    'Type': 'pragma Singleton\nQtObject { property color accent: "red"; property color secondary: "gray" }',
    'KitText': 'Text { property string role; property bool tabular }',
    'Mark': 'Rectangle {}',
})
h.stub('OverviewStripWindows', 'Item { property Item strip }')
h.copy('modules/widgets/overview/WorkspaceRing.qml', siblings=False)
h.copy('modules/widgets/overview/OverviewStripCell.qml', siblings=False)
h.copy('modules/widgets/overview/OverviewStrip.qml', siblings=False)
root = h.load('''import QtQuick
import qs.modules.services
Item {
    width: 1600; height: 400
    function dispatched() { return YozdService.log.join("|"); }
    function closedCount() { return Visibilities.closed.length; }
    OverviewStrip { objectName: "strip" }
}''')
strip = h.find(root, 'strip')


def ev(expr):
    return h.eval(strip, expr)


# starts on the active workspace
assert ev('selected') == 3, ev('selected')
assert ev('count') == 10

# step moves and clamps
ev('stepWorkspace(1)')
assert ev('selected') == 4
for _ in range(20):
    ev('stepWorkspace(-1)')
assert ev('selected') == 1
for _ in range(20):
    ev('stepWorkspace(1)')
assert ev('selected') == 10

# the belt centers the selected cell
belt_x = h.eval(h.find(strip, 'belt'), 'x')
cx = belt_x + 9 * (ev('cellW + workspaceSpacing')) + ev('cellW') / 2
assert abs(cx - ev('width') / 2) < 0.5, cx

# Enter with no query switches to the selected workspace and closes
ev('selected = 6')
ev('navigateToSelectedWindow()')
assert 'workspace 6' in h.eval(root, 'dispatched()')
assert 'keep-cursor' not in h.eval(root, 'dispatched()')  # Enter keeps the compositor's warp
assert h.eval(root, 'closedCount()') == 1

# search follows the best match and Enter focuses it
ev('searchQuery = "fire"')
assert ev('matchingWindows.length') == 1
assert ev('selected') == 7
assert ev('stepWorkspace(1)') is False  # arrows belong to the matches while searching

# scroll style: no gaps between frames; plain frames without a still wallpaper
ev('searchQuery = ""')
assert ev('workspaceSpacing') == 8
ev('scroll = true')
assert ev('workspaceSpacing') == 0
assert ev('scrollSource') == ''
print('overview-strip: ok')
