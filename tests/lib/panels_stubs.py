"""Fixture singletons and Quickshell stand-ins for tests/lib/panels_env.py.

A small believable desktop: 6 workspaces (2 active), a few windows, tray
apps, battery, weather and system stats, so every bar module renders.
"""
from __future__ import annotations

import json

APPS = ["firefox", "kitty", "code", "discord", "spotify", "telegram", "obsidian", "org.gnome.Nautilus", "steam"]
PINNED = ["firefox", "kitty", "code", "org.gnome.Nautilus", "obsidian", "spotify", "steam"]
# appId -> [workspace, title, active]
WINDOWS = [
    ("firefox", 2, "Yozakura — panels engine · Firefox", True),
    ("kitty", 2, "~/src/yozakura — nvim", False),
    ("code", 1, "PanelLayout.js — yozakura", False),
    ("discord", 3, "#shell-ricing — Discord", False),
    ("spotify", 4, "Spotify Premium", False),
    ("kitty", 4, "btop", False),
]
TRAY = ["telegram", "discord", "steam", "spotify"]
ACTIVE_WS = 2


def tz_offsets() -> dict:
    from datetime import datetime
    from zoneinfo import ZoneInfo, available_timezones
    now = datetime.now()
    out = {}
    for z in available_timezones():
        if "/" in z and not z.startswith(("Etc", "SystemV", "posix", "right")):
            out[z] = now.astimezone(ZoneInfo(z)).strftime("%z")
    return out


def config_extra(domains: dict) -> str:
    notch = domains.get("notch", {})
    # Like Config.qml: notch.style, else the legacy notch.theme
    style = notch.get("style") or ("attached" if notch.get("theme", "default") == "default" else "island")
    return f"""
    property bool barReady: true
    property bool dockReady: true
    property bool notchReady: true
    property bool workspacesReady: true
    property bool showBackground: theme.srBarBg.opacity > 0
    property string notchStyle: {json.dumps(style)}
    property string notchTheme: {json.dumps("default" if style == "attached" else "island")}
    property string notchPosition: {json.dumps(notch.get("position", "top"))}
    property QtObject pinnedApps: QtObject {{ property var apps: {json.dumps(PINNED)} }}
    function savePinnedApps() {{}}
"""


# Window geometry per workspace on a 2560x1440 screen (workspace previews)
LAYOUTS = {
    1: [("code", (12, 52, 2536, 1376))],
    2: [("firefox", (12, 52, 1480, 1376)), ("kitty", (1504, 52, 1044, 1376))],
    3: [("discord", (12, 52, 2536, 1376))],
    4: [("spotify", (12, 52, 1260, 1376)), ("kitty", (1284, 52, 1264, 680)), ("kitty", (1284, 744, 1264, 684))],
}


def _windows_map() -> str:
    out = {}
    for ws, wins in LAYOUTS.items():
        out[str(ws)] = [{"class": app, "at": [g[0], g[1]], "size": [g[2], g[3]], "workspace": {"id": ws}}
                        for app, g in wins]
    return json.dumps(out)


COMPOSITOR_DATA = """pragma Singleton
import QtQuick
QtObject {
    property var specialWorkspaceNames: ({})
    property var windowList: []
    property var monitors: []
    property var workspaceOccupationMap: ({ "1": true, "2": true, "3": true, "4": true })
    property var workspaceWindowsMap: (""" + _windows_map() + """)
    function monitorHasFullscreen(m) { return false; }
    function refreshSpecialWorkspaces() {}
}
"""

ACTIVITY_SERVICE = """pragma Singleton
QtObject { property string presentation: "notch"; property int count: 0; property var items: [] }
"""

GLOBAL_STATES = """pragma Singleton
QtObject {
    signal barPinToggled()
    property bool launcherOpen: false
    property bool dashboardOpen: false
    property int dashboardCurrentTab: 0
    property bool presetsOpen: false
    property int widgetsTabCurrentIndex: 0
    property bool assistantVisible: false
    property bool assistantPinned: false
    property int assistantEffectiveWidth: 0
    property string assistantPosition: "right"
    property string assistantScreenName: ""
    property string compositorLayout: "dwindle"
    property var availableLayouts: ["dwindle", "master", "scrolling"]
    property QtObject wallpaperManager: QtObject { property string currentWallpaper: "" }
    function clearLauncherState() {}
    function setCompositorLayout(l) { compositorLayout = l }
}
"""


