"""The selection popup displays selectable plain text and routes explicit actions.

The real SelectionMenuWindow over stubs of the kit pieces it is built from
(Surface, ListRow, SearchField, Chip, ...): the result preview, the copy /
continue chips, and the action list driven from the ask field (arrows,
Enter, a digit typed into the empty field, Escape).
"""
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
os.environ["QT_QUICK_CONTROLS_STYLE"] = "Basic"
from lib.qmlharness import Harness  # noqa: E402

h = Harness("ai-selection-preview")
h.module("Quickshell", {"Placeholder": "QtObject {}"})
h.module("qs.modules.aicenter.common", {"Spinner": "Item {}"})
h.singleton("qs.config", "Config", "QtObject { property var ai: ({sidebarWidth: 400}); property var theme: ({font: 'Sans', monoFont: 'Monospace'}); property int animDuration: 0 }")
h.singleton("qs.modules.services", "I18n", "QtObject { function t(key) { return key; } }")
h.module("qs.modules.globals", {})
h.singleton("qs.modules.theme", "Styling", "QtObject { function fontSize(offset) { return 14 + offset; } function monoFontSize(offset) { return 14 + offset; } function radius(offset) { return Math.max(12 + offset, 0); } }")
h.singleton("qs.modules.theme", "Colors", "QtObject { property color outline: '#888888'; property color overSurface: '#eeeeee'; property color overBackground: '#eeeeee'; property color error: '#ff0000'; property color primary: '#ee88ff' }")
h.singleton("qs.modules.theme", "Icons", "QtObject { property string font: 'Sans'; property string sparkle: '*'; property string sidebarSimple: 's'; property string clipboardText: 'c'; property string cursorText: 't' }")
h.singleton("qs.modules.theme", "Motion", "QtObject { property var exit: ({duration: 0}); property var morph: ({easing: Easing.OutCubic}) }")
h.module("qs.modules.components", {"StyledRect": "Rectangle { property string variant; property bool enableShadow; color: 'transparent' }"})
h.module("qs.modules.components.kit", {
    "Space": "pragma Singleton\nQtObject { property int xs: 4; property int s: 8; property int m: 12; property int l: 16; property int xl: 24; property int controlM: 40 }",
    "Look": "pragma Singleton\nQtObject { property int rowInset: 12; function radius(r, h) { return 8 } }",
    "Type": "pragma Singleton\nQtObject { property color text: 'white'; property color accent: 'pink'; property color danger: 'red'; "
            "function family(r) { return 'Sans' } function size(r) { return 13 } }",
    "Surface": "Rectangle { property int padding; property bool enableShadow; default property alias content: body.data; "
               "implicitHeight: body.childrenRect.height + 2 * padding; "
               "Item { id: body; anchors.fill: parent; anchors.margins: parent.padding } }",
    "KitText": "Text { property string role }",
    "Icon": "Item { property string role; property string tone; property string icon }",
    "KeyHint": "Item { property string text }",
    "Chip": "Item { property bool primary; property string icon; property string text; signal clicked; implicitWidth: 40; implicitHeight: 24 }",
    "ListRow": "Item { property string title; property bool highlighted; property Component leading; property Component trailing; "
               "signal clicked; implicitHeight: 30 }",
    "SearchField": "Item { property string text; property bool boxed; property string glyph; property string placeholderText; "
                   "property bool clearOnEscape: true; signal escapePressed; signal downPressed; signal upPressed; signal accepted; "
                   "signal searchTextChanged(string value); function focusInput() {} function clear() { text = '' } implicitHeight: 30 }",
})
path = "modules/aicenter/selection/SelectionMenuWindow.qml"
source = (Path(__file__).resolve().parents[1] / path).read_text()
# Layer shell only hosts the tested content; offscreen tests use an Item host.
content = source.replace("import Quickshell.Wayland\n", "").replace("PanelWindow {", "Item {", 1)
content = re.sub(r"\n    anchors \{[^}]*\}", "", content, count=1)
content = re.sub(r"\n    mask: Region \{[^}]*\}", "", content, count=1)
content = "\n".join(line for line in content.split("\n") if not re.match(r'\s*(screen:|color: "transparent"|exclusionMode:|WlrLayershell\.)', line))
content = content.replace("Quickshell.screens.find(s => s.name === actions.screenName) || Quickshell.screens[0]", "({x: 0, y: 0})")
h.copy(path, replace={source: content}, siblings=False)
root = h.load('''Item {
    width: 800; height: 600
    property QtObject state: QtObject {
        property bool working: false
        property bool hasResult: false
        property string result: ""
        property string text: "source"
        property string screenName: "test"
        property point cursor: Qt.point(100, 100)
        property string workingLabel: ""
        property string error: ""
        property var actions: []
        property var ran: []
        property var asked: []
        property int closed: 0
        property int copied: 0
        property int opened: 0
        function copyResult() { copied++; }
        function openResult() { opened++; }
        function run(a) { ran = ran.concat([a.id]); }
        function ask(t) { asked = asked.concat([t]); }
        function close() { closed++; }
    }
    SelectionMenuWindow { objectName: "menuWindow"; anchors.fill: parent; actions: parent.state }
}''', auto_stub=False)
h.eval(root, 'state.result = "<b>inspect me</b>\\nsecond line"; state.hasResult = true')
h.app.processEvents()
preview = h.find(root, "selectionResult")
assert preview.property("text") == "<b>inspect me</b>\nsecond line"
assert preview.property("readOnly") is True
assert preview.property("selectByMouse") is True
assert h.eval(preview, "textFormat === TextEdit.PlainText") is True
copy_button = h.find(root, "selectionCopy")
continue_button = h.find(root, "selectionContinue")
assert copy_button.property("visible") is True
assert continue_button.property("visible") is True
assert h.find(root, "selectionAsk").property("visible") is False
h.eval(copy_button, "clicked()")
h.eval(continue_button, "clicked()")
assert h.eval(root, "state.copied") == 1
assert h.eval(root, "state.opened") == 1
h.eval(root, "state.result = Array(200).fill(\"long result line\").join(\"\\n\")")
h.app.processEvents()
assert h.find(root, "selectionMenu").property("height") < root.property("height")

