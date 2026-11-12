"""NotchVisualizer redraws at the cava frame rate, never at the display's.

A height Behavior retargeted by every cava frame keeps an animation running
all the time, so the window repaints at the output refresh rate (240 Hz on
a 240 Hz monitor) while music plays. The visualizer must instead change
only when a frame arrives: this feeds a stub CavaService at 30 fps (below
the 60 Hz offscreen refresh, so animation-driven frames would show up) and
counts rendered frames. It also checks the bars still ease toward a new
level (smooth look) at the speed they had at 60 fps, settle on it, and that
frames which move no bar (silence, a held level) cause no redraw.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402
from PySide6.QtCore import QElapsedTimer  # noqa: E402
from lib.waits import pump, wait_until  # noqa: E402

h = Harness('notch-visualizer')
h.singleton('qs.config', 'Config', '''QtObject {
    property int animDuration: 300
    property QtObject notch: QtObject { property bool visualizer: true }
}''')
h.singleton('qs.modules.theme', 'Colors', 'QtObject { property color primary: "#ff0000"; property color tertiary: "#0000ff" }')
h.singleton('qs.modules.services', 'CavaService', '''QtObject {
    property bool available: true
    property var values: [0, 0, 0, 0, 0, 0]
    property int framerate: 30
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


ok_all = True


def check(name, ok, detail=''):
    global ok_all
    ok_all &= bool(ok)
    print(('PASS ' if ok else 'FAIL ') + name + (' ' + detail if detail else ''))


wait_until(lambda: root.property('swaps') > 0)  # shown and rendering
root.setProperty('feeding', True)
pump(200)  # warm up: the measured window starts with frames flowing
s0, f0 = root.property('swaps'), h.eval(root, 'CavaService.frames')
t = QElapsedTimer()
t.start()
pump(1200)  # ~36 cava frames: 60 Hz animation-driven redraws would stand out
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
check('settles on the level', h.eval(root, 'vis.children[0].height') == 60, str(h.eval(root, 'vis.children[0].height')))

# Same speed as before: 0.42 of the way per 60 fps frame is 0.66 per 30 fps
# frame (two 60 fps steps).
k = h.eval(root, 'vis.easing')
check('easing keeps the 60 fps speed at 30 fps', abs(k - (1 - 0.58 ** 2)) < 1e-9, f'({k})')

# Settled: a frame that moves no bar leaves `drawn` (and the window) alone.
root.setProperty('swaps', 0)
pump(100)
first_drawn = h.eval(root, 'vis.drawn')
for _ in range(10):
    h.eval(root, 'CavaService.push([1, 1, 1, 1, 1, 1])')
    pump(20)
check('settled frames keep the same drawn array', h.eval(root, 'vis.drawn').strictlyEquals(first_drawn))
check('settled frames cause no redraw', root.property('swaps') == 0, f'({root.property("swaps")} redraws)')

# Back to silence: the bars fall and stop at the flat level.
for _ in range(15):
    h.eval(root, 'CavaService.push([0, 0, 0, 0, 0, 0])')
pump(50)
check('falls back to silence', list(h.eval(root, 'vis.drawn').toVariant()) == [0] * 6, str(h.eval(root, 'vis.drawn').toVariant()))

# Inactive: bars are dropped and frames are ignored.
h.eval(root, 'vis.playing = false')
check('inactive clears the bars', h.eval(root, 'vis.drawn.length') == 0)
h.eval(root, 'CavaService.push([1, 1, 1, 1, 1, 1])')
check('inactive ignores frames', h.eval(root, 'vis.drawn.length') == 0)
h.eval(root, 'vis.playing = true')
check('reactivating starts at the current level', list(h.eval(root, 'vis.drawn').toVariant()) == [1] * 6)


def ease(expr):
    v = h.eval(root, f'vis.ease({expr})')
    return None if v is None or (hasattr(v, 'isNull') and v.isNull()) else list(v.toVariant() if hasattr(v, 'toVariant') else v)


check('ease: no previous bars start at the target', ease('[], [0.2, 1], 0.5') == [0.2, 1])
check('ease: one step of k', ease('[0, 0], [1, 1], 0.5') == [0.5, 0.5])
check('ease: k >= 1 jumps', ease('[0, 0], [1, 1], 1') == [1, 1])
check('ease: settled returns null', ease('[1, 0.5], [1, 0.5], 0.5') is None)
check('ease: close enough snaps onto the target', ease('[0.999, 1], [1, 1], 0.5') == [1, 1])
check('ease: only moving bars change', ease('[1, 0, 1], [1, 1, 1], 0.5') == [1, 0.5, 1])
check('ease: fewer bars shrink', ease('[1, 1, 1], [1, 1], 0.5') == [1, 1])
check('ease: more bars grow', ease('[1], [1, 1], 0.5') == [1, 1])
check('ease: prev is never mutated', h.eval(root, '(function () { const p = [0, 0]; vis.ease(p, [1, 1], 0.5); '
                                                  'return p[0] === 0 && p[1] === 0; })()') is True)

print('NotchVisualizer:', 'PASS' if ok_all else 'FAIL')
sys.exit(0 if ok_all else 1)