def _toplevels() -> str:
    items = []
    for app, ws, title, active in WINDOWS:
        items.append(f'{{ appId: "{app}", title: {json.dumps(title)}, activated: {str(active).lower()}, '
                     f'workspace: {{ id: {ws} }}, wayland: null, activate: function() {{}}, close: function() {{}} }}')
    return "[" + ", ".join(items) + "]"


def services(icon_path) -> dict:
    icons = {a: icon_path(a) for a in set(APPS + TRAY)}
    apps = []
    for app in dict.fromkeys(PINNED + ["SEPARATOR"] + [w[0] for w in WINDOWS]):
        if app == "SEPARATOR":
            apps.append('{ appId: "SEPARATOR", pinned: false, toplevels: [], toplevelCount: 0 }')
            continue
        tops = [w for w in WINDOWS if w[0] == app]
        tl = ", ".join(f'{{ appId: "{app}", title: {json.dumps(t)}, activated: {str(a).lower()}, '
                       f'activate: function() {{}} }}' for _, _, t, a in tops)
        apps.append(f'{{ appId: "{app}", pinned: {str(app in PINNED).lower()}, toplevels: [{tl}], '
                    f'toplevelCount: {len(tops)} }}')
    return {
        "OsdService": """pragma Singleton
QtObject {
    signal controlsRequested(string screenName)
    signal inlineRequest(string kind)
    signal level(string kind, real value, bool muted, string device)
    property int timeout: 2500
    property real lastValue: 0
    property bool lastMuted: false
    function registerInline(on) {}
}""",
        "Visibilities": """pragma Singleton
QtObject {
    id: v
    property var screens: ({})
    property var bars: ({})
    property var barPanels: ({})
    property var notches: ({})
    property var notchPanels: ({})
    property var docks: ({})
    property var dockPanels: ({})
    property var barPopupGroups: ({})
    property string currentActiveModule: ""
    property bool playerMenuOpen: false
    property var contextMenu: null
    readonly property QtObject screenState: QtObject {
        property bool launcher: false; property bool dashboard: false; property bool powermenu: false
        property bool tools: false; property bool presets: false; property bool voice: false
        property bool aiquick: false; property bool overview: false
    }
    function getForScreen(n) { return screenState }
    function getForActive() { return screenState }
    function setActiveModule(m) { currentActiveModule = m }
    function registerBarPopup(p) {}
    function unregisterBarPopup(p) {}
    function registerBar(n, b) { const m = Object.assign({}, bars); m[n] = b; bars = m }
    function unregisterBar(n) {}
    function registerBarPanel(n, b) {}
    function unregisterBarPanel(n) {}
    function getNotchForScreen(n) { return notches[n] || null }
    function getBarPanelForScreen(n) { return barPanels[n] || null }
    function setContextMenu(m) { contextMenu = m }
}""",
        "YozdService": f"""pragma Singleton
QtObject {{
    property string compositorName: "hyprland"
    readonly property QtObject monitor: QtObject {{
        property string name: "DP-1"
        property int x: 0
        property int y: 0
        property var activeWorkspace: ({{ id: {ACTIVE_WS}, name: "{ACTIVE_WS}" }})
    }}
    property var focusedMonitor: monitor
    property var focusedClient: ({{ address: "0xf1", "class": "{WINDOWS[0][0]}", title: {json.dumps(WINDOWS[0][2])}, workspace: {{ id: {ACTIVE_WS} }} }})
    property var monitors: ({{ values: [monitor] }})
    property var workspaces: ({{ values: [1, 2, 3, 4, 5, 6].map(i => ({{ id: i, name: String(i) }})) }})
    property var clients: ({{ values: {_toplevels()} }})
    property var toplevels: ({{ values: {_toplevels()} }})
    function monitorFor(s) {{ return monitor }}
    function dispatch(c) {{}}
}}""",
        "AppSearch": f"""pragma Singleton
QtObject {{
    readonly property var icons: ({json.dumps(icons)})
    function guessIcon(appId) {{ return appId }}
    function getCachedIcon(appId) {{ return appId }}
    function launchApp(e) {{}}
}}""",
        "Audio": """pragma Singleton
QtObject {
    property var sink: ({ audio: { volume: 0.62, muted: false }, description: "Speakers" })
    property var source: ({ audio: { volume: 0.8, muted: false }, description: "Mic" })
}""",
        "Battery": """pragma Singleton
QtObject {
    property bool available: true
    property real percentage: 82
    property bool isCharging: false
    property bool isPluggedIn: false
    property real timeToEmpty: 14400
    property real timeToFull: 0
    function getBatteryIcon() { return "" }
}""",
        "Brightness": """pragma Singleton
QtObject { property var monitors: []; function getMonitorForScreen(s) { return null } function syncBrightness() {} }""",
        "MprisController": """pragma Singleton
QtObject {
    property var activePlayer: null
    property var filteredPlayers: []
    property int loopState: 0
    property bool hasShuffle: false
    property bool shuffleSupported: false
    property bool loopSupported: false
    property bool canGoPrevious: false
    property bool canGoNext: false
    property bool canTogglePlaying: false
    function togglePlaying() {} function previous() {} function next() {} function cyclePlayer() {}
    function setActivePlayer(p) {} function setLoopState(s) {} function setShuffle(s) {}
}""",
        "Notifications": """pragma Singleton
QtObject {
    property var popupList: []; property var notchPopupList: []; property bool silent: false; property var appNameList: []
    function showsOnScreen(name) { return true }
    property var groupsByAppName: ({})
    function discardAllNotifications() {} function notifyInternal() {}
}""",
        "NumeralFonts": """pragma Singleton
QtObject { function family(t) { return "" } function weight(t) { return Font.Normal } }""",
        "GameModeClient": """pragma Singleton
QtObject { property bool toggled: false }""",
        "PowerProfileClient": """pragma Singleton
QtObject {
    property string currentProfile: "balanced"; property var availableProfiles: ["power-saver", "balanced", "performance"]
    property bool isAvailable: true
    function getProfileIcon(p) { return "" } function getProfileDisplayName(p) { return p }
    function setProfile(p) {} function refresh() {}
}""",
        "StateService": """pragma Singleton
QtObject { property var systrayHidden: []; function get(k, d) { return d } function set(k, v) {} }""",
        "SuspendManager": """pragma Singleton
QtObject { property bool isSuspending: false; property bool wakeReady: true }""",
        "FocusGrabManager": """pragma Singleton
QtObject { property bool hasActiveGrab: false; function clearTopGrab() {} function register(g) {} function unregister(g) {} }""",
        "FocusGrab": "QtObject { property var windows: []; property bool active: false; signal cleared() }",
        "TaskbarApps": f"""pragma Singleton
QtObject {{
    property var apps: [{", ".join(apps)}]
    function isPinned(a) {{ return {json.dumps(PINNED)}.indexOf(a) !== -1 }}
    function togglePin(a) {{}}
    function launchApp(a) {{}}
    function getDesktopEntry(a) {{ return null }}
}}""",
        "WeatherService": """pragma Singleton
QtObject {
    property bool dataAvailable: true
    property string weatherSymbol: "⛅"
    property real currentTemp: 18
    property real maxTemp: 21
    property real minTemp: 12
    property string weatherDescription: "Partly cloudy"
    property string effectiveWeatherDescription: weatherDescription
    property bool effectiveIsDay: false
    property bool isLoading: false
    property bool debugMode: false
    property real debugHour: 12
    property int debugWeatherCode: 0
    property var forecast: []
    property real effectiveSunProgress: 0.5
    property var effectiveTimeBlend: ({})
    property string effectiveWeatherEffect: ""
    property real effectiveWeatherIntensity: 0
    function updateWeather() {}
}""",
        "SystemResources": """pragma Singleton
QtObject {
    property real cpuUsage: 23.4
    property int cpuTemp: 48
    property real ramUsage: 41.2
    property real ramTotal: 33554432
    property real ramUsed: 13824000
    property int gpuTemp: 52
    property real gpuUsage: 12
    property bool gpuDetected: true
    property real netRxRate: 2621440
    property real netTxRate: 184320
    property var consumers: ({})
    function setConsumer(key, active) { const c = Object.assign({}, consumers); if (active) c[key] = true; else delete c[key]; consumers = c }
}""",
    }


