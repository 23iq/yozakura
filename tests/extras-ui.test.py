#!/usr/bin/env python3
"""Settings > Apps & Extras: catalog cards, selection, install bar, live
progress, multilib consent, failures and the offline banner, offscreen.

The real ExtrasService, ExtrasModel.js and modules/extras components run
against a scripted BackendService (tests/lib/extras_env.py).
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from extras_env import ExtrasEnv  # noqa: E402

from PySide6.QtCore import QPointF, Qt  # noqa: E402
from PySide6.QtQuick import QQuickItem  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

failures: list[str] = []


def check(cond: bool, msg: str) -> None:
    if not cond:
        failures.append(msg)
        print("FAIL:", msg)


NEEDS_MULTILIB = 'needs_confirm: {"kind":"multilib","entries":["steam"]}'
env = ExtrasEnv("extras-ui", overrides={"theme": {"animDuration": 0}},
                replies={"extras.install": [{"jobs": []}, {"error": NEEDS_MULTILIB}, {"jobs": []},
                                            {"error": 'unavailable: {"reasons":{"steam":"needs_aur_helper"}}'}]})
h = env.h
win = h.load("""
import QtQuick
import QtQuick.Window
import qs.modules.settings.extras
import qs.modules.services
Window {
    width: 1100; height: 1300; visible: true
    ExtrasPage { id: page; objectName: "page"; anchors.fill: parent
        category: ({"id": "extras", "icon": "packageBox", "title": "prefs.cat.extras", "description": "prefs.cat.extras.desc"}) }
}""")
QTest.qWait(80)


def ev(expr, obj=None):
    return h.eval(obj or win, expr)


def js(expr, obj=None):
    return json.loads(ev("JSON.stringify(%s)" % expr, obj))


def calls(method):
    return js("BackendService.calls.filter(c => c.method === '%s')" % method)


def item(root, name):
    """Repeater delegates are not QObject children of the grid: walk the visual tree."""
    for c in root.childItems():
        if c.objectName() == name:
            return c
        found = item(c, name)
        if found is not None:
            return found
    return None


def card(entry_id):
    return item(win.findChild(QQuickItem, "page"), "card-" + entry_id)


def visible(it) -> bool:
    return it is not None and bool(it.isVisible())


def click(it) -> None:
    p = it.mapToScene(QPointF(it.width() / 2, it.height() / 2)).toPoint()
    QTest.mouseClick(win, Qt.LeftButton, Qt.NoModifier, p)
    QTest.qWait(30)


def emit(service, data):
    ev("BackendService.emit('%s', %s)" % (service, json.dumps(data)))
    QTest.qWait(30)


check(len(calls("extras.catalog")) == 1, "the page loads the catalog once")
check(len(calls("extras.status")) >= 1, "the page loads the status")
check(card("nodejs") is None, "hidden entries are never shown")
check(card("claude-code") is not None and card("steam") is not None, "missing entries are shown")

firefox = card("firefox")
check(ev("cardState", firefox) == "installed", "installed entry has the installed state")
check(visible(item(firefox, "installedPill")), "installed card shows the Installed pill")
check(not visible(item(firefox, "toggle")), "installed card has no selection toggle")
check(ev("text", item(firefox, "installedPill")) == "Installed", "the pill reads Installed")

bar = h.find(win, "installBar")
check(ev("shown", bar) is False, "install bar hidden without selection")

# select two cards: the toggle of one, the card body of the other
click(item(card("claude-code"), "toggle"))
click(card("chromium"))
check(js("ids", bar) == ["claude-code", "chromium"], "two entries selected, in catalog order: %s" % js("ids", bar))
check(ev("shown", bar) is True, "install bar shows with a selection")
button = h.find(win, "installButton")
label = ev("text", button)
check("Install 2 apps" in label and "1.4 GB" in label, "button names the count and size: %r" % label)
click(card("chromium"))
check(js("ids", bar) == ["claude-code"], "clicking a selected card unselects it")
click(card("chromium"))

click(button)
inst = calls("extras.install")
check(len(inst) == 1 and inst[0]["params"] == {"ids": ["claude-code", "chromium"], "confirmMultilib": False},
      "install sends the selected ids: %s" % inst)
check(js("ids", bar) == [], "a queued request clears the selection")

# live progress
emit("extras.progress", {"job": "script-1", "kind": "script", "entries": ["claude-code"], "state": "running",
                         "percent": 40, "phase": "Downloading"})
cc = card("claude-code")
check(ev("cardState", cc) == "installing", "progress event switches the card to installing")
track = item(cc, "progressTrack")
check(visible(track) and ev("percent", track) == 40, "the card shows the progress bar at 40%")
check(not visible(item(cc, "toggle")), "an installing card has no toggle")
check(ev("enabled", item(cc, "cancelButton")) is True, "a running script job can be cancelled")
click(item(cc, "cancelButton"))
check(calls("extras.cancel") == [{"method": "extras.cancel", "params": {"job": "script-1"}}], "cancel sends the job id")
check("Installing Claude Code" in ev("text", h.find(win, "jobLabel")), "install bar summarises the running job")

# a running system job cannot be cancelled
emit("extras.progress", {"job": "system-2", "kind": "system", "entries": ["chromium"], "state": "running",
                         "percent": -1, "phase": "installing chromium..."})
check(ev("enabled", item(card("chromium"), "cancelButton")) is False, "running system install: cancel disabled")

# multilib consent, asked while the grid is scrolled to the bottom: the
# confirm floats in the sticky stack above the install bar
win.setHeight(560)
QTest.qWait(50)
flick = h.find(win, "catalogFlick")
ev("contentY = Math.max(0, contentHeight - height)", flick)
QTest.qWait(30)
check(ev("contentY", flick) > 0, "the catalog scrolls in a short window")
ev("toggle('steam')", h.find(win, "catalogGrid"))
click(h.find(win, "installButton"))
confirm = h.find(win, "multilibConfirm")
check(ev("visible", confirm) is True, "needs_confirm shows the multilib confirm card")
top = confirm.mapToScene(QPointF(0, 0)).y()
check(0 <= top and top + confirm.height() <= 560, "the confirm card is inside the viewport (y=%s)" % top)
check("Steam" in ev("title", confirm), "the confirm card names Steam: %r" % ev("title", confirm))
check(js("ids", bar) == ["steam"], "selection kept while waiting for consent")
click(h.find(win, "confirmAccept"))
inst = calls("extras.install")
check(inst[-1]["params"] == {"ids": ["steam"], "confirmMultilib": True}, "accepting re-sends with confirmMultilib: %s" % inst[-1])
check(ev("visible", confirm) is False, "confirm card closes after the accepted request")
ev("contentY = 0", flick)
win.setHeight(1300)
QTest.qWait(50)

# failure with needs_sync -> update system and retry; log popup
emit("extras.progress", {"job": "system-2", "kind": "system", "entries": ["chromium"], "state": "failed",
                         "percent": -1, "phase": "", "reason": "needs_sync"})
ch = card("chromium")
check(ev("cardState", ch) == "failed", "failed job marks the card failed")
retry = item(ch, "retryButton")
check(visible(retry) and ev("text", retry) == "Update system and retry", "needs_sync offers update and retry")
click(retry)
check(calls("extras.upgradeAndRetry") == [{"method": "extras.upgradeAndRetry", "params": {"job": "system-2"}}],
      "update and retry sends the failed job")
click(item(ch, "logButton"))
popup = h.find(win, "logPopup")
check(ev("opened", popup) is True, "Log opens the log popup")
check("failed retrieving" in ev("text", popup), "the popup shows the job log")
ev("close()", popup)
QTest.qWait(80)
check(ev("opened", popup) is False, "the log popup closes")

# refused install (no AUR helper)
click(card("steam"))
check(js("ids", bar) == ["steam"], "steam selectable again")
click(h.find(win, "installButton"))
notice = h.find(win, "unavailableNotice")
check(ev("visible", notice) is True, "unavailable error shows the refused notice")
check("AUR helper" in ev("message", notice), "the notice explains the AUR helper: %r" % ev("message", notice))

# offline
emit("extras.progress", {"job": "flatpak-4", "kind": "flatpak", "entries": ["claude-code"], "state": "failed",
                         "reason": "network"})
check(ev("visible", h.find(win, "offlineNotice")) is True, "a network failure shows the offline banner")
check(ev("enabled", h.find(win, "installButton")) is False, "installs are disabled while offline")

# status event: detection catches up
emit("extras.status", {**{k: {"id": k, "state": "missing"} for k in ("claude-code", "nodejs", "steam", "chromium")},
                       "firefox": {"id": "firefox", "state": "installed"},
                       "claude-code": {"id": "claude-code", "state": "installed", "source": "bin"}})
check(ev("cardState", card("claude-code")) == "installed", "a status event marks the card installed")

# guards: no install while offline
n = len(calls("extras.install"))
ev("ExtrasService.install(['chromium'], false)")
check(len(calls("extras.install")) == n, "install is refused while offline")

# a done job pins "installed" only until a fresh detection covers it
ev("ExtrasService.offline = false")
emit("extras.progress", {"job": "flatpak-6", "kind": "flatpak", "entries": ["chromium"], "state": "done"})
check(ev("cardState", card("chromium")) == "installed", "a finished job shows installed right away")
QTest.qWait(1700)
check(ev("cardState", card("chromium")) == "selectable", "the forced re-detection (still missing) drops the finished job")

# onboarding host: recommended + missing preselected once, installed never
emit("extras.status", __import__("extras_env").STATUS)
win2 = h.load("""
import QtQuick
import QtQuick.Window
import qs.modules.extras
Window {
    width: 900; height: 700; visible: true
    CatalogHost { objectName: "onboardingHost"; anchors.fill: parent; mode: "onboarding" }
}""")
QTest.qWait(80)
host = h.find(win2, "onboardingHost")
check(js("selected", host) == {"claude-code": True}, "onboarding preselects recommended missing entries: %s" % js("selected", host))
check(ev("autoPreselect", host) is True, "onboarding mode preselects by default")

if failures:
    print(f"{len(failures)} failure(s)")
    h.exit(1)
print("extras-ui: ok")
h.exit(0)
