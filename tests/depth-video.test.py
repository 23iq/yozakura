"""Depth clock on video wallpapers: render the real WallpaperImage offscreen
with a synthetic stacked "matte video" and a stub clock.

The matte (colour on top, mask below, each half padded to 16 rows exactly
like scripts/depth_video.py) has the subject in the top-left quadrant. A
solid stub clock covers the centre. Checks that the matte variant is played
straight away when DepthMaskService already knows the matte, that the
subject is drawn above the clock exactly where the mask says (and nowhere
else), that toggling `desktop.depthClockVideo` swaps between the plain and
the matte variant of the same video without black frames, and that leaving
for an image still transitions cleanly.

Needs ffmpeg and a GL context: tests/lib/headless.py re-runs it under a
private Xvfb (offscreen has no GL here and renders shader effects
black).
Set DEPTH_VIDEO_FRAMES=<dir> to keep the rendered frames.
"""
import os
import pathlib
import re
import shutil
import subprocess
import sys
import time

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from lib import headless  # noqa: E402

# Needs GL: re-runs itself under a private Xvfb (never the live session).
headless.ensure(gl=True)
from lib.qmlharness import Harness  # noqa: E402
from PySide6.QtCore import Q_ARG, QCoreApplication, QElapsedTimer, QMetaObject, QObject, Qt, QUrl  # noqa: E402
from PySide6.QtGui import QColor, QImage  # noqa: E402
from PySide6.QtQuick import QQuickView  # noqa: E402

REPO = pathlib.Path(__file__).resolve().parents[1]
WP = REPO / 'modules/widgets/dashboard/wallpapers'
FRAMES = os.environ.get('DEPTH_VIDEO_FRAMES')
W, H = 1280, 720
SW, SH, PH = 640, 360, 368          # source size, padded half height

if not shutil.which('ffmpeg'):
    print('SKIP depth video (ffmpeg not found)')
    sys.exit(0)

h = Harness('depth-video')
tmp = h.root
module = h.module


plain = tmp / 'clip.mp4'
matte = tmp / 'clip.matte.mp4'
subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 'lavfi', '-i', f'testsrc2=size={SW}x{SH}:rate=30', '-t', '3',
                '-c:v', 'libx264', '-pix_fmt', 'yuv420p', str(plain)], check=True, timeout=60)
# Subject = top-left quadrant of the source.
subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(plain),
                '-f', 'lavfi', '-i', f'color=black:size={SW}x{SH}:rate=30,drawbox=x=0:y=0:w={SW // 2}:h={SH // 2}:color=white:t=fill',
                '-filter_complex', f'[0:v]format=yuv420p,pad={SW}:{PH}:0:0:black[c];[1:v]format=gray,pad={SW}:{PH}:0:0:black,format=yuv420p[m];[c][m]vstack=inputs=2:shortest=1[v]',
                '-map', '[v]', '-frames:v', '90', '-c:v', 'libx264', '-crf', '12', '-pix_fmt', 'yuv420p', str(matte)], check=True, timeout=60)

broken = tmp / 'broken.mp4'
broken_matte = tmp / 'broken.matte.mp4'
subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 'lavfi', '-i', f'mandelbrot=size={SW}x{SH}:rate=30', '-t', '2',
                '-c:v', 'libx264', '-pix_fmt', 'yuv420p', str(broken)], check=True, timeout=60)
broken_matte.write_bytes(b'not a video' * 100)

