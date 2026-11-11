"""Overview, presets and AI selection popups close through SurfaceLatch.

A layer window that holds a text field with input-method focus must never
be unmapped or destroyed in the tick its keyboard focus drops (the Super+A
QtWayland crash). The real OverviewPopup / PresetsPopup (as Items over kit
stubs) run inside the real shell.qml Loader expressions: on close the field
lets go of focus and keyboard focus goes to None in the closing tick, the
window stays mapped and loaded, unmaps at least a frame later, and only then
does the Loader destroy it. Reopening in between keeps the same window. The
selection menu's Loader in shell.qml is checked the same way (its window
content is covered by tests/ai-selection-preview.test.py).

A window clicked in the overview (OverviewActivation) is asked for at once
and again only after the popup has unmapped: Hyprland refuses keyboard focus
to a window while the overview layer holds it.
"""
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402

from PySide6.QtCore import QElapsedTimer  # noqa: E402

REPO = Path(__file__).resolve().parents[1]
h = Harness("popup-latch")

h.module("Quickshell", {"Region": "QtObject { property Item item }"})
h.singleton("qs.config", "Config", "QtObject { property int animDuration: 0; property var workspaces: ({shown: 10}) }")
h.module("qs.modules.globals", {"Brand": "pragma Singleton\nQtObject { function namespace(n) { return n } }"})
h.module("qs.modules.theme", {
    "Motion": "pragma Singleton\nQtObject { property var enter: ({duration: 0, easing: Easing.OutCubic, overshoot: 1}); "
              "property var exit: ({duration: 0}); property var morph: ({duration: 0, easing: Easing.OutCubic}) }",
    "Colors": "pragma Singleton\nQtObject { property color scrim: 'black' }",
    "Styling": "pragma Singleton\nQtObject { function radius(o) { return 8 } }",
    "Icons": "pragma Singleton\nQtObject { property string overview: 'o' }",
})
h.singleton("qs.modules.services", "Visibilities", """QtObject {
    id: v
    property Component flags: Component { QtObject { property bool overview; property bool presets } }
    property var screens: ({})
    function getForScreen(n) {
        if (!screens[n])
            screens[n] = flags.createObject(v);
        return screens[n];
    }
    property string currentActiveModule: ""
    function setActiveModule(m) {
        currentActiveModule = m;
        for (const n in screens)
            screens[n].overview = screens[n].presets = false;
    }
}""")
h.module("qs.modules.services", {
    "FocusGrab": "QtObject { property var windows; property bool active; signal cleared }",
    "I18n": "pragma Singleton\nQtObject { function t(k) { return k } }",
    "YozdService": "pragma Singleton\nQtObject { property var focusedWorkspace: null; property var log: []; "
                   "function dispatch(c) { log = log.concat([c]) } }",
    "SuspendManager": "pragma Singleton\nQtObject { property bool wakeReady: true }",
})
# A focusable text field: the latch must take focus off it before the drop.
FIELD = ("FocusScope { id: f; implicitHeight: 20; implicitWidth: 100; property alias text: input.text; "
         "property bool boxed; property string placeholderText; property bool handleTabNavigation; property bool clearOnEscape; "
         "signal searchTextChanged(string text); signal accepted; signal tabPressed; signal shiftTabPressed; signal downPressed; "
         "signal upPressed; signal escapePressed; signal leftPressed; signal rightPressed; "
         "function clear() { input.text = '' } function focusInput() { input.forceActiveFocus() } "
         "TextInput { id: input; objectName: 'field'; anchors.fill: parent; focus: true; text: 'draft' } }")
h.copy("modules/components/SurfaceLatch.qml", "qs/modules/components", siblings=False)
h.module("qs.modules.components", {"StyledRect": "Item { property string variant; property real radius; property bool enableShadow }"})
h.module("qs.modules.components.kit", {
    "Space": "pragma Singleton\nQtObject { property int s: 8; property int m: 12; property int l: 16; property int xl: 24; property int xxl: 32; property int controlM: 40 }",
    "Look": "pragma Singleton\nQtObject { function radius(r, h) { return 8 } }",
    "Type": "pragma Singleton\nQtObject { property color accent: 'pink'; property color danger: 'red'; property color track: 'gray' }",
    "Scrim": "Item { property bool shown; signal clicked }",
    "Icon": "Item { property string icon; property string role; property string tone }",
    "KitText": "Text { property string role; property bool tabular }",
    "Mark": "Item { property color color }",
    "SearchField": FIELD,
})
h.module("qs.modules.widgets.overview", {
    "OverviewView": "Item { property var currentScreen; property string searchQuery; property var matchingWindows: []; "
                    "property int selectedMatchIndex; property bool needsScrollbar; function resetSearch() {} "
                    "function stepWorkspace(d) { return true } implicitWidth: 400; implicitHeight: 300 }",
})
h.module("qs.modules.widgets.presets", {
    "PresetsGallery": FIELD.replace("FocusScope { id: f;", "FocusScope { id: f; signal closeRequested;"),
})


