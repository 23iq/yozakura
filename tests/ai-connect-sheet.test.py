"""Connect provider sheet on the real AiCenterPanel (scripted Ai stub with the
real ProviderSetup; KeyStore/BackendService/SettingsStore are scene stubs,
tests/lib/aiscene.py). No network: `providers.test` / `providers.ollama.probe`
answers are scripted.

- The picker footer, a not-connected row and the Assistant CTA open the
  sheet inside the bar; step 1 lists every preset with its state.
- Step 2: key validation, Test (spinner -> model count / error), Save to
  the KeyStore, Disconnect; Custom keeps endpoint + curl template.
- Ollama: no key, probed when the form opens (models with capabilities),
  "Use this server" stores ai.ollama.endpoint.
- The old `ollama: enabled` KeyStore entry is migrated away quietly.
- Hidden providers are marked and left out of the picker's unconnected list.
"""
import json
import os
import sys
from pathlib import Path

os.environ["QT_QUICK_CONTROLS_STYLE"] = "Basic"
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import headless  # noqa: E402

headless.ensure(gl=True)
from lib import aiscene  # noqa: E402
from PySide6.QtCore import QCoreApplication, QElapsedTimer, Qt, QUrl, qInstallMessageHandler  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402
from PySide6.QtGui import QGuiApplication  # noqa: E402
from PySide6.QtQml import QQmlEngine, QQmlExpression  # noqa: E402
from PySide6.QtQuick import QQuickView  # noqa: E402

REPO = Path(__file__).resolve().parents[1]
app = QGuiApplication([])
errors = []
qInstallMessageHandler(lambda mode, ctx, msg: errors.append(msg) if ("aicenter" in msg and "Binding loop" not in msg) or "TypeError" in msg or "ReferenceError" in msg else None)

root = aiscene.build("Yozakura Night", "dark", (REPO / "tests/fixtures/aicenter-ai-stub.qml.in").read_text())
scene = root / "Connect.qml"
scene.write_text("""import QtQuick
import qs.config
import qs.modules.services
import qs.modules.settings.store
import qs.modules.aicenter
Item {
    width: 900; height: 760
    AiCenterPanel { id: panel; anchors.fill: parent }
    function openPicker() { Ai.modelSelectionRequested(); }
    function respond(method, fn) {
        const r = Object.assign({}, BackendService.responses);
        r[method] = fn;
        BackendService.responses = r;
    }
    function lastCall(method) {
        const c = BackendService.calls.filter(x => x.method === method);
        return c.length ? JSON.stringify(c[c.length - 1].params) : "";
    }
    function callCount(method) { return BackendService.calls.filter(x => x.method === method).length; }
}
""")

view = QQuickView()
view.engine().addImportPath(str(root))
view.setResizeMode(QQuickView.SizeRootObjectToView)
view.resize(900, 760)
view.setSource(QUrl.fromLocalFile(str(scene)))
assert view.status() == QQuickView.Ready, view.errors()
view.show()
top = view.rootObject()


def pump(ms=150):
    t = QElapsedTimer()
    t.start()
    while t.elapsed() < ms:
        QCoreApplication.processEvents()


def ev(expr, target=None):
    target = target or top
    e = QQmlExpression(QQmlEngine.contextForObject(target) or view.engine().rootContext(), target, expr)
    value = e.evaluate()
    assert not e.hasError(), f"{expr}: {e.error().toString()}"
    return value[0] if isinstance(value, tuple) else value


def find(name, item=None):
    item = item or view.contentItem()
    if item.objectName() == name:
        return item
    for child in item.childItems():
        hit = find(name, child)
        if hit is not None:
            return hit
    return None


def shown(name):
    obj = find(name)
    if obj is None:
        return False
    while obj is not None:
        if not obj.property("visible"):
            return False
        obj = obj.parentItem()
    return True


def click(obj):
    assert obj is not None
    point = obj.mapToScene(obj.boundingRect().center())
    QTest.mouseClick(view, Qt.LeftButton, Qt.NoModifier, point.toPoint())
    pump()


def type_into(name, text):
    field = find(name + "Input")
    assert field is not None, name
    field.setProperty("text", text)
    pump(50)


def status_text():
    return find("connectStatusText").property("text") if shown("connectStatus") else ""


def sheet_open():
    return bool(find("connectSheet").property("opened"))


pump()
assert not sheet_open(), "closed at start"

