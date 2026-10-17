"""Shell overlays take priority over an already-open fullscreen AI window.

Exercise the real AI window and per-screen visibility state offscreen. Only
the layer-shell boundary becomes ordinary properties; no compositor runs.
"""
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402

h = Harness("ai-overlay-priority")
h.module("Quickshell", {
    "Singleton": "Item {}",
    "PanelWindow": """Item {
        property var screen
        property color color
        property int exclusionMode
        property QtObject margins: QtObject {
            property real top; property real bottom; property real left; property real right
        }
    }""",
    "ExclusionMode": "QtObject { enum Mode { Ignore } }",
})
h.module("Quickshell.Wayland", {
    "WlrLayer": "QtObject { enum Layer { Top = 2, Overlay = 3 } }",
    "WlrKeyboardFocus": "QtObject { enum Focus { None = 0, Exclusive = 1, OnDemand = 2 } }",
})
h.singleton("qs.config", "Config", """QtObject {
    property int animDuration: 0
    property var ai: ({enabled: true, unloadAfterMinutes: 10})
    property var bar: ({frameEnabled: false})
}""")
h.singleton("qs.modules.globals", "GlobalStates", """QtObject {
    property bool assistantVisible: false
    property string assistantScreenName: "one"
    property string assistantPosition: "right"
    property bool assistantPinned: false
    property bool assistantWide: false
    property bool assistantFullscreen: false
    property int assistantWidth: 400
    property int assistantEffectiveWidth: 400
    signal assistantFocusRequested(bool wasAlreadyOpen)
    function hideAssistant() { assistantVisible = false; }
}""")
h.singleton("qs.modules.services", "YozdService", """QtObject {
    property var focusedMonitor: ({name: "one"})
}""")
h.copy("modules/services/Visibilities.qml", "qs/modules/services")
h.module("qs.modules.services", {})
h.singleton("qs.modules.theme", "Motion", """QtObject {
    property var morph: ({duration: 0, easing: Easing.Linear})
    property var enter: ({duration: 0})
}""")
h.singleton("qs.modules.aicenter.common", "BarLook", "QtObject { property int animDuration: 0 }")
h.copy("modules/aicenter/AiCenterHost.qml")
h.stub("AiCenterPanel", "Item { property bool frameWrapped; function focusComposer() {} }")
window = h.copy("modules/aicenter/AiCenterWindow.qml", siblings=False)
source = window.read_text()
source = re.sub(r"\n    anchors \{[^}]*\}", "", source, count=1)
source = source.replace("WlrLayershell.layer:", "property int compositorLayer:")
source = source.replace("WlrLayershell.keyboardFocus:", "property int compositorKeyboardFocus:")
source = source.replace("WlrLayershell.namespace:", "property string compositorNamespace:")
window.write_text(source)
scene = h.load("""import QtQuick
import qs.modules.globals
import qs.modules.services
Window {
    visible: true; width: 1920; height: 1080
    AiCenterWindow {
        objectName: "aiWindow"
        targetScreen: ({name: "one", width: 1920, height: 1080})
        width: 1920; height: 1080
    }
}""", auto_stub=False)
obj = h.find(scene, "aiWindow")


def ev(expr):
    return h.eval(obj, expr)


# Super+A, then the size control's fullscreen state, then Super+Ctrl+D.
ev("GlobalStates.assistantVisible = true; GlobalStates.assistantFullscreen = true")
h.app.processEvents()
ev("requestFocus()")
assert ev("visible && fullscreen")
assert ev("compositorLayer") == 3
assert ev("compositorKeyboardFocus") == 1
ev('Visibilities.setActiveModule("dashboard")')
assert ev("compositorLayer") == 2, "fullscreen AI must sit below the dashboard overlay"
assert ev("compositorKeyboardFocus") == 0, "AI must release keyboard ownership to the dashboard"
assert ev("GlobalStates.assistantVisible && GlobalStates.assistantFullscreen"), "opening dashboard preserves AI state"
ev("requestFocus()")
assert ev("compositorKeyboardFocus") == 0, "late AI focus requests cannot steal the dashboard keyboard"

# Closing the dashboard restores visibility priority without stealing focus.
ev('Visibilities.setActiveModule("")')
assert ev("compositorLayer") == 3
assert ev("compositorKeyboardFocus") == 2, "closing an overlay leaves AI at OnDemand"

# Every shell module uses the same priority, independent of AI size/host.
for fullscreen in (False, True):
    ev(f"GlobalStates.assistantFullscreen = {str(fullscreen).lower()}")
    for module in ("launcher", "dashboard", "overview", "powermenu", "tools", "presets", "aiquick", "keybinds"):
        ev(f'Visibilities.setActiveModule("{module}")')
        assert ev("compositorLayer") == 2, module
        assert ev("compositorKeyboardFocus") == 0, module
        ev('Visibilities.setActiveModule("")')

# A grown notch (hover, player) lifts above AI without taking its keyboard.
ev("requestFocus()")
ev('Visibilities.getForScreen("one").notchRaised = true')
assert ev("compositorLayer") == 2, "a grown notch must draw above fullscreen AI"
assert ev("compositorKeyboardFocus") == 1, "the notch never takes AI keyboard focus"
ev('Visibilities.getForScreen("one").notchRaised = false')
assert ev("compositorLayer") == 3

# An overlay on another monitor must not change this AI window's priority.
ev('YozdService.focusedMonitor = ({name: "two"}); Visibilities.setActiveModule("dashboard")')
assert ev("compositorLayer") == 3
ev("requestFocus()")
assert ev("compositorKeyboardFocus") == 1
ev("GlobalStates.assistantVisible = false")
assert ev("compositorKeyboardFocus") == 0, "hidden AI never requests keyboard focus"
print("ai-overlay-priority: ok")
