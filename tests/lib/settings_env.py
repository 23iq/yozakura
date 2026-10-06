"""Offscreen environment for the settings UI (modules/settings).

Builds a Harness where the settings, components, Styling and Icons are the
real repo files (mirrored under <root>/qs/...) and only the shell singletons
are generated:
  * Config     - every domain from config/defaults/*.js as typed properties
                 (optionally merged with the user's ~/.config/yozakura/config)
  * Colors     - every role of modules/theme/Colors.qml from a palette dict
  * I18n       - translations/en.json
  * GlobalStates - snapshot flags + a wallpaper manager stub
  * Quickshell, Quickshell.Io, Quickshell.Widgets - inert stand-ins

Used by tests/settings-ui.test.py and tools/render/settings_render.py.
"""
from __future__ import annotations

import json
import re
import shutil
import subprocess
from pathlib import Path

from qmlharness import HARNESS_HOME, REPO, Harness, brand_qml

DEFAULT_PALETTE = {
    "background": "#120c0d", "surface": "#1a1112", "surfaceDim": "#1a1112", "surfaceBright": "#413737",
    "surfaceContainerLowest": "#140c0d", "surfaceContainerLow": "#22191a", "surfaceContainer": "#271d1e",
    "surfaceContainerHigh": "#312828", "surfaceContainerHighest": "#3d3233", "surfaceVariant": "#524344",
    "primary": "#ffb2b8", "overPrimary": "#561d25", "primaryContainer": "#72333a", "overPrimaryContainer": "#ffdadb",
    "secondary": "#e5bdbf", "overSecondary": "#44292b", "secondaryContainer": "#5c3f41",
    "overSecondaryContainer": "#ffdadb", "tertiary": "#e8c08e", "overTertiary": "#442b06",
    "tertiaryContainer": "#5d411a", "overTertiaryContainer": "#ffddb5", "overBackground": "#f0dedf",
    "overSurface": "#f0dedf", "overSurfaceVariant": "#d7c1c2", "outline": "#9f8c8d", "outlineVariant": "#524344",
    "error": "#ffb4ab", "overError": "#690005", "shadow": "#000000",
}

USER_CONFIG = Path.home() / ".config" / "yozakura" / "config"
USER_BINDS = Path.home() / ".config" / "yozakura" / "binds.json"
APP_ID = "yozakura"
# Brand.cacheDir inside the harness (HOME = qmlharness.HARNESS_HOME).
BRAND_CACHE = Path(HARNESS_HOME) / ".cache" / APP_ID

# AI center editors read the agents/MCP state from the Ai service.
AI_STUB = """pragma Singleton
QtObject {
    property var agents: QtObject {
        property var agents: [{ id: "claude", label: "Claude Code", available: true, version: "2.1" },
                              { id: "codex", label: "Codex", available: false, version: "" }]
    }
    property var mcp: QtObject {
        property var servers: [{ name: "yozakura", source: "yozakura", transport: "stdio", command: "yozakura", args: ["mcp"] }]
        function isEnabled(name) { return true; }
        function setEnabled(name, on) {}
        function serverTools(name, cb) { cb([], ""); }
        function refresh() {}
    }
    property var models: [{ id: "anthropic:claude-sonnet-4-5", name: "Claude Sonnet 4.5", provider: "anthropic", kind: "api" }]
    // Provider connections (services/ai/ProviderSetup.qml): scripted.
    property var providers: QtObject {
        property var hidden: []
        property var saved: []
        function status(id) { return { state: id === "ollama" ? "connected" : "none", connected: id === "ollama", local: id === "ollama" || id === "lmstudio" }; }
        function current(id) { return { key: "", url: "", curl: "" }; }
        function test(id, key, url, cb) { cb({ ok: true, verified: true, count: 2, error: "", models: [] }); }
        function save(id, key, url, curl) { saved = saved.concat([id]); return true; }
        function disconnect(id) {}
        function setHidden(id, hide) { hidden = hide ? hidden.concat([id]) : hidden.filter(h => h !== id); }
    }
    function _ensureInit() {}
}"""

