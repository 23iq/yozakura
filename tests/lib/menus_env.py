"""Offscreen environment for the power and tools menus (modules/widgets/
powermenu, modules/widgets/tools) and their shared pieces (modules/widgets/
menus: RadialMenu, ActionStrip).

KitEnv (real kit, StyledRect, theme singletons, generated Config / Colors)
plus the menu trees and idle stand-ins for the services the tools read
(ScreenRecorder, Screenshot, Visibilities). Commands never run: the
Quickshell stub records execDetached argv.

Used by tests/menus-ui.test.py, tests/radial-menu.test.py and
tools/render/{power,tools}_render.py.
"""
from __future__ import annotations

import shutil

from kit_env import LANGUAGES, KitEnv  # noqa: F401  (re-exported for the renders)
from qmlharness import REPO

TREES = ["modules/widgets/powermenu", "modules/widgets/tools"]
MENUS = ["RadialMenu.qml", "ActionStrip.qml", "MenuStyles.js"]

SERVICES = {
    "ScreenRecorder": "pragma Singleton\nQtObject { property bool isRecording: false; property string duration: ''; "
                      "property string videosDir: ''; function initialize() {} function toggleRecording() {} }",
    "Screenshot": "pragma Singleton\nQtObject { property string screenshotsDir: ''; property string captureMode: ''; "
                  "function initialize() {} }",
    "Visibilities": "pragma Singleton\nQtObject { property string currentActiveModule: ''; "
                    "function setActiveModule(m) { currentActiveModule = m } }",
}

# The settings Quickshell stub with a user name (the power menu caption).
QUICKSHELL = ("pragma Singleton\nQtObject { property var screens: []; "
              "function env(n) { return n === 'HOME' ? '/home/user' : (n === 'USER' ? 'user' : '') } "
              "property var detached: []; function execDetached(a) { detached.push(a) } "
              "function iconPath(n, f) { return '' } }")


class MenusEnv(KitEnv):
    def __init__(self, name: str = "menus", **kw):
        super().__init__(name, **kw)
        qs = self.root / "qs"
        for rel in TREES:
            shutil.copytree(REPO / rel, qs / rel, dirs_exist_ok=True)
            self._qmldir(qs / rel, "qs." + rel.replace("/", "."))
            self._qmldir(qs / rel / "styles", "qs." + rel.replace("/", ".") + ".styles")
        menus = qs / "modules/widgets/menus"
        menus.mkdir(parents=True, exist_ok=True)
        for f in MENUS:
            shutil.copy(REPO / "modules/widgets/menus" / f, menus / f)
        self._qmldir(menus, "qs.modules.widgets.menus")
        self.h.module("qs.modules.services", SERVICES)
        self.h.module("Quickshell", {"Quickshell": QUICKSHELL})
