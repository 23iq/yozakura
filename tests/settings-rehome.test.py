"""SettingsWindow moves to another output only while hidden.

When its output goes away, the settings window re-homes to the first output
once the outputs settle. A mapped window is never moved while mapped: it is
hidden, moved while hidden, then shown again, and the whole sequence (with
its asynchronous hide) is never taken for the user closing it. The real
SettingsWindow runs as an Item (no xdg toplevel offscreen) over stubs.
"""
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402

from lib.waits import pump, wait_until  # noqa: E402

REPO = Path(__file__).resolve().parents[1]
h = Harness("settings-rehome")
h.module("Quickshell", {
    "Quickshell": "pragma Singleton\nQtObject { property var screens: [] }",
    "ShellScreen": "QtObject { property string name }",
})
h.copy("modules/components/SettleGate.qml", "qs/modules/components", siblings=False)
h.module("qs.modules.components", {})
h.singleton("qs.modules.globals", "GlobalStates", """QtObject {
    property bool settingsWindowVisible: false
    property bool settingsCloseConfirm: false
    property string settingsTargetScreenName: ""
    property int settingsTargetWorkspaceId: 0
}""")
h.module("qs.modules.services", {
    "YozdService": "pragma Singleton\nQtObject { property var focusedMonitor: null; property var focusedWorkspace: null; "
                   "property var clients: ({values: []}); function dispatch(c) {} }",
    "PresetStudio": "pragma Singleton\nQtObject { function refreshSessions() {} }",
})
h.module("qs.modules.theme", {"Unused": "QtObject {}"})
h.module("qs.config", {"Unused": "QtObject {}"})
h.singleton("qs.modules.settings.store", "SettingsStore", "QtObject { property bool hasChanges: false }")

rel = "modules/settings/SettingsWindow.qml"
src = (REPO / rel).read_text()
item = src.replace("FloatingWindow {", "Item {\n    property var screen\n    property size minimumSize\n    property string title\n    property color color", 1)
h.copy(rel, "app", replace={src: item}, siblings=False)
h.stub("SettingsShell", "Item {}", "app")

root = h.load("""import QtQuick
import QtQuick.Window
import Quickshell
import qs.modules.globals
Window {
    id: top
    width: 400; height: 300; visible: true
    property ShellScreen a: ShellScreen { name: "A" }
    property ShellScreen b: ShellScreen { name: "B" }
    property var win: null
    property var log: []
    Component { id: comp; SettingsWindow {} }
    function make() {
        Quickshell.screens = [a, b];
        win = comp.createObject(top.contentItem, {targetScreen: a});
        win.visibleChanged.connect(() => log = log.concat([(win.visible ? "show:" : "hide:") + win.targetScreen.name]));
        win.screenChanged.connect(() => log = log.concat(["move:" + win.screen.name + ":" + (win.visible ? "mapped" : "hidden")]));
    }
}""", auto_stub=False)


def ev(expr):
    return h.eval(root, expr)


ev("GlobalStates.settingsWindowVisible = true; make()")
wait_until(lambda: ev("win.visible") is True and ev("win.screen.name") == "A")
assert ev("win.visible") is True and ev("win.screen.name") == "A"

# Its output goes away while it is shown.
ev("log = []; Quickshell.screens = [b]")
pump(600)
log = ev("log.join()")
assert ev("win.screen.name") == "B", f"not re-homed: {log}"
assert ev("win.visible") is True, f"not shown again after the move: {log}"
assert ev("GlobalStates.settingsWindowVisible") is True, f"the move was taken for a close: {log}"
assert ev("win.rehoming") is False
assert log == "hide:A,move:B:hidden,show:B", f"moved while mapped: {log}"

# Hidden (kept alive): moved at once, never shown by the move.
ev("GlobalStates.settingsWindowVisible = false")
pump(10)
ev('log = []; Quickshell.screens = [a, b]; GlobalStates.settingsTargetScreenName = "A"')
wait_until(lambda: ev("win.screen.name") == "A" and ev("win.visible") is False)
assert ev("win.screen.name") == "A" and ev("win.visible") is False, ev("log.join()")
assert ev("log.join()") == "move:A:hidden", ev("log.join()")

# The user closing it (not a move) still closes it.
ev("GlobalStates.settingsWindowVisible = true")
wait_until(lambda: ev("win.visible") is True)
assert ev("win.visible") is True
assert not re.search("move", ev("log.join()").split("move:A:hidden", 1)[1])

print("settings-rehome: ok")
h.exit(0)