# Services the System / Terminal / Notifications editors read.
BACKEND_STUB = """pragma Singleton
QtObject {
    property var calls: []
    function call(method, params, cb) {
        calls = calls.concat([method]);
        if (cb && method === "voice.status")
            cb({ installed: true, modelPresent: true, serverRunning: false, backend: "vulkan" }, null);
    }
}"""

# Routines (modules/services/RoutinesService.qml): the routines editor, the
# "Run routine" bind picker and the per-routine keybind slots. Saves, runs
# and deletes are recorded in `calls`; callbacks answer right away.
ROUTINES_STUB = """pragma Singleton
import QtQuick
QtObject {
    property var routines: []
    property var calls: []
    property var nextReport: ({ "ok": true, "steps": [] })
    function find(ref) { return routines.find(r => r.id === ref) || null }
    function refresh() { calls = calls.concat([["refresh"]]) }
    function call(method, params, cb) {
        calls = calls.concat([[method, params]]);
        if (cb) cb(method === "run" ? nextReport : {}, "");
    }
    function save(r, replace, cb) {
        calls = calls.concat([["save", r, replace]]);
        const id = replace || String(r.name || "routine").toLowerCase().replace(/[^a-z0-9]+/g, "-");
        const saved = Object.assign({}, r, { "id": id });
        const i = routines.findIndex(x => x.id === id);
        const next = routines.slice();
        if (i >= 0) next[i] = saved; else next.push(saved);
        routines = next;
        if (cb) cb({ "routine": saved }, "");
    }
    function remove(id, cb) {
        calls = calls.concat([["delete", id]]);
        routines = routines.filter(x => x.id !== id);
        if (cb) cb({}, "");
    }
    function run(id, cb) { calls = calls.concat([["run", id]]); if (cb) cb(nextReport, "") }
    function test(r, cb) { calls = calls.concat([["test", r]]); if (cb) cb(nextReport, "") }
}"""

UPDATE_STUB = """pragma Singleton
QtObject {
    property string currentVersion: "1.3.9"
    property string lastDetectedVersion: ""
    property real lastCheckTime: 0
    property bool checking: false
    property string changelogUrl: "https://example.invalid/releases"
    property int checks: 0
    function checkUpdates() { checks++ }
    function isNewer(a, b) { return a > b }
}"""

NOTIFICATIONS_STUB = """pragma Singleton
QtObject {
    property string presentation: "notch"
    property string cornerPosition: "top-right"
    property bool silent: false
    property var sent: []
    function notifyInternal(o) { sent = sent.concat([o]); return null }
}"""

# Keybind edits ask the compositor TOML to be rewritten.
TOML_WRITER_STUB = """pragma Singleton
QtObject { property int writes: 0; function callWrite() { writes++ } }"""

MIRROR = [
    "modules/settings",
    "modules/components",
    "modules/aicenter/common",
    "modules/aicenter/providers",
    "modules/aicenter/agent/SettingsChoice.qml",
    "modules/aicenter/header/CapabilityBadges.qml",
    "modules/services/ai/ProviderConnect.js",
    "modules/services/ai/ProviderPresets.js",
    "modules/services/ai/Providers.js",
    "modules/services/ai/Effort.js",
    "modules/services/ai/ModelInfo.js",
    "modules/services/ai/ContextMath.js",
    "assets/aiproviders",
    "modules/keybinds",
    "assets/yozakura/super-key.svg",
    "config/KeybindActions.js",
    "config/CoreBinds.js",
    "modules/globals/BrandActions.js",
    "modules/globals/Urls.js",
    "modules/services/ai/Cron.js",
    "modules/services/ai/Automations.js",
    "modules/routines",
    "modules/theme/Styling.qml",
    "modules/theme/Glass.qml",
    "modules/theme/GlassModel.js",
    "modules/theme/GlassCurve.js",
    "modules/theme/GlassContrast.js",
    "modules/theme/Icons.qml",
    "modules/theme/AppThemes.js",
    "modules/notifications/NotificationPolicy.js",
    "modules/services/voice/VoiceModel.js",
    "config/defaults",
    "config/ColorSpec.js",
    "config/motion",
    "modules/services/CompositorAppearance.js",
    "modules/bar/BarLayout.js",
    "modules/bar/BarModuleRegistry.js",
    "modules/bar/panels/PanelStyles.js",
    "modules/bar/panels/PanelLayout.js",
    "modules/bar/workspaces/WorkspaceNumerals.js",
    "modules/bar/workspaces/indicators",
    "modules/widgets/dashboard/wallpapers/WallpaperFolders.js",
    "modules/widgets/launcher/Providers.js",
    "modules/specials/Specials.js",
    "modules/widgets/dashboard/wallpapers/wallpaper_transition.frag.qsb",
    "modules/widgets/dashboard/wallpapers/WallpaperCoverage.js",
    "modules/widgets/defaultview/NotchVisualizer.qml",
    "modules/desktop",
    # Lock screen style gallery: the real lock screen view and its styles.
    "modules/lockscreen",
    "modules/widgets/dashboard/wallpapers/palette.vert.qsb",
    "modules/widgets/dashboard/wallpapers/palette.frag.qsb",
    "assets/fonts/clock",
]