module('qs.config', {'Config': '''pragma Singleton
import QtQuick
QtObject {
    property int animDuration: 300
    property QtObject desktop: QtObject { property string wallpaperTransition: "fade"; property int wallpaperTransitionDuration: 300; property bool depthClock: true; property bool depthClockVideo: true }
}'''})
module('qs.modules.globals', {'GlobalStates': '''pragma Singleton
import QtQuick
QtObject { property bool lockscreenVisible: false; property var wallpaperTransitionOrigin: null; property int videoSyncTick: 0 }'''})
palette = ["background", "overBackground", "shadow", "surface", "surfaceBright", "surfaceDim", "surfaceContainer", "surfaceContainerHigh", "surfaceContainerHighest", "surfaceContainerLow", "surfaceContainerLowest", "primary", "secondary", "tertiary", "red", "lightRed", "green", "lightGreen", "blue", "lightBlue", "yellow", "lightYellow", "cyan", "lightCyan", "magenta", "lightMagenta"]
module('qs.modules.theme', {'Colors': 'pragma Singleton\nimport QtQuick\nQtObject {\n' + '\n'.join(f'    property color {n}: "#808080"' for n in palette) + '\n}'})
# Stub clock with the real interface: a solid block over the centre.
module('qs.modules.desktop', {'DepthClock': '''import QtQuick
Item {
    id: clock
    objectName: "clock"
    property string wallpaperPath
    property bool isVideo
    property bool matteActive
    property bool tint
    property bool suppressed
    property Item frontHost
    property color ink: "#ff0000"
    readonly property bool canDepth: true
    readonly property bool depthActive: canDepth && (!isVideo || matteActive)
    Rectangle { x: parent.width * 0.3; y: parent.height * 0.3; width: parent.width * 0.4; height: parent.height * 0.4; color: clock.ink }
}'''})
module('qs.modules.services', {'DepthMaskService': f'''pragma Singleton
import QtQuick
QtObject {{
    property bool available: true
    property int revision: 0
    property var wanted: ({{}})
    function result(p, w, h) {{
        revision;
        if (p === "{broken}")
            return {{ ok: true, matte: "{broken_matte}", matteInfo: {{ file: "{broken_matte}", width: {SW}, height: {SH}, paddedHeight: {PH} }} }};
        if (p !== "{plain}") return {{ ok: true }};
        return {{ ok: true, matte: "{matte}", matteInfo: {{ file: "{matte}", width: {SW}, height: {SH}, paddedHeight: {PH} }} }};
    }}
    function request(p, w, h) {{}}
    function setMatteWanted(o, p) {{ var n = Object.assign({{}}, wanted); n[o] = p; wanted = n; }}
}}'''})

src = (WP / 'Wallpaper.qml').read_text()
get_file_type = re.search(r'    function getFileType\(path\) \{.*?\n    \}\n', src, re.S).group(0)

# The real components (+ their shaders).
h.copy('modules/widgets/dashboard/wallpapers/WallpaperImage.qml')
h.copy('modules/widgets/dashboard/wallpapers/VideoWallpaper.qml')
h.copy('modules/widgets/dashboard/wallpapers/DepthMatteForeground.qml')
shutil.copy(WP / 'wallpaper_transition.frag.qsb', tmp / 'app')
main_qml = h.write(f'''import QtQuick
import QtQuick.Effects
import qs.modules.desktop
import qs.modules.globals
import qs.modules.services
import qs.modules.theme
import qs.config

Item {{
    id: wallpaper
    width: {W}; height: {H}
    property string effectiveWallpaper: ""
    property bool tintEnabled: false
    property bool videoPaused: false
    property bool fullscreenActive: false
    readonly property bool overviewBlurPossible: false
    readonly property bool overviewBlurActive: false
    property string currentScreenName: "TEST-1"
    readonly property string transitionStyle: Config.desktop.wallpaperTransition ?? "grow"
    readonly property int transitionDuration: Config.desktop.wallpaperTransitionDuration ?? 800
    property var activeVideo: null
    function requestVideoSync() {{}}
    function setDepthVideo(on) {{ Config.desktop.depthClockVideo = on; }}
    function setInk(c) {{ wallImage.clock.ink = c; }}
    readonly property string frontFile: wallImage.frontSlot.sourceFile
    readonly property bool frontReady: wallImage.frontSlot.contentReady
    readonly property bool frontMatte: wallImage.matteVideo !== null
    readonly property bool foregroundShown: wallImage.matteShowing && wallImage.clock !== null && wallImage.clock.depthActive
    readonly property string backFile: wallImage.backSlot.sourceFile
    readonly property string wanted: DepthMaskService.wanted["wallpaper:TEST-1"] ?? ""
{get_file_type}
    Rectangle {{
        id: background
        anchors.fill: parent
        color: "black"
        WallpaperImage {{
            id: wallImage
            objectName: "wallImage"
            anchors.fill: parent
            host: wallpaper
            source: wallpaper.effectiveWallpaper
            screenName: wallpaper.currentScreenName
        }}
    }}
}}
''', name='Main.qml')

