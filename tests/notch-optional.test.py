"""notch.enabled off: the island does not exist at all, and nothing needs it.

The real UnifiedShellPanel offscreen (its children are stubs; the layer-shell
boundary becomes plain properties), toggled at runtime both ways: the notch
Loader drops and recreates NotchContent, the null-safe proxies, input
regions and focus grab follow, Visibilities' notch geometry goes empty, and
no binding ever reads a missing notch (no TypeError/ReferenceError).
"""
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402

h = Harness("notch-optional")
h.module("Quickshell", {
    "Singleton": "Item {}",
    "ShellScreen": "QtObject { property string name; property int width; property int height }",
    "PanelWindow": """Item {
        property var screen
        property color color
        property int exclusionMode
        property var mask
        property bool aboveWindows
    }""",
    "Region": "QtObject { property Item item; property var regions: [] }",
    "ExclusionMode": "QtObject { enum Mode { Ignore } }",
})
h.module("Quickshell.Wayland", {
    "WlrLayer": "QtObject { enum Layer { Top = 2, Overlay = 3 } }",
    "WlrKeyboardFocus": "QtObject { enum Focus { None = 0, Exclusive = 1, OnDemand = 2 } }",
})
h.singleton("qs.config", "Config", """QtObject {
    property bool notchReady: true
    property bool barReady: true
    property bool dockReady: true
    property var dock: ({ enabled: false })
    property var bar: ({ frameEnabled: false })
}""")
h.module("qs.modules.services", {
    "ShellLayout": "pragma Singleton\nQtObject { property bool notchEnabled: true }",
    "FocusGrabManager": "pragma Singleton\nQtObject { property bool hasActiveGrab: false; function clearTopGrab() {} }",
    "YozdService": "pragma Singleton\nQtObject { property var focusedMonitor: null; function monitorFor(s) { return null } }",
})
h.copy("modules/services/Visibilities.qml", "qs/modules/services")
h.module("qs.modules.services", {})
h.singleton("qs.modules.bar.workspaces", "CompositorData", "QtObject { function monitorHasFullscreen(m) { return false } }")
h.singleton("qs.modules.bar.panels", "Panels", 'QtObject { property string primaryEdge: "top" }')
h.module("qs.modules.bar", {
    "PanelHost": """Item {
        property var screen; property bool active
        property var primary: null; property var bars: []; property var zones: ({}); property var containSides: ({})
        property var hitRegions: []
    }""",
})
h.module("qs.modules.bar.activities", {
    "ActivityHost": """import QtQuick
import qs.modules.services
Item {
        objectName: "activityHost"
        property string screenName; property var bar; property var notch: null; property bool barEnabled
        property Item leftHitbox: null; property Item rightHitbox: null
        // Like the real one: reads the notch only through its null-safe paths
        readonly property real notchWidth: Visibilities.notchRect(screenName).width
        readonly property bool revealed: notch ? notch.reveal : true
    }""",
})
# NotchContent: registers its container like the real one (Component.onCompleted
# / onDestruction), so the geometry API follows the Loader
h.module("qs.modules.notch", {
    "NotchContent": """import QtQuick
import qs.modules.services
Item {
        id: nc
        property var screen; property bool unifiedEffectActive
        property bool hoverActive: false; property bool screenNotchOpen: false
        property bool reveal: true; property bool panelModal: false
        property bool activeWindowFullscreen: false
        property int dismissed: 0
        function dismissPanel() { dismissed++ }
        readonly property Item notchHitbox: box
        readonly property Item notchStemHitbox: null
        readonly property Item visualRegion: box
        Item { id: box; x: 800; width: 320; height: 36 }
        Component.onCompleted: Visibilities.registerNotch(nc.screen.name, box)
        Component.onDestruction: Visibilities.unregisterNotch(nc.screen.name)
    }""",
})
h.module("qs.modules.dock", {
    "DockContent": """Item {
        property var screen; property bool unifiedEffectActive
        property string position: "bottom"; property bool pinned; property bool reveal
        property bool activeWindowFullscreen; property int dockSize; property int totalMargin
        property Item dockHitbox: null
    }""",
})
h.module("qs.modules.frame", {"ScreenFrameContent": "Item { property var targetScreen; property bool hasFullscreenWindow }"})
h.module("qs.modules.shell", {
    "PanelShadows": """Item {
        property var frame; property var bars; property var notch: null; property var dock; property var activities
        property bool barEnabled; property bool dockEnabled
        readonly property bool notchCast: notch !== null && notch.visualRegion !== null
    }""",
})
h.module("qs.modules.shell.rehome", {"CornerPills": "Item { property var panel; property Item hitbox: null }"})
h.module("qs.modules.notifications", {
    "CornerToasts": "Item { property var panel; property string screenName; property bool active; property Item hitbox: null }",
})
h.module("qs.modules.notifications.strips", {
    "StripsView": "Item { property var panel; property string screenName; property bool active; property bool wantsKeyboard; property Item hitbox: null }",
})
h.module("qs.modules.components", {
    "LanternScope": "Item {}",
    "FocusGrab": "Item { property var windows; property bool active; signal cleared() }",
})
h.module("qs.modules.globals", {})
panel = h.copy("modules/shell/UnifiedShellPanel.qml", "qs/modules/shell", siblings=False)
text = re.sub(r"\n    anchors \{[^}]*\}", "", panel.read_text(), count=1)
for old, new in (("WlrLayershell.keyboardFocus:", "property int compositorKeyboardFocus:"),
                 ("WlrLayershell.namespace:", "property string compositorNamespace:"),
                 ("WlrLayershell.layer:", "property int compositorLayer:")):
    assert old in text, old
    text = text.replace(old, new)
