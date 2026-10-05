"""Render the wallpaper transition offscreen with shell services stubbed.

Loads the real WallpaperImage.qml (+ its slot/layer files) under a stub root
that provides the Wallpaper `host` API, and checks that every
style blends without black frames (image/video in both directions), that the
shader layer is torn down afterwards, and that "none"/fullscreen swap
instantly. Set WALLPAPER_TRANSITION_FRAMES=<dir> to save rendered frames.
Video cases need ffmpeg (skipped otherwise).
"""
import os, sys, pathlib, shutil, subprocess, tempfile, time, re
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import headless  # noqa: E402

# Video frames need a GL/display context: re-runs under a private Xvfb.
headless.ensure(gl=True)
from PySide6.QtGui import QGuiApplication, QImage
from PySide6.QtQuick import QQuickView
from PySide6.QtCore import QUrl, QObject, QMetaObject, Qt, QCoreApplication, QElapsedTimer, Q_ARG

REPO = pathlib.Path(__file__).resolve().parents[1]
WP = REPO / 'modules/widgets/dashboard/wallpapers'
FRAMES = os.environ.get('WALLPAPER_TRANSITION_FRAMES')
W, H = 1280, 720

app = QGuiApplication([])
tmp = pathlib.Path(tempfile.mkdtemp(prefix='yozakura-wp-transition-'))


def module(name, files):
    d = tmp / name.replace('.', '/')
    d.mkdir(parents=True)
    lines = ['module ' + name]
    for n, body in files.items():
        (d / (n + '.qml')).write_text(body)
        lines.append(('singleton ' if body.startswith('pragma Singleton') else '') + n + ' 1.0 ' + n + '.qml')
    (d / 'qmldir').write_text('\n'.join(lines))


module('qs.config', {'Config': '''pragma Singleton
import QtQuick
QtObject {
    property int animDuration: 300
    property QtObject desktop: QtObject { property string wallpaperTransition: "grow"; property int wallpaperTransitionDuration: 800; property bool depthClock: false; property bool depthClockVideo: true }
}'''})
module('qs.modules.globals', {'GlobalStates': '''pragma Singleton
import QtQuick
QtObject { property bool lockscreenVisible: false; property var wallpaperTransitionOrigin: null; property int videoSyncTick: 0 }'''})
palette = ["background", "overBackground", "shadow", "surface", "surfaceBright", "surfaceDim", "surfaceContainer", "surfaceContainerHigh", "surfaceContainerHighest", "surfaceContainerLow", "surfaceContainerLowest", "primary", "secondary", "tertiary", "red", "lightRed", "green", "lightGreen", "blue", "lightBlue", "yellow", "lightYellow", "cyan", "lightCyan", "magenta", "lightMagenta"]
module('qs.modules.desktop', {'DepthClock': 'import QtQuick\nItem { property string wallpaperPath; property bool isVideo; property bool matteActive; property bool tint; property bool suppressed; property Item frontHost; property bool canDepth: false; property bool depthActive: false }'})
module('qs.modules.services', {'DepthMaskService': '''pragma Singleton
import QtQuick
QtObject { property bool available: false; property int revision: 0; function result(p, w, h) { return null; } function request(p, w, h) {} function setMatteWanted(o, p) {} }'''})
module('qs.modules.theme', {'Colors': 'pragma Singleton\nimport QtQuick\nQtObject {\n' + '\n'.join(f'    property color {n}: "#808080"' for n in palette) + '\n}'})

src = (WP / 'Wallpaper.qml').read_text()
get_file_type = re.search(r'    function getFileType\(path\) \{.*?\n    \}\n', src, re.S).group(0)

app_dir = tmp / 'app'
app_dir.mkdir()
for f in ['WallpaperImage.qml', 'WallpaperSlot.qml', 'StaticWallpaper.qml', 'WallpaperTransitionLayer.qml', 'VideoWallpaper.qml', 'DepthMatteForeground.qml', 'depth_matte.frag.qsb', 'palette.frag.qsb', 'palette.vert.qsb', 'wallpaper_transition.frag.qsb']:
    shutil.copy(WP / f, app_dir / f)
(app_dir / 'Main.qml').write_text(f'''import QtQuick
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
    function setOrigin(x, y) {{ GlobalStates.wallpaperTransitionOrigin = {{ screen: "TEST-1", x: x, y: y, time: Date.now() }}; }}
    function setStyle(s, d) {{ Config.desktop.wallpaperTransition = s; Config.desktop.wallpaperTransitionDuration = d; }}
    readonly property string frontFile: wallImage.frontSlot.sourceFile
    readonly property bool frontReady: wallImage.frontSlot.contentReady
    readonly property string backFile: wallImage.backSlot.sourceFile
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
        }}
    }}
}}
''')

view = QQuickView()
view.engine().addImportPath(str(tmp))
view.setResizeMode(QQuickView.SizeRootObjectToView)
view.setSource(QUrl.fromLocalFile(str(app_dir / 'Main.qml')))
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
    black = 0
    for y in range(small.height()):
        for x in range(small.width()):
            c = small.pixelColor(x, y)
            if max(c.red(), c.green(), c.blue()) < 8:
                black += 1
    return black / (small.width() * small.height())


