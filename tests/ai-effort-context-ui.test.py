"""Composer strip effort selector, context meter/notice and the model picker
on the real AiCenterPanel (scripted Ai stub, tests/lib/aiscene.py).

- `· level ▾` opens a segmented selector; picking a level calls
  Ai.effort.set(); the chip hides for models without effort levels.
- The context meter shows `170k/200k`, turns amber/red at the thresholds
  and offers Compact (strip and transcript notice) for HTTP chats only.
- The picker shows capability badges (tools, chat only, context size),
  groups by provider, lists unconnected providers with Connect, and
  re-probes Ollama when it opens.
"""
import os
import sys
from pathlib import Path

os.environ["QT_QUICK_CONTROLS_STYLE"] = "Basic"
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import headless  # noqa: E402,F401
from lib import aiscene  # noqa: E402
from PySide6.QtCore import QObject, QCoreApplication, QElapsedTimer, Qt, QUrl, qInstallMessageHandler  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402
from PySide6.QtGui import QGuiApplication  # noqa: E402
from PySide6.QtQml import QQmlEngine, QQmlExpression  # noqa: E402
from PySide6.QtQuick import QQuickView  # noqa: E402

REPO = Path(__file__).resolve().parents[1]
app = QGuiApplication([])
errors = []
qInstallMessageHandler(lambda mode, ctx, msg: errors.append(msg) if ("aicenter" in msg and "Binding loop" not in msg) or "TypeError" in msg or "ReferenceError" in msg else None)

root = aiscene.build("Yozakura Night", "dark", (REPO / "tests/fixtures/aicenter-ai-stub.qml.in").read_text())
scene = root / "Strip.qml"
scene.write_text("""import QtQuick
import qs.modules.services
import qs.modules.aicenter
Item {
    width: 900; height: 760
    AiCenterPanel { id: panel; anchors.fill: parent }
    function openPicker() { Ai.modelSelectionRequested(); }
    function addChat() {
        Ai.chat.append({role: "user", content: "Plan my week"});
        Ai.chat.append({role: "assistant", content: "Sure."});
    }
    function withInfo() {
        Ai.models = Ai.models.map(m => m.provider === "anthropic" ? Object.assign({}, m, {info: {tools: true, vision: true, reasoning: "anthropic_budget", contextWindow: 200000}})
            : (m.provider === "ollama" ? Object.assign({}, m, {tools: false, info: {tools: false, contextWindow: 32768}}) : m));
    }
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
    point = obj.mapToScene(obj.boundingRect().center())
    QTest.mouseClick(view, Qt.LeftButton, Qt.NoModifier, point.toPoint())
    pump()


pump()
# ── effort ───────────────────────────────────────────────────────────────
ev("addChat()")
pump()
chip = find("composerEffort")
assert shown("composerEffort"), "models with effort levels show the selector"
click(chip)
selector = top.findChild(QObject, "effortSelector")
assert selector.property("opened"), "the chip opens the segmented selector"
if os.environ.get("AI_CENTER_RENDER"):
    pump(300)
    view.grabWindow().save(str(Path(os.environ["AI_CENTER_RENDER"]) / "effort.png"))
for level in ("auto", "off", "low", "medium", "high", "max"):
    assert find("effortOption_" + level) is not None, level
click(find("effortOption_high"))
assert ev("JSON.stringify(Ai.effort.chosen)") == '["high"]'
pump(300)
assert not selector.property("visible"), "picking a level closes the selector"
ev("Ai.effort.levels = []")
pump()
assert not shown("composerEffort"), "no effort control for models without levels"
ev("Ai.effort.levels = ['low', 'high']")

# ── context meter and compaction ─────────────────────────────────────────
assert not shown("composerContext"), "no window known -> no meter"
ev("Ai.contextState.window = 200000; Ai.contextState.used = 62000; Ai.contextState.canCompact = true")
pump()
assert shown("composerContext")
assert find("contextLabel").property("text") == "62k/200k"
assert not shown("composerCompact") and not shown("contextNotice"), "below 80 % nothing to do"
ev("Ai.contextState.used = 170000")
pump()
assert shown("composerCompact"), "Compact appears at the warning threshold"
assert shown("contextNotice"), "and a notice above the composer"
assert find("contextLabel").property("color") != find("composerEffort").property("color")
click(find("composerCompact"))
assert ev("Ai.contextState.compactions") == 1
click(find("noticeCompact"))
assert ev("Ai.contextState.compactions") == 2
ev("Ai.contextState.used = 196000")
pump()
assert shown("composerCompact")
# Agents compact themselves: the meter stays, no Compact button.
ev("Ai.setSpace('code')")
pump()
assert shown("composerContext") and not shown("composerCompact")
ev("Ai.setSpace('assistant')")
pump()

if os.environ.get("AI_CENTER_RENDER"):
    ev("Ai.contextState.used = 170000")
    pump()
    view.grabWindow().save(str(Path(os.environ["AI_CENTER_RENDER"]) / "strip.png"))

# ── model picker ─────────────────────────────────────────────────────────
ev("withInfo()")
probes = ev("Ai.catalog.probes")
ev("openPicker()")
pump(300)
assert ev("Ai.catalog.probes") == probes + 1, "opening the picker re-probes Ollama"
assert shown("pickerSearch") and shown("pickerRefresh") and shown("pickerConnect")
sonnet = find("pickerRow_m:anthropic:claude-sonnet-4-5")
assert sonnet is not None, "models are listed by provider"
for kind in ("tools", "vision", "thinking", "context"):
    assert find("badge_" + kind, sonnet) is not None, kind
qwen = find("pickerRow_m:ollama:qwen3.5:9b")
assert find("badge_chatOnly", qwen) is not None, "Ollama models without tools are chat only"
connect = find("connect_openai")
assert connect is not None, "providers without a key are listed with Connect"
ev("clicked()", connect)  # the row may be scrolled out of the clipped list
pump()
assert ev("Ai.connectProvider") == "openai"
ev("openPicker()")
pump(300)
search = find("pickerSearch")
if os.environ.get("AI_CENTER_RENDER"):
    view.grabWindow().save(str(Path(os.environ["AI_CENTER_RENDER"]) / "picker-all.png"))
search.setProperty("text", "gemini")
pump()
assert find("pickerRow_m:gemini:gemini-2.5-flash") is not None
assert find("pickerRow_m:anthropic:claude-sonnet-4-5") is None, "search filters the list"

if os.environ.get("AI_CENTER_RENDER"):
    view.grabWindow().save(str(Path(os.environ["AI_CENTER_RENDER"]) / "picker.png"))
# The scene has no assets/ (provider icons): those load errors are expected.
bad = [m for m in errors if "Binding loop" not in m and "/assets/aiproviders/" not in m]
assert not bad, "\n".join(bad[:8])
print("ai-effort-context-ui: ok")
