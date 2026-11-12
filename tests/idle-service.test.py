"""IdleService: idle hooks run verbatim and fire on schedule without a tick.

executeCommand used to splice the configured hook into QML source for
Qt.createQmlObject; a hook with a newline, `${` or a quote broke the QML or
changed the command. The hook string must reach `sh -c` unchanged.

While the user was away a 1 s timer ticked for the whole absence and every
tick re-evaluated each wallpaper's videoPaused binding. The service now
sleeps until the next threshold (listener timeouts, the wallpaper idle-pause
delay): each listener still fires once at its timeout, resume hooks run on
activity, a listener list changed while idle is honoured without crediting
time spent suspended, and elapsedIdleTime reaches the wallpaper delay. Thresholds here are 1-3 s, so
the timing checks run in real time.
"""
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402
from lib.waits import pump, wait_until  # noqa: E402

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
h.singleton('qs.config', 'Config', '''QtObject {
    property QtObject system: QtObject {
        property QtObject idle: QtObject { property var general: ({}); property var listeners: [] }
    }
    property QtObject performance: QtObject {
        property bool pauseWallpaperOnIdle: true
        property real pauseWallpaperIdleDelay: 2
    }
}''')
h.module('qs.modules.globals', {})
h.stub('IdleMonitor', 'QtObject { property bool enabled: true; property int timeout; property bool respectInhibitors; property bool isIdle }')
for name in ('BackendService', 'SuspendManager', 'LockscreenService'):
    h.stub(name, 'pragma Singleton\nQtObject { function call() {} function addSubscription() { return 1 } '
                 'function onPrepareForSleep() {} function onWakingUp() {} function lock() {} }')
(h.root / 'app' / 'qmldir').write_text(
    'singleton BackendService 1.0 BackendService.qml\n'
    'singleton SuspendManager 1.0 SuspendManager.qml\nsingleton LockscreenService 1.0 LockscreenService.qml\n'
    'IdleMonitor 1.0 IdleMonitor.qml\nIdleService 1.0 IdleService.qml\n')
h.copy('modules/services/IdleService.qml', strip_singleton=True, siblings=False)
root = h.load('''import testlog
import qs.config
Item {
    property var log: Log
    property string hook
    property int wakes: 0
    property int elapsedChanges: 0
    property alias svc: s
    IdleService { id: s; onElapsedIdleTimeChanged: elapsedChanges++ }
    Connections { target: s.idleTimer; function onTriggered() { wakes++ } }
    function run() { s.executeCommand(hook) }
    function setListeners(l) { Config.system.idle.listeners = l }
    function setIdle(v) { s.masterMonitor.isIdle = v }
    function clearLog() { Log.started = [] }
}''', auto_stub=False)

ok_all = True


def check(name, ok, detail=''):
    global ok_all
    ok_all &= bool(ok)
    print(('PASS ' if ok else 'FAIL ') + name + (' ' + detail if detail else ''))


def started():
    return [list(c) for c in h.eval(root, 'log.started').toVariant()]


def hooks():
    return [c[2] for c in started()]


HOOK = 'notify-send "a\\"b" \'c\' ${HOME} `x`\nbrightnessctl -s set 10% \\\\ end'
root.setProperty('hook', HOOK)
h.eval(root, 'run()')
got = started()
check('idle hook reaches sh -c verbatim', got == [['sh', '-c', HOOK]], repr(got))

# --- Firing times: one wake-up per threshold, no tick -----------------------
h.eval(root, 'clearLog()')
h.eval(root, 'setListeners([{timeout: 1, onTimeout: "dim", onResume: "undim"}, '
             '{timeout: 3, onTimeout: "off", onResume: "on"}, {timeout: 3, onTimeout: "lock"}])')
check('thresholds: listeners + wallpaper delay', list(h.eval(root, 'svc.idleThresholds').toVariant()) == [1, 2, 3],
      str(h.eval(root, 'svc.idleThresholds').toVariant()))
check('no timer while active', h.eval(root, 'svc.idleTimer.running') is False)
root.setProperty('wakes', 0)
root.setProperty('elapsedChanges', 0)
t0 = time.monotonic()
h.eval(root, 'setIdle(true)')
check('first wait is the first threshold', h.eval(root, 'svc.idleTimer.interval') == 1000
      and h.eval(root, 'svc.idleTimer.repeat') is False)
pump(700)
check('nothing fires before 1 s', hooks() == [] and h.eval(root, 'svc.elapsedIdleTime') == 0)
wait_until(lambda: hooks() == ['dim'])
t1 = time.monotonic() - t0
check('1 s listener fires at 1 s', 0.9 <= t1 <= 1.6, f'({t1:.2f} s)')
check('elapsedIdleTime steps to 1', h.eval(root, 'svc.elapsedIdleTime') == 1)
wait_until(lambda: h.eval(root, 'svc.elapsedIdleTime') == 2)
t2 = time.monotonic() - t0
check('wallpaper delay reached at 2 s', 1.9 <= t2 <= 2.6 and hooks() == ['dim'], f'({t2:.2f} s, {hooks()})')
wait_until(lambda: len(hooks()) == 3)
t3 = time.monotonic() - t0
check('3 s listeners fire together at 3 s, in list order', hooks() == ['dim', 'off', 'lock'] and 2.9 <= t3 <= 3.6,
      f'({t3:.2f} s, {hooks()})')
