"""AI center UI, offscreen: chat, agent wide mode (tool cards, permission card,
diff), notch quick ask and the selection popup, in a dark and a light preset.

Real components + real ChatSession/AgentTimeline; services stubbed by
tests/lib/aiscene.py. Fails on QML errors/warnings from the AI center and
checks a few behaviours (permission card -> agents.respond, wide layout,
streaming text). Set AI_CENTER_RENDER=<dir> to save PNGs of every scene.
"""
import json
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import headless  # noqa: E402

headless.ensure(gl=True)
from PySide6.QtCore import QObject, QUrl, QCoreApplication, QElapsedTimer, qInstallMessageHandler  # noqa: E402
from PySide6.QtGui import QGuiApplication  # noqa: E402
from PySide6.QtQml import QQmlExpression  # noqa: E402
from PySide6.QtQuick import QQuickView  # noqa: E402

from lib import aiscene  # noqa: E402

REPO = Path(__file__).resolve().parents[1]
OUT = os.environ.get("AI_CENTER_RENDER")
PRESETS = [("Yozakura Night", "dark", ["chat", "agent", "quick", "selection", "selection-result", "history", "settings"]),
           ("Sumi-e", "light", ["chat", "agent", "quick", "selection", "selection-result"]),
           ("Kaze", "dark", ["chat", "agent"])]
W, H = 1440, 860

app = QGuiApplication([])
messages = []


def on_msg(mode, ctx, msg):
    if "aicenter" in msg or "services/ai" in msg or "is not a type" in msg or "TypeError" in msg or "ReferenceError" in msg:
        messages.append(msg)


qInstallMessageHandler(on_msg)

CHAT = [
    {"role": "user", "content": "Why doesn't my window rule float Firefox's picture-in-picture?", "attachments": [{"type": "text", "kind": "window", "name": "firefox", "text": "Active window: Picture-in-Picture (firefox)"}]},
    {"role": "assistant", "model": "Claude Sonnet 4.5", "thinking": "The PiP window has class firefox and title Picture-in-Picture; their rule matches the class only, so the main window is targeted too…",
     "content": "Your rule matches **every** Firefox window because it only checks the class. Match the *title* of the PiP window instead:\n\n```lua\nhl.windowrule({\n  match = { class = \"firefox\", title = \"^Picture%-in%-Picture$\" },\n  float = true, pin = true,\n  size = { 640, 360 },  -- keeps the 16:9 player\n})\n```\n\nThen reload with `yozakura reload`.",
     "toolCalls": [{"id": "c1", "name": "windows_list", "tool": "windows_list", "server": "yozakura", "title": "windows_list", "category": "read", "status": "done", "args": {}, "result": "[{\"class\":\"firefox\",\"title\":\"Picture-in-Picture\"}]"}]},
    {"role": "user", "content": "Do it for me and make it 25% smaller."},
    {"role": "assistant", "model": "Claude Sonnet 4.5", "content": "Sure — I'll add the rule to your compositor config.",
     "toolCalls": [{"id": "c2", "name": "config_set", "tool": "config_set", "server": "yozakura", "title": "config_set · compositor.windowRules", "category": "write", "status": "ask", "args": {"domain": "compositor", "key": "windowRules", "value": [{"class": "firefox", "title": "^Picture-in-Picture$", "float": True, "size": [480, 270]}]}}]},
]

EDIT_DIFF = """@@ -112,14 +112,17 @@
     // Timer to delay hiding the notch after mouse leaves
     Timer {
         id: hideDelayTimer
-        interval: 1000
+        interval: Config.notch.hideDelay ?? 350
         repeat: false
         onTriggered: {
-            if (!root.isMouseOverNotch) {
-                root.hoverActive = false;
-            }
+            // Re-check: a quick exit/re-enter must not hide the island.
+            if (!root.isMouseOverNotch && !root.screenNotchOpen)
+                root.hoverActive = false;
         }
     }
"""