view = QQuickView(h.engine, None)
view.setResizeMode(QQuickView.SizeRootObjectToView)
view.setSource(QUrl.fromLocalFile(str(main_qml)))
if view.status() != QQuickView.Ready:
    for e in view.errors():
        print('QML ERROR', e.toString())
    sys.exit(1)
view.show()
view.setGeometry(0, 0, W, H)
view.setMinimumSize(view.size())
view.setMaximumSize(view.size())
root = view.rootObject()
wall = root.findChild(QObject, 'wallImage')

results = []


def check(name, ok, detail=''):
    results.append(bool(ok))
    print(('PASS ' if ok else 'FAIL ') + name + (' ' + detail if detail else ''))


def pump(ms):
    t = QElapsedTimer(); t.start()
    while t.elapsed() < ms:
        QCoreApplication.processEvents()
        time.sleep(0.002)


def wait_for(pred, timeout=8000):
    t = QElapsedTimer(); t.start()
    while t.elapsed() < timeout:
        QCoreApplication.processEvents()
        if pred():
            return True
        time.sleep(0.002)
    return False


def grab(name=None):
    img = view.grabWindow()
    if FRAMES and name:
        pathlib.Path(FRAMES).mkdir(parents=True, exist_ok=True)
        img.save(str(pathlib.Path(FRAMES) / f'{name}.png'))
    return img


def black_fraction(img):
    small = img.scaled(160, 90).convertToFormat(QImage.Format_RGB32)
    black = sum(1 for y in range(small.height()) for x in range(small.width())
                if max(small.pixelColor(x, y).red(), small.pixelColor(x, y).green(), small.pixelColor(x, y).blue()) < 8)
    return black / (small.width() * small.height())


def px(img, fx, fy):
    return img.pixelColor(int(fx * W), int(fy * H))


def is_ink(c, ink):
    return abs(c.red() - ink.red()) < 12 and abs(c.green() - ink.green()) < 12 and abs(c.blue() - ink.blue()) < 12


def same(a, b, tol=10):
    return abs(a.red() - b.red()) <= tol and abs(a.green() - b.green()) <= tol and abs(a.blue() - b.blue()) <= tol


# 1) A video whose matte is known plays the matte variant right away.
root.setProperty('effectiveWallpaper', str(plain))
check('matte variant loaded first', wait_for(lambda: root.property('frontReady') and root.property('frontMatte')))
check('matte wanted for the shown video', root.property('wanted') == str(plain))
check('foreground drawn over the clock', wait_for(lambda: root.property('foregroundShown')))
pump(400)
check('first frame not black', black_fraction(grab('01_matte_playing')) < 0.02)

# 2) Subject (top-left source quadrant) above the clock, clock elsewhere.
root.setProperty('videoPaused', True)
pump(300)
red, blue = QColor('#ff0000'), QColor('#0000ff')
a = grab('02_paused_red')
root.setProperty('videoPaused', True)
QCoreApplication.processEvents()
root.findChild(QObject, 'clock').setProperty('ink', blue)
pump(100)
b = grab('03_paused_blue')
subject = [(0.35, 0.35), (0.45, 0.45), (0.33, 0.47)]      # mask = 1, inside the clock box
backdrop = [(0.6, 0.6), (0.35, 0.6), (0.65, 0.35)]        # mask = 0, inside the clock box
outside = [(0.1, 0.1), (0.9, 0.9), (0.2, 0.8)]
check('subject hides the clock', all(not is_ink(px(a, *p), red) and same(px(a, *p), px(b, *p)) for p in subject),
      str([px(a, *p).name() for p in subject]))