# ── the legacy Ollama opt-in key is migrated away ───────────────────────
ev("KeyStore.keyCache = ({ollama: {api_key: 'enabled', endpoint: 'http://old-gpu:11434', custom_curl: ''}}); KeyStore.keysChanged()")
pump()
assert ev("Config.ai.ollama.endpoint") == "http://old-gpu:11434", "its endpoint moves to ai.ollama.endpoint"
assert ev("KeyStore.keyCache.ollama === undefined"), "the fake key is deleted"
ev("Config.ai.ollama.endpoint = ''")

# ── open from the picker footer: step 1 grid ────────────────────────────
ev("openPicker()")
pump()
click(find("pickerConnect"))
pump(200)
assert sheet_open(), "picker footer opens the sheet in the bar"
for pid in ("openai", "anthropic", "gemini", "mistral", "groq", "minimax", "openrouter", "deepseek", "lmstudio", "ollama", "custom"):
    assert find("tile_" + pid) is not None, pid
assert find("tileState_ollama").property("text") == "Running", "Ollama is connected because it is reachable"
assert find("tileState_openai").property("text") == "Needs an API key"
if os.environ.get("AI_CENTER_RENDER"):
    pump(300)
    view.grabWindow().save(str(Path(os.environ["AI_CENTER_RENDER"]) / "connect-grid.png"))

# ── step 2: OpenAI key, validation, test, save ──────────────────────────
click(find("tile_openai"))
pump(200)
assert shown("connectKey") and shown("connectGetKey") and not shown("connectUrl")
assert not shown("connectDisconnect"), "nothing to disconnect yet"
click(find("connectTest"))
assert "API key first" in status_text(), "an empty key is rejected before any request"
assert ev("callCount('providers.test')") == 0
ev("""respond('providers.test', p => p.key === 'sk-good'
    ? {ok: true, verified: true, error: '', models: [{id: 'gpt-5'}, {id: 'gpt-5-mini'}, {id: 'gpt-4o'}]}
    : {ok: false, verified: false, error: 'HTTP 401: Incorrect API key provided: ***', models: []})""")
type_into("connectKey", "sk-bad")
click(find("connectTest"))
assert "401" in status_text(), status_text()
type_into("connectKey", "sk-good")
click(find("connectTest"))
assert status_text().startswith("It works · 3 models"), status_text()
assert json.loads(ev("lastCall('providers.test')")) == {"provider": "openai", "baseUrl": "https://api.openai.com/v1", "key": "sk-good"}
if os.environ.get("AI_CENTER_RENDER"):
    pump(300)
    view.grabWindow().save(str(Path(os.environ["AI_CENTER_RENDER"]) / "connect-form.png"))
click(find("connectSave"))
pump(300)
assert ev("KeyStore.getKey('openai')") == "sk-good", "saved to the keystore"
assert not sheet_open(), "saving closes the sheet"

# ── MiniMax cannot be verified for free ─────────────────────────────────
ev("Ai.openProviderSettings('minimax')")
pump(200)
assert sheet_open() and shown("connectKey")
ev("respond('providers.test', {ok: true, verified: false, error: '', models: []})")
type_into("connectKey", "mm-key")
click(find("connectTest"))
assert "first message" in status_text(), status_text()
click(find("connectBack"))
pump(200)
assert find("tile_openai") is not None and not shown("connectKey"), "back returns to the grid"
assert find("tileState_openai").property("text") == "Connected"

# ── Disconnect ──────────────────────────────────────────────────────────
click(find("tile_openai"))
pump(200)
assert shown("connectDisconnect")
click(find("connectDisconnect"))
pump(200)
assert ev("KeyStore.keyCache.openai === undefined"), "disconnect deletes the key"
assert find("tile_openai") is not None, "and returns to the grid"

# ── Custom: endpoint + optional key + curl template ─────────────────────
click(find("tile_custom"))
pump(200)
assert shown("connectUrl") and shown("connectKey")
click(find("connectSave"))
assert "base URL" in status_text(), "custom needs a URL"
type_into("connectUrl", "box:8000")
click(find("connectSave"))
assert "http://" in status_text(), "the URL must have a scheme"
type_into("connectUrl", "http://box:8000/v1/")
ev("respond('providers.test', {ok: true, verified: true, error: '', models: [{id: 'llama'}]})")
click(find("connectTest"))
assert json.loads(ev("lastCall('providers.test')"))["baseUrl"] == "http://box:8000/v1/"
assert status_text().startswith("It works · 1 models")
ev("Config.ai.providers.customHeaders = [{name: 'X-Proxy', value: 'tok'}]")
click(find("connectTest"))
assert json.loads(ev("lastCall('providers.test')"))["headers"] == {"X-Proxy": "tok"}, "custom headers are tested too"
assert not shown("connectCurl")
ev("Config.ai.providers.customHeaders = []")
# open the advanced section through the form's own flag
form = find("connectCurl").parentItem()
while form is not None and form.property("advanced") is None:
    form = form.parentItem()
