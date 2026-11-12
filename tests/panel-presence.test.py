"""performance.hidePanelInFullscreen: the unified panel window unmaps under a
fullscreen window while nothing in it has to show, and maps back at once.

The real UnifiedShellPanel offscreen (its children are stand-ins exposing
the properties the panel reads; the layer-shell boundary becomes plain
properties; PanelPresence, PanelPresence.js, FrameSplit and SettleGate are
the real ones), checking that:

* off (the default) the window stays mapped under a fullscreen window;
* on, without a fullscreen window it stays mapped; entering fullscreen
  unmaps it once, after the state has settled; a quick fullscreen toggle
  unmaps nothing; leaving fullscreen maps it in the same tick;
* every reason to show (a notification for this screen, a view opened on
  it, a focus grab, a bar revealed or its popup open, the notch revealed or
  opened, the dock revealed, live activities, an opened strip, corner
  pills, the OSD in the bar, the frame drawn with some thickness) maps it
  in the same tick, and its end unmaps it once settled;
* bar.availableOnFullscreen (the bar reveals on edge hover) and the dock's
  hover reveal in fullscreen keep it mapped;
* while unmapped the panel stays registered (Visibilities) and its
  reservations input (panelZones) is unchanged.
"""
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402
from lib.waits import pump, settle, wait_until  # noqa: E402

