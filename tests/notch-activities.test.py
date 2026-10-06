"""Live activities inside the notch (modules/widgets/defaultview/activities)
offscreen: segment content and badges, fixed widths while labels tick,
hover expansion availability with/without media, transfer row text."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import REPO, Harness  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

h = Harness("notch-activities")
h.singleton("qs.config", "Config", """QtObject {
    property int animDuration: 0
    property int roundness: 12
    property bool showBackground: true
    property string notchTheme: "default"
    property string notchPosition: "top"
    property var theme: ({ font: "Sans", fontSize: 14 })
    property var notch: ({ disableHoverExpansion: false, hoverExpandDelay: 20, hoverCollapseDelay: 20, expandedMediaWidth: 440, expandedArtworkSize: 64, mediaAnimationDuration: 0, customText: "Yozakura", visualizer: false })
}""")
h.module("qs.modules.theme", {
    "Styling": "pragma Singleton\nQtObject { property string defaultFont: \"Sans\"; function fontSize(o) { return 14 + o } function radius(o) { return 12 + o } function srItem(v) { return \"white\" } }",
    "Colors": "pragma Singleton\nQtObject { property color overBackground: \"white\"; property color overSurfaceVariant: \"silver\"; property color primary: \"pink\"; property color red: \"red\"; property color error: \"red\"; property color green: \"green\"; property color yellow: \"yellow\"; property color criticalRed: \"red\" }",
    "Icons": "pragma Singleton\nQtObject { property string font: \"Sans\"; property string accept: \"v\"; property string copy: \"c\"; property string sync: \"s\"; property string downloadSimple: \"d\"; property string folder: \"f\"; property string cancel: \"x\"; property string stop: \"S\"; property string pause: \"p\"; property string play: \"P\"; property string micSlash: \"m\"; property string player: \"P\"; property string spotify: \"S\"; property string mic: \"M\"; property string timer: \"T\"; property string recordScreen: \"R\" }",
    "BarMetrics": "pragma Singleton\nQtObject { property int notchRestHeight: 44; property int notchIslandHeight: 36 }",
})
h.module("qs.modules.components", {
    "StyledRect": "Rectangle { property string variant; property bool enableBorder; property bool enableShadow; property bool animateRadius; property color item: \"white\" }",
    "StyledToolTip": "Item { property string tooltipText; property bool show }",
    "Separator": "Item { property bool vert; implicitWidth: 2; implicitHeight: 2 }",
})
h.module("Quickshell.Widgets", {"IconImage": "Image { property real implicitSize }"})
h.module("qs.modules.services", {
    "I18n": "pragma Singleton\nQtObject { function t(k) { return ({ \"activities.left\": \"left\", \"activities.failed\": \"Failed\", \"activities.paused\": \"Paused\" })[k] || k } }",
    "MicrophoneStatus": "pragma Singleton\nQtObject { property bool muted: false; property bool available: true }",
    "MprisController": "pragma Singleton\nQtObject { property var activePlayer: null }",
    "Notifications": "pragma Singleton\nQtObject { property var popupList: [] }",
    "Visibilities": "pragma Singleton\nQtObject { property bool playerMenuOpen: false }",
    "VoiceService": "pragma Singleton\nQtObject { property bool panelOpen: false; property string panelScreen: \"\"; property string state: \"listening\"; property string target: \"ai\"; property var bands: []; property int dismissals: 0; function dismiss() { dismissals++; panelOpen = false; } }",
})
h.singleton("qs.modules.services.activities", "ActivityService", """QtObject {
    property string presentation: "notch"
    property var activities: []
    readonly property var tasks: activities.filter(a => a.category === "task")
    readonly property var privacy: activities.filter(a => a.category === "privacy")
    property var transfers: []
    readonly property int count: activities.length
    property bool showSpeed: true
    property var lastActivated: null
    function activate(a, b, s) { lastActivated = a; }
    function transferAction(t, a) {}
    function iconUrl(n) { return ""; }
}""")
(h.root / "qs/modules/services/activities/TransferModel.js").write_text((REPO / "modules/services/activities/TransferModel.js").read_text())
h.module("qs.modules.bar.activities", {n: (REPO / f"modules/bar/activities/{n}.qml").read_text() for n in ["ActivityIndicator", "ActivityRing"]})
acts_dir = REPO / "modules/widgets/defaultview/activities"
d = h.module("qs.modules.widgets.defaultview.activities", {f.stem: f.read_text() for f in sorted(acts_dir.glob("*.qml"))})
(d / "NotchActivities.js").write_text((acts_dir / "NotchActivities.js").read_text())
# DefaultView and its children (heavy media widgets stubbed)
for n in ["DefaultView", "IslandHeader"]:
    h.copy(f"modules/widgets/defaultview/{n}.qml", siblings=False)
h.copy("modules/widgets/defaultview/IslandMedia.js", siblings=False)
panels_src = REPO / "modules/widgets/defaultview/panels"
pd = h.module("qs.modules.widgets.defaultview.panels", {f.stem: f.read_text() for f in sorted(panels_src.glob("*.qml")) if f.stem != "MediaPanel"})
(pd / "NotchPanels.js").write_text((panels_src / "NotchPanels.js").read_text())
(h.root / "qs/modules/services/voice").mkdir(parents=True, exist_ok=True)
(h.root / "qs/modules/services/voice/VoiceModel.js").write_text((REPO / "modules/services/voice/VoiceModel.js").read_text())
(pd / "MediaPanel.qml").write_text("import QtQuick\nNotchPanel { implicitHeight: 120 }\n")
h._write_qmldir(pd, "qs.modules.widgets.defaultview.panels")
for n, body in {
    "UserInfo": "Item { implicitWidth: 24; implicitHeight: 24 }",
    "NotificationIndicator": "Item { implicitWidth: 24; implicitHeight: 24 }",
    "MediaSummary": "Item { property var player; property bool mediaExpanded; property bool revealed; property bool selectorOpen: false; property bool selectorHovered: false }",
    "CompactPlayer": "Item { property var player; property bool notchHovered }",
    "ExpandedMedia": "Item { property var player; property bool revealed; implicitHeight: 120 }",
    "IslandNotifications": "Item { property bool hovered; property bool navigating: false }",
}.items():
    h.stub(n, body)


def act(id_, category, indicator="glyph", label="", priority=50, source="x"):
    return f"({{ id: '{id_}', source: '{source}', category: '{category}', priority: {priority}, indicator: '{indicator}', label: '{label}', icon: '', image: '', detail: '{id_} detail', progress: 0.5, color: 'primary' }})"


# ── segments ──
root = h.load("""
import QtQuick
import qs.modules.services.activities
import qs.modules.widgets.defaultview.activities
Item {
    width: 600; height: 60
    NotchActivitySegment { objectName: "lead"; side: "leading"; items: ActivityService.tasks }
    NotchActivitySegment { objectName: "trail"; side: "trailing"; items: ActivityService.privacy }
    function set(list) { ActivityService.activities = list; }
}
""")
lead = h.find(root, "lead")
trail = h.find(root, "trail")
assert not h.eval(lead, "shown") and h.eval(lead, "targetWidth") == 0, "no activities: segments take no room"

h.eval(root, f"set([{act('timer:0', 'task', 'ring', '18:42')}, {act('downloads', 'task', 'ring', '47%', 40)}])")
QTest.qWait(10)
assert h.eval(lead, "item.id") == "timer:0"
assert h.eval(lead, "content.badge") == 1, "second task becomes a badge"
w = h.eval(lead, "targetWidth")
for label in ["18:41", "09:59", "00:00"]:
    h.eval(root, f"set([{act('timer:0', 'task', 'ring', label)}, {act('downloads', 'task', 'ring', '47%', 40)}])")
    QTest.qWait(5)
    assert h.eval(lead, "targetWidth") == w, f"timer tick {label} must not change the width"

h.eval(root, f"set([{act('downloads', 'task', 'ring', '5%')}])")
QTest.qWait(5)
w5 = h.eval(lead, "targetWidth")
h.eval(root, f"set([{act('downloads', 'task', 'ring', '100%')}])")
QTest.qWait(5)
assert h.eval(lead, "targetWidth") == w5, "5% and 100% reserve the same width"
assert h.eval(lead, "content.badge") == 0

privacy = [act("recording", "privacy", "dot", "02:13", 100, "recording"), act("privacy:screen", "privacy", priority=90), act("privacy:camera", "privacy", priority=80), act("privacy:mic", "privacy", priority=70)]
h.eval(root, "set([" + ",".join(privacy) + "])")
QTest.qWait(5)
assert h.eval(trail, "item.id") == "recording"
assert h.eval(trail, "content.extras.length") == 2, "two more privacy kinds shown as glyphs"
assert h.eval(trail, "content.badge") == 1
h.eval(trail, "activated(item, Qt.LeftButton)")

# ── panels: one per segment ──
# Panels are loaded by URL; a synchronous Loader that is the first to need
# QtQuick.Controls blocks the offscreen type loader (the shell has it loaded
# long before), so load it up front.
controls = h.load("import QtQuick\nimport QtQuick.Controls\nItem { ScrollIndicator {} }")
view = h.load(h.root / "app/DefaultView.qml")
h.eval(view, "ActivityService.activities = []")
QTest.qWait(5)
assert not any(h.eval(view, f"panelAvailability.{k}") for k in ["media", "transfers", "timers", "privacy"]), "nothing to open"
h.eval(view, "ActivityService.transfers = [({ id: 'b:1', source: 'browserDownloads', title: 'a.iso', processed: 1, total: 2, rate: 1, state: 'running', units: 'bytes', actions: [] })]")
h.eval(view, f"ActivityService.activities = [{act('downloads', 'task', 'ring', '47%', 40, 'downloads')}, {act('timer:0', 'task', 'ring', '18:42', 50, 'timers')}, {act('privacy:mic', 'privacy')}]")
QTest.qWait(5)
assert h.eval(view, "panelAvailability.transfers") and h.eval(view, "panelAvailability.timers") and h.eval(view, "panelAvailability.privacy")
assert not h.eval(view, "panelAvailability.media")
assert h.eval(view, "header.timersSegment.shown") and h.eval(view, "header.tasksSegment.shown"), "timers and downloads get their own segment"
assert h.eval(view, "header.activitiesWidth") > 0, "the header grows by the segment widths"

h.eval(view, "header.tasksSegment.hoverOverride = true")
QTest.qWait(60)
assert h.eval(view, "controller.openPanel") == "transfers", "downloads segment opens the transfers panel"
h0 = h.eval(view, "implicitHeight")
assert h0 > h.eval(view, "header.implicitHeight"), "the notch grows by the panel"
assert h.eval(view, "implicitWidth") >= 440
h.eval(view, "header.tasksSegment.hoverOverride = false; header.trailingSegment.hoverOverride = true")
QTest.qWait(60)
assert h.eval(view, "controller.openPanel") == "privacy", "moving to the privacy segment switches panels"
# Opening widens the notch and moves the segment off the pointer: its side
# of the header keeps the panel (no open/close loop), the other side does not
h.eval(view, "header.trailingZoneOverride = true; header.trailingSegment.hoverOverride = false")
QTest.qWait(80)
assert h.eval(view, "controller.openPanel") == "privacy", "the trailing side holds the privacy panel"
h.eval(view, "header.trailingZoneOverride = false; header.leadingZoneOverride = true")
QTest.qWait(80)
assert h.eval(view, "controller.openPanel") == "", "the other side does not hold it"
h.eval(view, "header.leadingZoneOverride = false; header.trailingSegment.hoverOverride = true")
QTest.qWait(60)
assert h.eval(view, "controller.openPanel") == "privacy"
h.eval(view, "header.trailingSegment.hoverOverride = false")
QTest.qWait(80)
assert h.eval(view, "controller.openPanel") == "", "leaving closes"

# click mode: clicks toggle panels instead of activating
h.eval(view, "Config.notch = Object.assign({}, Config.notch, { expandOn: 'click' })")
QTest.qWait(5)
h.eval(view, "onSegment('timers', ActivityService.tasks[0], Qt.LeftButton)")
assert h.eval(view, "controller.openPanel") == "timers"
h.eval(view, "onSegment('timers', ActivityService.tasks[0], Qt.LeftButton)")
assert h.eval(view, "controller.openPanel") == ""
h.eval(view, "Config.notch = Object.assign({}, Config.notch, { expandOn: 'hover' })")
h.eval(view, "onSegment('timers', ActivityService.tasks[0], Qt.LeftButton)")
assert h.eval(view, "controller.openPanel") == "" and h.eval(view, "ActivityService.lastActivated !== null"), "hover mode clicks activate the item"

h.eval(view, "ActivityService.presentation = 'islands'")
QTest.qWait(5)
assert not h.eval(view, "header.hasActivities") and h.eval(view, "header.activitiesWidth") == 0, "islands presentation leaves the notch alone"
h.eval(view, "ActivityService.presentation = 'notch'")
h.eval(view, "MprisController.activePlayer = ({ trackTitle: 'Song' })")
QTest.qWait(5)
assert h.eval(view, "panelAvailability.media"), "media panel available with a player"

# ── voice: registry panel that opens itself, modal, dismissal cancels ──
h.eval(view, "VoiceService.panelScreen = 'OTHER'; VoiceService.panelOpen = true")
QTest.qWait(5)
assert h.eval(view, "controller.openPanel") == "", "voice shows only on the screen it started on"
h.eval(view, "VoiceService.panelScreen = screenName")
QTest.qWait(5)
assert h.eval(view, "controller.openPanel") == "voice" and h.eval(view, "modalPanel") and h.eval(view, "autoPanel")
h.eval(view, "dismissPanel()")
QTest.qWait(5)

assert h.eval(view, "VoiceService.dismissals") == 1 and h.eval(view, "controller.openPanel") == "", "dismissing reaches VoicePanel"
h.eval(view, "VoiceService.panelOpen = false")
QTest.qWait(5)
assert not h.eval(view, "modalPanel")

# ── transfer row ──
row = h.load("""
import QtQuick
import qs.modules.widgets.defaultview.activities
NotchTransferRow {
    width: 400
    transfer: ({ id: "steam:1", source: "steam", app: "Steam", title: "Game", processed: 340 * 1048576, total: 720 * 1048576, rate: 2 * 1048576, state: "running", kind: "update", units: "bytes", actions: [] })
}
""")
assert h.eval(row, "status.left") == "340 MB / 720 MB · 2.0 MB/s", h.eval(row, "status.left")
assert h.eval(row, "status.right") == "3m 10s left", h.eval(row, "status.right")
h.eval(row, "transfer = Object.assign({}, transfer, { state: 'failed' })")
assert h.eval(row, "status.right") == "Failed" and h.eval(row, "status.tone") == "error"

print("notch activities: segments, badges, fixed widths, per-segment panels, click mode and transfer rows passed")
