"""IdleMonitor talks to yozd without a shell, learns idle flips by event and
only checks media while idle.

The monitor used to spawn `yozd system idle-monitor-get` every second for the
whole session. The backend now forwards the daemon's idle flips on the
`idlemon` subscription; the monitor polls only while that path is down (or a
daemon does not send the events), reads its state once when the path comes
up, after a daemon restart (a stale id recreates the monitor) and on a slow
safety timer. The media inhibitor check can only clear `isIdle`, so it must
not run (12 spawns/min) while active.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts' / 'lib'))
from lib.qmlharness import Harness  # noqa: E402
from lib.waits import pump, wait_until  # noqa: E402
from brand import DAEMON  # noqa: E402
from PySide6.QtCore import QMetaObject  # noqa: E402

h = Harness('idle-monitor')
h.module('Quickshell.Io', {
    'Process': '''QtObject {
    default property list<QtObject> data
    property var command: []
    property bool running: false
    property QtObject stdout
    property int starts: 0
    property string autoReply: ""
    signal exited(int exitCode, int exitStatus)
    onRunningChanged: {
        if (!running) return;
        starts++;
        if (autoReply !== "") Qt.callLater(() => { if (running) finish(0, autoReply); });
    }
    function finish(code, out) { if (stdout) stdout.text = out; running = false; exited(code, 0); }
}''',
    'StdioCollector': 'QtObject { property string text: "" }',
})
h.singleton('qs.modules.services', 'BackendService', '''QtObject {
    property bool socketAvailable: true
    property var subs: ({})
    property int nextKey: 1
    property int removed: 0
    function addSubscription(services, cb) {
        const k = nextKey++;
        subs[k] = {services: services, cb: cb};
        return k;
    }
    function removeSubscription(k) { delete subs[k]; removed++; }
    function servicesOf(k) { return subs[k] ? subs[k].services : null; }
    function emit(k, service, data) { if (subs[k]) subs[k].cb(service, data); }
}''')
h.module('qs.modules.globals', {})
h.copy('modules/services/IdleMonitor.qml', siblings=False)
root = h.load('''import qs.modules.services
Item {
    IdleMonitor { objectName: "mon"; timeout: 1 }
    IdleMonitor { objectName: "ev"; timeout: 1 }
}''', auto_stub=False)
mon = h.find(root, 'mon')
ev = h.find(root, 'ev')


ok_all = True


def check(name, ok, detail=''):
    global ok_all
    ok_all &= bool(ok)
    print(('PASS ' if ok else 'FAIL ') + name + (' ' + detail if detail else ''))


def cmd(obj, proc):
    return list(h.eval(obj, f'{proc}.command').toVariant())


def timer(obj, name):
    return h.find(obj, name).property('running')


def gets(obj):
    return h.eval(obj, '_getProcess.starts')


def emit(obj, service, data):
    h.eval(obj, f'BackendService.emit(_subscription, "{service}", {data})')


# ---- the CLI calls, unchanged (mon never gets an idlemon status: polling) ----
create = cmd(mon, '_createProcess')
check('create runs the daemon directly', create[:3] == [DAEMON, 'system', 'idle-monitor-create'], str(create))
h.eval(mon, '_createProcess.finish(0, \'{"id": 7}\')')
check('monitor id parsed', h.eval(mon, '_monitorId') == 7)

h.eval(mon, '_checkIdle()')
get = cmd(mon, '_getProcess')
check('poll runs the daemon directly', get == [DAEMON, 'system', 'idle-monitor-get', '7'], str(get))

check('media check idle while active', timer(mon, 'mediaCheckTimer') is False)
h.eval(mon, '_getProcess.finish(0, \'{"is_idle": true}\')')
check('session reported idle', h.eval(mon, 'isIdle') is True)
check('media check runs while idle', timer(mon, 'mediaCheckTimer') is True)
h.eval(mon, '_checkMediaInhibitor()')
media = cmd(mon, '_mediaCheckProcess')
check('media check runs the daemon directly', media == [DAEMON, 'system', 'media-inhibit-check'], str(media))
h.eval(mon, '_mediaCheckProcess.finish(0, \'{"count": 1}\')')
check('playing media clears idle', h.eval(mon, 'isIdle') is False)
check('media check stops once active again', timer(mon, 'mediaCheckTimer') is False)

h.eval(mon, 'timeout = 2')
update = cmd(mon, '_updateProcess')
check('update runs the daemon directly', update == [DAEMON, 'system', 'idle-monitor-update', '7', '2000', '1', '1'], str(update))

# ---- fallback: no event path -> poll every second, as before ----
check('subscribes to idlemon', list(h.eval(mon, 'BackendService.servicesOf(_subscription)').toVariant()) == ['idlemon'])
h.eval(mon, '_getProcess.autoReply = \'{"is_idle": false}\'')
if h.eval(mon, '_getProcess.running'):
    h.eval(mon, '_getProcess.finish(0, \'{"is_idle": false}\')')
check('no status yet: polling', timer(mon, 'pollTimer') is True and timer(mon, 'safetyTimer') is False)
emit(mon, 'idlemon.status', '{connected: true, events: false, epoch: 1}')
check('daemon without idle events: still polling', timer(mon, 'pollTimer') is True and timer(mon, 'safetyTimer') is False)
before = gets(mon)
wait_until(lambda: gets(mon) >= before + 2, timeout_ms=5000)
check('fallback polls idle-monitor-get every second', gets(mon) >= before + 2, f'{before} -> {gets(mon)}')

# ---- event mode ----
emit(ev, 'idlemon.status', '{connected: true, events: true, epoch: 1}')
check('event mode once the path is up', h.eval(ev, '_eventMode') is True)
h.eval(ev, '_createProcess.finish(0, \'{"id": 3}\')')
check('state read once after create', gets(ev) == 1 and cmd(ev, '_getProcess')[-1] == '3', str(gets(ev)))
h.eval(ev, '_getProcess.finish(0, \'{"is_idle": false}\')')
check('event mode does not poll', timer(ev, 'pollTimer') is False)
check('safety re-read armed (60 s while active)', timer(ev, 'safetyTimer') is True and h.find(ev, 'safetyTimer').property('interval') == 60000)

emit(ev, 'idlemon.changed', '{id: 3, is_idle: true}')
check('event flips to idle', h.eval(ev, 'isIdle') is True)
check('safety re-read sooner while idle (15 s)', h.find(ev, 'safetyTimer').property('interval') == 15000)
emit(ev, 'idlemon.changed', '{id: 99, is_idle: false}')
check("another monitor's flip is ignored", h.eval(ev, 'isIdle') is True)
emit(ev, 'idlemon.changed', '{id: 3, is_idle: false}')
check('event flips back to active', h.eval(ev, 'isIdle') is False)

before = gets(ev)
pump(2300)
check('no idle-monitor-get per second in event mode', gets(ev) == before, f'{before} -> {gets(ev)}')

QMetaObject.invokeMethod(h.find(ev, 'safetyTimer'), 'triggered')
check('safety timer re-reads the state', gets(ev) == before + 1)
emit(ev, 'idlemon.changed', '{id: 3, is_idle: true}')
h.eval(ev, '_getProcess.finish(0, \'{"is_idle": false}\')')
check('a read overlapping an event does not override it', h.eval(ev, 'isIdle') is True)

# Media playing while idle: cleared, then polled as before until it stops.
h.eval(ev, '_checkMediaInhibitor()')
h.eval(ev, '_mediaCheckProcess.finish(0, \'{"count": 1}\')')
check('media clears idle in event mode', h.eval(ev, 'isIdle') is False)
check('media hold polls so idle comes back', timer(ev, 'pollTimer') is True and timer(ev, 'safetyTimer') is False)
h.eval(ev, '_checkIdle()')
h.eval(ev, '_getProcess.finish(0, \'{"is_idle": true}\')')
check('held poll restores idle', h.eval(ev, 'isIdle') is True)
h.eval(ev, '_checkMediaInhibitor()')
h.eval(ev, '_mediaCheckProcess.finish(0, \'{"count": 0}\')')
check('media stopped: back to events only', timer(ev, 'pollTimer') is False and h.eval(ev, 'isIdle') is True)
emit(ev, 'idlemon.changed', '{id: 3, is_idle: false}')

# ---- daemon restart: stream down -> polling; back with a new epoch -> read,
# the stale id fails and the monitor is recreated ----
emit(ev, 'idlemon.status', '{connected: false, events: false, epoch: 1}')
check('stream down: fallback polling', timer(ev, 'pollTimer') is True and timer(ev, 'safetyTimer') is False)
before = gets(ev)
emit(ev, 'idlemon.status', '{connected: true, events: true, epoch: 2}')
check('stream back: state re-read', gets(ev) == before + 1)
h.eval(ev, '_getProcess.finish(1, "idle monitor not found")')
check('stale monitor dropped', h.eval(ev, '_monitorId') == 0 and timer(ev, 'retryTimer') is True)
check('nothing polls a dropped monitor', timer(ev, 'pollTimer') is False and timer(ev, 'safetyTimer') is False)
QMetaObject.invokeMethod(h.find(ev, 'retryTimer'), 'triggered')
check('monitor recreated', cmd(ev, '_createProcess')[:3] == [DAEMON, 'system', 'idle-monitor-create'])
h.eval(ev, '_createProcess.finish(0, \'{"id": 4}\')')
h.eval(ev, '_getProcess.finish(0, \'{"is_idle": false}\')')
check('recreated monitor followed by event', h.eval(ev, '_monitorId') == 4 and timer(ev, 'safetyTimer') is True)

# A new epoch without a visible disconnect (restart between two statuses).
before = gets(ev)
emit(ev, 'idlemon.status', '{connected: true, events: true, epoch: 3}')
check('new epoch re-reads', gets(ev) == before + 1)
h.eval(ev, '_getProcess.finish(0, \'{"is_idle": false}\')')
emit(ev, 'idlemon.status', '{connected: true, events: true, epoch: 3}')
check('same epoch does not re-read', gets(ev) == before + 1)

# Backend connection lost: poll until a fresh status arrives.
h.eval(ev, 'BackendService.socketAvailable = false')
check('backend down: polling', timer(ev, 'pollTimer') is True)
h.eval(ev, 'BackendService.socketAvailable = true')
check('backend back: polling until a new status', timer(ev, 'pollTimer') is True)
if h.eval(ev, '_getProcess.running'):
    h.eval(ev, '_getProcess.finish(0, \'{"is_idle": false}\')')
before = gets(ev)
emit(ev, 'idlemon.status', '{connected: true, events: true, epoch: 1}')
check('fresh status: event mode and one read', timer(ev, 'pollTimer') is False and gets(ev) == before + 1)
h.eval(ev, '_getProcess.finish(0, \'{"is_idle": false}\')')

# ---- disabling stops everything ----
emit(ev, 'idlemon.changed', '{id: 4, is_idle: true}')
removed = h.eval(ev, 'BackendService.removed')
h.eval(ev, 'enabled = false')
check('disable unsubscribes', h.eval(ev, 'BackendService.removed') == removed + 1 and h.eval(ev, '_subscription') is None)
check('disable destroys the monitor', cmd(ev, '_destroyProcess') == [DAEMON, 'system', 'idle-monitor-destroy', '4'])
check('disable clears idle', h.eval(ev, 'isIdle') is False)
check('disable stops all timers', not any(timer(ev, t) for t in ('pollTimer', 'safetyTimer', 'mediaCheckTimer')))
h.eval(ev, '_onIdlemon("idlemon.changed", {id: 4, is_idle: true})')
check('a late event after disable is ignored', h.eval(ev, 'isIdle') is False)
h.eval(ev, '_destroyProcess.finish(0, "")')
before = gets(ev)
pump(1300)
check('nothing runs while disabled', gets(ev) == before)

sys.exit(0 if ok_all else 1)
