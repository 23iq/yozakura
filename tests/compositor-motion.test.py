"""Motion profile + music-reactive border services, loaded as real QML.

CompositorMotion (modules/services/CompositorMotion.qml): resolves the
profile with the real config/motion registry, applies it live once (one
`compositor.eval`), re-applies on a change, stays quiet in GameMode and
restores the profile when GameMode ends.

BorderPulse (modules/services/BorderPulse.qml): idle (no cava consumer, no
timer, no socket traffic) unless enabled and a player is playing; while
active, cava frames become `eval hl.config(...)` requests on Hyprland's
socket only when the quantized level changes; stopping restores the base
border.
"""
import json
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402
from PySide6.QtCore import QCoreApplication, QElapsedTimer  # noqa: E402

h = Harness('compositor-motion')
h.singleton('Quickshell', 'Quickshell', '''QtObject {
    property var vars: ({ "HYPRLAND_INSTANCE_SIGNATURE": "sig", "XDG_RUNTIME_DIR": "/run/user/1000" })
    function env(n) { return vars[n] || ""; }
}''')
h.module('Quickshell.Io', {
    'Socket': '''QtObject {
    property string path
    property bool connected: false
    property QtObject parser
    property var written: []
    signal error(var error)
    onConnectedChanged: connectionStateChanged()
    signal connectionStateChanged()
    function write(s) { written = written.concat([s]); }
    function flush() {}
}''',
    'SplitParser': 'QtObject {}',
})
h.singleton('qs.config', 'Config', '''QtObject {
    property QtObject loader: QtObject { property bool loaded: true; signal loaded_(); signal fileChanged() }
    property QtObject bar: QtObject { property string position: "top" }
    property QtObject compositor: QtObject {
        property string motionProfile: "sakura"
        property real motionDurationScale: 1
        property string motionWorkspaceStyle: "auto"
        property string motionBorderLoop: "auto"
        property int motionBorderLoopSpeed: 0
        property var motionOverrides: ({})
        property var activeBorderColor: ["primary"]
        property int borderAngle: 45
        property string shadowColor: "shadow"
        property bool shadowEnabled: true
        property QtObject borderPulse: QtObject {
            property bool enabled: false
            property string source: "cava"
            property real intensity: 1
        }
    }
}''')
h.singleton('qs.modules.theme', 'Colors', 'QtObject { signal fileChanged() }')
h.module('qs.modules.services', {
    'GameModeClient': 'pragma Singleton\nQtObject { property bool toggled: false }',
    'BackendService': 'pragma Singleton\nQtObject { property var sent: []; function notify(m, p) { sent = sent.concat([p.expression]); } }',
    'MprisController': 'pragma Singleton\nQtObject { property bool isPlaying: false }',
    'CavaService': '''pragma Singleton
QtObject {
    property bool available: true
    property var values: []
    property var consumers: ({})
    function setConsumer(k, on) { const c = Object.assign({}, consumers); if (on) c[k] = true; else delete c[k]; consumers = c; }
}''',
    'CompositorTomlWriter': '''pragma Singleton
QtObject {
    function buildHyprlandConfig() {
        return { general: { col: { active_border: { colors: ["rgb(ff0000)", "rgb(00ff00)"], angle: 45 } } },
                 decoration: { shadow: { enabled: true, color: "rgba(00000080)" } } };
    }
}''',
})

motion_qml = h.copy('modules/services/CompositorMotion.qml', 'modules/services', strip_singleton=True,
                    replace={'Singleton {': 'Item {', 'target: Config.loader\n        function onLoaded()': 'target: Config.loader\n        function onLoaded_()'})
pulse_qml = h.copy('modules/services/BorderPulse.qml', 'modules/services')
h.allow_type_errors = True


def pump(ms):
    t = QElapsedTimer()
    t.start()
    while t.elapsed() < ms:
        QCoreApplication.processEvents()
        time.sleep(0.002)


ok_all = True


def js(obj, expr):
    return json.loads(h.eval(obj, f'JSON.stringify({expr})'))


