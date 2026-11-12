"""CavaService runs cava at 30 fps and drops repeated frames once settled.

Every `values` change redraws the screen-sized panel window that hosts the
notch visualizer, so cava runs at 30 fps (it used to be 60) and a frame equal
to the previous one (silence, a held note) is forwarded only `settleFrames`
times, enough for the eased bars to land, and then dropped. A changed frame
is always forwarded; torn frames never are.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402

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
h.copy('modules/services/CavaService.qml', strip_singleton=True)
root = h.load('Item { property int changes: 0; CavaService { id: s; objectName: "cava"; onValuesChanged: changes++ } '
              'function feed(line) { s.data[2].stdout.read(line) } }', auto_stub=False)
cava = h.find(root, 'cava')

ok_all = True


def check(name, ok, detail=''):
    global ok_all
    ok_all &= bool(ok)
    print(('PASS ' if ok else 'FAIL ') + name + (' ' + detail if detail else ''))


check('runs cava at 30 fps', h.eval(cava, 'framerate') == 30)
conf = list(h.eval(cava, 'data[2].command').toVariant())
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

print('CavaService:', 'PASS' if ok_all else 'FAIL')
sys.exit(0 if ok_all else 1)
