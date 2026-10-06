"""Offscreen environment for the Apps & Extras catalog (modules/extras) and
its settings page.

Extends SettingsEnv (real settings components, generated Config/Colors) with
the real ExtrasService + ExtrasModel.js and a scripted BackendService: every
call is recorded in `calls`; `replies` maps a method to its result, an
`{"error": "..."}` object, or a list of those consumed one call at a time;
`emit(service, data)` pushes a subscription event.

Used by tests/extras-ui.test.py and tools/render/extras_render.py.
"""
from __future__ import annotations

import json

from qmlharness import REPO
from settings_env import SettingsEnv

BACKEND = """pragma Singleton
QtObject {
    property var calls: []
    property var replies: ({})
    property var subs: []
    function call(method, params, cb) {
        calls = calls.concat([{method: method, params: params}]);
        let r = replies[method];
        if (Array.isArray(r)) {
            const rest = r.slice(1);
            const next = Object.assign({}, replies);
            next[method] = rest.length > 0 ? rest : r[0];
            replies = next;
            r = r[0];
        }
        if (!cb)
            return;
        if (r !== undefined && r !== null && r.error) cb(null, r.error);
        else cb(r === undefined ? null : r, null);
    }
    function addSubscription(services, cb) { subs = subs.concat([cb]); return subs.length; }
    function emit(service, data) { subs.forEach(cb => cb(service, data)); }
}"""

PLATFORM = {"distro": "arch", "gpu": "amd", "hasParu": True, "hasYay": False, "hasFlatpak": True,
            "hasNpm": True, "hasPkexec": True, "multilib": False}

CATALOG = {
    "categories": [
        {"id": "agents", "name": "extras.cat.agents", "icon": "robot"},
        {"id": "games", "name": "extras.cat.games", "icon": "gamepad"},
        {"id": "browsers", "name": "extras.cat.browsers", "icon": "globe"},
    ],
    "entries": [
        {"id": "claude-code", "category": "agents", "name": "Claude Code", "icon": "robot", "size": "200 MB",
         "recommended": True},
        {"id": "nodejs", "category": "agents", "name": "Node.js", "icon": "code", "hidden": True},
        {"id": "steam", "category": "games", "name": "Steam", "icon": "gamepad", "multilib": True},
        {"id": "firefox", "category": "browsers", "name": "Firefox", "icon": "firefox", "recommended": True},
        {"id": "chromium", "category": "browsers", "name": "Chromium", "icon": "globe", "size": "1.2 GB"},
    ],
}

STATUS = {
    "claude-code": {"id": "claude-code", "state": "missing"},
    "nodejs": {"id": "nodejs", "state": "missing"},
    "steam": {"id": "steam", "state": "missing"},
    "firefox": {"id": "firefox", "state": "installed", "source": "pkg"},
    "chromium": {"id": "chromium", "state": "missing"},
}


def full_catalog() -> dict:
    """The real assets/catalog/extras.json (renders)."""
    data = json.loads((REPO / "assets/catalog/extras.json").read_text())
    return {"categories": data["categories"], "entries": data["entries"]}


class ExtrasEnv(SettingsEnv):
    def __init__(self, name: str = "extras", *, catalog=None, status=None, platform=None, replies=None, **kw):
        super().__init__(name, **kw)
        cat = CATALOG if catalog is None else catalog
        replies = {"extras.catalog": {**cat, "platform": platform or PLATFORM},
                   "extras.status": STATUS if status is None else status,
                   "extras.install": {"jobs": []}, "extras.cancel": {}, "extras.upgradeAndRetry": {"jobs": []},
                   "extras.log": {"text": "resolving dependencies...\nerror: failed retrieving file"},
                   **(replies or {})}
        self.h.module("qs.modules.services", {
            "BackendService": BACKEND.replace("({})", "(" + json.dumps(replies) + ")", 1),
            "ExtrasService": (REPO / "modules/services/ExtrasService.qml").read_text()})
