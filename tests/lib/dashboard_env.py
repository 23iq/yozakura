"""Offscreen environment for the dashboard (modules/widgets/dashboard).

KitEnv (real kit, StyledRect, Styling, Metrics, generated Config / Colors)
plus the dashboard frame (Dashboard, DashboardTabRail, DashboardTabs.js),
the composed home (home/) and the bento widgets (widgets/), with sample
stand-ins for the services they call: a playing track (or none), Wi-Fi,
Bluetooth, levels and `notifications` (a list of {appName, summary, body,
image}). Calls are recorded on the stubs (`calls`, `cleared`, ...).

Used by tests/dashboard-home.test.py and tools/render/dashboard_render.py.
"""
from __future__ import annotations

import json
import shutil

from kit_env import KitEnv
from qmlharness import REPO  # first: enters the headless platform
from settings_env import global_states_qml

MIRROR = [
    "modules/widgets/dashboard/Dashboard.qml",
    "modules/widgets/dashboard/DashboardTabRail.qml",
    "modules/widgets/dashboard/DashboardTabs.js",
    "modules/widgets/dashboard/home",
    "modules/widgets/dashboard/widgets",
    "modules/notch/NotchAnimationBehavior.qml",
    "modules/bar/modules/WorldClock.js",
    "modules/services/timers/TimerFormat.js",
]

SAMPLE_NOTIFICATIONS = [
    {"appName": "Telegram", "summary": "Mira Tanaka", "body": "Sent the deck, take a look before the call"},
    {"appName": "Firefox", "summary": "Download complete", "body": "report-q3.pdf (2.4 MB)"},
    {"appName": "Kōyō", "summary": "Warm autumn palette", "body": "Applied to all screens", "image": "ART"},
]


def player_qml(playing: bool, art: str) -> str:
    if not playing:
        return "null"
    return f"""QtObject {{
        property string trackTitle: "Midnight City"; property string trackArtist: "M83"
        property string trackAlbum: "Hurry Up, We're Dreaming"; property string identity: "Spotify"
        property string trackArtUrl: {json.dumps(art)}; property real length: 243; property real position: 104
        property bool canSeek: true; property bool isPlaying: true
    }}"""


def services(playing: bool, notifications: list[dict], art: str) -> dict[str, str]:
    notifs = [{**n, "image": art if n.get("image") == "ART" else n.get("image", ""), "appIcon": ""} for n in notifications]
    return {
        "MprisController": f"""pragma Singleton
QtObject {{
    property var activePlayer: {player_qml(playing, art)}
    property bool isPlaying: {json.dumps(playing)}
    property bool canGoPrevious: {json.dumps(playing)}; property bool canGoNext: {json.dumps(playing)}
    property bool canTogglePlaying: {json.dumps(playing)}
    property var filteredPlayers: activePlayer ? [activePlayer] : []
    property bool hasShuffle: false; property bool shuffleSupported: false; property bool loopSupported: false
    property int loopState: 0; property int calls: 0
    function previous() {{ calls++ }} function next() {{ calls++ }} function togglePlaying() {{ calls++; isPlaying = !isPlaying }}
    function cyclePlayer(d) {{}} function setActivePlayer(p) {{}} function setLoopState(s) {{}} function setShuffle(s) {{}}
}}""",
        "NetworkService": """pragma Singleton
QtObject {
    property bool wifiEnabled: true; property string networkName: "Home 5G"; property int networkStrength: 80
    property int calls: 0
    function toggleWifi() { calls++; wifiEnabled = !wifiEnabled }
}""",
        "BluetoothService": """pragma Singleton
QtObject {
    property bool enabled: true; property bool connected: true; property int calls: 0
    property var friendlyDeviceList: [{ "name": "Buds Pro", "connected": true }]
    function initialize() {} function toggle() { calls++; enabled = !enabled }
}""",
        "Notifications": f"""pragma Singleton
QtObject {{
    id: n
    property string presentation: "notch"; property string cornerPosition: "top-right"
    property bool silent: false; property int cleared: 0; property var sent: []
    property var list: {json.dumps(notifs)}
    property var groupsByAppName: {{
        const g = {{}};
        for (const x of n.list) {{
            if (!g[x.appName]) g[x.appName] = {{ appName: x.appName, notifications: [] }};
            g[x.appName].notifications.push(x);
        }}
        return g;
    }}
    property var appNameList: Object.keys(groupsByAppName)
    function toggleDnd() {{ silent = !silent }}
    function discardAllNotifications() {{ cleared++; list = [] }}
    function hideAllPopups() {{}}
    function notifyInternal(o) {{ sent = sent.concat([o]); return null }}
}}""",
        "CaffeineClient": "pragma Singleton\nQtObject { property bool inhibit: false; function toggle() { inhibit = !inhibit } }",
        "NightLightClient": "pragma Singleton\nQtObject { property bool active: false; function toggle() { active = !active } }",
        "GameModeClient":"pragma Singleton\nQtObject { property bool toggled: false; function toggle() { toggled = !toggled } }",
        "Audio": """pragma Singleton
QtObject {
    property QtObject sink: QtObject { property QtObject audio: QtObject { property real volume: 0.62; property bool muted: false } }
    property QtObject source: QtObject { property QtObject audio: QtObject { property real volume: 0.3; property bool muted: false } }
}""",
        "Brightness": """pragma Singleton
QtObject {
    property bool syncBrightness: false
    property QtObject mon: QtObject {
        property var screen: ({ "name": "DP-1" }); property bool ready: true; property real brightness: 0.38
        function setBrightness(v) { brightness = v }
    }
    property var monitors: [mon]
}""",
        "YozdService": 'pragma Singleton\nQtObject { property string compositorName: "hyprland"; '
                       'property var focusedMonitor: ({ "name": "DP-1" }) }',
        "GlobalShortcuts": "pragma Singleton\nQtObject { property int settings: 0; function toggleSettings() { settings++ } }",
        "Visibilities": "pragma Singleton\nQtObject { function setActiveModule(m) {} }",
        "SystemResources": "pragma Singleton\nQtObject { property real cpuUsage: 23; property real ramUsage: 48; "
                           "property bool gpuDetected: true; property real gpuUsage: 12; function setConsumer(k, a) {} }",
    }


