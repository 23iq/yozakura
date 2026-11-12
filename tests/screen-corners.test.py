"""Screen corners: drawn by the unified panel, no window of their own.

Loads the real modules/shell/UnifiedShellPanel.qml (its other children are
stubs; the layer-shell boundary becomes plain properties) with the real
modules/corners/ScreenCornersContent.qml + RoundCorner, and checks that:
- the corners draw exactly the pixels of the former full-screen corners
  window (four RoundCorners anchored to the corners of a screen-size item),
  with the frame on and off, and above everything else the panel draws;
- they are in no input region of the panel (clicks at the corners pass
  through as through the former window's empty mask), whatever the mask is;
- nothing is loaded while theme.enableCorners is off or roundness is 0;
- they hide under a fullscreen window on this screen, without being
  unloaded (no churn on a fullscreen toggle);
- the size follows the frame thickness as before (clamped, 6 when invalid).
"""
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import REPO, Harness  # noqa: E402
from lib.waits import settle  # noqa: E402

import shiboken6  # noqa: E402
from PySide6.QtQuick import QQuickWindow  # noqa: E402

W, H = 640, 400

h = Harness("screen-corners")
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
    property var dock: ({ enabled: false })
    property var bar: ({ frameEnabled: false, frameThickness: 6 })
    property int roundness: 16
    property var theme: ({ enableCorners: true })
}""")
# Styling.radius as in modules/theme/Styling.qml.
h.singleton("qs.modules.theme", "Styling", """import QtQuick
import qs.config
QtObject {
    function radius(offset) { return Config.roundness > 0 ? Math.max(Config.roundness + offset, 0) : 0; }
}""")
h.module("qs.modules.services", {
    "ShellLayout": "pragma Singleton\nQtObject { property bool notchEnabled: true }",
    "FocusGrabManager": "pragma Singleton\nQtObject { property bool hasActiveGrab: false; function clearTopGrab() {} }",
    "YozdService": "pragma Singleton\nQtObject { property var focusedMonitor: null; function monitorFor(s) { return ({ name: s ? s.name : '' }) } }",
})
h.copy("modules/services/Visibilities.qml", "qs/modules/services")
h.module("qs.modules.services", {})
h.singleton("qs.modules.bar.workspaces", "CompositorData", """QtObject {
    property bool fullscreen: false
    function monitorHasFullscreen(m) { return fullscreen && !!m }
}""")
h.singleton("qs.modules.bar.panels", "Panels", 'QtObject { property string primaryEdge: "top" }')
h.module("qs.modules.bar", {
    "PanelHost": """Item {
        property var screen; property bool active
        property var primary: null; property var bars: []; property var zones: ({}); property var containSides: ({})
        property var hitRegions: []
    }""",
})
h.module("qs.modules.bar.activities", {
    "ActivityHost": """Item {
        property string screenName; property var bar; property var notch: null; property bool barEnabled
        property Item leftHitbox: null; property Item rightHitbox: null
    }""",
})
h.module("qs.modules.notch", {
    "NotchContent": """Item {
        property var screen; property bool unifiedEffectActive
        property bool hoverActive: false; property bool screenNotchOpen: false
        property bool reveal: true; property bool panelModal: false
        function dismissPanel() {}
        readonly property Item notchHitbox: box
        readonly property Item notchStemHitbox: null
        Item { id: box; x: 160; width: 320; height: 36 }
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
# The frame stub paints the whole screen when `paint` is set, to see what is
# drawn on top of what.
h.module("qs.modules.frame", {"ScreenFrameContent": """Item {
        property var targetScreen; property bool hasFullscreenWindow
        property bool paint: false
        Rectangle { anchors.fill: parent; color: "#ff0000"; visible: parent.paint }
    }"""})
h.module("qs.modules.shell", {
    "PanelShadows": "Item { property var frame; property var bars; property var notch; property var dock; property var activities; property bool barEnabled; property bool dockEnabled; property bool frameElsewhere }",
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
# Panel helpers that exist on some branches only (copied when present).
h.copy("modules/components/SettleGate.qml", "qs/modules/components")
h.module("qs.modules.components", {})
for helper in ("FrameSplit.qml", "PanelPresence.qml"):
    if (REPO / "modules/shell" / helper).is_file():
        h.copy(f"modules/shell/{helper}", "qs/modules/shell", siblings=False)
h.copy("modules/corners/ScreenCornersContent.qml", "qs/modules/corners")
h.module("qs.modules.corners", {})
panel = h.copy("modules/shell/UnifiedShellPanel.qml", "qs/modules/shell", siblings=False)
text = re.sub(r"\n    anchors \{[^}]*\}", "", panel.read_text(), count=1)
for old, new in (("WlrLayershell.keyboardFocus:", "property int compositorKeyboardFocus:"),
                 ("WlrLayershell.namespace:", "property string compositorNamespace:"),
                 ("WlrLayershell.layer:", "property int compositorLayer:")):
    assert old in text, old
    text = text.replace(old, new)
panel.write_text(text)
h.module("qs.modules.shell", {})

root = h.load(f"""import QtQuick
import QtQuick.Window
import Quickshell
import qs.config
import qs.modules.bar.workspaces
import qs.modules.corners
import qs.modules.services
import qs.modules.shell
import qs.modules.theme
Window {{
    id: win
    width: {W}; height: {H}; visible: true; color: "white"
    ShellScreen {{ id: scr; name: "DP-1"; width: {W}; height: {H} }}
    property alias panel: panel
    property alias reference: reference
    UnifiedShellPanel {{ id: panel; targetScreen: scr; width: {W}; height: {H} }}
    // The former corners window's content: a RoundCorner per screen corner.
    Item {{
        id: reference
        anchors.fill: parent
        visible: false
        readonly property int cornerSize: Styling.radius(4) + ((Config.bar?.frameEnabled ?? false)
            ? Math.max(1, Math.min(Math.round(typeof Config.bar.frameThickness === "number" ? Config.bar.frameThickness : 6), 40)) : 0)
        RoundCorner {{ size: reference.cornerSize; anchors.left: parent.left; anchors.top: parent.top; corner: RoundCorner.CornerEnum.TopLeft }}
        RoundCorner {{ size: reference.cornerSize; anchors.right: parent.right; anchors.top: parent.top; corner: RoundCorner.CornerEnum.TopRight }}
        RoundCorner {{ size: reference.cornerSize; anchors.left: parent.left; anchors.bottom: parent.bottom; corner: RoundCorner.CornerEnum.BottomLeft }}
        RoundCorner {{ size: reference.cornerSize; anchors.right: parent.right; anchors.bottom: parent.bottom; corner: RoundCorner.CornerEnum.BottomRight }}
    }}
    function corners() {{
        for (const c of panel.children)
            if (c instanceof Loader && c.item instanceof ScreenCornersContent)
                return c.item;
        return null;
    }}
    function inside(item, ancestor) {{
        for (let p = item; p; p = p.parent)
            if (p === ancestor)
                return true;
        return false;
    }}
    // Is any input region (or the full-screen mask item) the corners or in them?
    function maskTouchesCorners() {{
        const c = corners();
        if (!c)
            return false;
        const items = panel.mask.regions.map(r => r.item);
        if (panel.mask.item)
            items.push(panel.mask.item);
        return items.some(i => i && (inside(i, c) || i === c));
    }}
    function lastChildIsCorners() {{
        const kids = panel.children;
        const c = corners();
        return !!c && kids[kids.length - 1] === c.parent;
    }}
}}""", auto_stub=False)

ok_all = True


def check(name, ok, detail=""):
    global ok_all
    ok_all &= bool(ok)
    print(("PASS " if ok else "FAIL ") + name + (" " + detail if detail else ""))


def ev(expr):
    return h.eval(root, expr)


window = shiboken6.wrapInstance(shiboken6.getCppPointer(root)[0], QQuickWindow)


def grab():
    settle()
    return window.grabWindow()


def same_pixels(label):
    ev("reference.visible = false; panel.visible = true")
    a = grab()
    ev("reference.visible = true; panel.visible = false")
    b = grab()
    ev("reference.visible = false; panel.visible = true")
    check(f"{label}: pixels identical to the former corners window", a == b and not a.isNull())
    check(f"{label}: corner drawn", a.pixelColor(0, 0).lightness() < 128 and a.pixelColor(W // 2, H // 2).lightness() > 200)


def dark(img, x, y):
    return img.pixelColor(x, y).lightness() < 64


settle()
check("corners loaded by default", ev("corners() !== null"))
check("drawn last: above bar, notch, dock, frame, toasts", ev("lastChildIsCorners()"))
check("corners size: radius(4)", ev("corners().cornerSize") == 20)
same_pixels("frame off")


def set_frame_paint(on):
    ev(f"panel.children.forEach(c => c.children.forEach(k => {{ if (k.paint !== undefined) k.paint = {str(on).lower()}; }}))")


# Above the panel's own content: a frame painting the whole screen is covered
# at the corners, visible elsewhere.
set_frame_paint(True)
img = grab()
check("corners above the panel's content", dark(img, 0, 0) and dark(img, W - 1, H - 1)
      and img.pixelColor(W // 2, H // 2).red() > 200 and img.pixelColor(W // 2, H // 2).green() < 50)
set_frame_paint(False)

# Input: no region ever covers the corners
check("corners in no input region", not ev("maskTouchesCorners()"))
ev("FocusGrabManager.hasActiveGrab = true")
settle()
check("full-screen capture: the mask is the click-outside item, not the corners",
      not ev("maskTouchesCorners()") and ev("panel.mask.item !== null"))
ev("FocusGrabManager.hasActiveGrab = false")
settle()
check("mask back to the hitboxes, corners still shown", ev("panel.mask.item") is None and ev("corners() !== null && corners().visible"))

# Frame thickness
ev("Config.bar = ({ frameEnabled: true, frameThickness: 10 })")
check("frame on: size includes the thickness", ev("corners().cornerSize") == 30)
same_pixels("frame on")
ev("Config.bar = ({ frameEnabled: true, frameThickness: 400 })")
check("frame thickness clamped as before", ev("corners().cornerSize") == 60)
ev("Config.bar = ({ frameEnabled: true, frameThickness: 'x' })")
check("non-numeric thickness uses 6", ev("corners().cornerSize") == 26)
ev("Config.bar = ({ frameEnabled: false, frameThickness: 6 })")

# Fullscreen: hidden, not unloaded
ev("CompositorData.fullscreen = true")
img = grab()
check("fullscreen window: corners hidden", ev("corners() !== null && !corners().visible") and not dark(img, 0, 0))
ev("CompositorData.fullscreen = false")
img = grab()
check("fullscreen gone: shown again", ev("corners().visible") and dark(img, 0, 0))

# Off: nothing loaded at all
ev("Config.theme = ({ enableCorners: false })")
settle()
check("corners off: nothing loaded", ev("corners() === null"))
img = grab()
check("corners off: nothing drawn", not dark(img, 0, 0))
ev("Config.theme = ({ enableCorners: true })")
settle()
check("corners on again: loaded", ev("corners() !== null"))
ev("Config.roundness = 0")
settle()
check("roundness 0: nothing loaded", ev("corners() === null"))
ev("Config.roundness = 16")
settle()
same_pixels("back on")

errors = list(h.type_errors)
check("no TypeError / ReferenceError", not errors, str(errors))
sys.exit(0 if ok_all else 1)
