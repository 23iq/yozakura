"""Offscreen setup of the resting island (DefaultView, IslandHeader, live
activity segments and notch panels) with stubbed services, shared by the
notch tests. `island(name, config_extra)` returns the Harness."""
from lib.qmlharness import REPO, Harness
from lib import timers_stubs


def island(name: str, config_extra: str = "") -> Harness:
    h = Harness(name)
    h.singleton("qs.config", "Config", """QtObject {
        property int animDuration: 0
        property int roundness: 12
        property bool showBackground: true
        property string notchTheme: "default"
        property string notchPosition: "top"
        property var theme: ({ font: "Sans", fontSize: 14, srBg: { border: ["primary", 0] } })
        CONFIG_EXTRA
        property var notch: ({ disableHoverExpansion: false, hoverExpandDelay: 20, hoverCollapseDelay: 20, expandedMediaWidth: 440, expandedArtworkSize: 64, mediaAnimationDuration: 0, customText: "Yozakura", visualizer: false })
    }""".replace("CONFIG_EXTRA", config_extra))
    h.module("qs.modules.theme", {
        "Styling": "pragma Singleton\nQtObject { property string defaultFont: \"Sans\"; function fontSize(o) { return 14 + o } function radius(o) { return 12 + o } function srItem(v) { return \"white\" } }",
        "Colors": "pragma Singleton\nQtObject { property color overBackground: \"white\"; property color overSurfaceVariant: \"silver\"; property color primary: \"pink\"; property color red: \"red\"; property color error: \"red\"; property color green: \"green\"; property color yellow: \"yellow\"; property color criticalRed: \"red\"; property color surface: \"gray\"; property color background: \"black\" }",
        "Icons": "pragma Singleton\nQtObject { property string font: \"Sans\"; property string accept: \"v\"; property string copy: \"c\"; property string sync: \"s\"; property string downloadSimple: \"d\"; property string folder: \"f\"; property string cancel: \"x\"; property string stop: \"S\"; property string pause: \"p\"; property string play: \"P\"; property string micSlash: \"m\"; property string player: \"P\"; property string spotify: \"S\"; property string mic: \"M\"; property string timer: \"T\"; property string recordScreen: \"R\" }",
        "BarMetrics": "pragma Singleton\nQtObject { property int notchRestHeight: 44; property int notchIslandHeight: 36 }",
    })
    h.module("qs.modules.components", {
        "StyledRect": "Rectangle { property string variant; property bool enableBorder; property bool enableShadow; property bool animateRadius; property string glassSurface; property color item: \"white\" }",
        "StyledToolTip": "Item { property string tooltipText; property bool show }",
        "Separator": "Item { property bool vert; implicitWidth: 2; implicitHeight: 2 }",
    })
    h.module("Quickshell.Widgets", {"IconImage": "Image { property real implicitSize }"})
    h.module("qs.modules.services", {
        "I18n": "pragma Singleton\nQtObject { function t(k) { return ({ \"activities.left\": \"left\", \"activities.failed\": \"Failed\", \"activities.paused\": \"Paused\" })[k] || k } }",
        "MicrophoneStatus": "pragma Singleton\nQtObject { property bool muted: false; property bool available: true }",
        "MprisController": "pragma Singleton\nQtObject { property var activePlayer: null }",
        "Notifications": "pragma Singleton\nQtObject { property var popupList: []; property var notchPopupList: []; function showsOnScreen(s) { return true } }",
        "Visibilities": "pragma Singleton\nQtObject { property bool playerMenuOpen: false }",
        **timers_stubs.services(),
        "VoiceService": "pragma Singleton\nQtObject { property bool panelOpen: false; property string panelScreen: \"\"; property string state: \"listening\"; property string target: \"ai\"; property var bands: []; property int dismissals: 0; function dismiss() { dismissals++; panelOpen = false; } }",
        # Bar content re-homed into the notch (none: the bar is on)
        "ShellLayout": "pragma Singleton\nQtObject { property var notchSegments: [] }",
    })
    h.module("qs.modules.shell.rehome", {
        "RehomedClock": "Text { property real size }",
        "RehomedTray": "Item { property real iconSize }",
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
    (h.root / "app/activities").mkdir(exist_ok=True)
    (h.root / "app/activities/ActivityRegistry.js").write_text((acts_dir / "ActivityRegistry.js").read_text())
    panels_src = REPO / "modules/widgets/defaultview/panels"
    pd = h.module("qs.modules.widgets.defaultview.panels", {f.stem: f.read_text() for f in sorted(panels_src.glob("*.qml")) if f.stem != "MediaPanel"})
    (pd / "NotchPanels.js").write_text((panels_src / "NotchPanels.js").read_text())
    timers_stubs.copy_js(h.root)
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
        "IslandRail": "Column { property var player; property int motionDuration; property bool mediaHovered: false; signal mediaClicked }",
    }.items():
        h.stub(n, body)
    return h
