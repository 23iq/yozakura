"""Unified preset gallery (modules/widgets/presets + store): the Layout /
Style / Palette tabs preview and apply one part (`apply --part`), the
"Current: layout · style · palette" row saves a set, user set cards rename
and delete (official ones do not), and the one-time "Try the new look" card
previews the new default with a Keep / Revert countdown; any answer marks
general.newLookOffered through `<app> config set`."""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402
from lib import kit_stubs  # noqa: E402
from PySide6.QtCore import QCoreApplication, QElapsedTimer, QEvent, QPoint, Qt  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

PARTS = {
    "layouts": [{"kind": "layout", "name": "Classic", "official": True}, {"kind": "layout", "name": "Tatami", "official": True}],
    "styles": [{"kind": "style", "name": "Yoru", "official": True}, {"kind": "style", "name": "Kaze", "official": True}],
    "palettes": [{"kind": "palette", "name": "Violet Night", "official": True}],
    "current": {"layout": "Classic", "style": "Yoru", "palette": ""},
}

h = Harness("presets-unified")
h.singleton("qs.config", "Config", "QtObject { property int animDuration: 0; property string defaultFont: 'sans'; "
            "property var general: ({ onboardingDone: true, newLookOffered: false }) }")
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
    "Styling": "pragma Singleton\nQtObject { function fontSize(o) { return 14 + o; } function radius(o) { return 16 + o; } }",
})
h.module("qs.modules.services", {
    "I18n": "pragma Singleton\nQtObject { function t(k, a) { return a === undefined ? k : k + ':' + a; } }",
    "PresetsService": "pragma Singleton\nQtObject { property string activePreset: '' }",
})
h.module("qs.modules.globals", {})
h.module("Quickshell", {"Singleton": "QtObject { default property list<QtObject> data }"})
h.module("Quickshell.Io", {"Process": "QtObject { property var command; property bool running; signal exited(int code) }"})
h.module("qs.modules.settings.presets", {"PresetThumb": "Item { property var look }"})
h.singleton("qs.modules.settings.store", "PresetStudio", """QtObject {
    property var calls: []
    property bool loaded: true
    property string active: "Glacier"
    property var parts: %s
    property var presets: [
        { name: "Neon Tokyo", official: true, active: false, tags: [] },
        { name: "Glacier", official: true, active: true, tags: [] },
        { name: "Mine", official: false, active: false, tags: [] }
    ]
    function run(args, cb) {
        calls = calls.concat([JSON.stringify(args)]);
        const out = args[0] === "parts" ? JSON.stringify(parts) : "";
        if (cb) Qt.callLater(() => cb(true, out, ""));
    }
    function refresh() {}
    function afterFlush(fn) { fn(); }
    function cleanError(e) { return e; }
}""" % json.dumps(PARTS))
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
for f in ("PresetParts", "PresetNewLook"):
    h.copy(f"modules/widgets/presets/store/{f}.qml", "qs/modules/widgets/presets/store")
h.module("qs.modules.widgets.presets.store", {})
h.copy("modules/widgets/presets/PresetsGallery.qml", "qs/modules/widgets/presets")
h.module("qs.modules.widgets.presets", {})