AGENT = [
    {"kind": "user", "text": "The notch flickers when the cursor leaves it. Debounce the hide and add a test."},
    {"kind": "thinking", "text": "Look at the hover logic in NotchContent.qml first; the timer restarts on every leave event.", "delta": True},
    {"kind": "text", "text": "I'll start with the hover handling in the notch.", "delta": True},
    {"kind": "tool_call", "id": "t1", "tool": "Read", "title": "Read modules/notch/NotchContent.qml", "category": "read", "input": {"file_path": "modules/notch/NotchContent.qml"}},
    {"kind": "tool_result", "id": "t1", "output": "112  // Timer to delay hiding the notch…"},
    {"kind": "tool_call", "id": "t2", "tool": "Grep", "title": "Grep hideDelayTimer", "category": "read", "input": {"pattern": "hideDelayTimer"}},
    {"kind": "tool_result", "id": "t2", "output": "modules/notch/NotchContent.qml:115\nmodules/notch/NotchContent.qml:139"},
    {"kind": "text", "text": "The timer fires even when the cursor re-entered during the delay, and 1 s feels sluggish. I'll make the delay configurable and re-check the hover state before hiding.", "delta": True},
    {"kind": "tool_call", "id": "t3", "tool": "Edit", "title": "Edit modules/notch/NotchContent.qml", "category": "write", "input": {"file_path": "modules/notch/NotchContent.qml"}},
    {"kind": "permission_request", "id": "t3", "tool": "Edit", "title": "Edit modules/notch/NotchContent.qml", "category": "write", "path": "modules/notch/NotchContent.qml", "diff": EDIT_DIFF},
    {"kind": "permission_resolved", "id": "t3", "decision": "allow"},
    {"kind": "diff", "id": "t3", "path": "modules/notch/NotchContent.qml", "diff": EDIT_DIFF},
    {"kind": "tool_result", "id": "t3", "output": "The file has been updated."},
    {"kind": "tool_call", "id": "t4", "tool": "Bash", "title": "$ make test CHECKS=test-py", "category": "exec", "input": {"command": "make test CHECKS=test-py", "description": "Run the QML tests"}},
    {"kind": "permission_request", "id": "t4", "tool": "Bash", "title": "$ make test CHECKS=test-py", "category": "exec", "input": {"command": "make test CHECKS=test-py"}},
]

QUICK = [
    {"role": "user", "content": "72 °F in °C, and the formula?"},
    {"role": "assistant", "model": "qwen3.5:9b", "content": "**72 °F ≈ 22.2 °C**\n\nFormula: `°C = (°F − 32) × 5⁄9`, so (72 − 32) × 5⁄9 = 40 × 0.556 ≈ **22.2**."},
]

SELECTION_TEXT = "Das Treffen wurde auf Donnerstag verschoben, bitte bringt die Zahlen vom letzten Quartal mit."


def selection_window_source() -> str:
    """SelectionMenuWindow as a plain Item (no layer-shell window offscreen)."""
    src = (REPO / "modules/aicenter/selection/SelectionMenuWindow.qml").read_text()
    src = src.replace("import Quickshell.Wayland\n", "")
    src = re.sub(r"PanelWindow \{", "Item {", src, count=1)
    src = re.sub(r"\n    anchors \{[^}]*\}", "", src, count=1)
    src = re.sub(r"\n    mask: Region \{[^}]*\}", "", src, count=1)
    src = "\n".join(line for line in src.split("\n") if not re.match(r"\s*(screen:|color: \"transparent\"|exclusionMode:|WlrLayershell\.)", line))
    src = src.replace("readonly property var targetScreen: Quickshell.screens.find(s => s.name === actions.screenName) || Quickshell.screens[0]",
                      "readonly property var targetScreen: ({ x: 0, y: 0 })")
    # MultiEffect's layer suppresses the cloned PanelWindow subtree in this
    # Item fixture. Keep the real content and geometry, omit only its shadow.
    return src.replace("enableShadow: true", "enableShadow: false")


