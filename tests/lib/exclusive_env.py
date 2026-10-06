"""Offscreen environment for the exclusive-mode card (Settings > System).

Extends DisplaysEnv (real settings components, generated Config/Colors,
scripted BackendService with `replies` and recorded `calls`) with the real
ExclusiveService and modules/settings/system.

Used by tests/exclusive-ui.test.py and tools/render/exclusive_render.py.
"""
from __future__ import annotations

from displays_env import DisplaysEnv
from qmlharness import REPO

STATUS_OFF = {"active": False, "backup": "", "disabledUnits": [], "compositor": "hyprland"}
PLAN = {"entry": "hyprland.lua", "hyprDir": "/home/me/.config/hypr",
        "backupDir": "/home/me/.local/share/yozakura/backups", "userFile": "user.lua",
        "units": ["waybar.service", "mako.service", "hypridle.service"],
        "monitors": ["DP-1 2560x1440@144", "HDMI-A-1 1920x1080@60"], "keyboard": "us,ru", "alreadyDone": False}
STATUS_ON = {"active": True, "backup": "/home/me/.local/share/yozakura/backups/20261006-120000",
             "disabledUnits": ["waybar.service", "mako.service", "hypridle.service"], "compositor": "hyprland"}


class ExclusiveEnv(DisplaysEnv):
    def __init__(self, name: str = "exclusive", *, replies=None, **kw):
        replies = {"exclusive.status": STATUS_OFF, "exclusive.plan": PLAN, **(replies or {})}
        super().__init__(name, replies=replies, **kw)
        self.h.module("qs.modules.services", {"ExclusiveService": (REPO / "modules/services/ExclusiveService.qml").read_text()})
