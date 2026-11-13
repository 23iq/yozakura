"""Offscreen environment for the dashboard's tool tabs: the metrics tab,
the device panels of controls/ and the wallpapers tab.

DashboardEnv (real kit, sample Wi-Fi / Bluetooth / notifications) with the
real metrics/, controls/ and wallpapers/ directories in place of its
stand-ins, plus sample services: SystemResources (CPU, RAM, two GPUs, two
disks with a load history), Audio (two outputs, a mic, two app streams; the
Pipewire node type stubbed), EasyEffectsService (presets) and the
wallpapers tab's side of GlobalStates.wallpaperManager. StateService records
what the tabs save (`state`).

Used by tests/dashboard-tabs.test.py and tools/render/dashtabs_render.py.
"""
from __future__ import annotations

import json
import math
import shutil

from dashboard_env import DashboardEnv, global_states
from qmlharness import REPO

DIRS = ["modules/widgets/dashboard/metrics", "modules/widgets/dashboard/controls",
        "modules/widgets/dashboard/wallpapers"]


def wave(v: float, a: float, p: float, n: int = 120) -> list[float]:
    return [round(max(0.0, min(1.0, v + a * math.sin(i / 5.0 + p))), 3) for i in range(n)]


SYSTEM_RESOURCES = f"""pragma Singleton
QtObject {{
    property real cpuUsage: 23; property string cpuModel: "AMD Ryzen 7 7840U"; property int cpuTemp: 54
    property real ramUsage: 48; property real ramUsed: 15938355; property real ramTotal: 32505856
    property bool gpuDetected: true; property int gpuCount: 2; property real gpuUsage: 12
    property var gpuNames: ["Radeon 780M", "GeForce RTX 4060"]; property var gpuVendors: ["amd", "nvidia"]
    property var gpuUsages: [12, 37]; property var gpuTemps: [48, 61]
    property var validDisks: ["/", "/home"]; property var diskTypes: ({{ "/": "ssd", "/home": "hdd" }})
    property var diskUsage: ({{ "/": 41, "/home": 72 }})
    property int updateInterval: 2000; property int maxHistoryPoints: 250; property int totalDataPoints: 120
    property real netRxRate: 1468006; property real netTxRate: 41984
    property var cpuHistory: {json.dumps(wave(0.25, 0.12, 0.0))}
    property var ramHistory: {json.dumps(wave(0.47, 0.03, 1.0))}
    property var gpuHistories: [{json.dumps(wave(0.14, 0.1, 2.0))}, {json.dumps(wave(0.37, 0.15, 3.0))}]
    function setConsumer(k, a) {{}}
}}"""

AUDIO = """pragma Singleton
import QtQuick
import qs.modules.theme
import Quickshell.Services.Pipewire
QtObject {
    id: a
    property bool protectionEnabled: true; property bool protectionTriggered: false
    component Node: PwNode {}
    property QtObject sink: Node { name: "speakers"; nickname: "Speakers"; description: "Built-in Speakers" }
    property QtObject source: Node { name: "mic"; nickname: "Microphone"; isSink: false; description: "Built-in Microphone" }
    property var outputDevices: [sink, hdmi]
    property QtObject hdmi: Node { name: "hdmi"; nickname: "HDMI"; description: "LG UltraFine (HDMI)" }
    property var inputDevices: [source]
    property QtObject spotify: Node { name: "spotify"; isStream: true; properties: ({ "application.name": "Spotify" }) }
    property QtObject firefox: Node { name: "firefox"; isStream: true; properties: ({ "application.name": "Firefox" }) }
    property var outputAppNodes: [spotify, firefox]
    property var inputAppNodes: []
    function friendlyDeviceName(n) { return n ? (n.description || n.nickname || n.name) : "" }
    function appNodeDisplayName(n) { return n && n.properties ? (n.properties["application.name"] || n.name) : "" }
    function volumeIcon(volume, muted) { return muted ? Icons.speakerX : Icons.speakerHigh }
    function setDefaultSink(n) {} function setDefaultSource(n) {} function setNodeVolume(n, v) {}
    function setProtectionEnabled(on) { protectionEnabled = on }
}"""