# Services read by the Desktop & Clock page (depth clock previews, widget
# previews): idle stand-ins.
DESKTOP_STUBS = {
    "DepthMaskService": "pragma Singleton\nQtObject { property bool available: true; property string matteJob: ''; "
                        "property real matteProgress: 0; function result(p, w, h) { return null } function request(p, w, h) {} }",
    "DesktopService": "pragma Singleton\nQtObject { property int maxRowsHint: 6; property int maxColumnsHint: 10; "
                      "property QtObject items: QtObject { property int count: 0 } }",
    "MprisController": "pragma Singleton\nQtObject { property var activePlayer: null; property bool isPlaying: false; "
                       "property bool canTogglePlaying: false; property bool canGoPrevious: false; property bool canGoNext: false; "
                       "function togglePlaying() {} function previous() {} function next() {} }",
    "CavaService": "pragma Singleton\nQtObject { property bool available: false; property var consumers: ({}); "
                   "function setConsumer(k, a) { consumers[k] = a } function levels(n) { return [] } }",
    "SystemResources": "pragma Singleton\nQtObject { property real cpuUsage: 23; property real ramUsage: 48; property int gpuTemp: 54; "
                       "property var cpuHistory: [0.2, 0.3, 0.25, 0.4, 0.23]; property var ramHistory: [0.45, 0.46, 0.48, 0.47, 0.48]; "
                       "property var gpuTempHistories: [[50, 52, 54, 53, 54]]; property var consumers: ({}); "
                       "function setConsumer(k, a) { consumers[k] = a } }",
    "WeatherService": "pragma Singleton\nQtObject { property bool dataAvailable: true; property bool isLoading: false; "
                      "property bool hasFailed: false; property string weatherSymbol: '☀'; property real currentTemp: 18; "
                      "property real maxTemp: 21; property real minTemp: 11; property string weatherDescription: 'Clear sky'; "
                      "property var forecast: [{dayName: 'Today', emoji: '☀', maxTemp: 21, minTemp: 11}, "
                      "{dayName: 'Tue', emoji: '⛅', maxTemp: 19, minTemp: 10}, {dayName: 'Wed', emoji: '🌧', maxTemp: 15, minTemp: 9}, "
                      "{dayName: 'Thu', emoji: '☀', maxTemp: 20, minTemp: 12}, {dayName: 'Fri', emoji: '☀', maxTemp: 22, minTemp: 13}]; "
                      "function updateWeather() {} }",
}


def load_defaults() -> dict:
    script = """
const q = require(process.argv[1]);
const fs = require('fs'), path = require('path');
const dir = process.argv[2]; const out = {};
for (const f of fs.readdirSync(dir)) if (f.endsWith('.js'))
  out[f.slice(0, -3)] = q.loadLibrary(path.join(dir, f)).data;
console.log(JSON.stringify(out));
"""
    r = subprocess.run(["node", "-e", script, str(REPO / "tests/lib/qmljs.cjs"), str(REPO / "config/defaults")],
                       capture_output=True, text=True, check=True)
    return json.loads(r.stdout)


