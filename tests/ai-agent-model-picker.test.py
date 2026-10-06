"""Model picker on the real AiCenterPanel (scripted Ai stub): CLI agents
expand into their own models, a child row picks engine + model in one
step (Ai.pickAgentModel), the current agent model is marked and the
picker opens expanded on it, a search finds agent models, and the
manual model field picks a typed id.
"""
import os
import sys
from pathlib import Path

os.environ["QT_QUICK_CONTROLS_STYLE"] = "Basic"
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import headless  # noqa: E402,F401
from lib import aiscene  # noqa: E402
from PySide6.QtCore import QCoreApplication, QElapsedTimer, QUrl, qInstallMessageHandler  # noqa: E402
from PySide6.QtGui import QGuiApplication  # noqa: E402
from PySide6.QtQml import QQmlEngine, QQmlExpression  # noqa: E402
from PySide6.QtQuick import QQuickView  # noqa: E402

REPO = Path(__file__).resolve().parents[1]
app = QGuiApplication([])
errors = []
qInstallMessageHandler(lambda mode, ctx, msg: errors.append(msg) if ("aicenter" in msg and "Binding loop" not in msg) or "TypeError" in msg or "ReferenceError" in msg else None)

root = aiscene.build("Yozakura Night", "dark", (REPO / "tests/fixtures/aicenter-ai-stub.qml.in").read_text())
scene = root / "Picker.qml"
scene.write_text("""import QtQuick
import qs.modules.services
import qs.modules.aicenter
Item {
    width: 900; height: 760
    AiCenterPanel { id: panel; anchors.fill: parent }
    function openPicker() { Ai.modelSelectionRequested(); }
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


def picker():
    from PySide6.QtCore import QObject
    return top.findChild(QObject, "workspaceEnginePicker")


ev("Ai.setSpace('assistant')")
ev("openPicker()")
pump(300)
p = picker()
assert ev("opened", p), "the picker opens"
assert find("pickerRow_m:agent:claude") is not None, "agents are listed"
assert find("pickerRow_am:claude:sonnet") is None, "agents start collapsed while an HTTP model is current"
assert ev("rows.find(r => r.key === 'm:agent:claude').expandable", p)

# Tapping the agent expands its models (no engine change yet).
assert ev("activate(rows.findIndex(r => r.key === 'm:agent:claude'))", p)
pump()
assert ev("opened", p), "expanding keeps the picker open"
assert ev("Ai.agentPicks.length") == 0
assert find("pickerRow_am:claude:sonnet") is not None, "expanded agents list their models"
assert find("pickerRow_am:claude:default") is not None
assert find("pickerRow_amm:claude") is not None, "agents that accept any id get a manual field"

# One tap on a child = engine + model.
ev("activated()", find("pickerRow_am:claude:sonnet"))
pump()
assert ev("Ai.agentPicks[0]") == "claude/sonnet", ev("JSON.stringify(Ai.agentPicks)")
assert not ev("opened", p), "picking closes the picker"
assert ev("Ai.mode") == "agent"

# Reopening: expanded on the current agent, its model marked.
ev("openPicker()")
pump(300)
row = find("pickerRow_am:claude:sonnet")
assert row is not None, "the current agent opens expanded"
assert ev("current", row), "the chosen agent model is marked"
assert not ev("current", find("pickerRow_am:claude:default"))
assert ev("rows[selectedIndex].key", p) == "am:claude:sonnet", "the selection starts on the current model"

# The agent default alias is passed as "" (the CLI resolves it).
ev("activated()", find("pickerRow_am:claude:default"))
pump()
assert ev("Ai.agentPicks[1]") == "claude/"

# Search finds agent models by name.
ev("openPicker()")
pump(300)
ev("Ai.pickedAgentModel = 'sonnet'")
find("pickerSearch").setProperty("text", "sonnet")
pump()
assert find("pickerRow_am:claude:sonnet") is not None, "a search lists matching agent models"
assert find("pickerRow_am:claude:default") is None, "non-matching agent models are hidden"
assert find("pickerRow_m:anthropic:claude-sonnet-4-5") is not None, "HTTP models still match"
find("pickerSearch").setProperty("text", "")
pump()

# Manual model id.
field = find("agentManualModel", find("pickerRow_amm:claude"))
field.setProperty("text", "claude-haiku-4-5")
ev("accepted()", field)
pump()
assert ev("Ai.agentPicks[2]") == "claude/claude-haiku-4-5", ev("JSON.stringify(Ai.agentPicks)")

bad = [m for m in errors if "Binding loop" not in m and "/assets/aiproviders/" not in m]
assert not bad, "\n".join(bad[:8])
print("ai-agent-model-picker: ok")