def check(name, ok, detail=''):
    global ok_all
    ok_all &= bool(ok)
    print(('PASS ' if ok else 'FAIL ') + name + (' ' + detail if detail else ''))


motion = h.load(motion_qml)
pump(400)
sent = js(motion, 'BackendService.sent')
check('profile applied live once at start', len(sent) == 1, f'({len(sent)})')
check('live chunk is the sakura profile', 'sakuraOvershoot' in sent[0] and 'style = "loop"' in sent[0])
check('one line, no semicolons', '\n' not in sent[0] and ';' not in sent[0])
h.eval(motion, 'Config.compositor.motionProfile = "springs"')
pump(400)
sent = js(motion, 'BackendService.sent')
check('a profile change re-applies', len(sent) == 2 and 'spring = "springsBounce"' in sent[-1])
h.eval(motion, 'GameModeClient.toggled = true; Config.compositor.motionDurationScale = 2')
pump(400)
check('nothing applied during GameMode', len(js(motion, 'BackendService.sent')) == 2)
h.eval(motion, 'GameModeClient.toggled = false')
pump(100)
sent = js(motion, 'BackendService.sent')
check('GameMode exit restores the profile', len(sent) == 3 and 'speed = 9' in sent[-1], f'({len(sent)})')
h.eval(motion, 'Config.bar.position = "left"')
pump(400)
check('vertical bar re-applies with vertical slides', 'slidevert' in js(motion, 'BackendService.sent')[-1])

pulse = h.load(pulse_qml)
pump(100)
check('pulse idle by default', h.eval(pulse, 'active') is False and h.eval(pulse, 'ticker.running') is False)
check('no cava consumer while idle', h.eval(pulse, 'Object.keys(CavaService.consumers).length') == 0)
h.eval(pulse, 'Config.compositor.borderPulse.enabled = true')
pump(50)
check('enabled but nothing playing stays idle', h.eval(pulse, 'active') is False)
h.eval(pulse, 'MprisController.isPlaying = true')
pump(50)
check('playing activates the pulse', h.eval(pulse, 'active') is True and h.eval(pulse, 'ticker.running') is True)
check('cava consumer registered', h.eval(pulse, 'CavaService.consumers["border-pulse"]') is True)
check('socket path from the Hyprland instance', h.eval(pulse, 'hyprSocket.path') == '/run/user/1000/hypr/sig/.socket.sock')
# Quiet frame -> first level (0) is sent once; repeated identical frames send nothing.
h.eval(pulse, 'CavaService.values = [0, 0, 0, 0]')
pump(200)
h.eval(pulse, 'hyprSocket.connected = false')  # Hyprland closes after answering
pump(50)
sent0 = h.eval(pulse, 'hyprSocket.written.length')
pump(300)
check('steady level sends nothing more', h.eval(pulse, 'hyprSocket.written.length') == sent0, f'({sent0})')
first = h.eval(pulse, 'hyprSocket.written[0]')
check('frame is an eval of the active border', str(first).startswith('eval hl.config({general = {col = {active_border = {colors = {"rgba(ff000026)", "rgba(00ff0026)"}, angle = 45}}}'), first)
h.eval(pulse, 'CavaService.values = [1, 1, 1, 1]')
pump(150)
h.eval(pulse, 'hyprSocket.connected = false')
pump(300)
written = js(pulse, 'hyprSocket.written')
check('a beat raises the level', len(written) > sent0 and any('rgb(ff0000)' in w for w in written))
check('rate stays at or below 30 Hz', len(written) <= 1 + 0.45 * 30 + 2, f'({len(written)} in ~0.45 s)')
h.eval(pulse, 'hyprSocket.connected = false; MprisController.isPlaying = false')
pump(100)
last = h.eval(pulse, 'hyprSocket.written[hyprSocket.written.length - 1]')
check('stopping restores the exact base border', 'rgb(ff0000)' in last and 'rgb(00ff00)' in last and 'rgba(00000080)' in last, last)
check('stopping releases cava and the timer',
      h.eval(pulse, 'ticker.running') is False and h.eval(pulse, 'Object.keys(CavaService.consumers).length') == 0)

sys.exit(0 if ok_all else 1)