def as_item(rel: str) -> str:
    """The layer window as an Item: keyboard focus mode kept as a property."""
    src = (REPO / rel).read_text()
    out = src.replace("import Quickshell.Wayland\n", "")
    out = out.replace("PanelWindow {", "Item {\n    property var screen\n    property var mask\n    property Item contentItem: this", 1)
    out = re.sub(r"\n    anchors \{[^}]*\}", "", out, count=1)
    out = out.replace("WlrLayershell.keyboardFocus:", "property int keyboardFocus:")
    out = out.replace("WlrKeyboardFocus.Exclusive", "2").replace("WlrKeyboardFocus.None", "0")
    out = "\n".join(ln for ln in out.split("\n") if not re.match(r'\s*(color: "transparent"|exclusionMode:|WlrLayershell\.)', ln))
    return out


for rel, dest in (("modules/widgets/overview/OverviewPopup.qml", "qs/modules/widgets/overview"),
                  ("modules/widgets/presets/PresetsPopup.qml", "qs/modules/widgets/presets")):
    h.copy(rel, dest, replace={(REPO / rel).read_text(): as_item(rel)}, siblings=False)
h.copy("modules/widgets/overview/OverviewActivation.qml", "qs/modules/widgets/overview", siblings=False)
h.singleton("qs.modules.bar.workspaces", "CompositorData", "QtObject { property var windowByAddress: ({'0xa': {}}) }")
h.module("Quickshell", {"Singleton": "QtObject { default property list<QtObject> data }"})
h.module("qs.modules.widgets.overview", {})
h.module("qs.modules.widgets.presets", {})

# The LatchedLoaders' bindings, verbatim from shell.qml.
h.copy("modules/components/LatchedLoader.qml", "qs/modules/components", siblings=False)
h.module("qs.modules.components", {})
shell = (REPO / "shell.qml").read_text()


def loader_bindings(loader_id: str) -> str:
    m = re.search(r"LatchedLoader \{\n\s*id: " + loader_id + r"\n((?:\s*(?:allowed|wanted): [^\n]+\n)+)", shell)
    assert m, f"{loader_id}: not a LatchedLoader with allowed/wanted in shell.qml"
    return m.group(1)


sel = re.search(r"\n    LatchedLoader \{\n        (wanted: Ai\.selection[^\n]+)\n        sourceComponent: SelectionMenuWindow", shell)
assert sel, "selection LatchedLoader not found in shell.qml"

root = h.load("""import QtQuick
import QtQuick.Window
import qs.modules.services
import qs.modules.components
import qs.modules.widgets.overview
import qs.modules.widgets.presets
Window {
    id: top
    width: 800; height: 600; visible: true
    QtObject { id: aiStub; property QtObject selection: QtObject { property bool visible: false } }
    property alias ai: aiStub
    LatchedLoader {
        id: overviewLoader
        objectName: "overview"
        property var modelData: ({name: "A"})
        anchors.fill: parent
%(OV)s        sourceComponent: OverviewPopup { screen: overviewLoader.modelData }
    }
    LatchedLoader {
        id: presetsLoader
        objectName: "presets"
        property var modelData: ({name: "A"})
        anchors.fill: parent
%(PR)s        sourceComponent: PresetsPopup { screen: presetsLoader.modelData }
    }
    // The selection menu window: just its latch-facing surface.
    LatchedLoader {
        id: selLoader
        objectName: "selection"
        %(SEL)s
        sourceComponent: Item {
            readonly property bool mapped: latch.shown
            SurfaceLatch { id: latch; active: aiStub.selection.visible }
        }
    }
}""".replace("%(OV)s", loader_bindings("overviewLoader"))
    .replace("%(PR)s", loader_bindings("presetsLoader"))
    .replace("%(SEL)s", sel.group(1).replace("Ai.selection", "aiStub.selection")), auto_stub=False)
