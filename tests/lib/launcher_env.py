"""Offscreen environment for the launcher (modules/widgets/launcher).

Builds on SettingsEnv (real components, Styling, Icons, generated Config /
Colors / I18n / GlobalStates) and adds the launcher files, the command
registry and currency table, and stand-ins for the services the providers
call (AppSearch, UsageTracker, TaskbarApps, Visibilities, PresetsService,
GlobalShortcuts, Ai). Calls the shell would make are recorded on the stubs
(`GlobalShortcuts.ran`, `Ai.asked`, `Quickshell.detached`, `Visibilities.module`).

Used by tests/launcher-ui.test.py and tools/render/launcher_render.py.
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
from pathlib import Path

from qmlharness import HARNESS_HOME, REPO  # first: enters the headless platform
from PySide6.QtGui import QIcon  # noqa: E402
from settings_env import QUICKSHELL, QUICKSHELL_IO, SettingsEnv, global_states_qml

# FileView that really reads the file (XHR on file://), enough for the
# launcher's registry / rates loaders.
FILEVIEW = """QtObject {
    id: fv
    property string path: ""
    property bool printErrors: true
    property bool blockLoading: false
    property bool watchChanges: false
    property bool preload: true
    property string _text: ""
    signal loaded()
    signal loadFailed(var error)
    signal fileChanged()
    function text() { return _text }
    function setText(t) { _text = t }
    function reload() {
        const x = new XMLHttpRequest();
        x.open("GET", "file://" + path, false);
        try { x.send(); } catch (e) {}
        if (x.responseText) { _text = x.responseText; loaded(); } else loadFailed("FileNotFound");
    }
    onPathChanged: Qt.callLater(fv.reload)
}"""

DEFAULT_APPS = [
    {"id": "firefox", "name": "Firefox", "icon": "firefox", "comment": "Browse the World Wide Web"},
    {"id": "kitty", "name": "kitty", "icon": "kitty", "comment": "Fast, feature-rich, GPU based terminal"},
    {"id": "org.gnome.Nautilus", "name": "Files", "icon": "org.gnome.Nautilus", "comment": "Access and organize files"},
    {"id": "code", "name": "Visual Studio Code", "icon": "vscode", "comment": "Code Editing. Redefined."},
    {"id": "org.telegram.desktop", "name": "Telegram", "icon": "telegram", "comment": "Official desktop client"},
    {"id": "spotify", "name": "Spotify", "icon": "spotify", "comment": "Music for everyone"},
    {"id": "obsidian", "name": "Obsidian", "icon": "obsidian", "comment": "Knowledge base"},
    {"id": "gimp", "name": "GNU Image Manipulation Program", "icon": "gimp", "comment": "Create images and edit photographs"},
    {"id": "org.gnome.Calculator", "name": "Calculator", "icon": "org.gnome.Calculator", "comment": "Perform arithmetic calculations"},
    {"id": "discord", "name": "Discord", "icon": "discord", "comment": "All-in-one voice and text chat"},
]


def services(apps: list[dict], presets: list[str]) -> dict[str, str]:
    return {
        "AppSearch": f"""pragma Singleton
QtObject {{
    id: appSearch
    property var apps: {json.dumps(apps)}
    property var launched: []
    function wrap(a) {{
        return Object.assign({{ execString: a.id, categories: [], runInTerminal: false,
                                execute: () => appSearch.launched.push(a.id) }}, a);
    }}
    function getAllApps() {{ return apps.map(a => wrap(a)); }}
    function fuzzyQuery(q) {{
        const s = q.toLowerCase();
        return apps.filter(a => a.name.toLowerCase().indexOf(s) !== -1 || (a.comment || '').toLowerCase().indexOf(s) !== -1)
                   .map(a => wrap(a));
    }}
    function invalidateCache() {{}}
}}""",
        "UsageTracker": """pragma Singleton
QtObject { signal usageDataReady; property var used: []; function recordUsage(id) { used.push(id) } function getUsageScore(id) { return 0 } }""",
        "TaskbarApps": """pragma Singleton
QtObject { property var pinned: []; function isPinned(id) { return pinned.indexOf(id) !== -1 }
           function togglePin(id) { const i = pinned.indexOf(id); if (i < 0) pinned.push(id); else pinned.splice(i, 1); pinned = pinned.slice() } }""",
        "Visibilities": """pragma Singleton
QtObject { property string module: "launcher"; property string currentActiveModule: module
           function setActiveModule(m) { module = m } }""",
        "PresetsService": f"""pragma Singleton
QtObject {{ property var presets: {json.dumps([{"name": n} for n in presets])}; property int scans: 0
           function scanPresets() {{ scans++ }} }}""",
        "GlobalShortcuts": """pragma Singleton