def _merge(base: dict, over: dict) -> dict:
    out = dict(base)
    for k, v in over.items():
        if k in out and isinstance(out[k], dict) and isinstance(v, dict) and not k.startswith("sr"):
            out[k] = _merge(out[k], v)
        elif k in out:
            out[k] = v
    return out


def _literal(v) -> tuple[str, str]:
    if isinstance(v, bool):
        return "bool", "true" if v else "false"
    if isinstance(v, (int, float)):
        return "real", json.dumps(v)
    if isinstance(v, str):
        return "string", json.dumps(v)
    return "var", "(" + json.dumps(v) + ")"


def default_binds() -> dict:
    """binds.json with the core binds of config/CoreBinds.js, no custom ones."""
    script = """
const q = require(process.argv[1]);
const C = q.loadLibrary(process.argv[2]);
const root = {};
for (const e of C.BINDS) {
  const holder = e.section ? (root[e.section] = root[e.section] || {}) : root;
  holder[e.name] = C.defaultBind(e);
}
console.log(JSON.stringify(root));
"""
    r = subprocess.run(["node", "-e", script, str(REPO / "tests/lib/qmljs.cjs"), str(REPO / "config/CoreBinds.js")],
                       capture_output=True, text=True, check=True)
    return {APP_ID: json.loads(r.stdout), "custom": [], "disabled": []}


def keybinds_qml(binds: dict) -> str:
    """Config.keybindsLoader stand-in: a FileView-like object whose adapter
    holds binds.json as plain values (KeybindsStore re-reads on revision)."""
    return f"""
    property QtObject keybindsLoader: QtObject {{
        signal loaded()
        signal fileChanged()
        property int reloads: 0
        function reload() {{ reloads++ }}
        property QtObject adapter: QtObject {{
            property var {APP_ID}: ({json.dumps(binds.get(APP_ID, {}))})
            property var custom: ({json.dumps(binds.get("custom", []))})
            property var disabled: ({json.dumps(binds.get("disabled", []))})
        }}
    }}
"""


def config_qml(domains: dict, extra: str = "") -> str:
    parts = []
    for name, data in sorted(domains.items()):
        props = "\n".join(f"        property {t} {k}: {lit}" for k, (t, lit) in
                          ((k, _literal(v)) for k, v in data.items()))
        parts.append(f"    property QtObject {name}: QtObject {{\n{props}\n    }}")
    saves = "\n".join(f"    function save{n[0].upper()}{n[1:]}() {{ saved.push(\"{n}\") }}" for n in sorted(domains))
    return f"""pragma Singleton
import QtQuick
import qs.modules.theme
import "ColorSpec.js" as ColorSpec
QtObject {{
    id: root
{chr(10).join(parts)}
    property var saved: []
    property bool keybindsInitialLoadComplete: true
    property bool specialsReady: true
    property bool pauseAutoSave: false
    property bool initialLoadComplete: true
    property string version: "1.3.9"
    property string configDir: "/tmp/yozakura-config"
    property bool lightMode: theme.lightMode
    property bool oledMode: lightMode ? false : theme.oledMode
    property int roundness: theme.roundness
    property string defaultFont: theme.font
    property int animDuration: theme.animDuration
    property bool tintIcons: theme.tintIcons
{saves}
    function isHexColor(c) {{ return typeof c === "string" && (c.trim().startsWith("#") || c.trim().startsWith("rgb")); }}
    function resolveColor(v) {{
        if (!v) return "transparent";
        const spec = ColorSpec.parse(v);
        if (spec.alpha !== null) {{
            const base = resolveColor(spec.base);
            const c = (typeof base === "string") ? Qt.color(base) : base;
            return Qt.rgba(c.r, c.g, c.b, c.a * spec.alpha);
        }}
        if (isHexColor(v)) return v;
        return Colors[v] || "transparent";
    }}
{extra}
}}
"""


def color_roles() -> list[str]:
    raw = (REPO / "modules/theme/Colors.qml").read_text()
    seen: list[str] = []
    for name in re.findall(r"property color (\w+)", raw):
        if name not in seen:
            seen.append(name)
    return seen


