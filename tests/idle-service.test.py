"""IdleService runs idle hooks as `sh -c <hook>` without generating QML.

executeCommand used to splice the configured hook into QML source for
Qt.createQmlObject; a hook with a newline, `${` or a quote broke the QML or
changed the command. The hook string must reach `sh -c` unchanged.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402

h = Harness('idle-service')
h.singleton('testlog', 'Log', 'QtObject { property var started: [] }')
h.module('Quickshell', {'Singleton': 'QtObject { default property list<QtObject> data }'})
h.module('Quickshell.Io', {'Process': '''import testlog
QtObject {
    property var command: []
    property bool running: false
    signal exited(int exitCode, int exitStatus)
    onRunningChanged: if (running) { var s = Log.started.slice(); s.push(command); Log.started = s; }
}'''})
h.singleton('qs.config', 'Config', 'QtObject { property var system: ({ idle: { general: {}, listeners: [] } }) }')
h.module('qs.modules.globals', {})
h.stub('IdleMonitor', 'QtObject { property int timeout; property bool respectInhibitors; property bool isIdle }')
for name in ('BackendService', 'SuspendManager', 'LockscreenService'):
    h.stub(name, 'pragma Singleton\nQtObject { function call() {} function addSubscription() { return 1 } '
                 'function onPrepareForSleep() {} function onWakingUp() {} function lock() {} }')
(h.root / 'app' / 'qmldir').write_text(
    'singleton BackendService 1.0 BackendService.qml\n'
    'singleton SuspendManager 1.0 SuspendManager.qml\nsingleton LockscreenService 1.0 LockscreenService.qml\n'
    'IdleMonitor 1.0 IdleMonitor.qml\nIdleService 1.0 IdleService.qml\n')
h.copy('modules/services/IdleService.qml', strip_singleton=True, siblings=False)
root = h.load('import testlog\nItem { property var log: Log; property string hook; IdleService { id: s } '
              'function run() { s.executeCommand(hook) } }', auto_stub=False)

HOOK = 'notify-send "a\\"b" \'c\' ${HOME} `x`\nbrightnessctl -s set 10% \\\\ end'
root.setProperty('hook', HOOK)
h.eval(root, 'run()')
got = [list(c) for c in h.eval(root, 'log.started').toVariant()]
ok = got == [['sh', '-c', HOOK]]
print(('PASS' if ok else 'FAIL') + f' idle hook reaches sh -c verbatim: {got!r}')
sys.exit(0 if ok else 1)