def quickshell_modules(icon_path) -> dict:
    mods = dict(QUICKSHELL_MODULES)
    tray = dict(mods["Quickshell.Services.SystemTray"])
    items = " ".join(f'SystemTrayItem {{ title: "{t}"; tooltipTitle: "{t}"; icon: "file://{icon_path(t)}" }}' for t in TRAY)
    tray["SystemTray"] = ("pragma Singleton\nQtObject {\n"
                          f"property list<SystemTrayItem> all: [{items.replace('} S', '}, S')}]\n"
                          "readonly property var items: ({ values: all })\n}")
    mods["Quickshell.Services.SystemTray"] = tray
    return mods


QUICKSHELL_MODULES = {
    "Quickshell": {
        "Singleton": "QtObject { default property list<QtObject> data }",
        "Quickshell": "pragma Singleton\nQtObject { property var screens: []; property string shellDir: \"\"; "
                      "function env(n) { return n === 'HOME' ? '/home/user' : '' } "
                      "function iconPath(n, f) { return 'image://icon/' + n } function execDetached(a) {} }",
        "ShellScreen": "QtObject { property string name: \"DP-1\"; property int width: 2560; property int height: 1440 }",
        "PopupAnchorRect": "QtObject { property real x; property real y; property real width; property real height }",
        "PopupAnchor": "QtObject { property Item item; property var window; property int edges; property int gravity; "
                       "property int adjustment; readonly property PopupAnchorRect rect: PopupAnchorRect {} "
                       "signal anchoring() }",
        # Drawn in place, at its anchor (renders can open bar popups)
        "PopupWindow": "Item { id: pw; visible: false; z: 1000; property color color; property var mask; "
                       "property var screen; readonly property PopupAnchor anchor: PopupAnchor {}\n"
                       "x: anchor.item && parent ? anchor.item.mapToItem(parent, anchor.rect.x, anchor.rect.y).x : 0\n"
                       "y: anchor.item && parent ? anchor.item.mapToItem(parent, anchor.rect.x, anchor.rect.y).y : 0\n"
                       "width: implicitWidth; height: implicitHeight }",
        "PanelWindow": "Item { property color color; property var mask; property var screen; property int exclusiveZone; "
                       "property int exclusionMode; property var anchors2; property bool aboveWindows; "
                       "property var margins }",
        "QsMenuOpener": "QtObject { property var menu; property var children: ({ values: [] }) }",
        "QsMenuAnchor": "QtObject { property var menu; property var anchor; function open() {} }",
        "Variants": "Item { property var model; property Component delegate }",
        "ScriptModel": "QtObject { property var values: [] }",
        "DesktopEntries": "pragma Singleton\nQtObject { function heuristicLookup(a) { return null } "
                          "property var applications: ({ values: [] }) }",
        "LazyLoader": "Item { property bool active; property bool loading; property Component component }",
        "Region": "QtObject { property Item item; property var regions: []; property int intersection }",
    },
    "Quickshell.Widgets": {
        "ClippingRectangle": "Rectangle { clip: true; property bool contentUnderBorder: false }",
        "ClippingWrapperRectangle": "Rectangle { clip: true; property real margin }",
        "IconImage": "Image { property real implicitSize: 16; property bool asynchronous2; "
                     "sourceSize.width: implicitSize * 2; sourceSize.height: implicitSize * 2; "
                     "width: implicitSize; height: implicitSize; fillMode: Image.PreserveAspectFit }",
    },
    "Quickshell.Wayland": {
        "Toplevel": "QtObject { property string title; property string appId; property bool activated; "
                    "property bool fullscreen; property bool maximized; function activate() {} function close() {} }",
        "ToplevelManager": "pragma Singleton\nQtObject { "
                           "readonly property Toplevel activeToplevel: Toplevel { "
                           f"title: {json.dumps(WINDOWS[0][2])}; appId: \"{WINDOWS[0][0]}\"; activated: true }} "
                           "property var toplevels: ({ values: [] }) }",
        "WlrLayershell": "QtObject { property int layer; property int keyboardFocus; property string namespace }",
        "WlrLayer": "QtObject { readonly property int Overlay: 3; readonly property int Top: 2 }",
        "WlrKeyboardFocus": "QtObject { readonly property int None: 0; readonly property int Exclusive: 1; "
                            "readonly property int OnDemand: 2 }",
    },
    "Quickshell.Io": {
        # `sh -c 'for z ...; do TZ=$z date +%z'` (WorldClocks) answers from the tz database
        "Process": "QtObject { id: p; property var command: []; property bool running: false; property var stdout; "
                   "property var stderr; property var environment\nsignal exited(int exitCode, int exitStatus)\n"
                   "signal started()\nfunction startDetached() {}\n"
                   f"readonly property var tzOffsets: ({json.dumps(tz_offsets())})\n"
                   "onRunningChanged: if (running && command.length > 4 && String(command[2]).indexOf('date +%z') !== -1 "
                   "&& stdout) { stdout.text = command.slice(4).map(z => tzOffsets[z] || '+0000').join('\\n'); "
                   "stdout.streamFinished(); running = false }"
                   " }",
        "StdioCollector": "QtObject { property string text: ''; property bool waitForEnd; signal streamFinished() }",
        "SplitParser": "QtObject { signal read(string data) }",
        "IpcHandler": "QtObject { property string target; property bool enabled: true }",
        "FileView": "QtObject { property string path; property bool watchChanges; property bool blockLoading; "
                    "property bool printErrors; function text() { return '' } function reload() {} "
                    "signal loaded() signal fileChanged() signal loadFailed(var error) }",
    },
    "Quickshell.Services.SystemTray": {
        "SystemTrayItem": "QtObject { property string title; property string icon; property string tooltipDescription; "
                          "property string tooltipTitle; property bool hasMenu; property bool onlyMenu; "
                          "property var menu; function activate() {} function secondaryActivate() {} "
                          "function scroll(d, h) {} function display(w, x, y) {} }",
        "SystemTray": "pragma Singleton\nQtObject { property var items: ({ values: [] }) }",
        "Status": "QtObject { readonly property int Passive: 0; readonly property int Active: 1; "
                  "readonly property int NeedsAttention: 2 }",
    },
    "Quickshell.Services.Mpris": {
        "MprisLoopState": "QtObject { readonly property int None: 0; readonly property int Track: 1; "
                          "readonly property int Playlist: 2 }",
        "MprisPlaybackState": "QtObject { readonly property int Stopped: 0; readonly property int Playing: 1; "
                              "readonly property int Paused: 2 }",
        "Mpris": "pragma Singleton\nQtObject { property var players: ({ values: [] }) }",
    },
    "Quickshell.Hyprland": {
        "HyprlandFocusGrab": "QtObject { property var windows: []; property bool active; signal cleared() }",
        "Hyprland": "pragma Singleton\nQtObject { function dispatch(c) {} property var focusedMonitor: null }",
    },
}


