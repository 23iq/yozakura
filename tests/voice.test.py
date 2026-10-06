"""Voice input QML, offscreen: VoiceService routing and the listening panel.

* VoiceService (real file, stubbed backend/compositor/AI singletons): the
  panel opens on "listening" on the focused screen, level events feed the
  bars, finished transcripts go to dictation typing (after the panel
  released focus) or to Ai.handleVoice / the sidebar fallback, and
  dismissing the panel cancels an active session.
* VoicePanel (the notch registry panel "voice") + VoiceBars (real files)
  render every state with a dark and a light palette; set
  VOICE_RENDER_DIR=<dir> to keep the PNGs. The registry/controller side
  (auto open, dismissal) is covered in hover-expansion.test.py.
"""
import json
import os
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import REPO, Harness  # noqa: E402
from lib import kit_stubs  # noqa: E402
from PySide6.QtCore import QSize  # noqa: E402
from PySide6.QtGui import QColor  # noqa: E402
from PySide6.QtQuick import QQuickWindow  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

ok_all = True


def check(name, ok, detail=""):
    global ok_all
    ok_all &= bool(ok)
    print(("PASS " if ok else "FAIL ") + name + (" " + detail if detail else ""))


h = Harness("voice")
EN = json.loads((REPO / "translations/en.json").read_text())

h.singleton("qs.config", "Config", """QtObject {
    property int animDuration: 0
    property QtObject theme: QtObject { property string font: "Sans"; property string monoFont: "Monospace" }
    property QtObject voice: QtObject { property int previewMs: 0; property bool aiAutoSend: false }
}""")
h.module("Quickshell", {"Singleton": "Item {}"})
h.module("Quickshell.Io", {"IpcHandler": "QtObject { property string target }"})
h.singleton("qs.modules.globals", "GlobalStates", """QtObject {
    property bool assistantVisible: false
    property int toggles: 0
    function toggleAssistant() { toggles++; assistantVisible = true; }
}""")
h.module("qs.modules.services", {
    "I18n": "pragma Singleton\nQtObject { property var strings: (" + json.dumps(EN) + ")\n"
            "  function t(k) { var s = strings[k] || k; for (var i = 1; i < arguments.length; i++) s = s.replace('%' + i, arguments[i]); return s; } }",
    "BackendService": """pragma Singleton
QtObject {
    property var calls: []
    property var handler: null
    function call(method, params, cb) { calls = calls.concat([{ method: method, params: params }]); }
    function addSubscription(services, cb) { handler = cb; return 1; }
    function emit(service, data) { handler(service, data); }
}""",
    "YozdService": """pragma Singleton
QtObject {
    property var focusedMonitor: ({ name: "DP-1" })
}""",
    "Ai": """pragma Singleton
QtObject {
    property var voiceCalls: []
    property var sent: []
    // Ai.handleVoice(text, target) from feat/ai-center; null until installed
    property var handleVoice: null
    function sendMessage(text, attachments) { sent = sent.concat([text]); }
}""",
})

# ---------------------------------------------------------------- service
svc_file = h.copy("modules/services/VoiceService.qml", dest="svc", strip_singleton=True)
svc_root = h.load("""
import QtQuick
import qs.modules.services
import qs.modules.globals
import "../svc" as Svc
Item {
    Svc.VoiceService { id: voice; objectName: "voice" }
    property alias voice: voice
    function emitState(s) { BackendService.emit("voice.state", s); }
    function emitLevel(l) { BackendService.emit("voice.level", l); }
    function methods() { return BackendService.calls.map(c => c.method).join(","); }
    function lastParams() { return BackendService.calls[BackendService.calls.length - 1].params; }
    function module() { return voice.panelOpen ? "voice" : ""; }
    function closeModule() { voice.dismiss(); }
    function installApi() { Ai.handleVoice = function(t, target) { Ai.voiceCalls = Ai.voiceCalls.concat([t + "|" + target]); }; }
}
""")
ev = lambda expr: h.eval(svc_root, expr)  # noqa: E731

