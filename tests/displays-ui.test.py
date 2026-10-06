#!/usr/bin/env python3
"""Settings > Displays page and the keep/revert + identify overlays, offscreen.

The real DisplaysService, DisplayModel.js, page components and the confirm
card run against a scripted BackendService (tests/lib/displays_env.py).
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from displays_env import DisplaysEnv  # noqa: E402

from PySide6.QtTest import QTest  # noqa: E402

failures: list[str] = []


def check(cond: bool, msg: str) -> None:
    if not cond:
        failures.append(msg)
        print("FAIL:", msg)


env = DisplaysEnv("displays-ui", overrides={"theme": {"animDuration": 0}},
                  replies={"displays.apply": {"session": "s1", "revertIn": 15, "live": True},
                           "displays.conflicts": [{"file": "/h/hypr/monitors.conf", "line": 3, "text": "monitor=DP-1,preferred,auto,1"}]})
h = env.h
win = h.load("""
import QtQuick
import QtQuick.Window
import qs.modules.settings.displays
import qs.modules.shell
import qs.modules.services
import qs.config
Window {
    width: 1000; height: 1400; visible: true
    DisplaysPage { id: page; objectName: "page"; anchors.fill: parent; category: ({"id": "displays", "icon": "monitor", "title": "prefs.cat.displays", "description": "prefs.cat.displays.desc"}) }
    DisplayConfirmCard { id: card; objectName: "card"; x: 100; y: 100; visible: DisplaysService.pending }
}""", auto_stub=False)
page = h.find(win, "page")
QTest.qWait(50)


def ev(expr, obj=None):
    return h.eval(obj or win, expr)


def calls(method):
    return json.loads(ev("JSON.stringify(BackendService.calls.filter(c => c.method === '%s'))" % method))


check(len(calls("displays.conflicts")) >= 1, "the page scans for conflicts on open")
check(h.find(win, "conflictBanner").property("visible") is True, "the conflict banner shows when conflicts exist")
check(ev("title", h.find(win, "conflictBanner")) == "1 monitor rule in your compositor config", "banner pluralises (one)")
check(ev("page.draft.length") == 2, "draft has one entry per output")
tiles = h.find(win, "tiles")
check(ev("count", tiles) == 2 and ev("itemAt(0).config.name", tiles) == "DP-1" and ev("itemAt(1).visible", tiles) is True, "a tile per monitor")
check(ev("page.selectedName") == "DP-1", "first monitor selected")
check(ev("page.dirty") is False, "nothing to apply at first")
check(h.find(win, "applyButton").property("enabled") is False, "Apply is disabled until something changed")
check(h.find(win, "upgradeHint").property("visible") is True, "upgrade hint: 240 Hz available at 2560x1440")

# Pick 240 Hz, then Apply -> displays.apply with the candidate
ev("page.edit('DP-1', {refresh: 240})")
check(ev("page.dirty") is True, "a refresh change makes the draft dirty")
check(h.find(win, "applyButton").property("enabled") is True, "Apply enables")
check(h.find(win, "upgradeHint").property("visible") is False, "hint disappears at the maximum")
ev("page.applyDraft()")
applied = calls("displays.apply")
check(len(applied) == 1, "Apply calls displays.apply")
if applied:
    outs = {o["name"]: o for o in applied[0]["params"]["outputs"]}
    check(outs["DP-1"]["refresh"] == 240 and outs["HDMI-A-1"]["refresh"] == 144, "candidate carries the new refresh and the untouched monitor")
check(ev("DisplaysService.pending") is True, "session is pending after apply")
check(h.find(win, "card").property("visible") is True, "confirm card shows while pending")
check(ev("card.total") == 15, "the ring's total is captured when the session starts")
check(ev("card.remaining") == 15 and h.find(win, "countdownText").property("text") == "15", "countdown starts at 15")

# Keep -> displays.keep and the layout is saved
ev("BackendService.replies = Object.assign({}, BackendService.replies, {'displays.keep': {}})")
check(h.find(win, "keepButton") is not None, "Keep button exists")
ev("DisplaysService.keep()")
check(len(calls("displays.keep")) == 1 and calls("displays.keep")[0]["params"]["session"] == "s1", "Keep calls displays.keep with the session")
saved = json.loads(ev("JSON.stringify(Config.displays.monitors)"))
check(len(saved) == 2 and {s["name"]: s["refresh"] for s in saved}.get("DP-1") == 240, "Keep writes displays.monitors")
check("displays" in json.loads(ev("JSON.stringify(Config.saved)")), "displays domain saved to disk")

# Revert calls displays.revert (state pending again)
ev("DisplaysService.session = {id: 's2', state: 'pending', remaining: 9, live: true}")
ev("DisplaysService.revert()")
check(len(calls("displays.revert")) == 1, "Revert calls displays.revert")
check(h.find(win, "card").property("remaining") == 9, "countdown follows the session")
ev("DisplaysService.session = {id: 's5', state: 'pending', remaining: 15, live: true}")
ev("DisplaysService.session = {id: 's5', state: 'pending', remaining: 5, live: true}")
ring = h.find(win, "countdownRing")
check(ev("card.total") == 15 and abs(ev("fraction", ring) - 5 / 15) < 0.01, "ring is a third full at 5 s of 15")
ev("DisplaysService.session = {id: 's4', state: 'pending', remaining: 8, live: true}")
check(ev("card.total") == 8, "a new session id re-captures the total")
check(abs(ev("fraction", ring) - 1) < 0.01, "a fresh session starts with a full ring")

# Dragging: dropping HDMI near DP-1's bottom snaps below it
ev("DisplaysService.session = {id: '', state: '', remaining: 0, live: true}")
ev("page.resync()")
ev("page.edit('HDMI-A-1', {scale: 2})")
d = json.loads(ev("JSON.stringify(page.draft)"))
check(d[1]["scale"] == 2 and (d[1]["x"] >= 2560 or d[1]["y"] >= 1440), "scaling keeps the monitors from overlapping")

# Dragging: dropping HDMI-A-1 near the bottom of DP-1 snaps it below
ev("page.resync()")
ev("itemAt(1).dropped(100, 1450)", tiles)
d = json.loads(ev("JSON.stringify(page.draft)"))
check(d[1]["y"] == 1440 and d[0]["y"] == 0, f"a drop snaps to the other monitor's edge, got {d[1]['x']},{d[1]['y']}")
tile = ev("itemAt(1).x", tiles)
check(abs(tile - ev("itemAt(1).baseX", tiles)) < 1, "the tile sits on its snapped position")

# Disable guard: the last enabled monitor cannot be switched off
ev("page.resync()")
ev("page.edit('HDMI-A-1', {enabled: false})")
ev("page.edit('DP-1', {enabled: false})")
d = json.loads(ev("JSON.stringify(page.draft)"))
check(d[0]["enabled"] is True, "the last enabled monitor stays on")

# Not live (Mango): inline note, no overlay
ev("DisplaysService.session = {id: 's3', state: 'pending', remaining: 15, live: false}")
check(h.find(win, "deferredNote").property("visible") is True, "non-live session shows the inline note")
ev("DisplaysService.session = {id: '', state: '', remaining: 0, live: true}")

# Conflicts: move calls displays.moveConflicts
ev("BackendService.replies = Object.assign({}, BackendService.replies, {'displays.moveConflicts': {outputs: [], moved: [], skipped: []}})")
ev("DisplaysService.moveConflicts()")
check(len(calls("displays.moveConflicts")) == 1, "the banner action calls displays.moveConflicts")

# Identify
ev("DisplaysService.identify()")
check(len(calls("displays.identify")) == 1, "Identify calls displays.identify")

h.exit(1 if failures else 0)
