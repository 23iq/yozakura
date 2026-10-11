"""Brightness.qml writes the monitor through one process at a time.

A DDC write takes 150-350 ms and ddcutil serialises concurrent calls. The
service used to spawn a detached `ddcutil setvcp` every 200 ms while the
value moved, building a backlog the monitor replayed late and out of order.
Every write now goes through a single Process per monitor: requests that
arrive while it runs collapse into the newest value.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402
from PySide6.QtCore import QEventLoop, QTimer  # noqa: E402

h = Harness('brightness-service')
h.singleton('testlog', 'Log', 'QtObject { property var started: [] }')
h.module('Quickshell', {
    'Singleton': 'QtObject { default property list<QtObject> data; property string reloadableId }',
    'ShellScreen': 'QtObject { property string name; property string model }',
    'Quickshell': 'pragma Singleton\nQtObject { property var screens: [s0]; '
                  'property QtObject s0: ShellScreen { name: "DP-1"; model: "Legion" } }',
})
h.module('Quickshell.Io', {
    'Process': '''import testlog
QtObject {
    property var command: []
    property bool running: false
    signal exited(int exitCode, int exitStatus)
    property var stdout
    function startDetached() { Log.started = Log.started.concat([{ detached: true, cmd: command }]); }
    function finish(code) { running = false; exited(code, 0); }
    onRunningChanged: if (running) Log.started = Log.started.concat([{ proc: this, cmd: command }]);
}''',
    'SplitParser': 'QtObject { property string splitMarker; signal read(string data) }',
    'IpcHandler': 'QtObject { default property list<QtObject> data; property string target }',
})
h.module('qs.modules.services', {
    'StateService': 'pragma Singleton\nQtObject { property bool initialized: false; signal stateLoaded(); '
                    'function get(k, d) { return d } function set(k, v) {} }',
    'SuspendManager': 'pragma Singleton\nQtObject { property bool isSuspending: false; signal wakingUp() }',
    'YozdService': 'pragma Singleton\nQtObject { property var focusedMonitor: ({ name: "DP-1" }) }',
})
h.copy('modules/services/Brightness.qml', strip_singleton=True, siblings=False)
root = h.load('import testlog\nItem { property var log: Log; Brightness { id: b } '
              'property var svc: b }', auto_stub=False)

failures = []


def check(cond, label):
    print(('PASS ' if cond else 'FAIL ') + label)
    if not cond:
        failures.append(label)


def writes():
    """Commands of every setvcp the service started, in order."""
    out = []
    for e in h.eval(root, 'log.started').toVariant():
        cmd = list(e['cmd'])
        if 'setvcp' in cmd or cmd[:1] == ['brightnessctl']:
            out.append((bool(e.get('detached')), cmd))
    return out


def settle(ms):
    loop = QEventLoop()
    QTimer.singleShot(ms, loop.quit)
    loop.exec()


h.eval(root, 'svc.ddcMonitors = [{ model: "", busNum: "4" }]')
check(h.eval(root, 'svc.monitors[0].isDdc') is True, 'screen resolves to a DDC monitor')
check(h.eval(root, 'svc.monitors[0].busNum') == '4', 'bus number comes from ddcutil detect')

# 1) a burst of requests starts exactly one write
h.eval(root, 'svc.monitors[0].setBrightness(0.50)')
for i in range(1, 31):
    h.eval(root, f'svc.monitors[0].setBrightness({0.50 + i / 100})')
w = writes()
check(len(w) == 1, f'31 requests start one write, got {len(w)}')
check(w and not w[0][0], 'the write runs in a tracked Process, not startDetached')
check(w and w[0][1][-3:] == ['setvcp', '10', '50'], f'first write is the first value: {w[0][1] if w else None}')
check(w and '--noverify' in w[0][1] and '--skip-ddc-checks' in w[0][1], 'fast ddcutil flags are used')

# 2) when it ends only the newest value follows, then nothing
h.eval(root, 'log.started[log.started.length - 1].proc.finish(0)')
w = writes()
check(len(w) == 2, f'one follow-up write after the first ends, got {len(w)}')
check(w[-1][1][-1] == '80', f'follow-up carries the newest value: {w[-1][1]}')
h.eval(root, 'log.started[log.started.length - 1].proc.finish(0)')
check(len(writes()) == 2, 'nothing is queued behind the follow-up')

# 3) no timer keeps spawning writes while idle (old code: one per 200 ms)
settle(600)
check(len(writes()) == 2, 'no periodic writes while the value is unchanged')

# 4) a ddcutil that rejects the fast flags is retried with plain ones
h.eval(root, 'svc.monitors[0].setBrightness(0.30)')
h.eval(root, 'log.started[log.started.length - 1].proc.finish(1)')
w = writes()
check(len(w) == 4, f'failed fast write is retried once, got {len(w)} writes')
check('--noverify' not in w[-1][1] and w[-1][1][-1] == '30', f'retry uses plain flags: {w[-1][1]}')

print('RESULT', 'FAIL' if failures else 'PASS')
h.exit(1 if failures else 0)
