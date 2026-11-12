"""CompileWarmUp (modules/shell/hosts/CompileWarmUp.qml) compiles, never creates.

The queue compiles each entry with Qt.createComponent(url, Asynchronous),
one at a time, only once start() was called, not while a window is open or
opening, keeps the ready Component objects, and never instantiates one (the
probe entries log when created). A broken entry only logs a warning and the
queue goes on. performance.warmViews = false stops it and releases what it
holds; start() runs the queue once.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402
from lib.waits import pump, wait_until  # noqa: E402
from PySide6.QtCore import QUrl, qInstallMessageHandler  # noqa: E402

messages = []
qInstallMessageHandler(lambda _mode, _ctx, msg: messages.append(msg))

h = Harness('compile-warm-up')
h.module('Quickshell', {'Singleton': 'QtObject { default property list<QtObject> data }'})
h.singleton('qs.config', 'Config', 'QtObject { property QtObject performance: QtObject { property bool warmViews: false } }')
h.singleton('qs.modules.globals', 'GlobalStates', 'QtObject { property bool settingsWindowVisible: false }')
h.singleton('qs.modules.services', 'Visibilities', 'QtObject { property string currentActiveModule: "" }')
h.copy('modules/shell/hosts/CompileWarmUp.qml', strip_singleton=True)

entries = []
for name, body in (
    ('ProbeA', 'Item { Component.onCompleted: console.log("PROBE-CREATED A") }'),
    ('Broken', 'Item { this is not qml'),
    ('ProbeB', 'Item { Component.onCompleted: console.log("PROBE-CREATED B"); Rectangle { width: 2 } }'),
):
    p = h.root / 'entries' / f'{name}.qml'
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text('import QtQuick\n' + body + '\n')
    entries.append(QUrl.fromLocalFile(str(p)).toString())

root = h.load('''import QtQuick
import qs.config
import qs.modules.globals
import qs.modules.services
Item {
    property alias warm: w
    CompileWarmUp {
        id: w
        base: ""
        entries: %s
        timing: ({ "startDelay": 60, "gap": 30, "busyRetry": 40 })
    }
}''' % ('[' + ', '.join(f'"{u}"' for u in entries) + ']'), auto_stub=False)

ok_all = True


def check(name, ok, detail=''):
    global ok_all
    ok_all &= bool(ok)
    print(('PASS ' if ok else 'FAIL ') + name + (' ' + detail if detail else ''))


def ev(expr):
    return h.eval(root, expr)


perf = h.engine.singletonInstance('qs.config', 'Config').property('performance')
vis = h.engine.singletonInstance('qs.modules.services', 'Visibilities')

pump(200)
check('nothing runs before start()', ev('warm.index') == 0 and not ev('warm.started'))

ev('warm.start()')
pump(300)
check('warmViews off: nothing is compiled', ev('warm.index') == 0 and ev('warm.compiled') == 0)

vis.setProperty('currentActiveModule', 'dashboard')
perf.setProperty('warmViews', True)
pump(300)
check('waits while a window is open', ev('warm.index') == 0 and ev('warm.compiled') == 0)

vis.setProperty('currentActiveModule', '')
check('compiles every entry once idle', wait_until(lambda: ev('warm.index') == 3, 5000), f'(index {ev("warm.index")})')
check('ready entries are held', ev('warm.compiled') == 2 and ev('warm.held.length') == 2)
check('held components are ready (status 1)', ev('warm.held.every(c => c.status === 1)') is True)
check('a broken entry is a warning, not a stop', ev('warm.failed') == 1
      and any('could not compile' in m and 'Broken.qml' in m for m in messages))
pump(200)
check('nothing is ever instantiated', not any('PROBE-CREATED' in m for m in messages),
      str([m for m in messages if 'PROBE' in m]))
check('the queue is idle when done', ev('warm.pending') is None)

ev('warm.start()')
pump(200)
check('start() runs the queue once', ev('warm.index') == 3 and ev('warm.compiled') == 2)

ev('warm.held[0].createObject(null).destroy()')  # control: a created probe does log
pump(50)
check('(control) the probe logs when it is created', any('PROBE-CREATED A' in m for m in messages))

perf.setProperty('warmViews', False)
check('turning warmViews off releases the held components', ev('warm.held.length') == 0)

print('CompileWarmUp:', 'PASS' if ok_all else 'FAIL')
sys.exit(0 if ok_all else 1)