form.setProperty("advanced", True)
pump()
assert shown("connectCurl")
type_into("connectCurl", 'curl -sS "$AI_ENDPOINT" --data-binary @"$AI_BODY_PATH"')
click(find("connectSave"))
pump(300)
custom = json.loads(ev("JSON.stringify(KeyStore.keyCache.custom)"))
assert custom == {"api_key": "", "endpoint": "http://box:8000/v1", "custom_curl": 'curl -sS "$AI_ENDPOINT" --data-binary @"$AI_BODY_PATH"'}, custom

# ── Ollama: probe on open, models with capabilities, endpoint in config ─
PROBE = {"endpoint": "http://gpu:11434", "reachable": True, "version": "0.35.0", "models": [
    {"id": "qwen3.5:9b", "name": "qwen3.5:9b", "sizeLabel": "9.7B", "contextLength": 262144, "capabilities": ["completion", "tools", "thinking"], "detailed": True},
    {"id": "gemma3:4b", "name": "gemma3:4b", "contextLength": 131072, "capabilities": ["completion", "vision"], "detailed": True},
    {"id": "nomic-embed-text", "name": "nomic-embed-text", "capabilities": ["embedding"]}]}
ev(f"respond('providers.ollama.probe', {json.dumps(PROBE)})")
probes = ev("callCount('providers.ollama.probe')")
ev("Ai.openProviderSettings('ollama')")
pump(300)
assert sheet_open() and not shown("connectKey"), "no key for Ollama"
assert ev("callCount('providers.ollama.probe')") == probes + 1, "probed once when the form opens"
assert status_text().startswith("It works · 2 models"), status_text()
assert shown("probeModel_qwen3.5:9b") and shown("probeModel_gemma3:4b") and find("probeModel_nomic-embed-text") is None
assert find("badge_tools", find("probeModel_qwen3.5:9b")) is not None
assert find("badge_chatOnly", find("probeModel_gemma3:4b")) is not None, "no tools capability -> chat only"
if os.environ.get("AI_CENTER_RENDER"):
    pump(300)
    view.grabWindow().save(str(Path(os.environ["AI_CENTER_RENDER"]) / "connect-ollama.png"))
type_into("connectUrl", "http://gpu:11434")
click(find("connectSave"))
pump(300)
assert ev("Config.ai.ollama.endpoint") == "http://gpu:11434"
assert not sheet_open()
ev("Ai.openProviderSettings('ollama')")
pump(300)
ev("respond('providers.ollama.probe', {reachable: false, endpoint: 'http://gpu:11434', error: 'connection refused', models: []})")
click(find("connectTest"))
assert "connection refused" in status_text()
click(find("connectClose"))
pump(200)

# ── hidden providers ────────────────────────────────────────────────────
ev("Config.ai.providers.hidden = ['minimax']")
pump()
assert "minimax" not in json.loads(ev("JSON.stringify(Ai.providers.unconnected.map(p => p.id))"))
ev("Ai.openProviderSettings('')")
pump(200)
assert find("tileState_minimax").property("text") == "Hidden"
click(find("tile_minimax"))
pump(200)
type_into("connectKey", "mm-key")
click(find("connectSave"))
pump(200)
assert ev("JSON.stringify(Config.ai.providers.hidden)") == "[]", "connecting a hidden provider shows it again"
assert ev("KeyStore.getKey('minimax')") == "mm-key"

# ── a not-connected picker row opens its form ───────────────────────────
ev("openPicker()")
pump()
click(find("connect_groq"))
pump(200)
assert sheet_open() and shown("connectKey")
assert ev("Ai.connectProvider") == "groq"
QTest.keyClick(view, Qt.Key_Escape)
pump(200)
assert sheet_open() and find("tile_openai") is not None, "Esc goes back to the grid first"
QTest.keyClick(view, Qt.Key_Escape)
pump(200)
assert not sheet_open(), "then closes the sheet"

bad = [m for m in errors if "assets/aiproviders" not in m]
assert not bad, "\n".join(bad[:10])
print("ai-connect-sheet: ok")
