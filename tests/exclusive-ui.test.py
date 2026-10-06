#!/usr/bin/env python3
"""Settings > System > Exclusive mode card, offscreen.

The real ExclusiveService, ExclusiveCard and the SettingsStore compositor
gate run against a scripted BackendService (tests/lib/exclusive_env.py).
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from exclusive_env import STATUS_OFF, STATUS_ON, ExclusiveEnv  # noqa: E402

from PySide6.QtTest import QTest  # noqa: E402

failures: list[str] = []


def check(cond: bool, msg: str) -> None:
    if not cond:
        failures.append(msg)
        print("FAIL:", msg)


env = ExclusiveEnv("exclusive-ui", overrides={"theme": {"animDuration": 0}})
h = env.h
win = h.load("""
import QtQuick
import QtQuick.Window
import qs.modules.services
import qs.modules.settings
import qs.modules.settings.store
import qs.modules.settings.system
Window {
    width: 900; height: 900; visible: true
    ExclusiveCard { id: card; objectName: "card"; width: 800 }
    Item { objectName: "gate"; property bool shown: SettingsStore.visible({"compositor": "hyprland"}); property bool shownNiri: SettingsStore.visible({"compositor": "niri"}) }
}""", auto_stub=False)
QTest.qWait(50)


def ev(expr, obj=None):
    return h.eval(obj or win, expr)


def calls(method):
    return json.loads(ev("JSON.stringify(BackendService.calls.filter(c => c.method === '%s'))" % method))


def vis(name):
    o = h.find(win, name)
    return o is not None and o.property("visible") is True


check(len(calls("exclusive.status")) >= 1 and len(calls("exclusive.plan")) >= 1, "card loads status and plan on open")
check(h.find(win, "gate").property("shown") is True and h.find(win, "gate").property("shownNiri") is False,
      "compositor-bound entries show only on their compositor")
check(ev("title", h.find(win, "exclusiveStatus")) == "Make Yozakura the only shell", "off state: invitation title")
check(vis("exclusiveSteps") and not vis("exclusiveActive"), "off state lists the steps")
check("waybar.service, mako.service, hypridle.service" == ev("detail", h.find(win, "unitsStep")), "units step names the detected units")
check("DP-1 2560x1440@144" in ev("detail", h.find(win, "importStep")) and "us,ru" in ev("detail", h.find(win, "importStep")), "import step names monitors and layouts")
check(vis("exclusiveEnable") and not vis("exclusiveRestore"), "Enable shown, Restore hidden")
check(not vis("exclusiveConfirm"), "no confirmation until asked")

# Enable -> confirm -> exclusive.enable
ev("clicked()", h.find(win, "exclusiveEnable"))
check(vis("exclusiveConfirm") and not vis("exclusiveEnable"), "Enable opens the confirmation")
check(len(calls("exclusive.enable")) == 0, "nothing is called before confirming")
ev("clicked()", h.find(win, "exclusiveCancel"))
check(not vis("exclusiveConfirm") and len(calls("exclusive.enable")) == 0, "Cancel closes it without calling")
ev("clicked()", h.find(win, "exclusiveEnable"))
ev("BackendService.replies = Object.assign({}, BackendService.replies, {'exclusive.enable': %s, 'exclusive.status': %s})"
   % (json.dumps(STATUS_ON), json.dumps(STATUS_ON)))
ev("clicked()", h.find(win, "exclusiveConfirmButton"))
check(len(calls("exclusive.enable")) == 1, "confirming calls exclusive.enable once")
check(ev("ExclusiveService.active") is True and vis("exclusiveActive") and not vis("exclusiveSteps"), "active state after enable")
check(ev("title", h.find(win, "exclusiveStatus")) == "Yozakura is your only shell", "active title")
check(vis("exclusiveRestore") and not vis("exclusiveEnable"), "Restore shown when active")

# Restore -> confirm -> exclusive.restore, shows the replaced path
ev("BackendService.replies = Object.assign({}, BackendService.replies, {'exclusive.restore': %s, 'exclusive.status': %s})"
   % (json.dumps({**STATUS_OFF, "replaced": "/b/replaced-1"}), json.dumps(STATUS_OFF)))
ev("clicked()", h.find(win, "exclusiveRestore"))
check(vis("exclusiveConfirm"), "Restore opens the confirmation")
ev("clicked()", h.find(win, "exclusiveConfirmButton"))
check(len(calls("exclusive.restore")) == 1, "confirming calls exclusive.restore")
check(vis("exclusiveRestored") and "/b/replaced-1" in ev("detail", h.find(win, "exclusiveRestored")), "restore result names the replaced files")
check(ev("ExclusiveService.active") is False and vis("exclusiveSteps"), "back to the off state")

# Failure: the backend error is shown, state unchanged
ev("BackendService.replies = Object.assign({}, BackendService.replies, {'exclusive.enable': {error: {message: 'hyprland reload: config errors: x'}}})")
ev("clicked()", h.find(win, "exclusiveEnable"))
ev("clicked()", h.find(win, "exclusiveConfirmButton"))
check(vis("exclusiveError") and "config errors" in ev("detail", h.find(win, "exclusiveError")), "enable failure is shown")
check(ev("ExclusiveService.active") is False, "failed enable leaves it off")

# Blocked (home-manager): Enable disabled with the reason
ev("BackendService.replies = Object.assign({}, BackendService.replies, {'exclusive.status': {active: false, backup: '', disabledUnits: [], compositor: 'hyprland', reason: 'managed by home-manager'}})")
ev("ExclusiveService.refresh()")
check(h.find(win, "exclusiveEnable").property("enabled") is False and "home-manager" in ev("detail", h.find(win, "exclusiveStatus")), "blocked: Enable disabled, reason shown")

h.close() if hasattr(h, "close") else None
if failures:
    print(f"{len(failures)} failure(s)")
    sys.exit(1)
print("OK")
