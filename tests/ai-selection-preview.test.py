"""The selection popup displays selectable plain text and routes explicit actions."""
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
h.module("qs.modules.components", {"StyledRect": "Rectangle { property string variant; property bool enableShadow; color: 'transparent' }"})
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
        property int copied: 0
        property int opened: 0
        function copyResult() { copied++; }
        function openResult() { opened++; }
        function close() {}
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
print("PASS: selection result preview and explicit copy/continue controls")
