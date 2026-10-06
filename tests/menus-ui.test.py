"""Power and tools menus on the kit (modules/widgets/powermenu, tools,
menus/ActionStrip): keyboard navigation skips separators and wraps, the
caption names the focused item and asks to hold a destructive one, a tap
of Enter on it does nothing while a full hold runs it, plain actions run at
once, Escape closes, and the fullscreen caption reads uptime and user@host.
Commands never run (the Quickshell stub records them)."""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from lib.menus_env import MenusEnv  # noqa: E402
from PySide6.QtCore import QElapsedTimer, Qt  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

env = MenusEnv("menus-ui", overrides={"theme": {"animDuration": 0, "language": "ink"}})
h = env.h
root = env.load("""import QtQuick
import QtQuick.Window
import Quickshell
import qs.modules.services
import qs.modules.widgets.tools
import qs.modules.widgets.powermenu.styles as Styles
Window {
    width: 1280; height: 720; visible: true
    property int closes: 0
    property int toolsDone: 0
    property string page: "notch"
    function ran() { return Quickshell.detached.map(a => a.join(" ")) }
    Styles.Notch { objectName: "notch"; visible: page === "notch"; focus: page === "notch"
                   onCloseRequested: parent.Window.window.closes++ }
    Styles.Fullscreen { objectName: "full"; anchors.fill: parent; visible: page === "full"; shown: page === "full"
                        focus: page === "full"; onCloseRequested: parent.Window.window.closes++ }
    ToolsMenu { objectName: "tools"; visible: page === "tools"; focus: page === "tools"
                onItemSelected: parent.Window.window.toolsDone++ }
}""")
root.requestActivate()


def pump(ms):
    t = QElapsedTimer()
    t.start()
    while t.elapsed() < ms:
        h.app.processEvents()


def ran():
    return json.loads(h.eval(root, "JSON.stringify(ran())"))


def key(k):
    QTest.keyClick(root, k)
    pump(10)


# --- power: notch strip ---------------------------------------------------------
pump(50)
strip = h.find(root, "powerStrip")
caption = h.find(root, "stripCaption")
assert h.eval(strip, "currentIndex") == 0, "the first action takes focus"
assert caption.property("text") == "Lock Session", caption.property("text")
key(Qt.Key_Left)
assert h.eval(strip, "currentIndex") == 5, "Left wraps to the last action"
assert caption.property("text") == "Hold to shut down", caption.property("text")
QTest.keyPress(root, Qt.Key_Return)
pump(120)
QTest.keyRelease(root, Qt.Key_Return)
pump(700)
assert ran() == [], "an Enter tap on Shut down must not run it"
QTest.keyPress(root, Qt.Key_Return)
pump(750)
QTest.keyRelease(root, Qt.Key_Return)
pump(20)
assert ran() == ["systemctl poweroff"], ran()
assert root.property("closes") == 1
key(Qt.Key_Right)
assert h.eval(strip, "currentIndex") == 0
key(Qt.Key_Return)
assert ran()[-1] == "loginctl lock-session", "plain actions run at once"
key(Qt.Key_Escape)
assert root.property("closes") == 3

# --- power: fullscreen ------------------------------------------------------------
root.setProperty("page", "full")
pump(50)
model = h.find(h.find(root, "full"), "powerModel")
h.eval(model, 'session = "7505.31 28000.10\\narch\\n"')
assert h.eval(h.find(root, "powerCaption"), "text") == "up 2h 05m · user@arch"
full = h.find(root, "full")
assert full.property("currentIndex") == 0
key(Qt.Key_Right)
key(Qt.Key_Right)
key(Qt.Key_Right)
assert full.property("currentIndex") == 3
assert h.eval(h.find(root, "powerHint"), "text") == "Hold to log out"
key(Qt.Key_Tab)
key(Qt.Key_Tab)
key(Qt.Key_Tab)
assert full.property("currentIndex") == 0, "Tab wraps"
n = len(ran())
key(Qt.Key_Return)
assert len(ran()) == n + 1
key(Qt.Key_Escape)
assert root.property("closes") == 5

# --- tools: notch strip -----------------------------------------------------------
root.setProperty("page", "tools")
pump(50)
tools = h.find(root, "toolsStrip")
assert h.eval(tools, "currentIndex") == 0
key(Qt.Key_Right)
key(Qt.Key_Right)
assert h.eval(tools, "currentIndex") == 3, "separators are skipped"
h.eval(root, "ScreenRecorder.isRecording = true; ScreenRecorder.duration = '00:42'")
pump(20)
assert h.eval(tools, "current.active") is True, "a running recording is the active state"
assert h.find(tools, "stripCaption").property("text") == "Stop Recording · 00:42"
key(Qt.Key_Escape)
assert root.property("toolsDone") == 1

print("menus-ui: ok")
h.exit(0)
