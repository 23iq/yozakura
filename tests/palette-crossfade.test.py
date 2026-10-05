"""Construct Colors.qml with Quickshell types stubbed and check the palette crossfade.

A colors.json change must ease every role from the displayed value to the
new one (derived roles included), land exactly on the target, hand the
external-app generators only final colors, and snap when disabled.
"""
import json
import re
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402
from PySide6.QtCore import QCoreApplication, QElapsedTimer  # noqa: E402
from PySide6.QtGui import QColor  # noqa: E402
from PySide6.QtQml import QQmlExpression  # noqa: E402

h = Harness('palette-crossfade')
h.singleton('Quickshell', 'Quickshell', 'QtObject { function env(n) { return "/tmp"; } }')
h.module('Quickshell.Io', {
    'FileView': '''QtObject {
    default property list<QtObject> data
    property string path
    property bool preload
    property bool watchChanges
    property QtObject adapter
    property var pending: null
    signal fileChanged()
    function reload() { if (pending) { for (var k in pending) adapter[k] = pending[k]; pending = null; } }
}''',
    'JsonAdapter': 'QtObject {}',
})
h.singleton('qs.config', 'Config', '''QtObject {
    property bool oledMode: false
    property int animDuration: 300
    property QtObject loader: QtObject { signal fileChanged() }
    property QtObject theme: QtObject { property int paletteTransitionDuration: 600 }
}''')

h.module('qs.modules.globals', {})  # real Brand singleton (cache dir)

# Colors.qml + its relative JS imports; generators are replaced by recorders.
colors_qml = h.copy('modules/theme/Colors.qml', strip_singleton=True, siblings=False)
for g in sorted(set(re.findall(r'\b(\w+Generator)\s*\{', colors_qml.read_text()))):
    h.stub(g, 'QtObject { property var calls: []; function generate(c) { calls = calls.concat([{ t: Date.now(), '
              'primary: c.primary.toString(), crossfading: c._crossfading }]); } }')
colors = h.load(colors_qml, auto_stub=False)
engine = h.engine

def pump(ms):
    t = QElapsedTimer(); t.start()
    while t.elapsed() < ms:
        QCoreApplication.processEvents(); time.sleep(0.001)

def col(name):
    return QColor(colors.property(name))

ok_all = True
def check(name, ok, detail=''):
    global ok_all
    ok_all &= bool(ok)
    print(('PASS ' if ok else 'FAIL ') + name + (' ' + detail if detail else ''))

start_primary = col('primary').name()
start_surface = col('surface').name()
adapter = colors.property('adapter')
# New palette arrives on disk.
colors.setProperty('pending', {'primary': '#00ff00', 'overBackground': '#000000', 'background': '#ffffff'})
colors.fileChanged.emit()

samples = []
t = QElapsedTimer(); t.start()
while t.elapsed() < 900:
    QCoreApplication.processEvents()
    samples.append((t.elapsed(), col('primary').green(), colors.property('_crossfading')))
    time.sleep(0.005)
greens = [g for _, g, _ in samples]
mid = [g for ms, g, _ in samples if 250 < ms < 350]
check('primary starts at old value', greens[0] == QColor(start_primary).green(), f'{greens[0]}')
check('primary passes through intermediate values', any(20 < g < 235 for g in greens), f'mid={mid[:3]}')
check('monotonic', all(b >= a for a, b in zip(greens, greens[1:], strict=False)))
check('lands on target', col('primary').name() == '#00ff00', col('primary').name())
check('crossfade flag cleared', colors.property('_crossfading') is False)
check('derived surface updated', col('surface').name() != start_surface and col('background').name() == '#ffffff', col('surface').name())
steps = len(set(greens))
check('stepped at ~60Hz (bounded updates)', steps < 60, f'distinct values={steps}')

pump(300)
calls = json.loads(QQmlExpression(engine.rootContext(), colors, 'JSON.stringify(qtCtGenerator.calls)').evaluate()[0])
check('generators ran once after crossfade with final colors', len(calls) == 1 and calls[0]['primary'] == '#00ff00' and not calls[0]['crossfading'], str(calls))

# Disabled: snap
colors.setProperty('pending', {'primary': '#0000ff'})
cfg = engine.singletonInstance('qs.config', 'Config')
cfg.property('theme').setProperty('paletteTransitionDuration', 0)
colors.fileChanged.emit()
QCoreApplication.processEvents()
check('duration 0 snaps immediately', col('primary').name() == '#0000ff' and colors.property('_crossfading') is False, col('primary').name())

print('PaletteCrossfade:', 'PASS' if ok_all else 'FAIL')
sys.exit(0 if ok_all else 1)
