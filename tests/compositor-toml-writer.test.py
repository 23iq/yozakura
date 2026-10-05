"""CompositorTomlWriter coalesces compositor.write requests.

Every write spawns the yozakura CLI and makes the daemon regenerate and reload the
compositor config. A burst of changes (a preset load touches ~20 keys) must
produce one write with the final values; a request while a write is in
flight must run once afterwards (not be dropped); and the exit handler must
not pile up one extra connection per call.
"""
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402
from PySide6.QtCore import QCoreApplication, QElapsedTimer  # noqa: E402

h = Harness('compositor-toml-writer')
h.singleton('Quickshell', 'Quickshell', 'QtObject { function env(n) { return "/tmp"; } }')
h.module('Quickshell.Io', {
    'Process': '''QtObject {
    default property list<QtObject> data
    property var command: []
    property bool running: false
    property QtObject stdout
    property int starts: 0
    property var payloads: []
    signal exited(int exitCode, int exitStatus)
    onRunningChanged: if (running) { starts++; payloads = payloads.concat([command[command.length - 1]]); }
    function finish(code) { running = false; exited(code, 0); }
}''',
    'SplitParser': 'QtObject {}',
})
h.singleton('qs.config', 'Config', '''QtObject {
    property QtObject loader: QtObject { property bool loaded: false; signal fileChanged() }
    property QtObject keybindsLoader: QtObject { property var adapter: null; signal fileChanged(); signal adapterUpdated() }
    property bool keybindsInitialLoadComplete: false
    property QtObject compositor: QtObject {}
    property QtObject theme: QtObject {}
    property QtObject bar: QtObject {}
}''')
h.singleton('qs.modules.globals', 'GlobalStates', 'QtObject {}')

# gatherInput() reads the whole config tree; the test only needs a payload
# that says which revision of the state was sent.
# Repo layout under the harness root: the writer imports ../../config/CoreBinds.js.
writer_qml = h.copy('modules/services/CompositorTomlWriter.qml', 'modules/services', strip_singleton=True, replace={
    'function gatherInput() {': 'property int revision: 0\n'
                                '    function gatherInput() { return { revision: root.revision }; }\n'
                                '    function _realGatherInput() {',
})
writer = h.load(writer_qml)
h.allow_type_errors = True  # Singleton base type is stubbed by the auto-stubber


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


def proc(expr):
    return h.eval(writer, 'ipcProcess.' + expr)


# A burst of 20 changes in one tick -> one write carrying the last revision.
for i in range(1, 21):
    h.eval(writer, f'revision = {i}; callWrite()')
pump(400)
check('burst of 20 requests spawns one write', proc('starts') == 1, f'(starts={proc("starts")})')
check('the write carries the final state', '"revision":20' in str(proc('payloads[ipcProcess.payloads.length - 1]')))

# A request while the write is still running is queued, then sent once.
h.eval(writer, 'revision = 21; callWrite()')
pump(300)
check('no second spawn while a write is in flight', proc('starts') == 1)
h.eval(writer, 'ipcProcess.finish(0)')
pump(50)
check('queued request runs after the in-flight write', proc('starts') == 2, f'(starts={proc("starts")})')
check('queued write carries the newest state', '"revision":21' in str(proc('payloads[ipcProcess.payloads.length - 1]')))

# Exits do not accumulate handlers: a successful exit with nothing queued
# spawns nothing more, however many writes came before.
h.eval(writer, 'ipcProcess.finish(0)')
pump(300)
check('idle exit spawns nothing', proc('starts') == 2, f'(starts={proc("starts")})')

sys.exit(0 if ok_all else 1)
