"""Renaming a conversation edits the title in place in its history row.

The real SessionRow and kit InlineEdit run offscreen: the editor replaces
the title (no overlay over the row's text and buttons), Enter commits a
changed title, Escape and an unchanged title commit nothing.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402
from PySide6.QtCore import QObject  # noqa: E402

h = Harness("ai-session-rename")
h.singleton("qs.config", "Config", "QtObject { property var theme: ({font: 'Sans'}) }")
h.module("qs.modules.theme", {
    "Styling": "pragma Singleton\nQtObject { function radius(o) { return 8 } function fontSize(o) { return 13 } }",
    "Icons": "pragma Singleton\nQtObject { property string font: 'Sans'; property string terminalWindow; property string chatTeardrop; "
             "property string shieldCheck; property string stop; property string notePencil; property string pin; property string trash }",
    "Colors": "pragma Singleton\nQtObject { property color primary; property color tertiary; property color overSurface; "
              "property color outline; property color warning }",
})
h.module("qs.modules.components", {"StyledRect": "Rectangle { property string variant }"})
h.singleton("qs.modules.services", "I18n", "QtObject { function t(k) { return k } }")
h.module("qs.modules.aicenter.common", {
    "IconButton": "Item { property string glyph; property int size; property int iconSize; property bool active; "
                  "property bool danger; property string tooltip; signal clicked }",
    "StatusDot": "Item { property string status }",
})
h.module("qs.modules.components.kit", {
    "Type": "pragma Singleton\nQtObject { property color text; property color accent: 'red'; "
            "function family(r) { return 'Sans' } function size(r) { return 13 } }",
    "Look": "pragma Singleton\nQtObject { property int labelWeight: Font.Normal }",
})
h.copy("modules/components/kit/InlineEdit.qml", "qs/modules/components/kit", siblings=False)
h.module("qs.modules.components.kit", {})
h.copy("modules/aicenter/sessions/SessionRow.qml", siblings=False)
scene = h.load("""import QtQuick
Window {
    visible: true; width: 320; height: 60
    SessionRow {
        objectName: "row"
        width: 300
        entry: ({title: "БД", subtitle: "codex", updated: Date.now(), pinned: false, status: "idle"})
        property var got: []
        onRenamed: t => got = got.concat([t])
    }
}""", auto_stub=False)
row = h.find(scene, "row")


def ev(expr):
    return h.eval(row, expr)


def shown(cls, text=None):
    return [o for o in row.findChildren(QObject)
            if o.metaObject().className().startswith(cls) and o.property("visible")
            and (text is None or o.property("text") == text)]


assert len(shown("QQuickText", "БД")) == 1
ev("renaming = true")
for _ in range(3):
    h.app.processEvents()
assert ev("renaming")
edits = shown("InlineEdit")
assert len(edits) == 1 and edits[0].property("text") == "БД", "the editor replaces the title"
assert not shown("QQuickText", "БД"), "the title text must hide while renaming, not sit under the editor"
assert edits[0].property("selectedText") == "БД", "the editor opens with the title selected"
ev("finishRename('  Новое имя  ')")
assert ev("!renaming && got.length === 1 && got[0] === 'Новое имя'"), ev("JSON.stringify(got)")

ev("renaming = true")
ev("finishRename(entry.title)")
assert ev("got.length === 1"), "an unchanged title is not a rename"

ev("renaming = true")
ev("finishRename('   ')")
assert ev("got.length === 1"), "an empty title is not a rename"
print("ai-session-rename: ok")
