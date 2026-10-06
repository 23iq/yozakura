"""AI bar spaces, empty states and action rows on the real panel.

Real AiCenterPanel and components with the scripted Ai stub
(tests/fixtures/aicenter-ai-stub.qml.in) in tests/lib/aiscene.py: the space
switch shows Code (project bar, gear, project-grouped history) and back,
the Assistant empty state offers contextual chips or the "Connect a model"
call to action, and an undoable tool call shows a working Undo button.
"""
import json
import os
import sys
from pathlib import Path

os.environ["QT_QUICK_CONTROLS_STYLE"] = "Basic"
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import headless  # noqa: E402,F401
from lib import aiscene  # noqa: E402
from PySide6.QtCore import QObject, QUrl, QCoreApplication, QElapsedTimer, Qt  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402
from PySide6.QtGui import QGuiApplication  # noqa: E402
from PySide6.QtQml import QQmlEngine, QQmlExpression  # noqa: E402
from PySide6.QtQuick import QQuickView  # noqa: E402

REPO = Path(__file__).resolve().parents[1]
app = QGuiApplication([])
root = aiscene.build("Sumi-e", "light", (REPO / "tests/fixtures/aicenter-ai-stub.qml.in").read_text())
scene = root / "Spaces.qml"
scene.write_text("""import QtQuick
import qs.modules.services
import qs.modules.globals
import qs.config
import qs.modules.aicenter
Item {
    width: 1280; height: 760
    AiCenterPanel { id: panel; objectName: "panel"; anchors.fill: parent }
    function space() { return GlobalStates.aiSpace; }
    function noModels() { Ai.models = Ai.models.map(m => Object.assign({}, m, {available: false})); }
    function someModels() { Ai.models = Ai.models.map(m => Object.assign({}, m, {available: true})); }
    function wide() { GlobalStates.assistantWide = true; }
    function settingsOpened() { return Ai.settingsOpened; }
    function stream(text) { Ai.chat.rows.setProperty(Ai.chat.rows.count - 1, "content", text); }
    function undone() { return JSON.stringify(Ai.undone); }
    function addUndoable() {
        Ai.chat.append({role: "user", content: "Start a tea timer"});
        Ai.chat.append({role: "assistant", content: "Started.", toolCalls: [
            {id: "t1", name: "timer_start", title: "Timer 3:00 started", status: "done", args: {minutes: 3},
             undo: {server: "yozakura", tool: "timer_cancel", args: {id: "tea"}, label: ""}},
            {id: "t2", name: "windows_list", title: "Listed windows", status: "done", args: {}, result: "[]"}
        ]});
    }
}
""")

view = QQuickView()
view.engine().addImportPath(str(root))
view.setResizeMode(QQuickView.SizeRootObjectToView)
view.resize(1280, 760)
view.setSource(QUrl.fromLocalFile(str(scene)))
assert view.status() == QQuickView.Ready, view.errors()
view.show()
top = view.rootObject()


def pump(ms=120):
    t = QElapsedTimer()
    t.start()
    while t.elapsed() < ms:
        QCoreApplication.processEvents()


def ev(target, expr):
    e = QQmlExpression(QQmlEngine.contextForObject(target) or view.engine().rootContext(), target, expr)
    value = e.evaluate()
    assert not e.hasError(), f"{expr}: {e.error().toString()}"
    return value[0] if isinstance(value, tuple) else value


def click(obj):
    point = obj.mapToScene(obj.boundingRect().center())
    QTest.mouseClick(view, Qt.LeftButton, Qt.NoModifier, point.toPoint())
    pump()


def find(name, item=None):
    """Item by objectName, walking the visual tree (Repeater delegates are
    not QObject children of their view)."""
    item = item or top
    if item.objectName() == name:
        return item
    for child in item.childItems():
        hit = find(name, child)
        if hit is not None:
            return hit
    return None