QtObject { property var ran: []; property var toggled: []
           function run(c) { ran.push(c); ran = ran.slice() } function toggle(c) { toggled.push(c) } }""",
        "Ai": """pragma Singleton
QtObject {
    property bool enabled: true
    property var quickModel: ({ name: "Claude Sonnet" })
    property var asked: []
    property var agents: null
    property var mcp: null
    function askQuick(t) { asked.push(t); asked = asked.slice() }
    function _ensureInit() {}
}""",
    }


def _icon_theme() -> str:
    try:
        out = subprocess.run(["gsettings", "get", "org.gnome.desktop.interface", "icon-theme"],
                             capture_output=True, text=True, timeout=3).stdout.strip().strip("'")
        return out or "hicolor"
    except (OSError, subprocess.SubprocessError):
        return "hicolor"


def resolve_icons(apps: list[dict], out_dir: Path) -> list[dict]:
    """Icon theme names -> PNG files (the harness has no image://icon provider,
    and a Python one deadlocks Qt's pixmap reader thread)."""
    QIcon.setThemeName(_icon_theme())
    out_dir.mkdir(parents=True, exist_ok=True)
    res = []
    for a in apps:
        icon = QIcon.fromTheme(a.get("icon", ""))
        if icon.isNull():
            icon = QIcon.fromTheme("application-x-executable")
        path = out_dir / (a["id"] + ".png")
        if not icon.isNull() and icon.pixmap(64, 64).save(str(path)):
            a = {**a, "icon": str(path)}
        res.append(a)
    return res


class LauncherEnv(SettingsEnv):
    def __init__(self, name: str = "launcher", *, apps: list[dict] | None = None,
                 presets: list[str] | None = None, **kw):
        # The registry/rates loaders read files through the XHR FileView.
        os.environ["QML_XHR_ALLOW_FILE_READ"] = "1"
        super().__init__(name, **kw)
        qs = self.root / "qs"
        dst = qs / "modules/widgets/launcher"
        shutil.copytree(REPO / "modules/widgets/launcher", dst, dirs_exist_ok=True)
        self._qmldir(dst, "qs.modules.widgets.launcher")
        self._qmldir(qs / "modules/components/kit", "qs.modules.components.kit")
        # Motion / Metrics tokens (the layout.launcher looks size and animate with them).
        for rel in ("modules/theme/Metrics.qml", "modules/theme/Motion.qml", "modules/theme/DensityMetrics.js",
                    "config/motion/MotionBudget.js"):
            (qs / rel).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy(REPO / rel, qs / rel)
        self._qmldir(qs / "modules/theme", "qs.modules.theme",
                     only=["Colors", "Icons", "Styling", "Glass", "Metrics", "Motion"])
        for rel in ("assets/commands/commands.json", "assets/launcher/currency-fallback.json",
                    "modules/services/timers/TimerFormat.js", "modules/services/timers/QuickInput.js"):
            (qs / rel).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy(REPO / rel, qs / rel)
        # Prefix tabs: light stand-ins (the real tabs need the whole dashboard).
        for tab, typ in (("clipboard", "ClipboardTab"), ("emoji", "EmojiTab"), ("tmux", "TmuxTab"), ("notes", "NotesTab")):
            d = qs / "modules/widgets/dashboard" / tab
            d.mkdir(parents=True, exist_ok=True)
            (d / f"{typ}.qml").write_text(
                "import QtQuick\nItem { objectName: \"tab-" + tab + "\"; property int leftPanelWidth; property string prefixIcon; "
                "property string searchText: \"\"; signal backspaceOnEmpty; "
                "signal requestOpenItem(var itemId, var items, var currentContent, var filePathGetter, var urlChecker); "
                "property int focused: 0; function focusSearchInput() { focused++ } }\n")
        apps = resolve_icons(apps or DEFAULT_APPS, self.root / "icons")
        self.h.module("qs.modules.services", services(apps, presets or ["Neon Tokyo", "Yozakura Night", "Sumi-e", "Kōyō"]))
        gs = global_states_qml(kw.get("wallpaper") or {}).replace("    id: gs\n", """    id: gs
    property string launcherSearchText: ""
    property int launcherSelectedIndex: -1
    property int widgetsTabCurrentIndex: 0
    function clearLauncherState() { launcherSearchText = ""; launcherSelectedIndex = -1 }
""", 1)
        self.h.module("qs.modules.globals", {"GlobalStates": gs})
        self.h.module("Quickshell", QUICKSHELL)
        self.h.module("Quickshell.Io", {**QUICKSHELL_IO, "FileView": FILEVIEW})
        self.home = HARNESS_HOME
