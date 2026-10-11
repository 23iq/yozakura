"""Repeated AI bar shortcut closes the open panel even without keyboard focus."""
import os
import sys

os.environ['QT_QUICK_CONTROLS_STYLE'] = 'Basic'

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib.qmlharness import Harness  # noqa: E402

h = Harness('ai-toggle-close')
h.singleton('qs.config', 'Config', 'QtObject { property int animDuration: 0; property var ai: ({enabled: true, unloadAfterMinutes: 10}); property var bar: ({frameEnabled: false}) }')
h.singleton('qs.modules.globals', 'GlobalStates', '''QtObject {
property bool assistantVisible: true
property string assistantScreenName: "one"
property string assistantPosition: "right"
property bool assistantPinned: false
property bool assistantWide: false
property bool assistantFullscreen: false
property int assistantWidth: 400
property int assistantEffectiveWidth: 400
property int hides: 0
signal assistantFocusRequested(bool wasAlreadyOpen)
function hideAssistant() { hides++; assistantVisible = false; }
}''')
h.singleton('qs.modules.theme', 'Styling', 'QtObject {}')
h.singleton('qs.modules.services', 'Ai', 'QtObject {}')
h.singleton('qs.modules.aicenter.common', 'BarLook', 'QtObject { property int animDuration: 0 }')
p = h.copy('modules/aicenter/AiCenterHost.qml')
(p.parent / 'AiCenterPanel.qml').write_text('import QtQuick\nItem { property bool frameWrapped: false; function focusComposer() {} }')
wrapper = p.parent / 'HostScene.qml'
wrapper.write_text('import QtQuick\nimport qs.modules.globals\nAiCenterHost { targetScreen: ({name: "one"}); width: 1280; height: 720 }')
obj = h.load(wrapper)
h.eval(obj, 'targetScreen = ({name: "one"}); hasKeyboard = false')
assert h.eval(obj, 'active')

# Focus moved to another window (pointer hovered elsewhere): the shortcut still closes.
h.eval(obj, 'GlobalStates.assistantFocusRequested(true)')
from PySide6.QtCore import QCoreApplication  # noqa: E402
QCoreApplication.processEvents()
QCoreApplication.processEvents()
assert h.eval(obj, 'GlobalStates.hides') == 1, 'second shortcut must close the panel without keyboard focus'
print('ai-toggle-close: ok')
