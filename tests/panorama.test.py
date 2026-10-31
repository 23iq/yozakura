"""Panorama wallpaper: slots per workspace, pan, depth detection and depth layering.

PanoramaView scales a wide image to the screen height and places the viewport
on the active workspace's slot; the first placement jumps, later moves glide
(Motion.pan) and settle exactly on the slot. A <name>.depth.png found by the
wallpaper scan turns on the depth layers; without one the view is one plain
layer. WallpaperForeground (desktop.depthLayering) draws the near layer over
the desktop exactly where the wallpaper has it, only when enabled and when
depth exists. PanoramaSlot follows niri's per-output order.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402
from PIL import Image  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

h = Harness('panorama')
img_dir = h.root / 'walls'
img_dir.mkdir()
Image.new('RGB', (3000, 500), (40, 60, 90)).save(img_dir / 'wide.png')
Image.new('L', (3000, 500), 200).save(img_dir / 'wide.depth.png')
Image.new('RGB', (3000, 500), (90, 60, 40)).save(img_dir / 'flat.png')
WIDE, DEPTH, FLAT = (str(img_dir / n) for n in ('wide.png', 'wide.depth.png', 'flat.png'))

h.singleton('qs.modules.theme', 'Motion', '''QtObject {
    component Token: QtObject { property int duration: 0; property int easing: Easing.InOutCubic }
    property Token pan: Token { duration: 120 }
}''')
palette = ["background", "overBackground", "shadow", "surface", "surfaceBright", "surfaceDim", "surfaceContainer", "surfaceContainerHigh", "surfaceContainerHighest", "surfaceContainerLow", "surfaceContainerLowest", "primary", "secondary", "tertiary", "red", "lightRed", "green", "lightGreen", "blue", "lightBlue", "yellow", "lightYellow", "cyan", "lightCyan", "magenta", "lightMagenta"]
h.singleton('qs.modules.theme', 'Colors', 'QtObject {\n' + '\n'.join(f'    property color {n}: "#808080"' for n in palette) + '\n}')
h.singleton('qs.modules.services', 'DepthMaskService', '''QtObject { property bool available: false; property int revision: 0
    function result(p, w, h) { return null } function request(p, w, h) {} }''')
h.singleton('qs.modules.services', 'YozdService', '''QtObject {
    property int activeId: 1; property string compositorName: "hyprland"
    property QtObject workspaces: QtObject { property var values: [] }
    function monitorFor(s) { return { name: "DP-1", activeWorkspace: { id: activeId } } } }''')
h.singleton('qs.config', 'Config', '''QtObject {
    property QtObject workspaces: QtObject { property int shown: 3 }
    property QtObject desktop: QtObject { property string wallpaperMode: "panorama"; property bool panoramaParallax: true; property bool depthLayering: false }
}''')
h.singleton('qs.modules.globals', 'GlobalStates', f'''QtObject {{
    property QtObject wallpaperManager: QtObject {{
        property string currentWallpaper: "{WIDE}"; property var perScreenWallpapers: ({{}}); property var depthMaps: ["{DEPTH}"]
        property bool tintEnabled: false
        function getFileType(p) {{ return "image" }}
    }}
}}''')
for f in ('PanoramaView', 'WallpaperForeground', 'PanoramaSlot'):
    h.copy(f'modules/desktop/panorama/{f}.qml')

root = h.load('''import QtQuick
import qs.modules.services
import qs.modules.globals
import qs.config
Item {
    width: 1000; height: 500
    PanoramaSlot { id: slot; objectName: "slot" }
    PanoramaView {
        objectName: "view"
        anchors.fill: parent
        sourceFile: GlobalStates.wallpaperManager.currentWallpaper
        sourceHeight: 500
        slotIndex: slot.index
        slotCount: slot.count
        depthMaps: GlobalStates.wallpaperManager.depthMaps
    }
    WallpaperForeground { objectName: "fg"; anchors.fill: parent }
}''')
view, fg, slot = h.find(root, 'view'), h.find(root, 'fg'), h.find(root, 'slot')
yozd = h.eval(root, 'YozdService')
desk = h.eval(root, 'Config.desktop')
manager = h.eval(root, 'GlobalStates.wallpaperManager')


def ev(obj, expr):
    return h.eval(obj, expr)


def wait_for(cond, ms=3000):
    for _ in range(ms // 20):
        if cond():
            return True
        QTest.qWait(20)
    return cond()


assert wait_for(lambda: ev(view, 'contentReady') and ev(view, 'settled')), 'image never loaded'
# 3000x500 at height 500: 3 screens of 1000 px, slots a screen apart.
assert ev(view, 'geometry.width') == 3000 and ev(view, 'geometry.travel') == 2000
assert ev(view, 'targetX') == 0 and ev(view, 'pan.currentX') == 0, 'first placement jumps to slot 1'
assert wait_for(lambda: ev(view, 'depthKind') == 'map'), ev(view, 'depthKind')
assert ev(view, 'layerCount') == 3

# Switching workspace glides to the slot and settles exactly on it.
yozd.setProperty('activeId', 3)
assert ev(view, 'targetX') == 2000
QTest.qWait(30)
assert ev(view, 'pan.moving'), 'the pan animates'
assert wait_for(lambda: not ev(view, 'pan.moving'))
assert ev(view, 'pan.currentX') == 2000
yozd.setProperty('activeId', 9)  # beyond `shown`: count grows, stays on the scroll
assert ev(slot, 'count') == 9 and 0 <= ev(view, 'targetX') <= 2000

# Depth layering: off by default, on draws the near layer aligned with the view.
assert not ev(fg, 'visible')
yozd.setProperty('activeId', 2)
assert wait_for(lambda: not ev(view, 'pan.moving'))
desk.setProperty('depthLayering', True)
assert wait_for(lambda: ev(fg, 'visible')), 'foreground with a depth map'
assert wait_for(lambda: ev(fg, 'settled'))
assert ev(fg, 'targetX') == ev(view, 'targetX') == 1000

# Fill mode: the centred crop.
desk.setProperty('wallpaperMode', 'fill')
assert ev(fg, 'targetX') == 1000

# No depth map: one plain layer, nothing to layer over the desktop.
manager.setProperty('currentWallpaper', FLAT)
assert wait_for(lambda: ev(view, 'contentReady') and ev(view, 'depthKind') == 'none')
assert ev(view, 'layerCount') == 1
assert wait_for(lambda: not ev(fg, 'visible'))

# niri: per-output order, not ids.
yozd.setProperty('compositorName', 'niri')
ev(root, 'YozdService.workspaces.values = [{ id: 7, monitor: "DP-1" }, { id: 4, monitor: "HDMI" }, { id: 2, monitor: "DP-1" }]')
yozd.setProperty('activeId', 2)
assert ev(slot, 'index') == 1 and ev(slot, 'count') == 2, (ev(slot, 'index'), ev(slot, 'count'))
print('panorama: ok')
h.exit(0)
