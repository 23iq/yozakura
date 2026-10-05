"""CarouselProgress (WavyLine) only animates while `active`.

The wave is a Canvas repainted from a FrameAnimation. `active: false`
(paused player) must stop the per-frame repaint, which otherwise runs at the
output's refresh rate forever, while shape changes still redraw it once.
"""
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402
from PySide6.QtCore import QCoreApplication, QElapsedTimer  # noqa: E402

h = Harness('wavy-line')
h.singleton('qs.modules.theme', 'Styling', 'QtObject { function srItem(n) { return "white"; } }')
h.singleton('qs.config', 'Config', 'QtObject {}')
h.copy('modules/components/CarouselProgress.qml')
root = h.load('''import QtQuick.Window
Window {
    id: w
    width: 300; height: 40; visible: true
    property int paints: 0
    property alias wave: cp
    CarouselProgress { id: cp; anchors.fill: parent; active: false; onPainted: w.paints++ }
}''', auto_stub=False)


def pump(ms):
    t = QElapsedTimer()
    t.start()
    while t.elapsed() < ms:
        QCoreApplication.processEvents()
        time.sleep(0.001)


ok_all = True


def check(name, ok, detail=''):
    global ok_all
    ok_all &= bool(ok)
    print(('PASS ' if ok else 'FAIL ') + name + (' ' + detail if detail else ''))


def paints_during(ms):
    pump(100)
    p0 = root.property('paints')
    pump(ms)
    return root.property('paints') - p0


idle = paints_during(600)
check('inactive wave does not repaint per frame', idle <= 1, f'({idle} paints in 600 ms)')

before = root.property('paints')
h.eval(root, 'wave.amplitudeMultiplier = 2')
pump(150)
check('inactive wave redraws once on shape change', root.property('paints') > before)

h.eval(root, 'wave.active = true')
running = paints_during(600)
check('active wave animates', running >= 10, f'({running} paints in 600 ms)')

h.eval(root, 'wave.active = false')
stopped = paints_during(600)
check('deactivating stops the animation', stopped <= 1, f'({stopped} paints in 600 ms)')

sys.exit(0 if ok_all else 1)
