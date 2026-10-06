#!/usr/bin/env python3
"""Ruling K-1: the user's own compositor keyboard settings stay until changed.

The real KeyboardService, KeyboardModel.js and Settings > Keyboard page run
against a scripted BackendService whose compositor reports us,ru with
Alt+Shift and repeat 111/175 (keyboard.current) while the keyboard domain
still holds the defaults (us, 25/600, managed false). Nothing may be applied
or rendered at startup; the page shows the compositor's values with a note;
the first change takes them over (managed) and is applied once.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from keyboard_env import KeyboardEnv  # noqa: E402

from PySide6.QtTest import QTest  # noqa: E402

failures: list[str] = []


def check(cond: bool, msg: str) -> None:
    if not cond:
        failures.append(msg)
        print("FAIL:", msg)


CURRENT = {"available": True, "layouts": [{"layout": "us", "variant": ""}, {"layout": "ru", "variant": ""}],
           "switchBind": "alt_shift", "options": [], "repeatRate": 111, "repeatDelay": 175}
env = KeyboardEnv("keyboard-managed", overrides={"theme": {"animDuration": 0}}, replies={"keyboard.current": CURRENT})
h = env.h
win = h.load("""
import QtQuick
import QtQuick.Window
import qs.modules.settings.keyboard
import qs.modules.bar.modules
import qs.modules.services
import qs.config
Window {
    width: 1000; height: 1600; visible: true
    KeyboardPage { id: page; objectName: "page"; width: parent.width; height: 1400; category: ({"id": "keyboard", "icon": "keyboard", "title": "prefs.cat.keyboard", "description": "prefs.cat.keyboard.desc"}) }
    Item { id: fakeBar; property string orientation: "horizontal"; property int moduleSize: 36; property bool flat: false; property string panelStyle: "classic"; property string barPosition: "top" }
    KeyboardLayoutIndicator { id: indicator; objectName: "indicator"; bar: fakeBar; x: 10; y: 1500; width: 90; height: 36 }
}""")


def ev(expr, obj=None):
    return h.eval(obj or win, expr)


def js(expr, obj=None):
    return json.loads(ev("JSON.stringify(%s)" % expr, obj))


def calls(method):
    return js("BackendService.calls.filter(c => c.method === '%s')" % method)


QTest.qWait(900)  # past the apply debounce

# Startup: read only
check(len(calls("keyboard.current")) >= 1, "the compositor's settings are read")
check(calls("keyboard.apply") == [], "nothing is applied at startup while unmanaged")
check(ev("KeyboardService.compositorInput()") is None, "no keyboard in the compositor payload while unmanaged")
check(js("Config.saved") == [], "nothing is written at startup")

# The page shows the compositor's values, with the note
check([l["layout"] for l in js("layouts", h.find(win, "layoutList"))] == ["us", "ru"], "layouts are the compositor's (us,ru)")
check(ev("value", h.find(win, "rateSlider")) == 111, "repeat rate is the compositor's (111)")
check(ev("value", h.find(win, "delaySlider")) == 175, "repeat delay is the compositor's (175)")
check(ev("switchBind", h.find(win, "optionsCard")) == "alt_shift", "switch bind is the compositor's")
check(h.find(win, "unmanagedNote").property("visible") is True, "the unmanaged note shows")
check(ev("indicator.visible") is True, "the bar indicator follows the layouts in effect")
check([l["layout"] for l in js("Array.from(Config.keyboard.layouts)")] == ["us"], "the domain still holds the defaults")

# The indicator toggle is the shell's own: it does not take over
ev("indicatorToggled(false)", h.find(win, "layoutList"))
check(ev("Config.keyboard.showIndicator") is False and ev("Config.keyboard.managed") is False, "showIndicator alone stays unmanaged")
ev("indicatorToggled(true)", h.find(win, "layoutList"))
QTest.qWait(600)
check(calls("keyboard.apply") == [], "the indicator toggle applies nothing")

# The first change takes over the compositor's values, then applies once
h.find(win, "rateSlider").moved.emit(120)
check(ev("Config.keyboard.managed") is True, "the first change sets keyboard.managed")
check([l["layout"] for l in js("Array.from(Config.keyboard.layouts)")] == ["us", "ru"], "us,ru is copied in, never lost")
check(ev("Config.keyboard.repeatDelay") == 175 and ev("Config.keyboard.repeatRate") == 120, "the change lands on the compositor's values")
QTest.qWait(900)
applied = calls("keyboard.apply")
check(len(applied) == 1, f"applied exactly once, got {len(applied)}")
if applied:
    p = applied[0]["params"]
    check([l["layout"] for l in p["layouts"]] == ["us", "ru"] and p["repeatRate"] == 120 and p["repeatDelay"] == 175
          and p["switchBind"] == "alt_shift", f"apply carries us,ru 120/175 alt_shift, got {p}")
check(ev("KeyboardService.compositorInput() !== null"), "managed: the keyboard is rendered into the compositor config")
check(h.find(win, "unmanagedNote").property("visible") is False, "the note goes once managed")

if failures:
    sys.exit(1)
print("ok")