def find_all(name, item=None, out=None):
    out = [] if out is None else out
    item = item or top
    if item.objectName() == name:
        out.append(item)
    for child in item.childItems():
        find_all(name, child, out)
    return out


def visible(name):
    obj = find(name)
    return obj is not None and obj.property("visible")


pump()
# Assistant empty state: greeting + contextual chips from Ai.ambientContext().
assert ev(top, "space()") == "assistant"
assert visible("welcomeView"), "empty assistant chat shows the welcome view"
chips = find("suggestionChips")
labels = ev(chips, "JSON.stringify(children.filter(c => c.label !== undefined).map(c => c.label))")
labels = json.loads(labels)
assert any("error" in t.lower() for t in labels), labels
assert any("Clair de lune" in t for t in labels), labels
assert not visible("connectModel")
assert not visible("projectBar") and not visible("headerSettings"), "gear and project bar belong to Code"

# No usable model: one call to action that opens the settings.
ev(top, "noModels()")
pump()
assert visible("connectModel") and not visible("suggestionChips")
ev(find("welcomeView"), "connectRequested()")
assert ev(top, "settingsOpened()") == 1, "the call to action opens the provider settings"
ev(top, "someModels()")
pump()

# Space switch -> Code: project bar, gear, detailed transcript of the agent.
click(find("space_code"))
assert ev(top, "space()") == "code"
assert visible("projectBar") and visible("headerSettings")
assert ev(find("projectButton"), "children.length") > 0
assert not visible("welcomeView")
ev(top, "wide()")
pump(200)
assert visible("headerHistory") is False, "wide sizes dock the history column"
drawer_rows = None
for obj in top.findChildren(QObject):
    if obj.property("docked") is True and obj.property("space") == "code":
        drawer_rows = json.loads(ev(obj, "JSON.stringify(rows)"))
assert drawer_rows and drawer_rows[0]["header"] and drawer_rows[0]["name"] == "yozakura", drawer_rows
assert all(r["header"] or r["kind"] == "agent" for r in drawer_rows), "Code history lists agent sessions only"

# Back to the Assistant: the chat and its history return.
click(find("space_assistant"))
assert ev(top, "space()") == "assistant" and not visible("projectBar")
for obj in top.findChildren(QObject):
    if obj.property("docked") is True and obj.property("space") == "assistant":
        rows = json.loads(ev(obj, "JSON.stringify(rows)"))
        assert {r["kind"] for r in rows} == {"chat"}, rows

# Action rows: undoable tool call shows Undo, which runs the descriptor once.
ev(top, "addUndoable()")
pump(200)
rows = find_all("actionRow")
assert len(rows) == 2, len(rows)
undoable = [r for r in rows if r.property("canUndo")]
assert len(undoable) == 1
undo_chip = find("actionUndo", undoable[0])
assert undo_chip.property("visible")
ev(undoable[0], "undoRequested(undoInfo)")
pump()
assert json.loads(ev(top, "undone()")) == ["timer_cancel"]
assert not undoable[0].property("canUndo"), "undo is offered once"
assert find("actionTitle", undoable[0]).property("text").startswith("Undone")
other = [r for r in rows if not r.property("canUndo")][0]
assert not other.property("expanded"), "tool details start collapsed (ai.behavior.collapseTools)"
ev(other, "expanded = true")
pump()
assert other.property("implicitHeight") > 30

# Streaming into a source row patches its transcript rows in place.
chat_list = find("workspaceChatList")
before = chat_list.property("count")
ev(top, "stream('Started. Enjoy your tea!')")
pump()
assert chat_list.property("count") == before, "a streamed token must not add or drop rows"
texts = json.loads(ev(chat_list, "JSON.stringify(Array.from({length: count}, (_, i) => model.get(i).text))"))
assert "Started. Enjoy your tea!" in texts, texts

view.close()
view.deleteLater()
pump(50)
print("ai-spaces: ok")
