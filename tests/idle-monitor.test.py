"""IdleMonitor talks to yozd without a shell and only checks media while idle.

The monitor polls `yozd system idle-monitor-get` every second; each poll used
to go through `sh -c`, doubling the process spawns. The media inhibitor check
can only clear `isIdle`, so it must not run (12 spawns/min) while active.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts' / 'lib'))
from lib.qmlharness import Harness  # noqa: E402
from brand import DAEMON  # noqa: E402

h = Harness('idle-monitor')
h.module('Quickshell.Io', {
    'Process': '''QtObject {
    default property list<QtObject> data
    property var command: []
    property bool running: false
    property QtObject stdout
    signal exited(int exitCode, int exitStatus)
    function finish(code, out) { if (stdout) stdout.text = out; running = false; exited(code, 0); }
}''',
    'StdioCollector': 'QtObject { property string text: "" }',
})
h.module('qs.modules.services', {'Unused': 'QtObject {}'})
h.module('qs.modules.globals', {})
h.copy('modules/services/IdleMonitor.qml', siblings=False)
root = h.load('Item { IdleMonitor { objectName: "mon"; timeout: 1 } }', auto_stub=False)
mon = h.find(root, 'mon')


ok_all = True


def check(name, ok, detail=''):
    global ok_all
    ok_all &= bool(ok)
    print(('PASS ' if ok else 'FAIL ') + name + (' ' + detail if detail else ''))


def cmd(proc):
    return list(h.eval(mon, f'{proc}.command').toVariant())


create = cmd('_createProcess')
check('create runs the daemon directly', create[:3] == [DAEMON, 'system', 'idle-monitor-create'], str(create))
h.eval(mon, '_createProcess.finish(0, \'{"id": 7}\')')
check('monitor id parsed', h.eval(mon, '_monitorId') == 7)

h.eval(mon, '_checkIdle()')
get = cmd('_getProcess')
check('poll runs the daemon directly', get == [DAEMON, 'system', 'idle-monitor-get', '7'], str(get))

check('media check idle while active', h.find(mon, 'mediaCheckTimer').property('running') is False)
h.eval(mon, '_getProcess.finish(0, \'{"is_idle": true}\')')
check('session reported idle', h.eval(mon, 'isIdle') is True)
check('media check runs while idle', h.find(mon, 'mediaCheckTimer').property('running') is True)
h.eval(mon, '_checkMediaInhibitor()')
media = cmd('_mediaCheckProcess')
check('media check runs the daemon directly', media == [DAEMON, 'system', 'media-inhibit-check'], str(media))
h.eval(mon, '_mediaCheckProcess.finish(0, \'{"count": 1}\')')
check('playing media clears idle', h.eval(mon, 'isIdle') is False)
check('media check stops once active again', h.find(mon, 'mediaCheckTimer').property('running') is False)

h.eval(mon, 'timeout = 2')
update = cmd('_updateProcess')
check('update runs the daemon directly', update == [DAEMON, 'system', 'idle-monitor-update', '7', '2000', '1', '1'], str(update))

sys.exit(0 if ok_all else 1)
