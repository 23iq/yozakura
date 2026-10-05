"""NotchVisualizer redraws at the cava frame rate, never at the display's.

A height Behavior retargeted by every cava frame keeps an animation running
all the time, so the window repaints at the output refresh rate (240 Hz on
a 240 Hz monitor) while music plays. The visualizer must instead change
only when a frame arrives: this feeds a stub CavaService at 30 fps (below
the 60 Hz offscreen refresh, so animation-driven frames would show up) and
counts rendered frames. It also checks the bars still ease toward a new
level (smooth look) and settle on it.
"""
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402
from PySide6.QtCore import QCoreApplication, QElapsedTimer  # noqa: E402

h = Harness('notch-visualizer')
h.singleton('qs.config', 'Config', '''QtObject {
    property int animDuration: 300
    property QtObject notch: QtObject { property bool visualizer: true }
}''')
h.singleton('qs.modules.theme', 'Colors', 'QtObject { property color primary: "#ff0000"; property color tertiary: "#0000ff" }')
h.singleton('qs.modules.services', 'CavaService', '''QtObject {
    property bool available: true
    property var values: [0, 0, 0, 0, 0, 0]
    property int frames: 0
    function levels(count) { return values.slice(0, count); }
    function setConsumer(key, active) {}
    function push(v) { values = v; frames++; }
}''')
h.copy('modules/widgets/defaultview/NotchVisualizer.qml')
root = h.load('''import QtQuick
import QtQuick.Window
import qs.modules.services
Window {
    id: w
    width: 120; height: 60; visible: true
    property int swaps: 0
    property bool feeding: false
    property real phase: 0
    property alias vis: v
    onFrameSwapped: swaps++
    NotchVisualizer { id: v; anchors.fill: parent; barCount: 6; playing: true }
    Timer {
        interval: 33; repeat: true; running: w.feeding
        onTriggered: {
            w.phase += 1;
            const out = [];
            for (let i = 0; i < 6; i++) out.push(0.5 + 0.45 * Math.sin(w.phase * 0.7 + i));
            CavaService.push(out);
        }
    }
}''', auto_stub=False)


def pump(ms):
    t = QElapsedTimer()
    t.start()
    while t.elapsed() < ms:
        QCoreApplication.processEvents()
        time.sleep(0.0005)


ok_all = True


def check(name, ok, detail=''):
    global ok_all
    ok_all &= bool(ok)
    print(('PASS ' if ok else 'FAIL ') + name + (' ' + detail if detail else ''))


pump(300)
root.setProperty('feeding', True)
pump(300)
s0, f0 = root.property('swaps'), h.eval(root, 'CavaService.frames')
t = QElapsedTimer()
t.start()
pump(2000)
secs = t.elapsed() / 1000
root.setProperty('feeding', False)
fps = (root.property('swaps') - s0) / secs
cava = (h.eval(root, 'CavaService.frames') - f0) / secs
print(f'redraws: {fps:.1f} fps with cava at {cava:.1f} fps')
check('redraws only on cava frames', fps <= cava * 1.15 + 1, f'({fps:.1f} fps for {cava:.1f} cava fps)')

# Smooth: a jump eases over a few frames and then settles on the target.
h.eval(root, 'CavaService.push([0, 0, 0, 0, 0, 0])')
for _ in range(20):
    h.eval(root, 'CavaService.push([0, 0, 0, 0, 0, 0])')
pump(100)
low = h.eval(root, 'vis.children[0].height')
h.eval(root, 'CavaService.push([1, 1, 1, 1, 1, 1])')
pump(50)
first = h.eval(root, 'vis.children[0].height')
check('a jump eases in (not instant)', low < first < 60, f'({low:.1f} -> {first:.1f} of 60)')
for _ in range(15):
    h.eval(root, 'CavaService.push([1, 1, 1, 1, 1, 1])')
pump(50)
check('settles on the level', h.eval(root, 'vis.children[0].height') > 59, str(h.eval(root, 'vis.children[0].height')))

print('NotchVisualizer:', 'PASS' if ok_all else 'FAIL')
sys.exit(0 if ok_all else 1)
