"""Responsive AI host behavior using the real QML host."""
import os
import sys
from pathlib import Path

os.environ['QT_QUICK_CONTROLS_STYLE'] = 'Basic'

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib.qmlharness import Harness  # noqa: E402

h = Harness('ai-workspace')
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
signal assistantFocusRequested(bool wasAlreadyOpen)
function hideAssistant() {}
}''')
h.singleton('qs.modules.theme', 'Styling', 'QtObject {}')
h.singleton('qs.modules.services', 'Ai', 'QtObject {}')
h.singleton('qs.modules.aicenter.common', 'BarLook', 'QtObject { property int animDuration: 0 }')
p = h.copy('modules/aicenter/AiCenterHost.qml')
(p.parent / 'AiCenterPanel.qml').write_text('import QtQuick\nItem { property bool frameWrapped: false; function focusComposer() {} }')
wrapper = p.parent / 'HostScene.qml'
wrapper.write_text('import QtQuick\nimport qs.modules.globals\nAiCenterHost { targetScreen: ({name: "one"}); width: 1280; height: 720 }')
obj = h.load(wrapper)
h.eval(obj, 'targetScreen = ({name: "one"}); width = 1280; height = 720')
assert h.eval(obj, 'hitbox.width') == 404
h.eval(obj, 'GlobalStates.assistantFullscreen = true')
assert h.eval(obj, 'hitbox.width') == 1280, 'fullscreen must use all available monitor width'
assert h.eval(obj, 'hitbox.height') == 720
assert h.eval(obj, 'GlobalStates.assistantWidth') == 400, 'fullscreen must preserve sidebar preference'
h.eval(obj, 'targetScreen = ({name: "two"})')
assert not h.eval(obj, 'active'), 'fullscreen belongs only to the selected monitor'
print('ai-workspace-ui: ok')

# Real workspace and Composer: switching sessions or rejecting sends retains data.
from lib import aiscene  # noqa: E402
from PySide6.QtCore import QObject, QUrl, QCoreApplication, QElapsedTimer  # noqa: E402
from PySide6.QtQml import QQmlExpression  # noqa: E402
from PySide6.QtQuick import QQuickView  # noqa: E402

repo = Path(__file__).resolve().parents[1]
root = aiscene.build('Sumi-e', 'light', (repo / 'tests/fixtures/aicenter-ai-stub.qml.in').read_text())
scene = root / 'Workspace.qml'
scene.write_text('import QtQuick\nimport qs.modules.services\nimport qs.modules.globals\nimport qs.modules.aicenter\nAiCenterPanel { width: 1280; height: 720; function chooseAgent() { Ai.setSpace("code"); } function chooseChat() { Ai.setSpace("assistant"); } function expand() { GlobalStates.assistantWide = true; GlobalStates.assistantFullscreen = true; } function rejectSend() { Ai.acceptSend = false; } function acceptSend() { Ai.acceptSend = true; } function configuredEffort() { return Ai.lastConfiguration.effort; } function disableAgent() { const m=Ai.models.slice(); m[0]=Object.assign({}, m[0], {available: false}); Ai.models=m; } function deliverContext() { Ai.context.deliver(); } function fillChat() { for (let i=0; i<30; i++) Ai.chat.append({role: "user", content: "long conversation " + i}); } }')
view = QQuickView()
view.engine().addImportPath(str(root))
view.setSource(QUrl.fromLocalFile(str(scene)))
assert view.status() == QQuickView.Ready, view.errors()
workspace = view.rootObject()
composer = workspace.findChild(QObject, 'workspaceComposer')
assert composer

def evaluate(target, expression):
    expr = QQmlExpression(view.engine().rootContext(), target, expression)
    result = expr.evaluate()
    assert not expr.hasError(), expr.error().toString()
    return result[0] if isinstance(result, tuple) else result

composer.setProperty('text', 'chat draft')
evaluate(composer, 'attachments = [{kind: "file", name: "notes.txt"}]')
evaluate(composer, 'addContext("file")')
evaluate(workspace, 'chooseAgent()')
evaluate(workspace, 'deliverContext()')
assert evaluate(composer, 'attachments.length') == 0, 'late context must stay with its requesting session'
assert composer.property('text') == ''
composer.setProperty('text', 'agent draft')
evaluate(workspace, 'chooseChat()')
assert composer.property('text') == 'chat draft'
assert evaluate(composer, 'attachments.length') == 2
evaluate(workspace, 'expand()')
assert composer.property('text') == 'chat draft'
evaluate(workspace, 'rejectSend()')
evaluate(composer, 'submit()')
assert composer.property('text') == 'chat draft', 'rejected send must preserve text'
assert evaluate(composer, 'attachments.length') == 2, 'rejected send must preserve attachments'
evaluate(workspace, 'acceptSend()')
evaluate(composer, 'submit()')
assert composer.property('text') == ''
assert evaluate(composer, 'attachments.length') == 0
evaluate(workspace, 'fillChat()')
view.show()
def pump():
    timer = QElapsedTimer()
    timer.start()
    while timer.elapsed() < 100:
        QCoreApplication.processEvents()
pump()
chat_list = workspace.findChild(QObject, 'workspaceChatList')
evaluate(chat_list, 'contentY = 200; movementEnded()')
evaluate(workspace, 'chooseAgent()')
pump()
evaluate(workspace, 'chooseChat()')
pump()
chat_list = workspace.findChild(QObject, 'workspaceChatList')
assert abs(chat_list.property('contentY') - 200) < 1, 'session switching must restore manual scroll'
evaluate(workspace, 'chooseAgent()')
workspace.setProperty('settingsOpen', True)
pump()
effort_choice = workspace.findChild(QObject, 'workspaceEffortChoice')
assert effort_choice.property('visible'), 'native default model should expose declared efforts'
evaluate(effort_choice, 'currentIndex = 0; activated(0)')
assert evaluate(workspace, 'configuredEffort()') == '', 'engine default effort must send an empty value'
view.grabWindow().save('/tmp/ai-workspace-settings.png')
engine_picker = workspace.findChild(QObject, 'workspaceEnginePicker')
evaluate(workspace, 'disableAgent()')
assert evaluate(engine_picker, 'activate(rows.findIndex(r => r.type === "model" && r.entry.kind === "agent"))') is False, 'unavailable engine must reject keyboard/tap selection'
view.close()
view.deleteLater()
QCoreApplication.processEvents()
print('ai-workspace drafts: ok')

# Synthetic fullscreen scenes exercise full host geometry, parallel tasks and permission UI.
import json  # noqa: E402
import time  # noqa: E402

sessions = [
    {'id': 's1', 'agent': 'claude', 'cwd': '/home/user/src/yozakura', 'title': 'Improve the assistant workspace', 'status': 'waiting', 'pending': 1, 'pinned': True, 'mode': 'agent', 'updated': time.time() * 1000, 'model': 'sonnet', 'yolo': False},
    {'id': 's2', 'agent': 'codex', 'cwd': '/home/user/src/website', 'title': 'Check the landing page', 'status': 'running', 'pending': 0, 'pinned': False, 'mode': 'agent', 'updated': time.time() * 1000 - 120000, 'model': 'gpt-5.4', 'yolo': False},
]
events = [
    {'kind': 'user', 'text': 'Make the assistant easier to read and keep working sessions visible.'},
    {'kind': 'text', 'text': 'I simplified the header and adjusted the conversation spacing. The second session is still working in the background.', 'delta': True},
    {'kind': 'tool_call', 'id': 'r1', 'tool': 'Read', 'title': 'Read the workspace layout', 'category': 'read', 'input': {'file_path': 'modules/aicenter/AiCenterPanel.qml'}},
    {'kind': 'tool_result', 'id': 'r1', 'output': 'Layout read.'},
    {'kind': 'permission_request', 'id': 'p1', 'tool': 'Bash', 'title': 'Run the workspace checks', 'category': 'exec', 'input': {'command': 'make check'}},
    {'kind': 'diff', 'id': 'd1', 'path': 'modules/aicenter/header/CenterHeader.qml', 'diff': '@@ -1 +1 @@\n-    spacing: 8\n+    spacing: 3\n'},
]
for preset, palette in [('Yozakura Night', 'dark'), ('Sumi-e', 'light')]:
    scene_root = aiscene.build(preset, palette, (repo / 'tests/fixtures/aicenter-ai-stub.qml.in').read_text())
    scene_file = scene_root / 'Fullscreen.qml'
    scene_file.write_text('''import QtQuick
