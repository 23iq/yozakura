"""Offscreen environment for the island (notch) renders.

PanelsEnv (real theme, components, kit, Notch silhouette) plus the real
resting view (modules/widgets/defaultview: header, segments, panels) and
the notch notifications, with fixture services: a playing player, a
timer, a download, privacy, voice input and one notification.

    env = IslandEnv(notch={"style": "island"}, theme={"language": "ink"})
    win = env.scene(art="/path/cover.jpg", wallpaper="/path/wall.jpg")
    env.open_panel(win, "media")

Used by tools/render/island_render.py.
"""
from __future__ import annotations

import json
import shutil

from panels_env import PanelsEnv, icon_path
from qmlharness import REPO

MIRROR = ["modules/widgets/defaultview", "modules/notch", "modules/notifications"]
JS = ["modules/services/activities/TransferModel.js", "modules/services/activities/NotificationProgress.js",
      "modules/services/voice/VoiceModel.js"]

NOW = "Date.now()"

PLAYER = """QtObject {
        property string trackTitle: "Midnight City"
        property string trackArtist: "M83"
        property string trackAlbum: "Hurry Up, We're Dreaming"
        property string trackArtUrl: ART
        property bool isPlaying: true
        property real position: 104
        property real length: 243
        property bool canSeek: true
        property bool canControl: true
        property bool canGoPrevious: true
        property bool canGoNext: true
        property bool canTogglePlaying: true
        property bool shuffle: false
        property bool shuffleSupported: true
        property string identity: "Spotify"
        property string dbusName: "org.mpris.MediaPlayer2.spotify"
        property string desktopEntry: "spotify"
        function togglePlaying() { isPlaying = !isPlaying }
        function previous() {} function next() {}
    }"""


def services(art: str) -> dict:
    return {
        "MprisController": "pragma Singleton\nQtObject {\n    property QtObject player: " + PLAYER.replace("ART", json.dumps(art)) + """
    property var activePlayer: player
    property var filteredPlayers: [player]
    property bool hasShuffle: false
    property bool shuffleSupported: true
    function setShuffle(s) { hasShuffle = s } function setActivePlayer(p) {} function cyclePlayer() {}
}""",
        "CavaService": """pragma Singleton
QtObject {
    property bool available: true
    function levels(n) { var o = []; for (var i = 0; i < n; i++) o.push(0.25 + 0.7 * Math.abs(Math.sin(i * 1.7 + 0.4))); return o }
    function setConsumer(k, a) {}
}""",
        "MicrophoneStatus": "pragma Singleton\nQtObject { property bool muted: false; property bool available: true; function toggleMute() {} }",
        "VoiceService": """pragma Singleton
QtObject {
    property bool panelOpen: false; property string panelScreen: ""
    property string state: "listening"; property string target: "ai"; property string error: ""
    property string text: ""; property string language: "en"; property string activation: "toggle"
    property bool handsFree: false; property real level: 0.4; property real elapsedMs: 7400; property bool speech: true
    property var bands: [0.2, 0.5, 0.8, 0.6, 0.9, 0.4, 0.7, 0.3, 0.6, 0.8, 0.5, 0.3, 0.6, 0.4, 0.2, 0.5]
    function dismiss() { panelOpen = false } function stop() {}
}""",
        "Notifications": """pragma Singleton
QtObject {
    property var notchPopupList: []
    property var popupList: []; property var list: []; property bool silent: false; property var appNameList: []
    property var groupsByAppName: ({})
    function showsOnScreen(name) { return true }
    function activateNotification(id) {} function attemptInvokeAction(id, a) {}
    function discardNotification(id) {} function discardAllNotifications() {} function notifyInternal() {}
    function timeoutNotification(id) {} function pauseTimeout(id) {} function resumeTimeout(id) {}
    function pauseAllTimers() {} function resumeAllTimers() {}
}""",
    }


ACTIVITY_SERVICE = """pragma Singleton
QtObject {
    property string presentation: "notch"
    property var activities: []
    readonly property var tasks: activities.filter(a => a.category === "task")
    readonly property var privacy: activities.filter(a => a.category === "privacy")
    property var transfers: []
    readonly property int count: activities.length
    property bool showSpeed: true
    property int maxVisible: 4
    function activate(a, b, s) {}
    function transferAction(t, a) {}
    readonly property var icons: ICONS
    function iconUrl(n) { return icons[n] || "" }
}"""

ACTIVITIES = """[
    { id: "timer:1", source: "timers", category: "task", priority: 50, indicator: "ring", label: "18:42",
      icon: Icons.timer, image: "", detail: "Focus", progress: 0.38, color: "primary" },
    { id: "downloads", source: "downloads", category: "task", priority: 40, indicator: "ring", label: "47%",
      icon: Icons.downloadSimple, image: "", detail: "2 downloads", progress: 0.47, color: "primary" },
    { id: "privacy:mic", source: "privacy", category: "privacy", priority: 60, indicator: "glyph", label: "Discord",
      icon: Icons.mic, image: "", detail: "Microphone · Discord", color: "yellow", action: "mic" },
    { id: "privacy:screen", source: "privacy", category: "privacy", priority: 55, indicator: "glyph", label: "OBS",
      icon: Icons.screencast, image: "", detail: "Screen shared · OBS", color: "primary", action: "screen" }
]"""

