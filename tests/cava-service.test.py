"""CavaService runs cava at 30 fps and drops repeated frames once settled.

Every `values` change redraws the screen-sized panel window that hosts the
notch visualizer, so cava runs at 30 fps (it used to be 60) and a frame equal
to the previous one (silence, a held note) is forwarded only `settleFrames`
times, enough for the eased bars to land, and then dropped. A changed frame
is always forwarded; torn frames never are.

The rate is performance.visualizerFps (default 30, clamped to 15..60); a
change while cava runs restarts it once, debounced, without counting a
failure or looping.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402
from lib.waits import pump, wait_until  # noqa: E402
from lib.waits import settle as settle_events  # noqa: E402

h = Harness('cava-service')
h.module('Quickshell', {'Singleton': 'QtObject { default property list<QtObject> data }'})
h.module('Quickshell.Io', {
    'Process': '''QtObject {
    property var command: []
    property bool running: false
    property QtObject stdout
    signal exited(int exitCode, int exitStatus)
}''',
    'SplitParser': 'QtObject { signal read(string data) }',
})
h.module('qs.modules.globals', {'Brand': '''pragma Singleton
QtObject { property string appId: "app"; function runtimeFile(s) { return "/run/app" + s } }'''})
h.singleton('qs.config', 'Config', 'QtObject { property QtObject performance: QtObject { property int visualizerFps: 30 } }')
h.copy('modules/services/CavaService.qml', strip_singleton=True)
root = h.load('Item { property int changes: 0; CavaService { id: s; objectName: "cava"; onValuesChanged: changes++ } '
              'function proc() { for (let i = 0; i < s.data.length; i++) if (s.data[i].stdout) return s.data[i]; return null } '
              'function feed(line) { proc().stdout.read(line) } }', auto_stub=False)
cava = h.find(root, 'cava')

ok_all = True


def check(name, ok, detail=''):
    global ok_all
    ok_all &= bool(ok)
    print(('PASS ' if ok else 'FAIL ') + name + (' ' + detail if detail else ''))


check('runs cava at 30 fps', h.eval(cava, 'framerate') == 30)
conf = list(h.eval(root, 'proc().command').toVariant())
check('the cava config carries the rate', 'framerate = 30' in conf[4].split('\n'), conf[4][:60])
settle = h.eval(cava, 'settleFrames')
check('settles for ~0.4 s of frames', settle == 12, str(settle))

bars = h.eval(cava, 'barCount')
loud = ';'.join(['500'] * bars) + ';'
quiet = ';'.join(['0'] * bars) + ';'


def feed(line, n=1):
    for _ in range(n):
        h.eval(root, f'feed("{line}")')


root.setProperty('changes', 0)
feed(loud)
check('a new frame is forwarded', root.property('changes') == 1)
check('levels are normalized', list(h.eval(cava, 'values').toVariant()) == [0.5] * bars)
feed(loud, 40)
check('repeats are forwarded settleFrames times, then dropped', root.property('changes') == 1 + settle,
      f'({root.property("changes")} changes)')
feed(quiet)
check('a changed frame after a run of repeats is forwarded', root.property('changes') == 2 + settle)
check('silence reads as zeros', list(h.eval(cava, 'values').toVariant()) == [0] * bars)
feed(quiet, 100)
check('silence stops notifying', root.property('changes') == 2 + 2 * settle, f'({root.property("changes")} changes)')
before = root.property('changes')
feed('1;2;')
feed('garbage')
check('torn frames are ignored', root.property('changes') == before)
feed(loud)
check('music after silence is forwarded at once', root.property('changes') == before + 1)

# performance.visualizerFps: the rate follows the setting (clamped), and a
# running cava restarts once with the new config, without counting a failure
# or arming the 3 s failure-retry timer.
config = h.engine.singletonInstance('qs.config', 'Config')
perf = config.property('performance')


def rate_in_command():
    lines = list(h.eval(root, 'proc().command').toVariant())[4].split('\n')
    return next((ln for ln in lines if ln.startswith('framerate')), '')


def running():
    return h.eval(root, 'proc().running')


def emit_exit(code=143):
    h.eval(root, f'proc().exited({code}, 0)')


def retry_armed():
    return h.eval(cava, '(function() { for (let i = 0; i < data.length; i++) '
                        'if (data[i].interval === 3000) return data[i].running; return null })()')


h.eval(cava, 'setConsumer("t", true)')
check('a consumer starts cava', running() is True)
perf.setProperty('visualizerFps', 20)
check('the rate follows performance.visualizerFps', h.eval(cava, 'framerate') == 20 and rate_in_command() == 'framerate = 20')
check('the restart is debounced', running() is True)
perf.setProperty('visualizerFps', 25)
pump(150)
check('still running while the value keeps changing', running() is True)
check('cava is stopped once to pick up the new rate', wait_until(lambda: running() is False, 3000))
emit_exit()
settle_events()
check('and started again at once with the new rate', running() is True and rate_in_command() == 'framerate = 25')
check('the rate restart is not a failure', h.eval(cava, '_failures') == 0 and not h.eval(cava, '_rateRestart'))
check('no failure-retry is armed', retry_armed() is False)
pump(900)
check('one restart only (no loop)', running() is True)

perf.setProperty('visualizerFps', 5)
check('too low clamps to 15', h.eval(cava, 'framerate') == 15)
perf.setProperty('visualizerFps', 999)
check('too high clamps to 60', h.eval(cava, 'framerate') == 60)
wait_until(lambda: running() is False, 3000)
h.eval(cava, 'setConsumer("t", false)')
emit_exit()
settle_events()
check('a consumer leaving during the restart keeps cava off', running() is False)

pump(1700)  # stopTimer (1.5 s) settles the stopped state
perf.setProperty('visualizerFps', 30)
pump(700)
check('a rate change while cava is off starts nothing', running() is False and not h.eval(cava, '_rateRestart'))
h.eval(cava, 'setConsumer("t", true)')
check('the next start uses the new rate', running() is True and rate_in_command() == 'framerate = 30')

print('CavaService:', 'PASS' if ok_all else 'FAIL')
sys.exit(0 if ok_all else 1)