def colors_qml(palette: dict) -> str:
    fallback = palette.get("outline", "#888888")
    props = "\n".join(f'    property color {r}: "{palette.get(r, fallback)}"' for r in color_roles())
    return f"pragma Singleton\nimport QtQuick\nQtObject {{\n{props}\n}}\n"


def i18n_qml() -> str:
    strings = json.loads((REPO / "translations/en.json").read_text())
    return ("pragma Singleton\nimport QtQuick\nQtObject {\n"
            f"    property var strings: ({json.dumps(strings, ensure_ascii=False)})\n"
            f"    property var availableLanguages: ({(REPO / 'translations/languages.json').read_text()})\n"
            "    function detectSystemLanguage() { return 'en' }\n"
            "    function t(key) { let s = strings[key] ?? key;"
            " for (let i = 1; i < arguments.length; i++) s = s.replace('%' + i, arguments[i]); return s; }\n}\n")


def global_states_qml(wallpaper: dict) -> str:
    raw = (REPO / "modules/globals/GlobalStates.qml").read_text()
    m = re.search(r"readonly property var _shellSections: (\{.*?\n    \})", raw, re.S)
    sections = m.group(1) if m else "({})"
    return f"""pragma Singleton
import QtQuick
QtObject {{
    id: gs
    property bool themeHasChanges: false
    property bool shellHasChanges: false
    property bool compositorHasChanges: false
    property int applied: 0
    property int discarded: 0
    property int settingsCurrentTab: 0
    property string compositorLayout: "dwindle"
    property string settingsCategory: "appearance"
    property bool settingsWindowVisible: true
    readonly property var _shellSections: {sections}
    function markThemeChanged() {{ themeHasChanges = true }}
    function markShellChanged() {{ shellHasChanges = true }}
    function markCompositorChanged() {{ compositorHasChanges = true }}
    function applyThemeChanges() {{ if (themeHasChanges) applied++; themeHasChanges = false }}
    function applyShellChanges() {{ if (shellHasChanges) applied++; shellHasChanges = false }}
    function applyCompositorChanges() {{ if (compositorHasChanges) applied++; compositorHasChanges = false }}
    function discardThemeChanges() {{ if (themeHasChanges) discarded++; themeHasChanges = false }}
    function discardShellChanges() {{ if (shellHasChanges) discarded++; shellHasChanges = false }}
    function discardCompositorChanges() {{ if (compositorHasChanges) discarded++; compositorHasChanges = false }}
    property QtObject wallpaperManager: QtObject {{
        property string wallpaperDir: {json.dumps(wallpaper.get("dir", "/walls"))}
        property var scanDirs: {json.dumps(wallpaper.get("scanDirs", [wallpaper.get("dir", "/walls")]))}
        property var wallpaperPaths: {json.dumps(wallpaper.get("paths", []))}
        property string currentWallpaper: {json.dumps(wallpaper.get("current", ""))}
        property string currentMatugenScheme: "scheme-tonal-spot"
        property string activeColorPreset: ""
        property var colorPresets: {json.dumps(wallpaper.get("presets", []))}
        property var thumbs: ({json.dumps(wallpaper.get("thumbs", {}))})
        function getFileType(p) {{
            const e = p.toLowerCase().split('.').pop();
            if (['mp4', 'webm', 'mov', 'avi', 'mkv'].includes(e)) return 'video';
            if (e === 'gif') return 'gif';
            return 'image';
        }}
        function getDisplaySource(p) {{ return thumbs[p] || p }}
        function getColorSource(p) {{ return getFileType(p) === 'video' ? getDisplaySource(p) : p }}
        function setMatugenScheme(s) {{ currentMatugenScheme = s; activeColorPreset = "" }}
        function setColorPreset(n) {{ activeColorPreset = n }}
        function setWallpaperDir(d) {{ wallpaperDir = d }}
        function setWallpaper(p) {{ currentWallpaper = p }}
        function nextWallpaper() {{}}
        function previousWallpaper() {{}}
    }}
}}
"""


