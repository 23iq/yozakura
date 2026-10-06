"""Offscreen environment for the Terminal & Apps status pills.

SettingsEnv (real settings components, generated Config/Colors) with the real
AppHooksService and a scripted BackendService: `replies` maps a method to its
result, every call is recorded in `calls`.

Used by tests/apphooks-ui.test.py and tools/render/apphooks_render.py.
"""
from __future__ import annotations

import json

from displays_env import BACKEND
from qmlharness import REPO
from settings_env import SettingsEnv

STATUS = {
    "kitty": {"id": "kitty", "state": "connected", "files": ["~/.config/kitty/kitty.conf"]},
    "ghostty": {"id": "ghostty", "state": "connected", "needsRestart": True},
    "foot": {"id": "foot", "state": "disconnected"},
    "alacritty": {"id": "alacritty", "state": "managed",
                  "reason": "alacritty.toml is read-only or in the Nix store; add: [general]\nimport = [\"~/.cache/yozakura/alacritty.toml\"]"},
    "discord": {"id": "discord", "state": "error", "reason": "parse: ~/.config/vesktop/settings/settings.json"},
    "qt": {"id": "qt", "state": "absent"},
}


class AppHooksEnv(SettingsEnv):
    def __init__(self, name: str = "apphooks", *, replies=None, **kw):
        super().__init__(name, **kw)
        replies = {"apphooks.status": STATUS, "apphooks.ensure": {}, "apphooks.apply": {"id": "foot", "state": "connected"},
                   "apphooks.revert": {"id": "kitty", "state": "disconnected"}, **(replies or {})}
        h = self.h
        h.module("qs.modules.services", {"BackendService": BACKEND.replace("({})", "(" + json.dumps(replies) + ")", 1)})
        h.module("qs.modules.services", {"AppHooksService": (REPO / "modules/services/AppHooksService.qml").read_text()})
