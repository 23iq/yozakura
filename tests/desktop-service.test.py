"""DesktopService hands file names to child processes as argv, never as code.

A desktop file name is attacker-controlled (downloads, archives). trashFile
used to splice it into QML source for Qt.createQmlObject, where the QML
parser undid the shell escaping; double-clicking a .desktop file ran its
Exec line without any trust check.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402

h = Harness('desktop-service')
h.singleton('testlog', 'Log', 'QtObject { property var started: [] }')
h.module('Quickshell', {
    'Singleton': 'QtObject { default property list<QtObject> data }',
    'Quickshell': 'pragma Singleton\nQtObject { function dataPath(p) { return "/tmp/qmlharness-home/data/" + p } }',
})
h.module('Quickshell.Io', {
    'Process': '''import testlog
QtObject {
    id: p
    default property list<QtObject> data
    property var command: []
    property bool running: false
    property QtObject stdout
    property QtObject stderr
    signal exited(int exitCode, int exitStatus)
    onRunningChanged: if (running) { var s = Log.started.slice(); s.push({ cmd: command, proc: p }); Log.started = s; }
    function finish(code) { running = false; exited(code, 0); }
}''',
    'StdioCollector': 'QtObject { property string text: ""; signal streamFinished() }',
    'FileView': 'QtObject { property string path; property bool watchChanges; property bool printErrors; signal fileChanged(); function reload() {} }',
})
h.module('qs.modules.globals', {})
h.copy('modules/services/DesktopService.qml', strip_singleton=True, siblings=False)
root = h.load('import testlog\nItem { property var log: Log; property string evil: ""; DesktopService { id: s; objectName: "svc" } }',
              auto_stub=False)
svc = h.find(root, 'svc')

ok_all = True


def check(name, ok, detail=''):
    global ok_all
    ok_all &= bool(ok)
    print(('PASS ' if ok else 'FAIL ') + name + (' ' + detail if detail else ''))


def started():
    return [list(c) for c in h.eval(root, 'log.started.map(e => e.cmd)').toVariant()]


def reset():
    h.eval(root, 'log.started = []')


def finish(i, code):
    h.eval(root, f'log.started[{i}].proc.finish({code})')


EVIL = "/home/u/Desktop/x'; touch /tmp/pwned; echo '\\\" ]\nProcess { }\n$(id)`id`"
root.setProperty('evil', EVIL)

# #3: trashFile
reset()
h.eval(root, 's.trashFile(evil)')
cmds = started()
check('trash runs gio trash with the path as one argv entry',
      cmds == [['gio', 'trash', '--', EVIL]], repr(cmds))

# #11: double-clicking a .desktop file only launches it when trusted
def launched_argv(cmd):
    """argv a `bash -c '... "$@" ...' launch ARGV...` launcher runs."""
    if cmd[:2] != ['bash', '-c'] or '"$@"' not in cmd[2]:
        return None
    return cmd[4:]


reset()
h.eval(root, 's.executeDesktopFile(evil)')
cmds = started()
check('desktop file: trust check first, path as argv',
      len(cmds) == 1 and cmds[0][:2] == ['sh', '-c'] and cmds[0][-1] == EVIL and EVIL not in cmds[0][2]
      and 'metadata::trusted' in cmds[0][2] and '-x' in cmds[0][2], repr(cmds))
finish(0, 1)
check('untrusted desktop file is not launched', len(started()) == 1, repr(started()))

reset()
h.eval(root, 's.executeDesktopFile(evil)')
finish(0, 0)
cmds = started()
check('trusted desktop file launches via gio launch argv',
      len(cmds) == 2 and launched_argv(cmds[1]) == ['gio', 'launch', EVIL], repr(cmds))

# openFile, position saving and the directory scan pass data as argv
reset()
h.eval(root, 's.openFile(evil)')
cmds = started()
check('openFile launches xdg-open with the path as argv',
      len(cmds) == 1 and launched_argv(cmds[0]) == ['xdg-open', EVIL], repr(cmds))

reset()
h.eval(root, 's.iconPositions = {}; s.updateIconPosition(evil, 1, 2)')
cmds = started()
check('positions are written with the JSON as an argument, not in the script',
      len(cmds) == 1 and cmds[0][:2] == ['sh', '-c'] and EVIL not in cmds[0][2]
      and cmds[0][-2].endswith('desktop-positions.json') and EVIL in json.loads(cmds[0][-1]), repr(cmds))

reset()
h.eval(root, 's.desktopDir = evil; s.scanDesktop()')
cmds = [c for c in started() if c and c[0] in ('ls', 'sh', 'bash')]
check('desktop scan lists the directory via argv',
      cmds and all(EVIL not in c[2] for c in cmds if c[:2] in (['sh', '-c'], ['bash', '-c']))
      and any(c[-1] == EVIL for c in cmds), repr(cmds))

sys.exit(0 if ok_all else 1)
