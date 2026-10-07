"""Preset switcher gallery (modules/widgets/presets): opening previews
nothing; moving over a card previews it live after a short dwell (only the
last one when moving fast) through `preset apply --preview`; Escape and
closing revert, Enter keeps (a real apply, no revert)."""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402
from lib import kit_stubs  # noqa: E402
from PySide6.QtCore import QCoreApplication, QElapsedTimer, QEvent, QPoint, Qt  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

h = Harness("presets-preview")
h.singleton("qs.config", "Config", "QtObject { property int animDuration: 0; property string defaultFont: 'sans' }")
h.module("qs.modules.theme", {
    "Motion": """pragma Singleton
QtObject {
    property QtObject enter: QtObject { property int duration: 0; property int easing: Easing.OutCubic; property real overshoot: 1 }
    property QtObject exit: QtObject { property int duration: 0; property int easing: Easing.OutCubic; property real overshoot: 1 }
}""",
    "Metrics": "pragma Singleton\nQtObject { property int rowHeight: 48; property int iconSize: 32; property int spacing: 8; property int padding: 16 }",
    "Colors": "pragma Singleton\nQtObject { property color primary: 'red'; property color overBackground: 'white'; property color outline: 'gray' }",
    "Icons": "pragma Singleton\nQtObject { property string font: 'sans'; property string magicWand: 'w'; property string magnifyingGlass: 'm'; "
             "property string pencil: 'p'; property string trash: 't'; property string check: 'c'; property string plus: '+'; "
             "property string sparkle: 's'; property string arrowCounterClockwise: 'r'; property string squaresFour: 'q'; "
             "property string paintBrush: 'b'; property string circleHalf: 'h' }",
    "Styling": "pragma Singleton\nQtObject { function fontSize(o) { return 14 + o; } function radius(o) { return 16 + o; } function srItem(v) { return 'white'; } }",
})
h.module("qs.modules.services", {"I18n": "pragma Singleton\nQtObject { function t(k) { return k; } }"})
h.module("qs.modules.settings.presets", {"PresetThumb": "Item { property var look }"})
h.singleton("qs.modules.settings.store", "PresetStudio", """QtObject {
    property var calls: []
    property int refreshes: 0
    property var presets: [
        { name: "Neon Tokyo", official: true, active: false, tags: [] },
        { name: "Glacier", official: true, active: true, tags: [] },
        { name: "Mine", official: false, active: false, tags: [] }
    ]
    function run(args, cb) {
        calls = calls.concat([JSON.stringify(args)]);
        if (cb) Qt.callLater(() => cb(true, "", ""));
    }
    function refresh() { refreshes++; }
}""")
h.module("qs.modules.components", {
    "StyledRect": "Item { property string variant; property real radius; property bool enableShadow }",
    "SearchInput": """FocusScope {
    property string text; property string placeholderText; property string iconText
    property bool clearOnEscape
    signal accepted; signal escapePressed; signal leftPressed; signal rightPressed; signal upPressed; signal downPressed
    function focusInput() { forceActiveFocus(); }
}""",
})
kit_stubs.install(h)
h.module("qs.modules.components.kit", {
    "SearchField": "FocusScope { property string text; property string glyph; property bool clearOnEscape; "
                   "signal accepted; signal escapePressed; function focusInput() { forceActiveFocus(); } }",
})
h.module("qs.modules.widgets.presets.store", {
    "PresetParts": "pragma Singleton\nQtObject { property var parts: ({ current: {} }); function refresh() {} "
                   "function save(n) {} function rename(a, b) {} function remove(n) {} }",
    "PresetNewLook": "pragma Singleton\nQtObject { property bool offer: false; property bool trying: false; "
                     "property string phase: 'idle'; property int left: 0; property real fraction: 0 }",
})
for f in ("PresetsGallery", "PresetGalleryCard", "PresetPreviewer"):
    h.copy(f"modules/widgets/presets/{f}.qml", "qs/modules/widgets/presets")
h.module("qs.modules.widgets.presets", {})

root = h.load("""import QtQuick
import QtQuick.Window
import qs.modules.widgets.presets
import qs.modules.settings.store
Window {
    width: 1200; height: 800; visible: true
    property int closes: 0
    property Component galleryComponent: Component {
        PresetsGallery { anchors.fill: parent; dwell: 60; onCloseRequested: parent.Window.window.closes++ }
    }
    property var gallery: null
    function openGallery() { gallery = galleryComponent.createObject(contentItem); gallery.forceActiveFocus(); }
    function closeGallery() { gallery.destroy(); gallery = null; }
}""", auto_stub=False)
root.requestActivate()


def pump(ms):
    t = QElapsedTimer()
    t.start()
    while t.elapsed() < ms:
        h.app.processEvents()
        QCoreApplication.sendPostedEvents(None, QEvent.DeferredDelete)


def calls():
    return [json.loads(c) for c in json.loads(h.eval(root, "JSON.stringify(PresetStudio.calls)"))]


def gal(expr):
    return h.eval(root, "gallery." + expr)


QTest.mouseMove(root, QPoint(1190, 790))  # keep the pointer off the cards
h.eval(root, "openGallery()")
pump(150)
assert gal("currentIndex") == 1, "starts on the active preset"
assert calls() == [], "opening must not preview"

QTest.keyClick(root, Qt.Key_Right)
pump(150)
assert calls() == [["apply", "--preview", "Mine"]], calls()

# moving fast previews only where the selection stops
QTest.keyClick(root, Qt.Key_Left)
QTest.keyClick(root, Qt.Key_Left)
pump(150)
assert calls()[1:] == [["apply", "--preview", "Neon Tokyo"]], calls()

# Escape reverts and closes
QTest.keyClick(root, Qt.Key_Escape)
pump(50)
assert calls()[-1] == ["revert"], calls()
assert root.property("closes") == 1
h.eval(root, "closeGallery()")
pump(50)
assert calls()[-1] == ["revert"] and len(calls()) == 3, "no second revert on close"

# Enter keeps: a real apply, no revert when the popup goes away
h.eval(root, "PresetStudio.calls = []; openGallery()")
pump(50)
QTest.keyClick(root, Qt.Key_Right)
pump(150)
QTest.keyClick(root, Qt.Key_Return)
pump(50)
assert calls() == [["apply", "--preview", "Mine"], ["apply", "Mine"]], calls()
assert root.property("closes") == 2
h.eval(root, "closeGallery()")
pump(50)
assert ["revert"] not in calls(), calls()

# closing any other way (click outside, focus loss) reverts a preview
h.eval(root, "PresetStudio.calls = []; openGallery()")
pump(50)
QTest.keyClick(root, Qt.Key_Left)
pump(150)
h.eval(root, "closeGallery()")
pump(50)
assert calls() == [["apply", "--preview", "Neon Tokyo"], ["revert"]], calls()

# closing during the dwell, before any preview ran: nothing to revert
h.eval(root, "PresetStudio.calls = []; openGallery()")
pump(50)
QTest.keyClick(root, Qt.Key_Left)
h.eval(root, "closeGallery()")
pump(150)
assert calls() == [], calls()

print("presets-preview: ok")
h.exit(0)
