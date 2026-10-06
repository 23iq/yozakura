"""Offscreen environment for the Displays page and its overlays.

Extends SettingsEnv (real settings components, generated Config/Colors) with
the real DisplaysService + DisplayModel.js, the real modules/settings/displays
and modules/shell files, and a scripted BackendService: `replies` maps a
method to its result, every call is recorded in `calls`.

Used by tests/displays-ui.test.py and tools/render/displays_render.py.
"""
from __future__ import annotations

import json
import shutil

from qmlharness import REPO
from settings_env import SettingsEnv

BACKEND = """pragma Singleton
QtObject {
    property var calls: []
    property var replies: ({})
    function call(method, params, cb) {
        calls = calls.concat([{method: method, params: params}]);
        if (cb) {
            const r = replies[method];
            if (r !== undefined && r !== null && r.error) cb(null, r.error);
            else cb(r === undefined ? null : r, null);
        }
    }
    function addSubscription(services, cb) { }
}"""

OUTPUTS = [
    {"id": "DEL-U2723QE-1", "name": "DP-1", "make": "Dell", "model": "U2723QE", "enabled": True,
     "width": 2560, "height": 1440, "refresh": 60, "x": 0, "y": 0, "scale": 1, "transform": 0, "vrr": False,
     "physical_width_mm": 597, "physical_height_mm": 336,
     "modes": [{"width": w, "height": h, "refresh": r}
               for (w, h, rates) in [(3840, 2160, [60, 30]), (2560, 1440, [240, 144, 120, 60]),
                                     (1920, 1080, [240, 144, 60]), (1280, 720, [60])] for r in rates]},
    {"id": "LG-27GL-2", "name": "HDMI-A-1", "make": "LG", "model": "27GL850", "enabled": True,
     "width": 1920, "height": 1080, "refresh": 144, "x": 2560, "y": 180, "scale": 1, "transform": 0, "vrr": False,
     "physical_width_mm": 598, "physical_height_mm": 336,
     "modes": [{"width": 1920, "height": 1080, "refresh": r} for r in (144, 120, 60)]
              + [{"width": 1280, "height": 720, "refresh": 60}]},
]


class DisplaysEnv(SettingsEnv):
    def __init__(self, name: str = "displays", *, outputs=None, replies=None, **kw):
        super().__init__(name, **kw)
        h = self.h
        qs = self.root / "qs"
        cfg = qs / "config" / "Config.qml"
        cfg.write_text(cfg.read_text().replace("    property var saved: []", "    property var saved: []\n    property bool displaysReady: true", 1))
        svc = qs / "modules/services"
        self.outputs = OUTPUTS if outputs is None else outputs
        replies = {"displays.list": self.outputs, "displays.conflicts": [], **(replies or {})}
        h.module("qs.modules.services", {"BackendService": BACKEND.replace("({})", "(" + json.dumps(replies) + ")", 1)})
        h.module("qs.modules.services", {"DisplaysService": (REPO / "modules/services/DisplaysService.qml").read_text()})
        shutil.copy(REPO / "modules/services/DisplayModel.js", svc / "DisplayModel.js")
        shutil.copytree(REPO / "modules/shell", qs / "modules/shell", dirs_exist_ok=True)
        for d in ("modules/settings/displays", "modules/shell"):
            self._qmldir(qs / d, "qs." + d.replace("/", "."))
