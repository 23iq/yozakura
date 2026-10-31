"""The real NotchContent on a side edge, with the screen frame on (offscreen):
a left/right notch is laid out against the frame (never past it, never
detached from the monitor edge) on both notch styles, resting and hidden."""
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import REPO  # noqa: E402
from lib import island_stubs  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

SW, SH, FRAME, BAR = 1920, 1080, 8, 44

h = island_stubs.island("notch-side-edge")
h.singleton("qs.config", "Config", f"""QtObject {{
    id: cfg
    property int animDuration: 0
    property int roundness: 12
    property bool showBackground: true
    property string notchStyle: "attached"
    property string notchTheme: notchStyle === "attached" ? "default" : "island"
    property string notchPosition: "top"
    property bool barReady: true
    property var theme: ({{ font: "Sans", fontSize: 14, srBg: {{ border: ["primary", 0] }} }})
    property var performance: ({{ blurTransition: false }})
    property var bar: ({{ position: "top", frameEnabled: true, frameThickness: {FRAME}, availableOnFullscreen: false, pinnedOnStartup: true }})
    property var dock: ({{ position: "bottom", enabled: true, height: 64 }})
    property var notch: ({{ position: cfg.notchPosition, align: "center", keepHidden: false, enabled: true,
        disableHoverExpansion: false, hoverExpandDelay: 20, hoverCollapseDelay: 20, hoverRegionHeight: 16,
        expandedMediaWidth: 440, expandedArtworkSize: 64, mediaAnimationDuration: 0, customText: "Yozakura", visualizer: false }})
    function resolveColor(c) {{ return "white" }}
}}""")
h.module("qs.modules.globals", {})
h.module("qs.modules.theme", {
    "Metrics": "pragma Singleton\nQtObject { property int spacing: 8 }",
    "Motion": "pragma Singleton\nQtObject { property var morph: ({ duration: 0, easing: Easing.OutCubic, overshoot: 1 }); property var enter: morph; property var exit: morph }",
})
h.module("qs.modules.corners", {"RoundCorner": "Item { enum CornerEnum { TopLeft, TopRight, BottomLeft, BottomRight } property int corner; property real size; property color color }"})
h.module("Quickshell", {"ShellScreen": "QtObject { property string name; property int width; property int height }"})
h.module("Quickshell.Widgets", {"ClippingRectangle": "Rectangle {}"})
h.singleton("qs.modules.shell.hosts", "HostRouter", "QtObject { function notchOpen(v) { return false } function hostFor(k) { return \"\" } }")
h.singleton("qs.modules.shell", "ShellLayout", "QtObject { property bool notchEnabled: true; property var notchSegments: [] }")
h.singleton("qs.modules.shell", "EdgeService", f"""QtObject {{
    function envFor(screen) {{
        const bar = Config.bar;
        return {{ screen: {{ w: screen.width, h: screen.height }}, frame: bar.frameEnabled ? bar.frameThickness : 0,
            panels: [{{ pos: "top", size: {BAR}, visible: true }}],
            dock: {{ pos: Config.dock.position, size: Config.dock.height, visible: Config.dock.enabled }},
            notch: {{ pos: Config.notch.position, height: 36, align: Config.notch.align, visible: true }} }};
    }}
    function notchRect(screen, size) {{ return EdgeLayout.notchRect(envFor(screen), size) }}
}}""")
sd = h.root / "qs/modules/shell"
(sd / "EdgeLayout.js").write_text((REPO / "modules/shell/EdgeLayout.js").read_text())
svc = (sd / "EdgeService.qml").read_text()
(sd / "EdgeService.qml").write_text(svc.replace("QtObject {", 'import qs.config\nimport "EdgeLayout.js" as EdgeLayout\nQtObject {', 1) if "EdgeLayout.js" not in svc else svc)
h.singleton("qs.modules.services", "YozdService", "QtObject { property var focusedMonitor: null; property var clients: ({ values: [] }); function monitorFor(s) { return null } }")
h.singleton("qs.modules.services", "CompositorData", "QtObject { function monitorHasFullscreen(m) { return false } }")
h.singleton("qs.modules.bar.panels", "Panels", 'QtObject { property string primaryEdge: "top" }')
h.module("qs.modules.services", {
    "Visibilities": """pragma Singleton
QtObject {
    id: v
    property var barPanels: ({})
    property var bars: ({})
    property var screens: ({})
    property Component flags: Component { QtObject { property bool launcher; property bool dashboard; property bool powermenu; property bool tools; property bool aiquick; property bool playerMenuOpen } }
    function getForScreen(n) {
        if (!screens[n])
            screens[n] = flags.createObject(v);
        return screens[n];
    }
    function setActiveModule(m) {}
}""",
    "Notifications": "pragma Singleton\nQtObject { property var popupList: []; property var notchPopupList: []; function showsOnScreen(s) { return true } }",
    "MicrophoneStatus": "pragma Singleton\nQtObject { property bool noticeVisible: false; property string noticeScreen: \"\"; property bool muted: false; property bool available: true }",
})
notch_dir = REPO / "modules/notch"
names = ["Notch", "NotchSilhouette", "NotchOutline", "NotchViewTransition", "NotchPlacement", "NotchContent",
         "NotchHoverHold", "NotchAvoidance"]