EASY_EFFECTS = """pragma Singleton
QtObject {
    property bool available: true; property bool bypassed: false
    property var outputPresets: ["Loudness", "Bass Boost", "Night", "Podcast"]
    property var inputPresets: ["Noise Gate", "Voice"]
    property string activeOutputPreset: "Loudness"; property string activeInputPreset: ""
    function initialize() {} function setConsumer(key, on) {} function refresh() {} function openApp() {} function setBypass(b) { bypassed = b }
    function loadOutputPreset(p) { activeOutputPreset = p } function loadInputPreset(p) { activeInputPreset = p }
}"""

# The wallpapers tab's side of the manager (the rest is the settings stub).
WALLPAPER_MANAGER = """function nextWallpaper() {}
        property var perScreenWallpapers: ({})
        property var subfolderFilters: []
        property int thumbnailsVersion: 0
        property bool tintEnabled: false
        function getThumbnailPath(p) { return thumbs[p] || p }
        function getSubfolderFromPath(p) { return "" }
        function scanSubfolders() {}
        function clearPerScreenWallpaper(s) {}"""
GLOBALS_EXTRA = """property bool settingsWindowVisible: true
    property int wallpaperSelectedIndex: 2
    function setWallpaperTransitionOrigin(item, x, y, screen) {}"""

PIPEWIRE = {
    "PwNode": "QtObject { property string name; property string nickname; property string description; "
              "property bool isSink: true; property bool isStream: false; property var properties: ({}); "
              "property bool ready: true; "
              "property QtObject audio: QtObject { property real volume: 0.6; property bool muted: false } }",
    "PwObjectTracker": "QtObject { property var objects: [] }",
}


class DashTabsEnv(DashboardEnv):
    def __init__(self, name: str = "dashtabs", *, wallpaper: dict | None = None, **kw):
        super().__init__(name, wallpaper=wallpaper, **kw)
        qs = self.root / "qs"
        for rel in DIRS:
            shutil.copytree(REPO / rel, qs / rel, dirs_exist_ok=True)
            self._qmldir(qs / rel, "qs." + rel.replace("/", "."))
        self.h.module("Quickshell.Services.Pipewire", PIPEWIRE)
        gs = global_states(wallpaper or {}).replace("function nextWallpaper() {}", WALLPAPER_MANAGER, 1)
        gs = gs.replace("property bool settingsWindowVisible: true", GLOBALS_EXTRA, 1)
        self.h.module("qs.modules.globals", {"GlobalStates": gs})
        self.h.module("qs.modules.services", {"SystemResources": SYSTEM_RESOURCES, "Audio": AUDIO,
                                              "EasyEffectsService": EASY_EFFECTS})

    def scene(self, element: str, width: int, height: int):
        """`element` (QML, e.g. "MetricsTab {}") filling a width x height
        box on the popup Surface, over `wallpaper` (a url property)."""
        body = element.replace("{", "{ objectName: \"view\"; anchors.fill: parent;", 1)
        return self.load(SCENE % (width, height, body))


SCENE = """
import QtQuick
import QtQuick.Window
import qs.modules.components.kit
import qs.modules.widgets.dashboard.metrics
import qs.modules.widgets.dashboard.controls
import qs.modules.widgets.dashboard.wallpapers
Window {
    id: win
    property url wallpaper: ""
    width: surface.width + 96; height: surface.height + 96; visible: true; color: "black"
    Image { anchors.fill: parent; source: win.wallpaper; fillMode: Image.PreserveAspectCrop }
    Surface {
        id: surface
        anchors.centerIn: parent
        Item {
            width: %d; height: %d
            %s
        }
    }
}"""