LEGACY_HOST = """Item {
            id: host
            anchors.fill: parent
            z: 2
            readonly property alias primary: legacyBar
            readonly property var zones: ({ top: 0, bottom: 0, left: 0, right: 0 })
            readonly property var containSides: ({ top: 0, bottom: 0, left: 0, right: 0 })
            BarContent { id: legacyBar; objectName: "host"; anchors.fill: parent; screen: scr }
        }"""


def scene_qml(width: int, height: int, wallpaper: str, windows: bool, notch_text: str,
              legacy: bool = False) -> str:
    host = LEGACY_HOST if legacy else 'PanelHost { id: host; objectName: "host"; anchors.fill: parent; screen: scr; z: 2 }'
    shell_import = "" if legacy else "import qs.modules.shell"
    # Shadows like the live shell: one caster per surface (old trees: one layer)
    shadows = ("layer.enabled: true\n        layer.effect: Shadow {}" if legacy else
               "PanelShadows { anchors.fill: parent; z: 0; frame: frameItem; bars: host.bars }\n"
               "        ShadowCaster { z: 0; source: notch; sourceRect: Qt.rect(notch.x - 24, notch.y, notch.width + 48, "
               "notch.height + 24) }")
    text = notch_text or "Pull Me Under"
    wall = f'Image {{ anchors.fill: parent; source: "file://{wallpaper}"; fillMode: Image.PreserveAspectCrop; ' \
           f'sourceSize.width: {width} }}' if wallpaper else "Rectangle { anchors.fill: parent; color: Colors.background }"
    return f"""
import QtQuick
import QtQuick.Window
import Quickshell
import qs.config
import qs.modules.theme
import qs.modules.services
import qs.modules.globals
import qs.modules.components
import qs.modules.bar
import qs.modules.frame
import qs.modules.notch
{shell_import}

Window {{
    id: win
    width: {width}; height: {height}; visible: true; color: "black"

    ShellScreen {{ id: scr; name: "DP-1"; width: {width}; height: {height} }}
    property alias host: host
    readonly property int frame: Config.bar.frameEnabled ? Config.bar.frameThickness : 0

    {wall}

    // Tiled windows in the work area the panels leave free
    Item {{
        id: workArea
        visible: {str(windows).lower()}
        x: win.frame + host.zones.left + 10
        y: win.frame + host.zones.top + 10
        width: win.width - x - win.frame - host.zones.right - 10
        height: win.height - y - win.frame - host.zones.bottom - 10
        Repeater {{
            model: [[0, 0, 0.58, 1], [0.58, 0, 0.42, 0.55], [0.58, 0.55, 0.42, 0.45]]
            delegate: Rectangle {{
                required property var modelData
                required property int index
                x: modelData[0] * workArea.width + (index > 0 ? 5 : 0)
                y: modelData[1] * workArea.height + (index === 2 ? 5 : 0)
                width: modelData[2] * workArea.width - (index > 0 ? 5 : 5)
                height: modelData[3] * workArea.height - (index === 1 ? 5 : 0)
                radius: Math.max(0, Config.roundness - 4)
                color: Qt.rgba(Colors.surfaceContainerLow.r, Colors.surfaceContainerLow.g, Colors.surfaceContainerLow.b, 0.93)
                border.width: 2
                border.color: index === 0 ? Colors.primary : Qt.rgba(Colors.outlineVariant.r, Colors.outlineVariant.g, Colors.outlineVariant.b, 0.6)
                Column {{
                    x: 22; y: 18; spacing: 12
                    Repeater {{
                        model: index === 0 ? 9 : 4
                        Rectangle {{
                            required property int index
                            width: [360, 520, 280, 440, 610, 230, 390, 470, 300][index % 9] * (workArea.width / 2400)
                            height: 9; radius: 4
                            color: index === 0 ? Colors.primary : Colors.outlineVariant
                            opacity: index === 0 ? 0.8 : 0.45
                        }}
                    }}
                }}
            }}
        }}
    }}

    QtObject {{
        id: barProxy
        readonly property string barPosition: host.primary ? host.primary.barPosition : "top"
        readonly property bool reveal: host.primary ? host.primary.reveal : true
        readonly property bool pinned: true
        readonly property bool hoverActive: false
        readonly property bool barHoverActive: false
        readonly property bool notchHoverActive: false
        readonly property bool notchOpen: false
        readonly property bool notchReveal: true
        readonly property var panelContainSides: host.containSides
        readonly property var panelZones: host.zones
        readonly property int barTargetHeight: host.primary ? host.primary.barTargetHeight : 0
        readonly property int barTargetWidth: host.primary ? host.primary.barTargetWidth : 0
    }}
    Component.onCompleted: {{
        Visibilities.barPanels = {{ "DP-1": barProxy }};
        Visibilities.notchPanels = {{ "DP-1": barProxy }};
        Visibilities.notches = {{ "DP-1": notch }};
        GlobalStates.wallpaperManager.currentWallpaper = {json.dumps(wallpaper)};
    }}

    Item {{
        id: visual
        anchors.fill: parent
        {shadows}

        ScreenFrameContent {{ id: frameItem; anchors.fill: parent; targetScreen: scr; z: 1 }}
        {host}
        Notch {{
            id: notch
            objectName: "notch"
            visible: !Config.notch.keepHidden
            z: 4
            width: implicitWidth; height: implicitHeight
            x: (parent.width - width) / 2
            y: Config.notchPosition === "bottom" ? parent.height - height - win.frame : win.frame
            visibilities: Visibilities.getForScreen("DP-1")
            defaultViewComponent: Component {{
                Item {{
                    implicitWidth: 380
                    implicitHeight: Config.notchTheme === "island" ? BarMetrics.notchIslandHeight : BarMetrics.notchRestHeight
                    Row {{
                        anchors.centerIn: parent; spacing: 10
                        Rectangle {{ width: 24; height: 24; radius: 12; color: Colors.primary; opacity: 0.85; anchors.verticalCenter: parent.verticalCenter }}
                        Text {{ text: {json.dumps(text)}; font.bold: true; font.family: Config.theme.font; font.pixelSize: 14; color: Colors.overBackground; anchors.verticalCenter: parent.verticalCenter }}
                        Text {{ text: "Dream Theater"; font.family: Config.theme.font; font.pixelSize: 13; color: Colors.overSurfaceVariant; anchors.verticalCenter: parent.verticalCenter }}
                    }}
                }}
            }}
        }}
    }}
}}
"""
