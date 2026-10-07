"""Offscreen environment for the bento widgets
(modules/widgets/dashboard/widgets) and the bar clock popup
(modules/bar/clock/ClockPanel*.qml).

KitEnv (real kit, Styling, Metrics, Config defaults, I18n) plus the widget
and clock trees mirrored under qs/ (they import each other relatively) and
fixture services: a playing MPRIS track, audio / brightness levels, Wi-Fi
and Bluetooth, notifications, system load, special workspaces, the weather,
a running Pomodoro, a timer and a reminder.

Used by tests/bento-widgets.test.py, tests/clock-panel.test.py and
tools/render/{widgets,clockpanel}_render.py.
"""
from __future__ import annotations

import json
import shutil

import timers_stubs
from kit_env import KitEnv
from qmlharness import REPO

POMODORO = {"id": "p", "name": "", "leftMs": 754000, "progress": 0.5, "state": "running", "ringing": False,
            "pomodoro": {"phase": "work", "round": 1, "every": 4}}

FORECAST = [{"dayName": d, "weatherCode": c, "maxTemp": hi, "minTemp": lo} for d, c, hi, lo in [
    ("Today", 2, 21, 12), ("Wed", 61, 17, 11), ("Thu", 3, 19, 10), ("Fri", 0, 23, 13),
    ("Sat", 1, 22, 14), ("Sun", 95, 18, 12), ("Mon", 71, 6, 1)]]

SERVICES = {
    "MprisController": """pragma Singleton
import QtQuick
QtObject {
    property QtObject track: QtObject {
        property string trackTitle: "Midnight City"; property string trackArtist: "M83"
        property string trackAlbum: "Hurry Up, We're Dreaming"; property string trackArtUrl: ""
        property real position: 104; property real length: 243; property bool canSeek: true
        property int playbackState: 1; property string identity: "Spotify"
        property string dbusName: "org.mpris.MediaPlayer2.spotify"; property string desktopEntry: "spotify"
    }
    property var activePlayer: track
    property var filteredPlayers: [track]
    property bool hasShuffle: false; property int loopState: 2
    property bool shuffleSupported: true; property bool loopSupported: true
    property bool canGoPrevious: true; property bool canGoNext: true
    property int toggles: 0
    function togglePlaying() { toggles++ } function previous() {} function next() {}
    function setShuffle(s) { hasShuffle = s } function setLoopState(s) { loopState = s }
    function setActivePlayer(p) { activePlayer = p } function cyclePlayer(d) {}
}""",
    "Audio": """pragma Singleton
import QtQuick
QtObject {
    property QtObject sink: QtObject { property QtObject audio: QtObject { property real volume: 0.62; property bool muted: false } }
    property QtObject source: QtObject { property QtObject audio: QtObject { property real volume: 0.3; property bool muted: false } }
}""",
    "Brightness": """pragma Singleton
import QtQuick
QtObject {
    property bool syncBrightness: false
    property QtObject mon: QtObject {
        property var screen: ({ "name": "DP-1" }); property bool ready: true; property real brightness: 0.38
        function setBrightness(v) { brightness = v }
    }
    property var monitors: [mon]
}""",
    "YozdService": """pragma Singleton
import QtQuick
QtObject { property string compositorName: "hyprland"; property var focusedMonitor: ({ "name": "DP-1" }) }""",
    "NetworkService": """pragma Singleton
import QtQuick
QtObject { property bool wifiEnabled: true; property int networkStrength: 80; function toggleWifi() { wifiEnabled = !wifiEnabled } }""",
    "BluetoothService": """pragma Singleton
import QtQuick
QtObject { property bool enabled: true; property bool connected: false; function toggle() { enabled = !enabled } function initialize() {} }""",
    "NightLightClient": "pragma Singleton\nimport QtQuick\nQtObject { property bool active: true; function toggle() { active = !active } }",
    "CaffeineClient": "pragma Singleton\nimport QtQuick\nQtObject { property bool inhibit: false; function toggle() { inhibit = !inhibit } }",
    "GameModeClient": "pragma Singleton\nimport QtQuick\nQtObject { property bool toggled: false; function toggle() { toggled = !toggled } }",
    "Visibilities": "pragma Singleton\nimport QtQuick\nQtObject { function setActiveModule(m) {} }",
    "SystemResources": """pragma Singleton
import QtQuick
QtObject { property real cpuUsage: 23; property real ramUsage: 61; property real gpuUsage: 8; property bool gpuDetected: true
 function setConsumer(k, on) {} }""",
    "Notifications": """pragma Singleton
import QtQuick
QtObject {
    property bool silent: false
    property string presentation: "notch"; property string cornerPosition: "top-right"
    property var list: [
        { "id": 1, "appName": "Telegram", "summary": "Mira Tanaka", "body": "Sent the deck, take a look before the call", "time": 1 },
        { "id": 2, "appName": "Firefox", "summary": "Download complete", "body": "report-q3.pdf", "time": 2 },
        { "id": 3, "appName": "Firefox", "summary": "Download complete", "body": "slides.key", "time": 3 }
    ]
    property var groupsByAppName: ({
        "Telegram": { "appName": "Telegram", "notifications": [list[0]] },
        "Firefox": { "appName": "Firefox", "notifications": [list[1], list[2]] }
    })
    property var appNameList: ["Telegram", "Firefox"]
    property var discarded: []
    property var sent: []
    function toggleDnd() { silent = !silent }
    function discardAllNotifications() { appNameList = [] }
    function discardNotifications(ids) { discarded = discarded.concat(ids) }
    function activateNotification(id) { return true }
    function notifyInternal(o) { sent = sent.concat([o]); return null }
}""",
    "WeatherService": """pragma Singleton
import QtQuick
QtObject {
    property bool dataAvailable: true; property bool isLoading: false; property bool debugMode: false
    property real currentTemp: 18.4; property real maxTemp: 21.2; property real minTemp: 11.8
    property int rainChance: 40; property real windSpeed: 12.3
    property int effectiveWeatherCode: 2; property bool effectiveIsDay: true
    property string effectiveWeatherDescription: "Partly cloudy"
    property real debugHour: 12; property int debugWeatherCode: 0
    property var forecast: %s
    function updateWeather() {}
}""" % json.dumps(FORECAST),
}