root = h.load("""import QtQuick
import QtQuick.Window
import qs.modules.widgets.presets
import qs.modules.widgets.presets.store
import qs.modules.settings.store
Window {
    width: 1200; height: 1000; visible: true
    property var execs: []
    property Component galleryComponent: Component {
        PresetsGallery { anchors.fill: parent; dwell: 30 }
    }
    property var gallery: null
    function openGallery() { gallery = galleryComponent.createObject(contentItem); gallery.forceActiveFocus(); }
    function closeGallery() { gallery.destroy(); gallery = null; }
    // The visual item `n` (Repeater delegates are not QObject children).
    function named(n, it) {
        it = it || contentItem;
        if (it.objectName === n) return it;
        for (let i = 0; i < it.children.length; i++) {
            const r = named(n, it.children[i]);
            if (r) return r;
        }
        return null;
    }
    Component.onCompleted: {
        PresetNewLook.seconds = 1;
        PresetNewLook.exec = (argv, cb) => { execs = execs.concat([JSON.stringify(argv)]); };
    }
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


def execs():
    return [json.loads(c) for c in json.loads(h.eval(root, "JSON.stringify(execs)"))]


def reset():
    h.eval(root, "PresetStudio.calls = []")


def gal(expr):
    return h.eval(root, "gallery." + expr)


def click(name):
    assert h.eval(root, f"named('{name}') !== null"), name
    h.eval(root, f"named('{name}').clicked()")
    pump(30)


QTest.mouseMove(root, QPoint(1190, 990))  # keep the pointer off the cards
h.eval(root, "openGallery()")
pump(100)
assert ["parts", "--json"] in calls(), calls()
assert h.eval(h.find(root, "currentLookText"), "text") == "Classic · Yoru · presets.current.custom"

# Style tab: only style parts, starting on the current one; hover previews
# the part, Enter applies just that part
reset()
click("galleryTab:style")
assert gal("tab") == "style"
assert [c["title"] for c in json.loads(h.eval(root, "JSON.stringify(gallery.cards)"))] == ["Yoru", "Kaze"]
assert gal("currentIndex") == 0
QTest.keyClick(root, Qt.Key_Right)
pump(120)
assert calls() == [["apply", "--part", "style", "--preview", "Kaze"]], calls()
QTest.keyClick(root, Qt.Key_Return)
pump(50)
assert calls()[-1] == ["apply", "--part", "style", "Kaze"], calls()
h.eval(root, "closeGallery()")
pump(50)

# Save as: a taken name is refused, a free one runs `preset save`
h.eval(root, "openGallery()")
pump(50)
reset()
click("saveAsSet")
assert h.eval(h.find(root, "galleryPrompt"), "mode") == "save"
assert h.eval(h.find(root, "promptName"), "text") == "prefs.presets.my_look"
h.eval(h.find(root, "promptName"), "text = 'mine'")
assert h.eval(h.find(root, "promptConfirm"), "enabled") is False
h.eval(h.find(root, "galleryPrompt"), "submit()")
assert calls() == [], calls()
h.eval(h.find(root, "promptName"), "text = 'Evening'")
click("promptConfirm")
pump(30)
assert ["save", "Evening"] in calls(), calls()
assert h.eval(h.find(root, "galleryPrompt"), "open") is False

# Rename (F2) and delete a user set; official sets cannot be managed
reset()
h.eval(root, "gallery.select(2)")
QTest.keyClick(root, Qt.Key_F2)
pump(30)
assert h.eval(h.find(root, "galleryPrompt"), "mode") == "rename"
assert h.eval(h.find(root, "promptName"), "text") == "Mine"
h.eval(h.find(root, "promptName"), "text = 'Ours'")
click("promptConfirm")
assert ["rename", "Mine", "Ours"] in calls(), calls()
h.eval(root, "gallery.manage('delete')")
assert h.eval(h.find(root, "galleryPrompt"), "mode") == "delete"
click("promptConfirm")
assert ["delete", "Mine"] in calls(), calls()
h.eval(root, "gallery.select(1); gallery.manage('delete')")
assert h.eval(h.find(root, "galleryPrompt"), "open") is False, "official sets are read-only"
h.eval(root, "closeGallery()")
pump(50)

# Try the new look: preview, countdown, revert on timeout, marked offered
h.eval(root, "openGallery()")
pump(50)
reset()
assert h.eval(h.find(root, "tryNewLook"), "visible") is True
click("newLookTry")
pump(30)
assert calls() == [["apply", "--preview", "Yozakura"]], calls()
assert h.eval(root, "PresetNewLook.phase") == "trying"
assert h.eval(h.find(root, "newLookText"), "text") == "presets.newlook.countdown:1"
QTest.keyClick(root, Qt.Key_Right)  # no gallery preview while trying
pump(80)
assert calls() == [["apply", "--preview", "Yozakura"]], calls()
pump(1400)
assert calls()[-1] == ["revert"], calls()
assert h.eval(root, "PresetNewLook.phase") == "done"
assert execs() == [["yozakura", "config", "set", "general.newLookOffered", "true"]], execs()
assert h.eval(h.find(root, "tryNewLook"), "visible") is False

# Keep applies it for real
h.eval(root, "PresetNewLook.phase = 'idle'; PresetNewLook.answered = false; execs = []")
reset()
click("newLookTry")
pump(30)
click("newLookKeep")
pump(30)
assert calls() == [["apply", "--preview", "Yozakura"], ["apply", "Yozakura"]], calls()
assert len(execs()) == 1

# Not now: no preset command, still marked
h.eval(root, "PresetNewLook.phase = 'idle'; PresetNewLook.answered = false; execs = []")
reset()
click("newLookNotNow")
assert calls() == [], calls()
assert len(execs()) == 1
assert h.eval(h.find(root, "tryNewLook"), "visible") is False

# Nothing offered to a user already on the new look
h.eval(root, "PresetNewLook.phase = 'idle'; PresetNewLook.answered = false; PresetStudio.active = 'Yozakura'")
assert h.eval(root, "PresetNewLook.offer") is False

print("presets-unified: ok")
h.exit(0)