QUICKSHELL = {
    "Singleton": "QtObject { default property list<QtObject> data }",
    "Quickshell": "pragma Singleton\nQtObject { property var screens: []; function env(n) { return n === 'HOME' ? '/home/user' : '' } "
                  "property var detached: []; function execDetached(a) { detached.push(a) } "
                  "function iconPath(n, f) { return '' } }",
    # Installed apps (special workspaces app picker): looked up by id.
    "DesktopEntries": "pragma Singleton\nQtObject { function byId(id) { return null } }",
    "FloatingWindow": "import QtQuick.Window\nWindow {}",
}
QUICKSHELL_IO = {
    "Process": "QtObject { property var command: []; property bool running: false; property var stdout; property var stderr; "
               "signal exited(int exitCode, int exitStatus) }",
    "StdioCollector": "QtObject { property string text: ''; property bool waitForEnd: false; signal streamFinished() }",
    "FileView": "QtObject { property string path; property bool blockLoading; signal loaded(); function reload() {} "
                "function text() { return '' } }",
}
QUICKSHELL_WIDGETS = {
    "ClippingRectangle": "Rectangle { clip: true; property bool contentUnderBorder: false }",
    "IconImage": "Image { property real implicitSize: 16; width: implicitSize; height: implicitSize; "
                 "sourceSize.width: implicitSize; sourceSize.height: implicitSize }",
}

# Special workspaces runtime (modules/specials/SpecialsService.qml): the
# editors read support, window counts and open state from it. Shared with
# panels_env (dashboard list, bar indicator).
SPECIALS_STUB = """pragma Singleton
import QtQuick
QtObject {
    property bool supported: true
    property bool active: true
    property var items: []
    property var counts: ({})
    function isOpen(it) { return false }
    function countOf(it) { return 0 }
    function forHyprName(n) { return null }
    function toggle(ref) { return true }
}"""
# Installed apps (AppSearch: fuzzyQuery, getAllApps, list): the special
# workspaces app picker and the keybinds "Open app" picker.
APP_SEARCH_STUB = """pragma Singleton
import QtQuick
QtObject {
    property var apps: [
        {"id": "org.telegram.desktop", "name": "Telegram", "icon": "telegram", "execString": "Telegram -- %u"},
        {"id": "discord", "name": "Discord", "icon": "discord", "execString": "/usr/bin/discord --url -- %u"}
    ]
    property var list: apps
    function fuzzyQuery(q) {
        const l = String(q).toLowerCase();
        return apps.filter(a => a.name.toLowerCase().indexOf(l) !== -1);
    }
    function getAllApps() { return apps }
}"""
YOZD_STUB = 'pragma Singleton\nimport QtQuick\nQtObject { property string compositorName: "hyprland" }'


