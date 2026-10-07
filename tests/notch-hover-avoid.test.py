"""Notch hover and bar avoidance offscreen:
- NotchHoverHold: on at once, held for the collapse delay after leaving;
- a HoverHandler on the notch container stays hovered while the pointer is
  on a child MouseArea / button (real pointer moves);
- DefaultView: the pointer anywhere on the notch holds an open panel; a
  collapsing style answers a notification with a peek (card only);
- NotchAvoidance (real EdgeLayout): a grown notch over a dock-like bar on
  its edge drops past it, fits between strip groups, never moves on a side
  edge or with the bar elsewhere, and flags its way back (`returning`)."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import REPO  # noqa: E402
from lib import island_stubs  # noqa: E402
from PySide6.QtCore import QPoint  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

h = island_stubs.island("notch-hover-avoid")
h.module("qs.modules.theme", {
    "Metrics": "pragma Singleton\nQtObject { property int spacing: 8 }",
    "Motion": "pragma Singleton\nQtObject { property var morph: ({ duration: 100, easing: Easing.OutCubic, overshoot: 1 }); property var enter: morph; property var exit: morph }",
})
notch_dir = REPO / "modules/notch"
nd = h.module("qs.modules.notch", {n: (notch_dir / f"{n}.qml").read_text() for n in ["NotchHoverHold", "NotchAvoidance"]})
(nd / "NotchAvoid.js").write_text((notch_dir / "NotchAvoid.js").read_text())
sd = h.module("qs.modules.shell", {"EdgeService": """pragma Singleton
import QtQuick
import "EdgeLayout.js" as EdgeLayout
QtObject {
    property string barPos: "top"
    property bool barOn: true
    function notchRect(screen, size) {
        return EdgeLayout.notchRect({ screen: { w: screen.width, h: screen.height }, frame: 0,
            bar: { pos: barPos, size: 40, visible: barOn }, dock: { visible: false },
            notch: { pos: "top", height: 44, align: "center", visible: true } }, size);
    }
}"""})
(sd / "EdgeLayout.js").write_text((REPO / "modules/shell/EdgeLayout.js").read_text())

# ── hold ──
hold = h.load("import QtQuick\nimport qs.modules.notch\nNotchHoverHold { delay: 60 }")
hold.setProperty("over", True)
assert h.eval(hold, "held"), "on as soon as the pointer arrives"
hold.setProperty("over", False)
QTest.qWait(20)
assert h.eval(hold, "held"), "kept while crossing a gap"
hold.setProperty("over", True)
hold.setProperty("over", False)
QTest.qWait(40)
assert h.eval(hold, "held"), "coming back restarts the delay"
QTest.qWait(60)
assert not h.eval(hold, "held"), "released after the delay"

# ── container hover survives child controls ──
win = h.load("""
import QtQuick
import QtQuick.Window
Window {
    width: 300; height: 200; visible: true
    Item {
        objectName: "box"
        x: 50; y: 50; width: 200; height: 100
        HoverHandler { id: hh }
        readonly property bool hovered: hh.hovered
        MouseArea { x: 20; y: 20; width: 40; height: 40; hoverEnabled: true }
        Rectangle { x: 100; y: 20; width: 40; height: 40; TapHandler {} HoverHandler {} }
    }
}""")
box = h.find(win, "box")
QTest.qWaitForWindowExposed(win)
for p, want in [((10, 10), False), ((60, 60), True), ((90, 90), True), ((170, 90), True), ((120, 120), True), ((290, 190), False)]:
    QTest.mouseMove(win, QPoint(*p))
    QTest.qWait(20)
    assert h.eval(box, "hovered") == want, f"container hover at {p}"
win.close()

# ── DefaultView: notch-wide hold, notification peek ──
QTest.qWait(1)
h.load("import QtQuick\nimport QtQuick.Controls\nItem { ScrollIndicator {} }")
view = h.load(h.root / "app/DefaultView.qml")
h.eval(view, "ActivityService.transfers = [({ id: 'b:1', source: 'browserDownloads', title: 'a.iso', processed: 1, total: 2, rate: 1, state: 'running', units: 'bytes', actions: [] })]")
h.eval(view, "ActivityService.activities = [({ id: 'downloads', source: 'downloads', category: 'task', priority: 40, indicator: 'ring', label: '47%', icon: '', image: '', detail: '', progress: 0.5, color: 'primary' })]")
h.eval(view, "header.tasksSegment.hoverOverride = true")
QTest.qWait(60)
assert h.eval(view, "controller.openPanel") == "transfers"
# The pointer leaves the segment for the bell / avatar: still on the notch
h.eval(view, "parentHoverActive = true; header.tasksSegment.hoverOverride = false")
QTest.qWait(80)
assert h.eval(view, "controller.openPanel") == "transfers", "the pointer on the notch holds the panel"
h.eval(view, "parentHoverActive = false")
QTest.qWait(80)
assert h.eval(view, "controller.openPanel") == "", "leaving the notch closes it"

h.eval(view, "ActivityService.activities = []; ActivityService.transfers = []")
h.eval(view, "collapsingStyle = true")
h.eval(h.find(view, "islandNotifications"), "implicitHeight = 90")
h.eval(view, "Notifications.notchPopupList = [({ id: 1 })]")
QTest.qWait(10)
assert h.eval(view, "peek"), "a notification on a pill peeks"
assert h.eval(view, "implicitWidth") == h.eval(view, "notificationWidth"), "the peek is as wide as the card"
assert h.eval(view, "implicitHeight") == h.eval(view, "notificationSlot.height"), "and holds the card only"
assert not h.eval(view, "header.visible")
h.eval(view, "parentHoverActive = true")
QTest.qWait(10)
assert not h.eval(view, "peek") and h.eval(view, "header.visible"), "the pointer brings the header back"
assert h.eval(view, "implicitHeight") > h.eval(view, "header.implicitHeight")
h.eval(view, "parentHoverActive = false; collapsingStyle = false")
QTest.qWait(10)
assert not h.eval(view, "peek"), "other styles keep the full notch"
h.eval(view, "Notifications.notchPopupList = []")

# ── avoidance ──
av = h.load("""
import QtQuick
import qs.modules.notch
import qs.config
Item {
    width: 1920; height: 1080
    // dock-like bar: one run in the middle of the top edge
    property string dockPos: "top"
    QtObject { id: dock; property string barPosition: dockPos; property bool reveal: true; property real spanStart: 560; property real spanLength: 800
        property bool aligned: true; property int frameOffset: 0; property int sideMargin: 0; property int edgeDepth: 48
        property var styleItem: ({ startReach: 0, endReach: 0 }); property var centerIds: [] }
    // strip bar: start and end groups, middle free
    QtObject { id: strip; property string barPosition: "top"; property bool reveal: true; property real spanStart: 0; property real spanLength: 1920
        property bool aligned: false; property int frameOffset: 0; property int sideMargin: 0; property int edgeDepth: 40
        property var styleItem: ({ startReach: 500, endReach: 400 }); property var centerIds: [] }
    property bool useStrip: false
    NotchAvoidance {
        objectName: "av"
        screen: ({ width: 1920, height: 1080 })
        bar: parent.useStrip ? strip : dock
        targetAlong: 440; restAlong: 32; restAcross: 12; edgeGap: 4; gap: 4
    }
}""")
a = h.find(av, "av")
assert h.eval(a, "result.mode") == "edge" and h.eval(a, "offsetY") == 0, "the resting notch stays on the edge"
a.setProperty("grown", True)
assert h.eval(a, "result.mode") == "drop" and h.eval(a, "offsetY") == 48, "a grown notch drops past a dock-like bar (48 + 4 - 4)"
assert h.eval(a, "stem.y") == 0 and h.eval(a, "stem.h") == 52 and h.eval(a, "stem.w") == 32, "the stem bridges edge and notch, resting width"
a.setProperty("grown", False)
assert h.eval(a, "offsetY") == 0
h.eval(av, "useStrip = true")
a.setProperty("grown", True)
assert h.eval(a, "result.mode") == "edge", "it fits between the strip's groups"
a.setProperty("targetAlong", 1100)
assert h.eval(a, "result.mode") == "drop", "too long for the gap: drops"
h.eval(av, "useStrip = false")
a.setProperty("targetAlong", 440)
for pos in ["left", "right"]:
    a.setProperty("position", pos)
    assert h.eval(a, "result.mode") == "edge", f"a {pos} notch is laid out beside its bar already"
a.setProperty("position", "top")
h.eval(av, "dockPos = 'bottom'")
assert h.eval(a, "result.mode") == "edge", "a bar on another edge is never in the way"
h.eval(av, "dockPos = 'top'")
h.eval(av, "Config.animDuration = 100")
assert h.eval(a, "moved")
a.setProperty("grown", False)
assert h.eval(a, "returning"), "sliding back is flagged (hover from a still pointer does not re-open)"
QTest.qWait(250)
assert not h.eval(a, "returning")
print("notch hover/avoid: hold, container hover, notch-wide hold, peek, avoidance passed")