def anim():
    for c in wall.findChildren(QObject):
        if c.metaObject().className().startswith('QQuickNumberAnimation'):
            return c
    raise RuntimeError('transition animation not found')


def invoke(name, a, b):
    QMetaObject.invokeMethod(root, name, Qt.DirectConnection, Q_ARG('QVariant', a), Q_ARG('QVariant', b))


imgs = sorted((REPO / 'assets/wallpapers_example').glob('*.png'))
imgA, imgB = str(imgs[0]), str(imgs[min(4, len(imgs) - 1)])

root.setProperty('effectiveWallpaper', imgA)
check('initial image ready', wait_for(lambda: root.property('frontReady')))
pump(100)
grab('00_initial')

# Mid-transition stills per style, animation paused at fixed progress.
for i, (style, target) in enumerate([('grow', imgB), ('wipe', imgA), ('dissolve', imgB), ('fade', imgA)]):
    invoke('setStyle', style, 600000)
    if style == 'grow':
        invoke('setOrigin', W * 0.3, H * 0.65)
    root.setProperty('effectiveWallpaper', target)
    check(f'{style}: transition started', wait_for(lambda: wall.property('transitioning')))
    anim().setProperty('paused', True)
    for p in (0.25, 0.5, 0.75):
        wall.setProperty('progress', p)
        pump(30)
        bf = black_fraction(grab(f'{i + 1:02d}_{style}_{int(p * 100):02d}'))
        check(f'{style} p={p}: no black', bf < 0.02, f'black={bf:.3f}')
    QMetaObject.invokeMethod(wall, 'finishTransition', Qt.DirectConnection)
    pump(30)
    check(f'{style}: shader layer gone', not wall.property('transitioning'))
    # Deferred deletes are not processed here, so this also proves the
    # hideSource references are released synchronously.
    bf = black_fraction(grab(f'{i + 1:02d}_{style}_done'))
    check(f'{style}: final frame not black', bf < 0.02, f'black={bf:.3f}')


def run_sequence(label, target, style, duration=500):
    invoke('setStyle', style, duration)
    root.setProperty('effectiveWallpaper', target)
    worst, frames, started, saved = 0.0, 0, False, False
    t = QElapsedTimer(); t.start()
    while t.elapsed() < 8000:
        QCoreApplication.processEvents()
        img = grab()
        frames += 1
        worst = max(worst, black_fraction(img))
        if wall.property('transitioning'):
            started = True
            if not saved and wall.property('progress') > 0.4:
                grab(f'seq_{label}_mid')
                saved = True
        elif started:
            break
    pump(50)
    worst = max(worst, black_fraction(grab(f'seq_{label}_end')))
    check(f'{label}: transitioned', started and not wall.property('transitioning'), f'frames={frames}')
    check(f'{label}: no black frames', worst < 0.02, f'worst={worst:.3f}')
    check(f'{label}: old slot unloaded', root.property('backFile') == '')


if shutil.which('ffmpeg'):
    vidA, vidB = str(tmp / 'a.mp4'), str(tmp / 'b.mp4')
    subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-f', 'lavfi', '-i', 'testsrc2=size=640x360:rate=30', '-t', '2', '-c:v', 'libx264', '-pix_fmt', 'yuv420p', vidA], check=True)
    subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-f', 'lavfi', '-i', 'mandelbrot=size=640x360:rate=30', '-t', '2', '-c:v', 'libx264', '-pix_fmt', 'yuv420p', vidB], check=True)
    run_sequence('image_to_video', vidA, 'grow')
    pump(300)
    run_sequence('video_to_video', vidB, 'wipe')
    pump(300)
    run_sequence('video_to_image', imgA, 'dissolve')
else:
    print('SKIP video cases (ffmpeg not found)')
    root.setProperty('effectiveWallpaper', imgA)
    wait_for(lambda: root.property('frontFile') == imgA and not wall.property('transitioning') and not wall.property('pending'))

invoke('setStyle', 'none', 800)
root.setProperty('effectiveWallpaper', imgB)
ok = wait_for(lambda: root.property('frontFile') == imgB, 4000)
check('none: swaps without shader', ok and not wall.property('transitioning'))

invoke('setStyle', 'grow', 800)
root.setProperty('fullscreenActive', True)
root.setProperty('effectiveWallpaper', imgA)
ok = wait_for(lambda: root.property('frontFile') == imgA, 4000)
check('fullscreen: swaps instantly', ok and not wall.property('transitioning'))
root.setProperty('fullscreenActive', False)

invoke('setStyle', 'random', 400)
root.setProperty('effectiveWallpaper', imgB)
wait_for(lambda: wall.property('transitioning'))
pump(100)
root.setProperty('effectiveWallpaper', imgs[1].as_posix())
pump(50)
root.setProperty('effectiveWallpaper', imgA)
wait_for(lambda: root.property('frontFile') == imgA and not wall.property('transitioning') and not wall.property('pending'), 6000)
pump(100)
bf = black_fraction(grab('rapid_end'))
check('rapid changes settle on the last source', root.property('frontFile') == imgA and root.property('backFile') == '' and bf < 0.02)

shutil.rmtree(tmp, ignore_errors=True)
print('WallpaperTransition:', 'PASS' if all(results) else 'FAIL', f'({sum(results)}/{len(results)})')
sys.exit(0 if all(results) else 1)
