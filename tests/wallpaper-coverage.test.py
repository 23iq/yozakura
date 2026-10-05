"""WallpaperCoverage.qml: the video wallpaper pauses when windows hide it.

Real WallpaperCoverage.qml/.js with stubbed CompositorData, Visibilities,
Config and Styling: a gapless tiled window covers, gaps do not, the shell's
reserved strips count only when they are opaque edge to edge, and the
performance.pauseWallpaperWhenCovered toggle turns it off.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402

h = Harness('wallpaper-coverage')
h.singleton('qs.config', 'Config', '''QtObject {
    property int compositorBorderSize: 0
    property QtObject bar: QtObject { property bool frameEnabled: true; property bool containBar: true; property var layout: ({ style: "classic" }) }
    property QtObject theme: QtObject { property var srBarBg: ({ opacity: 1 }) }
    property QtObject performance: QtObject { property bool pauseWallpaperWhenCovered: true }
}''')
h.singleton('qs.modules.theme', 'Styling', 'QtObject { property real frameOpacity: 1; function getStyledRectConfig(v) { return { opacity: frameOpacity }; } }')
h.singleton('qs.modules.bar.workspaces', 'CompositorData', 'QtObject { property var windowList: [] }')
h.module('qs.modules.services', {
    'Visibilities': '''pragma Singleton
QtObject {
    property var reservations: ({ "DP-1": res })
    property QtObject res: QtObject {
        property int topZone: 56; property int bottomZone: 6; property int leftZone: 6; property int rightZone: 6
        property bool dockEnabled: false; property bool dockPinned: false; property bool sidebarEnabled: false; property bool sidebarPinned: false
    }
}''',
})
h.copy('modules/widgets/dashboard/wallpapers/WallpaperCoverage.qml')
root = h.load('''import QtQuick
import qs.config
import qs.modules.services
import qs.modules.theme
import qs.modules.bar.workspaces
import "."
WallpaperCoverage {
    screenName: "DP-1"
    monitor: ({ id: 0, x: 0, y: 0, width: 2560, height: 1440, scale: 1, transform: 0, activeWorkspace: { id: 1 } })
    enabled: Config.performance.pauseWallpaperWhenCovered
}''', auto_stub=False)

ok_all = True


def check(name, ok):
    global ok_all
    ok_all &= bool(ok)
    print(('PASS ' if ok else 'FAIL ') + name)


def windows(js):
    h.eval(root, f'CompositorData.windowList = {js}')


def covered():
    return h.eval(root, 'covered')


W = '{ monitor: 0, workspace: { id: 1 }, hidden: false, at: [%d, %d], size: [%d, %d] }'
check('no windows: wallpaper visible', not covered())
windows('[' + W % (0, 0, 2560, 1440) + ']')
check('gapless window covers', covered())
windows('[' + W % (22, 22, 2516, 1396) + ']')
check('gaps keep it playing', not covered())
# Inside an opaque frame with a contained bar: the reserved strips count.
windows('[' + W % (6, 56, 2548, 1378) + ']')
check('opaque frame + contained bar: work area covered', covered())
h.eval(root, 'Styling.frameOpacity = 0.8')
check('translucent frame: strips show the wallpaper', not covered())
h.eval(root, 'Styling.frameOpacity = 1')
h.eval(root, 'Visibilities.res.dockEnabled = true; Visibilities.res.dockPinned = true')
check('floating pinned dock leaves margins', not covered())
h.eval(root, 'Visibilities.res.dockPinned = false')
check('back to covered', covered())
h.eval(root, 'Config.performance.pauseWallpaperWhenCovered = false')
check('toggle off', not covered())

print('WallpaperCoverage:', 'PASS' if ok_all else 'FAIL')
sys.exit(0 if ok_all else 1)