pump(600)
check('each listener fires once', hooks() == ['dim', 'off', 'lock'])
check('no wake-up after the last threshold', h.eval(root, 'svc.idleTimer.running') is False)
check('one wake-up per threshold', root.property('wakes') == 3, f'({root.property("wakes")} wake-ups)')
check('elapsedIdleTime changes only at thresholds', root.property('elapsedChanges') == 3,
      f'({root.property("elapsedChanges")} changes)')
live = h.eval(root, 'svc.idleSecondsNow()')
check('idleSecondsNow reads the running value', live == 3, str(live))

# Suspend/wake events only lock; they neither reset nor fire idle state.
h.eval(root, 'svc.handleSleepEvent("sleep", {event: "SUSPEND"}); svc.handleSleepEvent("sleep", {event: "WAKE"})')
check('suspend/wake keep the idle state', h.eval(root, 'svc.elapsedIdleTime') == 3
      and hooks() == ['dim', 'off', 'lock'])

h.eval(root, 'setIdle(false)')
check('activity runs resume hooks, latest first', hooks()[3:] == ['on', 'undim'], str(hooks()))
check('activity resets the idle state', h.eval(root, 'svc.elapsedIdleTime') == 0
      and h.eval(root, 'svc.triggeredListeners.length') == 0 and h.eval(root, 'svc.idleSecondsNow()') == 0)
check('no timer after activity', h.eval(root, 'svc.idleTimer.running') is False)

# --- Listener list changed while idle ---------------------------------------
h.eval(root, 'clearLog()')
h.eval(root, 'setListeners([{timeout: 30, onTimeout: "late"}])')
root.setProperty('wakes', 0)
t0 = time.monotonic()
h.eval(root, 'setIdle(true)')
pump(400)
h.eval(root, 'setListeners([{timeout: 30, onTimeout: "late"}, {timeout: 1, onTimeout: "added"}])')
check('a change keeps the time already spent idle', h.eval(root, 'svc.idleTimer.interval') <= 700,
      f'(waits {h.eval(root, "svc.idleTimer.interval")} ms)')
wait_until(lambda: hooks() == ['added'])
ta = time.monotonic() - t0
check('a listener added while idle fires at its timeout', 0.9 <= ta <= 1.6, f'({ta:.2f} s)')
pump(1300)
h.eval(root, 'setListeners([{timeout: 30, onTimeout: "late"}, {timeout: 1, onTimeout: "added"}, '
             '{timeout: 2, onTimeout: "overdue"}])')
check('a listener already overdue fires at once', hooks() == ['added', 'overdue'], str(hooks()))
check('the next wait is the next threshold', 27000 <= h.eval(root, 'svc.idleTimer.interval') <= 28000,
      f'({h.eval(root, "svc.idleTimer.interval")} ms)')

# Wallpaper idle pause turned off and on while idle.
h.eval(root, 'Config.performance.pauseWallpaperOnIdle = false')
check('wallpaper delay leaves the thresholds when off',
      list(h.eval(root, 'svc.idleThresholds').toVariant()) == [1, 2, 30])
h.eval(root, 'setIdle(false)')
h.eval(root, 'Config.performance.pauseWallpaperOnIdle = true')
check('no timer after activity', h.eval(root, 'svc.idleTimer.running') is False)

# --- Suspend: the time asleep is never credited ----------------------------
# The timer does not run while suspended, the wall clock does. A clock jump
# is simulated by moving the wait's wall-clock start (and the reported
# suspend's start) back by the time asleep.
h.eval(root, 'Config.performance.pauseWallpaperOnIdle = false')
h.eval(root, 'clearLog()')
h.eval(root, 'setListeners([{timeout: 30, onTimeout: "late"}])')
h.eval(root, 'setIdle(true)')
pump(300)
# A 10 s suspend reported by SUSPEND/WAKE, then the listeners re-set.
h.eval(root, 'svc.handleSleepEvent("sleep", {event: "SUSPEND"})')
h.eval(root, 'svc._stepStart -= 10000; svc._sleptAt -= 10000')
h.eval(root, 'svc.handleSleepEvent("sleep", {event: "WAKE"})')
h.eval(root, 'setListeners([{timeout: 30, onTimeout: "late"}, {timeout: 5, onTimeout: "dim"}])')
wait_ms = h.eval(root, 'svc.idleTimer.interval')
check('after a reported suspend a new listener waits its own timeout', hooks() == [] and 4000 <= wait_ms <= 4800,
      f'({wait_ms} ms, {hooks()})')
# A one-hour suspend the service missed: the gap exceeds the armed wait.
h.eval(root, 'setIdle(false)')
h.eval(root, 'setListeners([{timeout: 30, onTimeout: "late"}])')
h.eval(root, 'setIdle(true)')
pump(300)
h.eval(root, 'svc._stepStart -= 3600000')
h.eval(root, 'setListeners([{timeout: 30, onTimeout: "late"}, {timeout: 20, onTimeout: "dim"}])')
wait_ms = h.eval(root, 'svc.idleTimer.interval')
check('after a missed suspend nothing fires at once', hooks() == [] and 19000 <= wait_ms <= 20000,
      f'({wait_ms} ms, {hooks()})')
h.eval(root, 'setIdle(false)')

print('IdleService:', 'PASS' if ok_all else 'FAIL')
sys.exit(0 if ok_all else 1)