ev('emitState({state: "listening", session: 1, target: "dictation", mode: "push-to-talk", language: "auto"})')
QTest.qWait(20)
check("listening opens the voice panel", ev("module()") == "voice" and ev("voice.panelScreen") == "DP-1")
ev('emitLevel({session: 1, level: 0.6, bands: [0.1, 0.9, 0.4], speech: true, elapsedMs: 1530})')
QTest.qWait(20)
check("level events feed bands/elapsed", ev("voice.bands.length === 3") and ev("voice.elapsedMs") == 1530 and ev("voice.speech"))
ev('emitLevel({session: 99, level: 1, bands: [1], elapsedMs: 9})')
QTest.qWait(20)
check("stale session levels are ignored", ev("voice.elapsedMs") == 1530)
ev('emitState({state: "transcribing", session: 1, target: "dictation", elapsedMs: 2100})')
QTest.qWait(20)
check("transcribing keeps the panel", ev("module()") == "voice" and ev("voice.elapsedMs") == 2100)
ev('emitState({state: "done", session: 1, target: "dictation", text: "Привет, мир.", language: "ru"})')
QTest.qWait(40)
check("dictation closes the panel before typing", ev("module()") == "" and "voice.type" not in ev("methods()").split(","))
QTest.qWait(250)
check("dictation types the transcript", ev("methods()").split(",")[-1] == "voice.type" and ev("lastParams().text") == "Привет, мир.")

# Voice to AI goes through Ai.handleVoice; the target follows the sidebar state.
ev("installApi()")
ev("GlobalStates.assistantVisible = true")
ev('emitState({state: "listening", session: 3, target: "ai"})')
QTest.qWait(20)
ev('emitState({state: "done", session: 3, target: "ai", text: "hello"})')
QTest.qWait(60)
ev("GlobalStates.assistantVisible = false")
ev('emitState({state: "listening", session: 4, target: "ai"})')
QTest.qWait(20)
ev('emitState({state: "done", session: 4, target: "ai", text: "quick"})')
QTest.qWait(60)
check("Ai.handleVoice gets sidebar/notch targets", ev("Ai.voiceCalls.join(',')") == "hello|sidebar,quick|notch",
      ev("Ai.voiceCalls.join(',')"))

# Closing the panel while listening cancels the session (mic closes).
ev('emitState({state: "listening", session: 5, target: "ai"})')
QTest.qWait(20)
ev("closeModule()")
QTest.qWait(20)
check("closing the panel cancels", ev("methods()").split(",")[-1] == "voice.cancel")
ev('emitState({state: "cancelled", session: 5, target: "ai"})')
QTest.qWait(20)
check("cancelled hides the panel", not ev("voice.panelOpen"))

# Errors stay visible briefly, then close.
ev('emitState({state: "listening", session: 6, target: "ai"})')
QTest.qWait(20)
ev('emitState({state: "empty", session: 6, target: "ai", reason: "no_speech"})')
QTest.qWait(20)
check("empty result is shown", ev("module()") == "voice")
QTest.qWait(1500)
check("empty result dismisses itself", ev("module()") == "")

# ------------------------------------------------------------------- view
PALETTES = {
    "dark": {"primary": "#ffb3ae", "tertiary": "#e1c38c", "overBackground": "#f1dedd", "overSurfaceVariant": "#d8c2c0",
             "error": "#ffb4ab", "background": "#1a1111", "surface": "#231918", "surfaceBright": "#423736", "overPrimary": "#571d1c"},
    "light": {"primary": "#8f4a4c", "tertiary": "#7a5a2f", "overBackground": "#231919", "overSurfaceVariant": "#524343",
              "error": "#ba1a1a", "background": "#fff8f7", "surface": "#fceae9", "surfaceBright": "#fff8f7", "overPrimary": "#ffffff"},
}
colors_props = "\n".join(f'    property color {k}: "{v}"' for k, v in PALETTES["dark"].items())
h.module("qs.modules.theme", {
    "Colors": "pragma Singleton\nQtObject {\n" + colors_props + "\n}",
    "Styling": "pragma Singleton\nQtObject { function fontSize(n) { return 14 + n; } function monoFontSize(n) { return 13 + n; } function radius(n) { return Math.max(0, 12 + n); } }",
    "Icons": 'pragma Singleton\nQtObject { property string font: "Sans"; property string mic: "●"; property string alert: "!"; '
             'property string keyboard: "K"; property string sparkle: "*"; property string circleNotch: "◌" }',
})
h.module("qs.modules.components", {"StyledRect": """Rectangle {
    property string variant
    property bool enableShadow
    property color item: variant === "primary" ? Colors.overPrimary : Colors.overBackground
    color: variant === "primary" ? Colors.primary : Colors.surface
}"""})
(h.root / "qs/modules/components/StyledRect.qml").write_text(
    "import QtQuick\nimport qs.modules.theme\n" + (h.root / "qs/modules/components/StyledRect.qml").read_text().split("\n", 1)[1])