SPECIALS = """pragma Singleton
import QtQuick
QtObject {
    property bool supported: true
    property bool active: true
    property var items: [
        { "id": "music", "name": "Music", "icon": "musicNotes", "accent": "primary" },
        { "id": "chat", "name": "Chat", "icon": "chatTeardrop", "accent": "tertiary" },
        { "id": "notes", "name": "Notes", "icon": "notePencil", "accent": "secondary" }
    ]
    function isOpen(it) { return it.id === "music" }
    function countOf(it) { return it.id === "music" ? 2 : 1 }
    function toggle(ref) { return true }
}"""

APP_ICON = """Item {
    property var appIcon; property string appName; property var summary; property var image
    property real size; property real radius
    Rectangle { anchors.fill: parent; radius: parent.radius; color: Qt.rgba(1, 1, 1, 0.08)
        Text { anchors.centerIn: parent; text: appName.charAt(0); color: "#d7c1c2"; font.pixelSize: parent.height * 0.4 } }
}"""

MPRIS = {
    "MprisPlaybackState": "QtObject { enum Values { Stopped, Playing, Paused } }",
    "MprisLoopState": "QtObject { enum Values { None, Track, Playlist } }",
}

GLOBAL_STATES = """pragma Singleton
import QtQuick
QtObject { property bool dashboardOpen: false; property int dashboardCurrentTab: 0; property int widgetsTabCurrentIndex: 0 }"""

# `date +%z` per zone (WorldClockSource) answers from these offsets.
PROCESS = """QtObject {
    property var command: []; property bool running: false; property var stdout; property var stderr
    signal exited(int exitCode, int exitStatus)
    readonly property var zones: ({ "Asia/Tokyo": "+0900", "Europe/London": "+0100", "America/New_York": "-0400" })
    onRunningChanged: {
        if (!running || !stdout || command.length < 5 || String(command[2]).indexOf("date +%z") < 0)
            return;
        stdout.text = command.slice(4).map(z => zones[z] || "+0000").join("\\n");
        running = false;
        stdout.streamFinished();
    }
}"""

TREES = ["modules/widgets/dashboard/widgets", "modules/bar/clock", "modules/bar/modules/WorldClock.js"]


class WidgetsEnv(KitEnv):
    def __init__(self, name: str = "widgets", **kw):
        super().__init__(name, **kw)
        qs = self.root / "qs"
        for rel in TREES:
            src, dst = REPO / rel, qs / rel
            if src.is_dir():
                shutil.copytree(src, dst, dirs_exist_ok=True)
            else:
                dst.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy(src, dst)
        # SettingsEnv lists only HostWidget there; directory imports read it.
        self._qmldir(qs / "modules/widgets/dashboard/widgets", "qs.modules.widgets.dashboard.widgets")
        timers_stubs.copy_js(self.root)
        self.h.module("qs.modules.services", {**timers_stubs.services(), **SERVICES})
        self.h.module("qs.modules.specials", {"SpecialsService": SPECIALS})
        self.h.module("qs.modules.notifications", {"NotificationAppIcon": APP_ICON})
        self.h.module("Quickshell.Services.Mpris", MPRIS)
        self.h.module("Quickshell.Io", {"Process": PROCESS})
        self.h.module("qs.modules.globals", {"GlobalStates": GLOBAL_STATES})

    def timers(self, obj, pomodoro: bool = True, extra: bool = True) -> None:
        """Fill TimersService: a running Pomodoro, a tea timer and a call reminder."""
        timers = ([POMODORO] if pomodoro else []) + (
            [{"id": "t", "name": "Tea", "leftMs": 240000, "state": "running", "ringing": False}] if extra else [])
        self.h.eval(obj, f"TimersService.timers = {json.dumps(timers)}")
        if extra:
            self.h.eval(obj, "TimersService.reminders = [{ id: 'r', message: 'Call Mira', "
                             "at: TimersService.now + 5400000, leftMs: 5400000 }]")