# The action list: arrows move the cursor, Enter runs it, a digit picks one.
h.eval(root, 'state.hasResult = false; state.actions = [{id: "a", label: "A", icon: "x", output: "replace"}, '
       '{id: "b", label: "B", icon: "x", output: "sidebar"}, {id: "c", label: "C", icon: "x", output: "clipboard"}]')
h.app.processEvents()
ask = h.find(root, "selectionAsk")
win = h.find(root, "menuWindow")
assert ask.property("visible") is True
assert h.eval(win, "selectedIndex") == 0
h.eval(ask, "downPressed(); downPressed(); downPressed()")
assert h.eval(win, "selectedIndex") == 2, "Down stops at the last action"
h.eval(ask, "upPressed()")
assert h.eval(win, "selectedIndex") == 1
h.eval(ask, "accepted()")
assert h.eval(root, "state.ran.join()") == "b", "Enter on an empty field runs the highlighted action"
h.eval(ask, 'text = "what is it"; accepted()')
assert h.eval(root, "state.asked.join()") == "what is it", "Enter with text asks about the selection"
h.eval(ask, 'text = ""; searchTextChanged("3")')
assert h.eval(root, "state.ran.join()") == "b,c", "a digit runs that action"
h.eval(ask, 'searchTextChanged("7")')
assert h.eval(root, "state.ran.join()") == "b,c", "a digit without an action does nothing"
h.eval(ask, 'searchTextChanged(""); searchTextChanged("a1"); searchTextChanged("1")')
assert h.eval(root, "state.ran.join()") == "b,c", "a digit left after deleting text is not a pick"
h.eval(ask, 'searchTextChanged(""); searchTextChanged("1")')
assert h.eval(root, "state.ran.join()") == "b,c,a", "a digit typed into the empty field picks"
h.eval(ask, "escapePressed()")
assert h.eval(root, "state.closed") == 1
rows = h.eval(h.find(root, "selectionMenu"), "JSON.stringify(col.children.filter(c => c.title !== undefined).map(c => [c.title, c.highlighted]))")
assert rows == '[["A",false],["B",true],["C",false]]', f"the keyboard cursor highlights its row: {rows}"
print("PASS: selection result preview, copy/continue chips and the keyboard-driven action list")