h.module("qs.modules.services", {"VoiceService": """pragma Singleton
QtObject {
    property string state: "listening"
    property string target: "ai"
    property string activation: "push-to-talk"
    property bool handsFree: false
    property int elapsedMs: 7400
    property string language: "auto"
    property string text: ""
    property string error: ""
    property real level: 0.55
    property var bands: []
    property bool speech: true
    function cancel() {}
    function stop() {}
}"""})

kit_stubs.install(h)
view_file = h.copy("modules/widgets/defaultview/panels/VoicePanel.qml", dest="modules/widgets/defaultview/panels")
# VoiceModel.js was already copied next to the service; the view needs it too
(h.root / "modules/services/voice").mkdir(parents=True, exist_ok=True)
(h.root / "modules/services/voice/VoiceModel.js").write_text((REPO / "modules/services/voice/VoiceModel.js").read_text())
render_dir = Path(os.environ.get("VOICE_RENDER_DIR") or tempfile.mkdtemp(prefix="voice-render-"))
render_dir.mkdir(parents=True, exist_ok=True)
view_root = h.load("""
import QtQuick
import qs.modules.services
import qs.modules.theme
import "../modules/widgets/defaultview/panels" as V
Rectangle {
    width: 480; height: 240
    color: Colors.background
    V.VoicePanel { id: view; objectName: "view"; width: 480 }
    property alias view: view
    function setState(props) { for (var k in props) VoiceService[k] = props[k]; }
    function setPalette(p) { for (var k in p) Colors[k] = p[k]; }
}
""")
win = QQuickWindow()
win.resize(QSize(480, 240))
view_root.setParentItem(win.contentItem())
win.show()

bands = [round(0.15 + 0.8 * abs(((i * 37) % 23) / 23 - 0.5) * 2, 3) for i in range(24)]
STATES = {
    "listening": {"state": "listening", "target": "ai", "bands": bands, "language": "auto", "text": ""},
    "dictation_hands_free": {"state": "listening", "target": "dictation", "handsFree": True, "bands": bands, "language": "ru"},
    "transcribing": {"state": "transcribing", "target": "ai", "language": "auto"},
    "done": {"state": "done", "target": "ai", "language": "ru", "text": "Напомни мне завтра в девять утра позвонить маме."},
    "no_speech": {"state": "empty", "target": "dictation", "text": ""},
    "not_installed": {"state": "error", "target": "ai", "error": "not_installed"},
}
for pal_name, pal in PALETTES.items():
    h.eval(view_root, f"setPalette({json.dumps(pal)})")
    for name, props in STATES.items():
        h.eval(view_root, f"setState({json.dumps(props)})")
        for _ in range(6):  # several level updates so the smoothed bars settle
            h.eval(view_root, f"setState({{bands: {json.dumps(bands)}}})")
            QTest.qWait(15)
        QTest.qWait(80)
        img = win.grabWindow()
        path = render_dir / f"voice-{name}-{pal_name}.png"
        img.save(str(path))
        bg = QColor(pal["background"])
        distinct = sum(1 for x in range(0, img.width(), 6) for y in range(0, img.height(), 6)
                       if QColor(img.pixel(x, y)).rgb() != bg.rgb())
        check(f"render {name}/{pal_name}", img.width() > 0 and distinct > 20, f"{distinct} px -> {path.name}")

check("view height fits the notch", 60 < h.eval(view_root, "view.implicitHeight") < 240,
      str(h.eval(view_root, "view.implicitHeight")))
h.eval(view_root, 'setState({state: "listening", target: "ai", handsFree: false})')
check("hold hint", h.eval(view_root, "view.hintText()") == EN["voice.hint.release"])
h.eval(view_root, 'setState({handsFree: true})')
check("hands-free hint", h.eval(view_root, "view.hintText()") == EN["voice.hint.hands_free"])
print(f"renders in {render_dir}")

if not ok_all:
    raise SystemExit(1)