root.requestActivate()


def pump(ms):
    t = QElapsedTimer()
    t.start()
    while t.elapsed() < ms:
        h.app.processEvents()


def ev(obj, expr):
    return h.eval(obj, expr)


for name, flag in (("overview", "overview"), ("presets", "presets")):
    loader = h.find(root, name)
    assert ev(loader, "item") is None, f"{name}: loaded while closed"
    ev(root, f'Visibilities.getForScreen("A").{flag} = true')
    win = ev(loader, "item")
    assert win is not None, f"{name}: not loaded when opened"
    assert ev(win, "visible") is True and ev(win, "mapped") is True and ev(win, "keyboardFocus") == 2
    pump(30)
    field = h.find(win, "field")
    ev(field, "forceActiveFocus()")
    pump(10)
    assert ev(field, "activeFocus") is True, f"{name}: the field never took focus"

    # Close: focus leaves the field and keyboard focus drops in this tick,
    # while the window stays mapped and loaded.
    ev(root, f'Visibilities.getForScreen("A").{flag} = false')
    assert ev(field, "activeFocus") is False, f"{name}: the field kept input focus past the close"
    assert ev(win, "keyboardFocus") == 0, f"{name}: keyboard focus kept after closing"
    assert ev(loader, "item") == win, f"{name}: destroyed in the focus-drop tick"
    assert ev(win, "visible") is True, f"{name}: unmapped in the focus-drop tick"
    pump(5)
    assert ev(loader, "item") == win, f"{name}: destroyed before a frame passed"

    # Reopened before the unmap: the same window, keyboard back.
    ev(root, f'Visibilities.getForScreen("A").{flag} = true')
    assert ev(loader, "item") == win and ev(win, "keyboardFocus") == 2
    ev(root, f'Visibilities.getForScreen("A").{flag} = false')
    pump(80)
    assert ev(loader, "item") is None, f"{name}: never released after closing"

# A window clicked in the overview: asked for with the click, and again only
# once the popup has unmapped (never while it is still on screen).
ov = h.find(root, "overview")
ev(root, 'Visibilities.currentActiveModule = "overview"; Visibilities.getForScreen("A").overview = true')
win = ev(ov, "item")
pump(30)
ev(root, "YozdService.log = []")
ev(win, 'OverviewActivation.activate("0xa")')
FOCUS = "focuswindow address:0xa"
assert ev(root, "YozdService.log.join('|')") == FOCUS, "the click is not sent at once"
assert ev(win, "keyboardFocus") == 0 and ev(win, "visible") is True, "the overview did not start closing"
while ev(ov, "item") is not None and ev(win, "visible") is True:
    assert ev(root, "YozdService.log.join('|')") == FOCUS, "focus asked for again while the overview is mapped"
    pump(1)
pump(30)
assert ev(ov, "item") is None, "the overview never unmapped"
assert ev(root, "YozdService.log.join('|')") == FOCUS + "|" + FOCUS, \
    "focus not asked for again after the unmap: " + ev(root, "YozdService.log.join('|')")

# Suspend while open: unloaded at once, nothing held over to the resume.
ov = h.find(root, "overview")
ev(root, 'Visibilities.getForScreen("A").overview = true')
assert ev(ov, "item") is not None
pump(20)
ev(root, "SuspendManager.wakeReady = false")
assert ev(ov, "item") is None, "kept loaded while suspended"
ev(root, 'Visibilities.getForScreen("A").overview = false')
ev(root, "SuspendManager.wakeReady = true")
assert ev(ov, "item") is None, "resume reloaded a closed popup"

# Selection menu: the same Loader wiring.
sl = h.find(root, "selection")
ev(root, "ai.selection.visible = true")
w = ev(sl, "item")
assert w is not None and ev(w, "mapped") is True
ev(root, "ai.selection.visible = false")
assert ev(sl, "item") == w, "selection menu destroyed in the focus-drop tick"
pump(80)
assert ev(sl, "item") is None, "selection menu never released"

print("popup-latch: ok")
h.exit(0)