def global_states(wallpaper: dict) -> str:
    extra = """property bool settingsWindowVisible: false
    property int dashboardCurrentTab: 0
    property bool dashboardOpen: true
    property int widgetsTabCurrentIndex: 0
    property string launcherSearchText: ""
    function clearLauncherState() {}"""
    qml = global_states_qml(wallpaper).replace("property bool settingsWindowVisible: true", extra)
    # The bento player tints itself with the wallpaper.
    return qml.replace("function nextWallpaper() {}", "function nextWallpaper() {}\n"
                       "        function getLockscreenFramePath(p) { return thumbs[p] || p }")


class DashboardEnv(KitEnv):
    def __init__(self, name: str = "dashboard", *, playing: bool = True, notifications: list[dict] | None = None,
                 art: str = "", wallpaper: dict | None = None, **kw):
        super().__init__(name, wallpaper=wallpaper, **kw)
        qs = self.root / "qs"
        for rel in MIRROR:
            src, dst = REPO / rel, qs / rel
            if src.is_dir():
                shutil.copytree(src, dst, dirs_exist_ok=True)
            elif src.exists():
                dst.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy(src, dst)
        notifs = SAMPLE_NOTIFICATIONS if notifications is None else notifications
        self.h.module("qs.modules.services", services(playing, notifs, art))
        self.h.module("qs.modules.globals", {"GlobalStates": global_states(wallpaper or {})})
        self.h.module("qs.modules.notifications", {"NotificationAppIcon": "Item { property var appIcon; property string appName; property var image; "
                                                   "property var summary; property var urgency; property real size: 28; "
                                                   "implicitWidth: size; implicitHeight: size }"})
        self.h.module("Quickshell.Services.Mpris", {
            "MprisLoopState": "QtObject { readonly property int None: 0; readonly property int Track: 1; "
                              "readonly property int Playlist: 2 }",
            "MprisPlaybackState": "QtObject { readonly property int Stopped: 0; readonly property int Playing: 1; "
                                  "readonly property int Paused: 2 }"})
        self.h.module("qs.modules.widgets.dashboard.metrics", {"MetricsTab": "Item {}"})
        self.h.module("qs.modules.widgets.dashboard.wallpapers", {"WallpapersTab": "Item {}"})
        self._qmldir(qs / "modules/notch", "qs.modules.notch", only=["NotchAnimationBehavior"])
        self._qmldir(qs / "modules/widgets/dashboard", "qs.modules.widgets.dashboard")
        self._qmldir(qs / "modules/widgets/dashboard/home", "qs.modules.widgets.dashboard.home")
        self._qmldir(qs / "modules/widgets/dashboard/widgets", "qs.modules.widgets.dashboard.widgets")
        # Bento tiles load their widgets by URL, compiled on the QML loader
        # thread, whose warnings wait for the GIL (a deadlock). The player's
        # seek bar warns that its `enabled` shadows Item.enabled: in this
        # copy, drop the redundant declaration (same meaning, no warning).
        seek = qs / "modules/components/CircularSeekBar.qml"
        seek.write_text(seek.read_text().replace("    property bool enabled: true\n", "", 1))
