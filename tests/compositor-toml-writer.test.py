"""CompositorTomlWriter coalesces compositor.write requests and never
replaces a good compositor TOML.

Every write makes the daemon regenerate the compositor config. A burst of
changes (a preset load touches ~20 keys) must produce one write with the
final values; a request while a write is in flight must run once afterwards
(not be dropped); and the answer handler must not pile up one extra write
per call. The payload goes over the daemon socket (BackendService), never
as a CLI argument (argv elements are capped at 128 KiB). A failed write
keeps the existing TOML: the minimal [target] fallback is only created
when no TOML exists yet.
"""
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402
from lib.waits import pump, wait_until  # noqa: E402

h = Harness('compositor-toml-writer')
h.singleton('Quickshell', 'Quickshell', 'QtObject { function env(n) { return "/tmp"; } }')
h.module('Quickshell.Io', {
    'Process': '''QtObject {
    default property list<QtObject> data
    property var command: []
    property bool running: false
    property QtObject stdout
    property int starts: 0
    property var commands: []
    signal exited(int exitCode, int exitStatus)
    onRunningChanged: if (running) { starts++; commands = commands.concat([command]); }
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
h.singleton('qs.modules.services', 'DisplaysService', 'QtObject { property bool pending: false; property var outputs: [] }')
# The daemon socket: records each call; answer(error) replies to the oldest
# unanswered one.
h.singleton('qs.modules.services', 'BackendService', '''QtObject {
    property bool socketAvailable: true
    property int starts: 0
    property var methods: []
    property var payloads: []
    property var callbacks: []
    function call(method, params, callback) {
        starts++;
        methods = methods.concat([method]);
        payloads = payloads.concat([JSON.stringify(params)]);
        callbacks = callbacks.concat([callback]);
    }
    function answer(error) {
        const cb = callbacks[0];
        callbacks = callbacks.slice(1);
        cb(error ? null : { ok: true }, error || undefined);
    }
}''')

# gatherInput() reads the whole config tree; the test only needs a payload
# that says which revision of the state was sent.
# Repo layout under the harness root: the writer imports ../../config/CoreBinds.js.
writer_qml = h.copy('modules/services/CompositorTomlWriter.qml', 'modules/services', strip_singleton=True, replace={
    'function gatherInput() {': 'property int revision: 0\n'
                                '    function gatherInput() { return { revision: root.revision, displays: [] }; }\n'
                                '    function _realGatherInput() {',
})
writer = h.load(writer_qml)
h.allow_type_errors = True  # Singleton base type is stubbed by the auto-stubber

# The coalescing is under test, not the 700 ms: a shorter debounce (the
# drag below keeps the same 7x margin between its steps and the debounce).
DEBOUNCE = 250
h.eval(writer, f"writeDebounce.interval = {DEBOUNCE}")
# The start-up readiness timers would add writes of their own.
h.eval(writer, "tomlDeferTimer.stop(); tomlTimeoutTimer.stop()")


ok_all = True


def check(name, ok, detail=''):
    global ok_all
    ok_all &= bool(ok)
    print(('PASS ' if ok else 'FAIL ') + name + (' ' + detail if detail else ''))


def backend(expr):
    return h.eval(writer, 'BackendService.' + expr)


def last_payload():
    return str(backend('payloads[BackendService.payloads.length - 1]'))


def fallback(expr):
    return h.eval(writer, 'fallbackProcess.' + expr)


# A burst of 20 changes in one tick -> one write carrying the last revision.
for i in range(1, 21):
    h.eval(writer, f'revision = {i}; callWrite()')
wait_until(lambda: backend('starts') >= 1)
pump(2 * DEBOUNCE)  # and no second one
check('burst of 20 requests sends one write', backend('starts') == 1, f'(starts={backend("starts")})')
check('the write is compositor.write over the socket', str(backend('methods[0]')) == 'compositor.write')
check('the write carries the final state', '"revision":20' in last_payload())

# A request while the write is still unanswered is queued, then sent once.
h.eval(writer, 'revision = 21; callWrite()')
pump(2 * DEBOUNCE)
check('no second write while one is in flight', backend('starts') == 1)
h.eval(writer, 'BackendService.answer(null)')
wait_until(lambda: backend('starts') == 2)
check('queued request runs after the in-flight write', backend('starts') == 2, f'(starts={backend("starts")})')
check('queued write carries the newest state', '"revision":21' in last_payload())

# Answers do not accumulate handlers: a successful answer with nothing
# queued sends nothing more, however many writes came before.
h.eval(writer, 'BackendService.answer(null)')
pump(DEBOUNCE + 50)
check('idle answer sends nothing', backend('starts') == 2, f'(starts={backend("starts")})')

# A slider drag: a change every DEBOUNCE/7 for 13 steps is one write after it
# settles, not one per step (each write regenerates the compositor config).
for i in range(30, 43):
    h.eval(writer, f'revision = {i}; callWrite()')
    pump(DEBOUNCE // 7)
check('no write while the drag is still moving', backend('starts') == 2, f'(starts={backend("starts")})')
wait_until(lambda: backend('starts') >= 3)
pump(DEBOUNCE)  # and only one
check('one write once the drag settles', backend('starts') == 3, f'(starts={backend("starts")})')
check('the settled write carries the last step', '"revision":42' in last_payload())
check('no process carries the payload', fallback('starts') == 0, f'(fallback starts={fallback("starts")})')

# A failed write (e.g. a wrong-typed entry in binds.json) keeps the last
# good TOML: the fallback only creates a missing one.
tmp = Path(tempfile.mkdtemp(prefix='compositor-toml-writer-'))
toml = tmp / 'data' / 'yozd.toml'
h.eval(writer, f'outputPath = {str(toml)!r}')
h.eval(writer, 'revision = 50; callWrite()')
h.eval(writer, 'BackendService.answer({ code: -32000, message: "compositor.write: bad bind" })')
wait_until(lambda: fallback('starts') == 1)
cmd = h.eval(writer, 'fallbackProcess.command')
cmd = [str(a) for a in (cmd.toVariant() if hasattr(cmd, 'toVariant') else cmd)]
check('the fallback script holds no path or content', cmd[:2] == ['sh', '-c'] and str(tmp) not in cmd[2]
      and '[target]' not in cmd[2], str(cmd[:3]))

good = '[target]\nhyprland = "hyprland.lua"\n\n[[binds]]\nkey = "Q"\n'
toml.parent.mkdir(parents=True)
toml.write_text(good)
r = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
check('an existing TOML is not replaced', toml.read_text() == good, repr(toml.read_text()[:200]))
check('…and the script reports it did nothing', r.returncode != 0)
check('…quietly', r.stderr == '', r.stderr)

link_target = tmp / 'dotfiles.toml'
link_target.write_text(good)
toml.unlink()
toml.symlink_to(link_target)
subprocess.run(cmd, capture_output=True, text=True, timeout=30)
check('a symlinked TOML is not written through', link_target.read_text() == good and toml.is_symlink())

toml.unlink()
toml.parent.rmdir()
r = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
check('a missing TOML is created with the [target] block', r.returncode == 0
      and toml.read_text() == '[target]\nhyprland = "hyprland.lua"\n', repr(toml.read_text() if toml.exists() else None))
h.eval(writer, 'fallbackProcess.finish(0)')

# The queue keeps going after a failure.
n = backend('starts')
h.eval(writer, 'revision = 51; callWrite()')
wait_until(lambda: backend('starts') == n + 1)
check('a write after a failed one is sent', '"revision":51' in last_payload())
h.eval(writer, 'BackendService.answer(null)')

# Socket down: the call waits in BackendService's queue; only a missing TOML
# gets the fallback meanwhile.
n = backend('starts')
h.eval(writer, 'BackendService.socketAvailable = false; revision = 52; callWrite()')
wait_until(lambda: backend('starts') == n + 1)
check('socket down: the fallback (create-only) runs', fallback('starts') == 2, f'(fallback starts={fallback("starts")})')
h.eval(writer, 'fallbackProcess.finish(1)')

# An answer lost with the socket does not block later writes forever.
h.eval(writer, 'writeWatchdog.interval = 400')
n = backend('starts')
h.eval(writer, 'BackendService.socketAvailable = true; revision = 53; callWrite()')
pump(DEBOUNCE + 50)
check('queued behind the unanswered write', backend('starts') == n)
wait_until(lambda: backend('starts') == n + 1)
h.eval(writer, 'writeWatchdog.interval = 30000')
check('the watchdog releases the queue', '"revision":53' in last_payload())
# The late answer of the abandoned write is ignored (the new one is in flight).
h.eval(writer, 'BackendService.answer(null)')
h.eval(writer, 'revision = 54; callWrite()')
pump(DEBOUNCE + 50)
check('a late answer does not end the write in flight', backend('starts') == n + 1, f'(starts={backend("starts")})')
h.eval(writer, 'BackendService.answer(null)')
wait_until(lambda: backend('starts') == n + 2)
check('the answer of the write in flight sends the queued one', '"revision":54' in last_payload())

shutil.rmtree(tmp, ignore_errors=True)
sys.exit(0 if ok_all else 1)