SCENE = """
import QtQuick
import qs.config
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.modules.globals
import qs.modules.aicenter
import qs.modules.aicenter.quickask

Item {
    id: scene
    width: %(W)d
    height: %(H)d
    property string kind: "chat"

    function setup(data) {
        for (const r of data.chat) Ai.chat.append(r);
        for (const r of data.quick) Ai.quick.append(r);
        Ai.agents.feed("s1", data.agent);
    }
    function agentWide() {
        GlobalStates.assistantWide = true;
        Ai.setMode("agent");
    }
    function state() {
        return JSON.stringify({
            pending: Ai.agents.timeline("s1").state.pending,
            diffs: Ai.agents.timeline("s1").state.diffs.length,
            responses: Ai.agents.responses,
            chatRows: Ai.chat.rows.count,
            approvals: Ai.chat.pendingApprovals
        });
    }
    function respond(id, d) {
        Ai.agents.respond("s1", id, d);
    }

    // Wallpaper-ish backdrop so translucent (glass) variants read like on a desktop.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.darker(Colors.primaryContainer, Config.theme.lightMode ? 0.9 : 1.6) }
            GradientStop { position: 0.55; color: Colors.surfaceContainerLow }
            GradientStop { position: 1.0; color: Qt.darker(Colors.tertiaryContainer, Config.theme.lightMode ? 0.95 : 1.4) }
        }
    }

    onKindChanged: if (kind === "history" && panelLoader.item)
        panelLoader.item.toggleHistory()

    Loader {
        id: panelLoader
        active: scene.kind === "chat" || scene.kind === "agent" || scene.kind === "history"
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: 8
        width: scene.kind === "agent" ? 1120 : 460
        sourceComponent: AiCenterPanel {}
        onLoaded: if (scene.kind === "history")
            item.toggleHistory()
    }

    StyledRect {
        visible: scene.kind === "settings"
        variant: "bg"
        anchors.centerIn: parent
        width: 640
        height: parent.height - 16
        Flickable {
            anchors.fill: parent
            anchors.margins: 16
            contentHeight: settingsLoader.implicitHeight
            clip: true
            Loader {
                id: settingsLoader
                width: parent.width
                active: scene.kind === "settings"
                source: "Settings.qml"
            }
        }
    }

    // Quick ask lives inside the island (notch module), like the real notch.
    StyledRect {
        visible: scene.kind === "quick"
        variant: "bg"
        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        width: quickLoader.width + 32
        height: quickLoader.height + 28
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: Styling.radius(12)
        bottomRightRadius: Styling.radius(12)
        Loader {
            id: quickLoader
            x: 16
            y: 14
            active: scene.kind === "quick"
            sourceComponent: QuickAskCard {}
        }
    }

    Item {
        visible: (scene.kind === "selection" || scene.kind === "selection-result")
        anchors.fill: parent
        StyledRect {
            id: editor
            variant: "pane"
            x: 180; y: 140; width: 760; height: 420
            radius: Styling.radius(0)
            Text {
                x: 32; y: 40; width: parent.width - 64
                wrapMode: Text.Wrap
                textFormat: Text.RichText
                font.family: Config.theme.font
                font.pixelSize: 18
                color: Colors.overSurface
                text: "Hallo zusammen,<br><br><span style='background-color:" + Colors.primary + ";color:" + Colors.overPrimary + "'>%(SEL)s</span><br><br>Danke!"
            }
        }
        Loader {
            id: selLoader
            z: 100
            active: (scene.kind === "selection" || scene.kind === "selection-result")
            anchors.fill: parent
            Component.onCompleted: setSource("SelectionMenu.qml", { actions: selState })
        }
        QtObject {
            id: selState
            property string text: "%(SEL)s"
            property string screenName: ""
            property point cursor: Qt.point(560, 238)
            property bool working: false
            property string workingLabel: ""
            property string error: ""
            property bool hasResult: scene.kind === "selection-result"
            property string result: "The meeting has been moved to Thursday. Please bring last quarter’s figures."
            function copyResult() {}
            function openResult() {}
            property var actions: [
                { id: "translate", label: "Translate", icon: "translate", output: "replace" },
                { id: "explain", label: "Explain", icon: "lightbulb", output: "sidebar" },
                { id: "rewrite", label: "Rewrite", icon: "magicWand", output: "replace" },
                { id: "fix", label: "Fix code", icon: "bug", output: "replace" },
                { id: "summarize", label: "Summarize", icon: "list", output: "sidebar" },
                { id: "prompt:reply", label: "Draft a reply", icon: "scroll", output: "sidebar" }
            ]
            property var ran: []
            function run(a) { ran = ran.concat([a.id]); }
            function ask(t) {}
            function close() {}
        }
    }
}
"""