check('clock visible behind backdrop', all(is_ink(px(a, *p), red) and is_ink(px(b, *p), blue) for p in backdrop))
check('wallpaper untouched outside the clock', all(same(px(a, *p), px(b, *p)) for p in outside))
# Mask edge lands on the quadrant border (x = y = 0.5), proving framing and padding.
check('mask edge aligned (x)', not is_ink(px(a, 0.49, 0.4), red) and is_ink(px(a, 0.51, 0.4), red))
check('mask edge aligned (y)', not is_ink(px(a, 0.4, 0.49), red) and is_ink(px(a, 0.4, 0.51), red))
root.findChild(QObject, 'clock').setProperty('ink', red)
root.setProperty('videoPaused', False)


def watch_swap(label, want_matte):
    worst, started = 0.0, False
    t = QElapsedTimer(); t.start()
    while t.elapsed() < 8000:
        QCoreApplication.processEvents()
        worst = max(worst, black_fraction(grab()))
        if wall.property('pending') or wall.property('transitioning'):
            started = True
        elif started and root.property('frontMatte') == want_matte:
            break
    pump(50)
    worst = max(worst, black_fraction(grab(label)))
    check(f'{label}: swapped', started and root.property('frontMatte') == want_matte and root.property('frontFile') == str(plain))
    check(f'{label}: no black frames', worst < 0.02, f'worst={worst:.3f}')
    check(f'{label}: back slot unloaded', root.property('backFile') == '')


# 3) Toggle the feature: plain <-> matte variant of the same video.
QMetaObject.invokeMethod(root, 'setDepthVideo', Qt.DirectConnection, Q_ARG('QVariant', False))
watch_swap('04_to_plain', False)
check('foreground gone with the plain video', not root.property('foregroundShown'))
check('matte no longer wanted', root.property('wanted') == '')
QMetaObject.invokeMethod(root, 'setDepthVideo', Qt.DirectConnection, Q_ARG('QVariant', True))
watch_swap('05_to_matte', True)
check('foreground back', wait_for(lambda: root.property('foregroundShown'), 3000))

# 4) A corrupt/missing matte falls back to the plain video.
root.setProperty('effectiveWallpaper', str(broken))
ok = wait_for(lambda: root.property('frontFile') == str(broken) and not wall.property('pending') and not wall.property('transitioning') and root.property('frontReady'), 10000)
pump(300)
bf = black_fraction(grab('06_broken_matte'))
check('broken matte: plain video shown', ok and not root.property('frontMatte') and bf < 0.02, f'black={bf:.3f}')
check('broken matte: no foreground', not root.property('foregroundShown'))
root.setProperty('effectiveWallpaper', str(plain))
check('good matte still used afterwards', wait_for(lambda: root.property('frontFile') == str(plain) and root.property('frontMatte') and not wall.property('transitioning'), 8000))

# 5) Leaving the video for an image.
img = str(sorted((REPO / 'assets/wallpapers_example').glob('*.png'))[0])
root.setProperty('effectiveWallpaper', img)
worst = 0.0
t = QElapsedTimer(); t.start()
while t.elapsed() < 8000 and (root.property('frontFile') != img or wall.property('transitioning')):
    QCoreApplication.processEvents()
    worst = max(worst, black_fraction(grab()))
pump(50)
check('matte -> image: transitioned', root.property('frontFile') == img and not root.property('frontMatte'))
check('matte -> image: no black frames', worst < 0.02, f'worst={worst:.3f}')
check('foreground hidden on images', not root.property('foregroundShown'))

print('DepthVideo:', 'PASS' if all(results) else 'FAIL', f'({sum(results)}/{len(results)})')
# Tear the view down while the event loop still runs, then leave without
# the interpreter's global destructor pass (media backend threads must not
# be torn down from Python's atexit).
root.setProperty('effectiveWallpaper', '')
view.close()
pump(100)
h.exit(0 if all(results) else 1)