class SettingsEnv:
    def __init__(self, name: str = "settings", *, palette: dict | None = None, user_config: bool = False,
                 overrides: dict | None = None, wallpaper: dict | None = None, binds: dict | None = None):
        self.h = Harness(name)
        self.root = self.h.root
        domains = load_defaults()
        if user_config and USER_CONFIG.is_dir():
            for f in USER_CONFIG.glob("*.json"):
                if f.stem in domains:
                    try:
                        domains[f.stem] = _merge(domains[f.stem], json.loads(f.read_text()))
                    except (ValueError, OSError):
                        pass
        for dom, values in (overrides or {}).items():
            domains[dom] = _merge(domains[dom], values)
        self.domains = domains
        self._mirror()
        qs = self.root / "qs"
        if binds is None:
            binds = default_binds()
            if user_config and USER_BINDS.is_file():
                try:
                    binds = json.loads(USER_BINDS.read_text())
                except (ValueError, OSError):
                    pass
        self.binds = binds
        (qs / "config" / "Config.qml").write_text(config_qml(domains, keybinds_qml(binds)))
        self._qmldir(qs / "config", "qs.config", only=["Config"])
        (qs / "modules/theme/Colors.qml").write_text(colors_qml(palette or DEFAULT_PALETTE))
        self._qmldir(qs / "modules/theme", "qs.modules.theme", only=["Colors", "Icons", "Styling", "Glass"])
        # DepthClock (clock style gallery) reads the bar edge
        self.h.module("qs.modules.bar.panels", {
            "Panels": 'pragma Singleton\nQtObject { property string primaryEdge: "top" }'})
        from lockscreen_env import SERVICES as LOCK_SERVICES  # (lockscreen_env imports this module)
        self.h.module("qs.modules.services", {"I18n": i18n_qml(), "Ai": AI_STUB, "CompositorTomlWriter": TOML_WRITER_STUB,
                                              "BackendService": BACKEND_STUB, "UpdateService": UPDATE_STUB,
                                              "Notifications": NOTIFICATIONS_STUB, "AppSearch": APP_SEARCH_STUB,
                                              "YozdService": YOZD_STUB, "RoutinesService": ROUTINES_STUB,
                                              **LOCK_SERVICES, **DESKTOP_STUBS})
        self.h.module("qs.modules.specials", {"SpecialsService": SPECIALS_STUB})
        self.h.module("qs.modules.globals", {"GlobalStates": global_states_qml(wallpaper or {}),
                                             "Brand": brand_qml()})
        self.h.module("Quickshell", QUICKSHELL)
        self.h.module("Quickshell.Io", QUICKSHELL_IO)
        self.h.module("Quickshell.Widgets", QUICKSHELL_WIDGETS)
        # Legacy panel components reused by editors (heavy service deps).
        self.h.module("qs.modules.widgets.dashboard.controls", {
            "BarActivitiesSettings": "import QtQuick.Layouts\nColumnLayout { implicitHeight: 120 }"})
        self._qmldir(qs / "modules/widgets/defaultview", "qs.modules.widgets.defaultview", only=["NotchVisualizer"])
        self._qmldir(qs / "modules/aicenter/providers", "qs.modules.aicenter.providers")
        self._qmldir(qs / "modules/aicenter/agent", "qs.modules.aicenter.agent")
        self._qmldir(qs / "modules/aicenter/header", "qs.modules.aicenter.header")
        for d in ["modules/settings", "modules/settings/controls", "modules/settings/editors",
                  "modules/settings/previews", "modules/settings/store", "modules/components",
                  "modules/components/surfaceeffects", "modules/bar/workspaces/indicators",
                  "modules/aicenter/common", "modules/keybinds", "modules/settings/editors/keybinds",
                  "modules/settings/editors/desktopwidgets", "modules/settings/editors/specials",
                  "modules/settings/editors/routines", "modules/desktop", "modules/desktop/widgets",
                  "modules/desktop/widgets/types", "modules/desktop/clockstyles",
                  "modules/lockscreen", "modules/lockscreen/styles", "modules/settings/presets"]:
            self._qmldir(qs / d, "qs." + d.replace("/", "."))

        # Modules first imported by a URL Loader (lock screen styles) load on
        # the QML loader thread, whose warnings wait for the GIL: preload.
        self.h.load("import QtQuick\nimport QtQuick.Controls\nimport QtQuick.Effects\nimport QtQuick.Layouts\n"
                    "import QtQuick.Shapes\nItem { TextField {} }", auto_stub=False)

    def _mirror(self) -> None:
        for rel in MIRROR:
            src = REPO / rel
            dst = self.root / "qs" / rel
            if not src.exists():  # older trees (tools/render --root) lack newer files
                continue
            if src.is_dir():
                shutil.copytree(src, dst, dirs_exist_ok=True)
            else:
                dst.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy(src, dst)

    def _qmldir(self, d: Path, module: str, only: list[str] | None = None) -> None:
        lines = [f"module {module}"]
        for f in sorted(d.glob("*.qml")):
            if only is not None and f.stem not in only:
                continue
            single = f.read_text().lstrip().startswith("pragma Singleton")
            lines.append(f"{'singleton ' if single else ''}{f.stem} 1.0 {f.name}")
        (d / "qmldir").write_text("\n".join(lines) + "\n")

    def load(self, qml: str):
        return self.h.load(qml, auto_stub=False)