def pump(ms):
    t = QElapsedTimer()
    t.start()
    while t.elapsed() < ms:
        QCoreApplication.processEvents()


def evaluate(view, expr):
    e = QQmlExpression(view.engine().rootContext(), view.rootObject(), expr)
    value = e.evaluate()
    if isinstance(value, tuple):
        value = value[0]
    if e.hasError():
        raise AssertionError(f"{expr}: {e.error().toString()}")
    return value


failures = []
for preset, mode, kinds in PRESETS:
    root = aiscene.build(preset, mode, (REPO / "tests/fixtures/aicenter-ai-stub.qml.in").read_text())
    app_dir = root / "app"
    app_dir.mkdir()
    (app_dir / "Scene.qml").write_text(SCENE % {"W": W, "H": H, "SEL": SELECTION_TEXT})
    (app_dir / "Settings.qml").write_text("import QtQuick\nimport QtQuick.Layouts\nimport qs.modules.settings.editors\nColumnLayout { spacing: 24; AiAgentsEditor { Layout.fillWidth: true } AiPromptsEditor { Layout.fillWidth: true } AiAutomationsEditor { Layout.fillWidth: true } }\n")
    (app_dir / "SelectionMenu.qml").write_text(selection_window_source().replace(
        "import qs.modules.aicenter.common", "import qs.modules.aicenter.common\nimport qs.modules.aicenter.selection"))
    for kind in kinds:
        view = QQuickView()
        view.engine().addImportPath(str(root))
        view.setResizeMode(QQuickView.SizeRootObjectToView)
        view.resize(W, H)
        messages.clear()
        view.setSource(QUrl.fromLocalFile(str(app_dir / "Scene.qml")))
        if view.status() != QQuickView.Ready:
            failures.append(f"{preset}/{kind}: " + "; ".join(e.toString() for e in view.errors()))
            continue
        evaluate(view, "setup(" + json.dumps({"chat": CHAT, "quick": QUICK, "agent": AGENT}) + ")")
        if kind == "agent":
            evaluate(view, "agentWide()")
        evaluate(view, f"kind = '{kind}'")
        view.show()
        pump(700)
        if kind == "agent":
            # Permission card for the pending Bash call is live and answers the agents service.
            st = json.loads(evaluate(view, "state()"))
            assert st["pending"] == 1, st
            assert st["diffs"] == 1, st
            evaluate(view, "respond('t4', 'allow')")
            assert "t4:allow" in json.loads(evaluate(view, "state()"))["responses"]
        if kind == "chat":
            st = json.loads(evaluate(view, "state()"))
            assert st["chatRows"] == len(CHAT), st
        if kind in ("selection", "selection-result"):
            menu = view.rootObject().findChild(QObject, "selectionMenu")
            assert menu is not None, "selection menu must be mounted"
            assert menu.property("visible") and menu.property("width") > 0 and menu.property("opacity") == 1, "selection preview must be visible"
        if OUT:
            Path(OUT).mkdir(parents=True, exist_ok=True)
            name = f"{kind}-{preset.lower().replace(' ', '-')}.png"
            view.grabWindow().save(str(Path(OUT) / name))
        bad = [m for m in messages if "Binding loop" not in m]
        if bad:
            failures.append(f"{preset}/{kind}: " + " | ".join(bad[:6]))
        view.close()
        view.deleteLater()
        pump(50)

if failures:
    print("\n".join(failures))
    sys.exit(1)
print("ai-center-ui: ok")