import qs.modules.aicenter
import qs.modules.services
import qs.modules.globals
import qs.config
Item {
    width: 1440; height: 860
    AiCenterHost { id: host; anchors.fill: parent; targetScreen: ({name: "one"}) }
    Component.onCompleted: {
        GlobalStates.assistantFullscreen = true;
        Config.bar.frameEnabled = true;
        Ai.agents.sessions = %s;
        Ai.agents.feed("s1", %s);
        Ai.setSpace("code");
    }
    function geometry() { return host.hitbox.width; }
}
''' % (json.dumps(sessions), json.dumps(events)))
    render_view = QQuickView()
    render_view.engine().addImportPath(str(scene_root))
    render_view.resize(1440, 860)
    render_view.setSource(QUrl.fromLocalFile(str(scene_file)))
    assert render_view.status() == QQuickView.Ready, render_view.errors()
    render_view.show()
    pump()
    render_expr = QQmlExpression(render_view.engine().rootContext(), render_view.rootObject(), 'geometry()')
    geometry = render_expr.evaluate()
    if isinstance(geometry, tuple):
        geometry = geometry[0]
    assert geometry == 1440, 'fullscreen with frame must fill host'
    render_view.grabWindow().save(f'/tmp/ai-workspace-fullscreen-{palette}.png')
    render_view.close()
    render_view.deleteLater()
    QCoreApplication.processEvents()
print('ai-workspace fullscreen scenes: ok')