TRANSFERS = """[
    { id: "b:1", source: "browserDownloads", app: "Firefox", appIcon: "firefox", title: "archlinux-2026.10.01-x86_64.iso",
      processed: 612000000, total: 1300000000, rate: 11800000, state: "running", units: "bytes",
      actions: ["cancel"], path: "/home/user/Downloads/a.iso" },
    { id: "b:2", source: "browserDownloads", app: "Firefox", appIcon: "firefox", title: "report-q3.pdf",
      processed: 2100000, total: 2100000, rate: 0, state: "done", units: "bytes", actions: [], path: "/home/user/Downloads/r.pdf" },
    { id: "t:1", source: "torrents", app: "qBittorrent", appIcon: "qbittorrent", title: "Big Buck Bunny 4K",
      processed: 3100000000, total: 9800000000, rate: 4200000, state: "paused", units: "bytes", actions: ["resume", "cancel"] }
]"""

TIMERS = """[
    { id: "1", name: "Focus", state: "running", leftMs: 1122000, totalMs: 1800000, progress: 0.38, pomodoro: true },
    { id: "2", name: "Tea", state: "paused", leftMs: 184000, totalMs: 300000, progress: 0.61 }
]"""

NOTIFICATION = """({ id: 7, appName: "Telegram", appIcon: TG_ICON, cachedAppIcon: "", image: TG_ICON, cachedImage: "",
    summary: "Mira Tanaka", body: "Sent the deck, take a look before the review at 22:30", time: Date.now() - 120000,
    urgency: 1, actions: [{ identifier: "reply", text: "Reply" }, { identifier: "open", text: "Open" }], isCached: false })"""


class IslandEnv(PanelsEnv):
    def __init__(self, name: str = "island", *, art: str = "", **kw):
        super().__init__(name, **kw)
        qs = self.root / "qs"
        for rel in MIRROR:
            shutil.copytree(REPO / rel, qs / rel, dirs_exist_ok=True)
        for rel in JS:
            (qs / rel).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy(REPO / rel, qs / rel)
        for d in sorted({p.parent for rel in MIRROR for p in (qs / rel).rglob("*.qml")}):
            self._qmldir(d, ".".join(d.relative_to(self.root).parts))
        self.h.module("qs.modules.services", services(art))
        icons = {n: "file://" + icon_path(n) for n in ("firefox", "qbittorrent", "telegram", "discord") if icon_path(n)}
        self.h.module("qs.modules.services.activities", {"ActivityService": ACTIVITY_SERVICE.replace("ICONS", json.dumps(icons))})
        self.h.module("qs.modules.shell.rehome", {"RehomedClock": "Text { property real size }",
                                                   "RehomedTray": "Item { property real iconSize }"})
        self.h.module("Quickshell.Services.Notifications", {
            "NotificationUrgency": "QtObject { enum Urgency { Low, Normal, Critical } }"})

    def scene(self, width: int = 1100, height: int = 560, *, wallpaper: str = "") -> object:
        tg = ("file://" + icon_path("telegram")) if icon_path("telegram") else ""
        wall = (f'Image {{ anchors.fill: parent; source: "file://{wallpaper}"; fillMode: Image.PreserveAspectCrop }}'
                if wallpaper else "Rectangle { anchors.fill: parent; color: Colors.background }")
        return self.load(f"""
import QtQuick
import QtQuick.Window
import qs.config
import qs.modules.theme
import qs.modules.services
import qs.modules.services.activities
import qs.modules.notch
import qs.modules.widgets.defaultview

Window {{
    id: win
    width: {width}; height: {height}; visible: true; color: "black"
    {wall}
    readonly property string edge: Config.notchPosition
    Notch {{
        id: notch
        objectName: "notch"
        width: implicitWidth; height: implicitHeight
        x: win.edge === "left" ? 0 : (win.width - width) / 2
        y: win.edge === "left" ? (win.height - height) / 2 : 0
        screenName: "DP-1"
        visibilities: Visibilities.getForScreen("DP-1")
        defaultViewComponent: Component {{
            DefaultView {{ objectName: "defaultView"; screenName: "DP-1" }}
        }}
    }}
    function seed() {{
        ActivityService.activities = {ACTIVITIES};
        ActivityService.transfers = {TRANSFERS};
        TimersService.timers = {TIMERS};
        TimersService.hubOpen = false;
        TimersService.stopwatchActive = false;
        VoiceService.panelOpen = false;
        notify(false);
    }}
    function notify(on) {{ Notifications.notchPopupList = on ? [{NOTIFICATION.replace("TG_ICON", json.dumps(tg))}] : [] }}
}}""")