files = {n: (notch_dir / f"{n}.qml").read_text() for n in names}
files["NotchContent"] = files["NotchContent"].replace('import "./NotchNotificationView.qml"\n', "")
files["NotchNotificationView"] = "Item { property bool notchHovered }"
files["NotchMenuViews"] = "Item { property var vis; property var container }"
nd = h.module("qs.modules.notch", files)
for js in ["NotchShape.js", "NotchReveal.js", "NotchAvoid.js"]:
    (nd / js).write_text((notch_dir / js).read_text())
(nd / "styles").mkdir(exist_ok=True)
(nd / "styles/NotchStyles.js").write_text((notch_dir / "styles/NotchStyles.js").read_text())
h.module("qs.modules.widgets.powermenu", {"PowerMenuView": "Item {}"})
h.module("qs.modules.widgets.tools", {"ToolsMenuView": "Item {}"})
h.module("qs.modules.aicenter.quickask", {"QuickAskCard": "Item {}"})
h.module("qs.modules.shell.hosts", {"NotchHostedSurfaces": "Item { property var screen; property var vis; property var container }"})
h.module("qs.modules.widgets.defaultview", {"DefaultView": """Item {
    property string screenName
    property bool revealed
    property bool panelExpanded: false
    property bool modalPanel: false
    property bool autoPanel: false
    property bool expandedState: false
    property bool hasActivities: false
    implicitWidth: 380
    implicitHeight: 36
    function dismissPanel() {}
}"""})

root = h.load("""
import QtQuick
import qs.config
import qs.modules.notch
import Quickshell
Item {
    id: root
    width: 1920; height: 1080
    ShellScreen { id: scr; name: "DP-1"; width: 1920; height: 1080 }
    NotchContent { id: nc; objectName: "nc"; screen: scr; anchors.fill: parent }
}""")
QTest.qWait(50)


def where(style: str, pos: str) -> dict:
    h.eval(root, f"Config.notchStyle = '{style}'; Config.notchPosition = '{pos}'")
    QTest.qWait(80)
    nc = h.find(root, "nc")
    r = h.eval(nc, "(function(){ var n = notchContainerRef; var p = n.mapToItem(null, 0, 0); var q = visualRegion.mapToItem(null, 0, 0);"
                   " return [p.x, p.y, n.width, n.height, q.x, q.y, visualRegion.width, visualRegion.height, reveal]; })()")
    return r.toVariant() if hasattr(r, "toVariant") else r


GAP = {"attached": 0, "island": 4}
for style in ("attached", "island"):
    gap = GAP[style]
    x, y, w, hh, qx, qy, qw, qh, shown = where(style, "top")
    assert shown and y == FRAME + gap, f"{style}: the top notch sits under the frame ({y})"
    x, y, w, hh, qx, qy, qw, qh, shown = where(style, "left")
    assert shown and x == gap, f"{style}: the left notch comes out of the monitor edge, not from behind the frame ({x})"
    assert qx == 0, f"{style}: the left notch region starts on the monitor edge ({qx})"
    assert FRAME + BAR <= y and y + hh <= SH - FRAME, f"{style}: clear of the top bar and the frame ({y})"
    x, y, w, hh, qx, qy, qw, qh, shown = where(style, "right")
    assert shown and x + w == SW - gap, f"{style}: the right notch comes out of the monitor edge ({x} + {w})"

# hidden (notch.keepHidden): all the way behind its monitor edge
for style in ("attached", "island"):
    h.eval(root, "Config.notch = ({ position: 'left', align: 'center', keepHidden: true, enabled: true, hoverExpandDelay: 20, hoverCollapseDelay: 20, hoverRegionHeight: 16, expandedMediaWidth: 440, expandedArtworkSize: 64, mediaAnimationDuration: 0, customText: 'Y', visualizer: false, disableHoverExpansion: false })")
    x, y, w, hh, qx, qy, qw, qh, shown = where(style, "left")
    assert not shown and x + w <= 0, f"{style}: hidden left notch is off the monitor ({x} + {w})"
print("notch on a side edge: flush with the monitor edge under a frame, hidden behind it")
sys.stdout.flush()
# Skip the engine teardown (singletons die before the views that read them)
os._exit(0)