h = Harness("panel-presence")
h.module("Quickshell", {
    "Singleton": "Item {}",
    "ShellScreen": "QtObject { property string name; property int width; property int height }",
    "PanelWindow": """Item {
        property var screen
        property color color
        property int exclusionMode
        property var mask
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
    property int animDuration: 0
    property var dock: ({ enabled: true, availableOnFullscreen: false, hoverToReveal: true })
    property var bar: ({ frameEnabled: true, availableOnFullscreen: false })
    property QtObject performance: QtObject {
        property bool hidePanelInFullscreen: false
        property bool splitFrame: false
    }
}""")
h.module("qs.modules.services", {
    "ShellLayout": "pragma Singleton\nQtObject { property bool notchEnabled: true }",
    "FocusGrabManager": "pragma Singleton\nQtObject { property bool hasActiveGrab: false; function clearTopGrab() {} }",
    "YozdService": "pragma Singleton\nQtObject { property var focusedMonitor: null; function monitorFor(s) { return ({ id: 1 }) } }",
    "Notifications": """pragma Singleton
QtObject {
    property var popupList: []
    property string screen: "DP-1"
    function showsOnScreen(name) { return name === screen }
}""",
    "OsdService": """pragma Singleton
QtObject {
    property bool inline: false
    function routeForScreen(name) { return { "style": inline ? "bar-inline" : "pill", "window": !inline } }
}""",
})
h.copy("modules/services/Visibilities.qml", "qs/modules/services")
h.module("qs.modules.services", {})
h.module("qs.modules.globals", {"GlobalStates": "pragma Singleton\nQtObject { property bool osdVisible: false }"})
h.singleton("qs.modules.bar.workspaces", "CompositorData",
            "QtObject { property bool fullscreen: false; function monitorHasFullscreen(m) { return fullscreen && !!m } }")
h.singleton("qs.modules.bar.panels", "Panels", 'QtObject { property string primaryEdge: "top" }')
h.module("qs.modules.bar", {
    "PanelHost": """Item {
        objectName: "panelHost"
        property var screen; property bool active
        property QtObject bar: QtObject {
            property bool reveal: true; property bool popupOpen: false
            property string barPosition: "top"; property bool pinned: true; property string autohideMode: "never"
            property bool hoverActive: false; property bool activeWindowFullscreen: false
            property int barTargetWidth: 0; property int barTargetHeight: 40; property int baseOuterMargin: 0
            property bool contained: false; property bool integratedDockEnabled: false
        }
        property var primary: bar; property var bars: [bar]
        property var zones: ({ top: 40, bottom: 0, left: 0, right: 0 }); property var containSides: ({})
        property var hitRegions: []
    }""",
})
h.module("qs.modules.bar.activities", {
    "ActivityHost": """Item {
        objectName: "activityHost"
        property string screenName; property var bar; property var notch: null; property bool barEnabled
        property Item leftHitbox: null; property Item rightHitbox: null
        property bool revealed: true; property bool wanted: false; property bool lingering: false
    }""",
})
h.module("qs.modules.notch", {
    "NotchContent": """Item {
        property var screen; property bool unifiedEffectActive
        property bool hoverActive: false; property bool screenNotchOpen: false
        property bool reveal: true; property bool panelModal: false
        property bool activeWindowFullscreen: false
        function dismissPanel() {}
        readonly property Item notchHitbox: null
        readonly property Item notchStemHitbox: null
    }""",
})
h.module("qs.modules.dock", {
    "DockContent": """Item {
        objectName: "dockContent"
        property var screen; property bool unifiedEffectActive
        property string position: "bottom"; property bool pinned: true; property bool reveal: true
        property bool activeWindowFullscreen; property int dockSize: 56; property int totalMargin: 8
        property Item dockHitbox: null
    }""",
})
h.module("qs.modules.frame", {"ScreenFrameContent": """Item {
    objectName: "frameContent"
    property var targetScreen; property bool hasFullscreenWindow
    property int topThickness: hasFullscreenWindow ? 0 : 6
    property int bottomThickness: hasFullscreenWindow ? 0 : 6
    property int leftThickness: hasFullscreenWindow ? 0 : 6
    property int rightThickness: hasFullscreenWindow ? 0 : 6
}"""})
h.module("qs.modules.shell", {
    "PanelShadows": """Item {
        property var frame; property var bars; property var notch: null; property var dock; property var activities
        property bool barEnabled; property bool dockEnabled; property bool frameElsewhere
    }""",
})
h.module("qs.modules.shell.rehome", {"CornerPills": "Item { objectName: \"cornerPills\"; property var panel; property bool active: false; property Item hitbox: null }"})
h.module("qs.modules.notifications", {
    "CornerToasts": "Item { property var panel; property string screenName; property bool active; property Item hitbox: null }",
})
h.module("qs.modules.notifications.strips", {
    "StripsView": "Item { objectName: \"stripsView\"; property var panel; property string screenName; property bool active; property bool wantsKeyboard: false; property Item hitbox: null }",
})
h.copy("modules/components/SettleGate.qml", "qs/modules/components")
h.module("qs.modules.components", {
    "LanternScope": "Item {}",
    "FocusGrab": "Item { property var windows; property bool active; signal cleared() }",
})
h.copy("modules/shell/FrameSplit.qml", "qs/modules/shell", siblings=False)
h.copy("modules/shell/PanelPresence.qml", "qs/modules/shell", siblings=False)
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
import qs.modules.globals
import qs.modules.bar.workspaces
import qs.modules.shell
Item {
    width: 1920; height: 1080
    ShellScreen { id: scr; name: "DP-1"; width: 1920; height: 1080 }
    UnifiedShellPanel { objectName: "panel"; targetScreen: scr; width: 1920; height: 1080 }
}""", auto_stub=False)
obj = h.find(scene, "panel")
ok_all = True


def check(name, ok, detail=""):
    global ok_all
    ok_all &= bool(ok)
    print(("PASS " if ok else "FAIL ") + name + (" " + detail if detail else ""))


CHILDREN = ["panelHost", "activityHost", "dockContent", "frameContent", "cornerPills", "stripsView"]


def ev(expr):
    """Evaluate on the panel; `<child>.` names one of its stand-ins (ids
    inside the panel are not visible from here)."""
    m = re.match(r"^(\w+)\.(.*)$", expr)
    if m and m.group(1) in CHILDREN:
        return h.eval(h.find(obj, m.group(1)), m.group(2))
    return h.eval(obj, expr)


def run(*exprs):
    for e in exprs:
        ev(e.strip())


def mapped():
    return ev("visible")


ev("presence.settleInterval = 150")
SETTLE = 150
flips = []
obj.visibleChanged.connect(lambda: flips.append(ev("visible")))


def fullscreen(on):
    ev(f"CompositorData.fullscreen = {str(on).lower()}")


def hide_everything():
    """What the real children do under a fullscreen window: the bar, notch
    and dock slide out, the frame goes to 0."""
    run("panelHost.bar.reveal = false", "notchContent.reveal = false", "dockContent.reveal = false")


def show_everything():
    run("panelHost.bar.reveal = true", "notchContent.reveal = true", "dockContent.reveal = true")


# Off: never unmapped
check("off by default", ev("Config.performance.hidePanelInFullscreen") is False)
fullscreen(True)
hide_everything()
pump(SETTLE * 3)
check("off: stays mapped under a fullscreen window", mapped() is True and flips == [], str(flips))
fullscreen(False)
show_everything()
settle()

# On, no fullscreen
ev("Config.performance.hidePanelInFullscreen = true")
settle()
check("on, no fullscreen: mapped", mapped() is True and ev("JSON.stringify(presence.reasons)") == '["noFullscreen"]')
pump(SETTLE * 2)
check("on, no fullscreen: stays mapped", mapped() is True and flips == [])

# Entering fullscreen: unmaps once, after the state settled
fullscreen(True)
hide_everything()
check("fullscreen: still mapped before the state settles", mapped() is True)
check("fullscreen: unmapped once settled", wait_until(lambda: mapped() is False))
check("fullscreen: exactly one unmap", flips == [False], str(flips))
check("unmapped: still registered for the other windows",
      ev('Visibilities.barPanels["DP-1"].objectName') == "panel")
check("unmapped: reservations input unchanged", ev("panelZones.top") == 40)

# Each reason maps it at once, its end unmaps it once settled
REASONS = {
    "a notification for this screen": ("Notifications.popupList = [{}]", "Notifications.popupList = []"),
    "a view opened on this screen": ('Visibilities.getForScreen("DP-1").launcher = true', 'Visibilities.getForScreen("DP-1").launcher = false'),
    "a focus grab": ("FocusGrabManager.hasActiveGrab = true", "FocusGrabManager.hasActiveGrab = false"),
    "a bar revealed": ("panelHost.bar.reveal = true", "panelHost.bar.reveal = false"),
    "a bar popup open": ("panelHost.bar.popupOpen = true", "panelHost.bar.popupOpen = false"),
    "the notch revealed": ("notchContent.reveal = true", "notchContent.reveal = false"),
    "a view in the notch": ("notchContent.screenNotchOpen = true", "notchContent.screenNotchOpen = false"),
    "a modal notch panel": ("notchContent.panelModal = true", "notchContent.panelModal = false"),
    "the dock revealed": ("dockContent.reveal = true", "dockContent.reveal = false"),
    "live activities out": ("activityHost.wanted = true", "activityHost.wanted = false"),
    "an opened strip": ("stripsView.wantsKeyboard = true", "stripsView.wantsKeyboard = false"),
    "corner pills": ("cornerPills.active = true", "cornerPills.active = false"),
    "the OSD in the bar": ("OsdService.inline = true; GlobalStates.osdVisible = true", "GlobalStates.osdVisible = false; OsdService.inline = false"),
    "the frame restored around a revealed bar": ("frameContent.topThickness = 3", "frameContent.topThickness = 0"),
}
for name, (on, off) in REASONS.items():
    flips.clear()
    run(*on.split(";"))
    now = mapped()
    run(*off.split(";"))
    check(f"{name}: maps in the same tick", now is True)
    check(f"{name}: unmaps once settled after it ends", wait_until(lambda: mapped() is False) and flips == [True, False],
          str(flips))

# A notification for another screen does not map it
flips.clear()
ev("Notifications.screen = 'HDMI-1'; Notifications.popupList = [{}]")
pump(SETTLE * 2)
check("a notification for another screen: stays unmapped", mapped() is False and flips == [], str(flips))
ev("Notifications.popupList = []; Notifications.screen = 'DP-1'")

# Hover reveal in fullscreen: the edge must stay hoverable
for name, (on, off) in {
    "bar.availableOnFullscreen": ("Config.bar = Object.assign({}, Config.bar, { availableOnFullscreen: true })",
                                  "Config.bar = Object.assign({}, Config.bar, { availableOnFullscreen: false })"),
    "dock hover reveal in fullscreen": ("Config.dock = Object.assign({}, Config.dock, { availableOnFullscreen: true })",
                                        "Config.dock = Object.assign({}, Config.dock, { availableOnFullscreen: false })"),
}.items():
    flips.clear()
    run(on)
    first = mapped()
    pump(SETTLE * 2)
    check(f"{name}: mapped and stays mapped", first is True and mapped() is True, str(flips))
    run(off)
    check(f"{name} off again: unmapped once settled", wait_until(lambda: mapped() is False))

# Leaving fullscreen: mapped in the same tick
flips.clear()
fullscreen(False)
check("fullscreen gone: mapped in the same tick", mapped() is True and flips == [True], str(flips))
show_everything()

# A quick fullscreen toggle unmaps nothing
flips.clear()
fullscreen(True)
hide_everything()
pump(SETTLE // 3)
fullscreen(False)
show_everything()
pump(SETTLE * 2)
check("quick fullscreen toggle: never unmapped", mapped() is True and flips == [], str(flips))

# Turning the flag off while unmapped maps it at once
fullscreen(True)
hide_everything()
wait_until(lambda: mapped() is False)
ev("Config.performance.hidePanelInFullscreen = false")
check("flag turned off while unmapped: mapped at once", mapped() is True)

errors = list(h.type_errors)
check("no TypeError / ReferenceError", not errors, str(errors))
h.exit(0 if ok_all else 1)
