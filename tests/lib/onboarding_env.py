"""Offscreen environment for the onboarding wizard (modules/onboarding).

Extends KeyboardEnv (real settings store/editors/components, generated
Config/Colors, the real DisplaysService + KeyboardService over a scripted
BackendService: `replies`, `calls`, `emit`) with the onboarding module and
stand-ins for the shell services the wizard talks to: PresetsService
(built-in presets from assets/presets), GlobalShortcuts (records run() and
emits commandRan), TerminalLookService (enablePrompt() writes terminal.prompt like
the real one), the real OnboardingService, Visibilities, I18n with the
language catalog, the real ExtrasService (catalog/status replies from
extras_env unless given) and ExclusiveService, and a Quickshell.Io FileView
that reads files synchronously.

Used by tests/onboarding-ui.test.py and tools/render/onboarding_render.py.
"""
from __future__ import annotations

import json
import re
import os
import shutil

from displays_env import OUTPUTS as DISPLAY_OUTPUTS
from extras_env import CATALOG as EXTRAS_CATALOG, PLATFORM as EXTRAS_PLATFORM, STATUS as EXTRAS_STATUS
from keyboard_env import KeyboardEnv
from qmlharness import REPO
from settings_env import APP_SEARCH_STUB, TERMINAL_LOOK_STUB, YOZD_STUB, global_states_qml

os.environ.setdefault("QML_XHR_ALLOW_FILE_READ", "1")

PRESETS_DIR = REPO / "assets" / "presets"


def builtin_presets() -> list[dict]:
    out = []
    for d in sorted(p for p in PRESETS_DIR.iterdir() if p.is_dir()):
        info = {}
        try:
            info = json.loads((d / "info.json").read_text())
        except (OSError, ValueError):
            pass
        out.append({"name": d.name, "path": str(d), "isOfficial": True,
                    "configFiles": [f.stem + ".js" for f in d.glob("*.json") if f.name != "info.json"],
                    "author": info.get("author", ""), "authorUrl": ""})
    return out


def i18n_qml(lang: str = "en") -> str:
    strings = json.loads((REPO / f"translations/{lang}.json").read_text())
    langs = json.loads((REPO / "translations/languages.json").read_text())
    return ("pragma Singleton\nimport QtQuick\nQtObject {\n"
            f"    property var strings: ({json.dumps(strings, ensure_ascii=False)})\n"
            f"    property var availableLanguages: ({json.dumps(langs, ensure_ascii=False)})\n"
            "    function tn(key, n) { const k = key + (n === 1 ? '.one' : '.other'); return t(strings[k] !== undefined ? k : key, n); }\n"
            "    function t(key) { let s = strings[key] ?? key;"
            " for (let i = 1; i < arguments.length; i++) s = s.replace('%' + i, arguments[i]); return s; }\n}\n")


SERVICES = {
    # the real one sets the prompt, switches it on and saves
    "TerminalLookService": re.sub(r"\n\s*function (choose|enablePrompt)\(id\) \{\}", "", TERMINAL_LOOK_STUB).replace(
        "QtObject {", "import qs.config\nQtObject {\n    property var chosen: []\n    property bool nerdFontAvailable: true\n"
        "    function enablePrompt(id) { chosen = chosen.concat([id]); Config.terminal.prompt = id;"
        " Config.terminal.enabled = true }", 1),
    "GlobalShortcuts": """pragma Singleton
QtObject {
    signal commandRan(string command)
    property var ran: []
    property int settingsToggles: 0
    function run(command) { ran = ran.concat([command]); commandRan(command); }
    function toggleSettings() { settingsToggles++ }
}""",
    # Persisted wizard state: an in-memory stand-in for the daemon-backed one.
    "StateService": """pragma Singleton
QtObject {
    property var state: ({})
    property bool initialized: true
    property var writes: []
    function get(key, d) { return state[key] !== undefined ? state[key] : d }
    function set(key, value) {
        const s = Object.assign({}, state); s[key] = value; state = s;
        writes = writes.concat([key]);
    }
}""",
    "Visibilities": """pragma Singleton
QtObject {
    property string currentActiveModule: ""
    function setActiveModule(m) { currentActiveModule = m }
}""",
}

QUICKSHELL_IO = {
    "Process": "QtObject { property var command: []; property bool running: false; property var stdout; "
               "property var stderr; signal exited(int exitCode, int exitStatus) }",
    "StdioCollector": "QtObject { property string text: ''; property bool waitForEnd: false; signal streamFinished() }",
    "SplitParser": "QtObject { signal read(string data) }",
    "FileView": """QtObject {
    id: fv
    property string path: ""
    property string _text: ""
    signal loaded()
    function text() { return _text }
    onPathChanged: {
        if (!path) return;
        const x = new XMLHttpRequest();
        x.open("GET", "file://" + path, false);
        try { x.send(); } catch (e) { return; }
        if (x.responseText) { _text = x.responseText; Qt.callLater(fv.loaded); }
    }
}""",
}


class OnboardingEnv(KeyboardEnv):
    def __init__(self, name: str = "onboarding", *, lang: str = "en", presets: list | None = None,
                 wallpaper: dict | None = None, outputs: list | None = None, replies: dict | None = None, **kw):
        outputs = DISPLAY_OUTPUTS if outputs is None else outputs
        replies = {"displays.list": outputs, "displays.conflicts": [],
                   "extras.catalog": {**EXTRAS_CATALOG, "platform": EXTRAS_PLATFORM},
                   "extras.status": EXTRAS_STATUS, "extras.install": {"jobs": []},
                   **(replies or {})}
        super().__init__(name, wallpaper=wallpaper, outputs=outputs, replies=replies, **kw)
        h = self.h
        h.module("Quickshell.Io", QUICKSHELL_IO)
        presets = builtin_presets() if presets is None else presets
        services = dict(SERVICES)
        # the real service: it owns the wizard state under test
        services["OnboardingService"] = (REPO / "modules/services/OnboardingService.qml").read_text()
        services["AppSearch"] = APP_SEARCH_STUB
        for real in ("ExtrasService", "ExclusiveService"):
            services[real] = (REPO / f"modules/services/{real}.qml").read_text()
        services["YozdService"] = YOZD_STUB
        services["I18n"] = i18n_qml(lang)
        services["PresetsService"] = f"""pragma Singleton
QtObject {{
    property var presets: ({json.dumps(presets)})
    property string activePreset: ""
    property var loaded: []
    function initialize() {{}}
    function loadPreset(n) {{ loaded = loaded.concat([n]); activePreset = n }}
}}"""
        h.module("qs.modules.services", services)
        gs = global_states_qml(wallpaper or {}).replace(
            "property bool settingsWindowVisible: true",
            "property bool settingsWindowVisible: false\n    property bool assistantVisible: false")
        h.module("qs.modules.globals", {"GlobalStates": gs})
        self._mirror_dir("modules/onboarding")
        self._qmldir(self.root / "qs/modules/onboarding", "qs.modules.onboarding")

    def _mirror_dir(self, rel: str) -> None:
        shutil.copytree(REPO / rel, self.root / "qs" / rel, dirs_exist_ok=True)
