"""Offscreen environment for the Keyboard page and the bar layout indicator.

Extends DisplaysEnv (real settings components, generated Config/Colors,
scripted BackendService) with the real KeyboardService + KeyboardModel.js, the
real modules/settings/keyboard files and the bar module base. The backend
stub records every call and lets a test push events (`emit`).

Used by tests/keyboard-ui.test.py and tools/render/keyboard_render.py.
"""
from __future__ import annotations

import json
import shutil

from displays_env import DisplaysEnv
from qmlharness import REPO

CATALOG = {
    "layouts": [
        {"name": "us", "description": "English (US)", "variants": [
            {"name": "intl", "description": "English (US, intl., with dead keys)"},
            {"name": "dvorak", "description": "English (Dvorak)"}]},
        {"name": "ru", "description": "Russian", "variants": [
            {"name": "phonetic", "description": "Russian (phonetic)"}]},
        {"name": "de", "description": "German", "variants": [{"name": "nodeadkeys", "description": "German (no dead keys)"}]},
        {"name": "fr", "description": "French", "variants": []},
        {"name": "ua", "description": "Ukrainian", "variants": []},
    ],
    "groups": [{"name": "grp", "description": "Switching to another layout"},
               {"name": "caps", "description": "Caps Lock behavior"},
               {"name": "compose", "description": "Compose key position"}],
    "options": [
        {"group": "grp", "name": "grp:alt_shift_toggle", "description": "Alt+Shift"},
        {"group": "caps", "name": "caps:escape", "description": "Make Caps Lock an additional Esc"},
        {"group": "caps", "name": "caps:swapescape", "description": "Swap Esc and Caps Lock"},
        {"group": "caps", "name": "caps:backspace", "description": "Make Caps Lock an additional Backspace"},
        {"group": "compose", "name": "compose:ralt", "description": "Right Alt"},
        {"group": "compose", "name": "compose:menu", "description": "Menu"},
    ],
}

BACKEND = """pragma Singleton
QtObject {
    property var calls: []
    property var replies: ({})
    property var subs: []
    function call(method, params, cb) {
        calls = calls.concat([{method: method, params: params}]);
        let r = replies[method];
        if (Array.isArray(r) && r.length > 0 && r[0] !== null && typeof r[0] === "object" && ("error" in r[0] || "jobs" in r[0])) {
            // a sequence of replies, consumed one call at a time (the last repeats)
            const next = Object.assign({}, replies);
            next[method] = r.length > 1 ? r.slice(1) : r[0];
            replies = next;
            r = r[0];
        }
        if (cb) {
            if (r !== undefined && r !== null && r.error) cb(null, r.error);
            else cb(r === undefined ? null : r, null);
        }
    }
    function addSubscription(services, cb) { subs = subs.concat([cb]); }
    function emit(service, data) { subs.forEach(cb => cb(service, data)); }
}"""


# keyboard.current: the compositor's own settings (the defaults' shape).
CURRENT = {"available": True, "layouts": [{"layout": "us", "variant": ""}], "switchBind": "alt_shift",
           "options": [], "repeatRate": 25, "repeatDelay": 600}


class KeyboardEnv(DisplaysEnv):
    def __init__(self, name: str = "keyboard", *, replies=None, **kw):
        replies = {"keyboard.catalog": CATALOG, "keyboard.next": {}, "keyboard.current": CURRENT, **(replies or {})}
        super().__init__(name, replies=replies, **kw)
        h = self.h
        qs = self.root / "qs"
        cfg = qs / "config" / "Config.qml"
        cfg.write_text(cfg.read_text().replace("    property var saved: []", "    property var saved: []\n    property bool keyboardReady: true", 1))
        h.module("qs.modules.services", {"BackendService": BACKEND.replace("({})", "(" + json.dumps(replies) + ")", 1)})
        h.module("qs.modules.services", {"KeyboardService": (REPO / "modules/services/KeyboardService.qml").read_text()})
        shutil.copytree(REPO / "modules/settings/keyboard", qs / "modules/settings/keyboard", dirs_exist_ok=True)
        self._qmldir(qs / "modules/settings/keyboard", "qs.modules.settings.keyboard")
        shutil.copytree(REPO / "modules/bar/modules", qs / "modules/bar/modules", dirs_exist_ok=True)
        self._qmldir(qs / "modules/bar/modules", "qs.modules.bar.modules")
        # The bar modules draw with the shared kit (modules/bar/look)
        self._qmldir(qs / "modules/components/kit", "qs.modules.components.kit")
        shutil.copytree(REPO / "modules/bar/look", qs / "modules/bar/look", dirs_exist_ok=True)
        self._qmldir(qs / "modules/bar/look", "qs.modules.bar.look")
        shutil.copy(REPO / "modules/theme/BarMetrics.qml", qs / "modules/theme/BarMetrics.qml")
        self._qmldir(qs / "modules/theme", "qs.modules.theme")