panel.write_text(text)
h.module("qs.modules.shell", {})

scene = h.load("""import QtQuick
import Quickshell
import qs.config
import qs.modules.services
import qs.modules.shell
Item {
    width: 1920; height: 1080
    ShellScreen { id: scr; name: "DP-1"; width: 1920; height: 1080 }
    UnifiedShellPanel { objectName: "panel"; targetScreen: scr; width: 1920; height: 1080 }
}""", auto_stub=False)
obj = h.find(scene, "panel")


def ev(expr):
    return h.eval(obj, expr)


def settle():
    for _ in range(5):
        h.app.processEvents()


def check(enabled: bool):
    settle()
    assert ev("notchContent !== null") is enabled, f"NotchContent exists only while notch.enabled ({enabled})"
    assert ev('Visibilities.hasNotch("DP-1")') is enabled, enabled
    w = ev('Visibilities.notchRect("DP-1").width')
    assert (w == 320) if enabled else (w == 0), w
    assert ev("notchRegion.item !== null") is enabled, "the mask takes the notch only while it exists"
    assert ev("notchStemRegion.item") is None
    act = h.find(obj, "activityHost")
    assert h.eval(act, "notch !== null") is enabled
    assert h.eval(act, "notchWidth") == (320 if enabled else 0)
    for prop in ("notchHoverActive", "notchOpen", "notchPanelModal"):
        assert ev(prop) is False, prop
    assert ev("notchReveal") is enabled
    assert ev("compositorKeyboardFocus") == 0


check(True)
# An open notch view takes the keyboard and click-outside; with the notch gone
# nothing is left holding them
ev("notchContent.screenNotchOpen = true")
settle()
assert ev("compositorKeyboardFocus") == 1 and ev("needsFullScreenInput") is True
for enabled in (False, True, False, True):
    ev(f"ShellLayout.notchEnabled = {str(enabled).lower()}")
    check(enabled)
    assert ev("needsFullScreenInput") is False

# Not ready yet (config still loading): no island either
ev("Config.notchReady = false")
check(False)
ev("Config.notchReady = true")
check(True)

errors = [e for e in h.type_errors]
assert not errors, errors
print("notch-optional: ok")
h.exit(0)
