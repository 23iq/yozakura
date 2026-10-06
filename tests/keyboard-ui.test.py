#!/usr/bin/env python3
"""Settings > Keyboard page and the bar layout indicator, offscreen.

The real KeyboardService, KeyboardModel.js, page components and indicator run
against a scripted BackendService (tests/lib/keyboard_env.py).
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from keyboard_env import KeyboardEnv  # noqa: E402

from PySide6.QtCore import QPoint, Qt  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

failures: list[str] = []


def check(cond: bool, msg: str) -> None:
    if not cond:
        failures.append(msg)
        print("FAIL:", msg)


env = KeyboardEnv("keyboard-ui", overrides={"theme": {"animDuration": 0}})
h = env.h
win = h.load("""
import QtQuick
import QtQuick.Window
import QtQuick.Layouts
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
page = h.find(win, "page")
QTest.qWait(80)


def ev(expr, obj=None):
    return h.eval(obj or win, expr)


def calls(method):
    return json.loads(ev("JSON.stringify(BackendService.calls.filter(c => c.method === '%s'))" % method))


def item(root, name):
    """Delegates of a Repeater are not QObject children of the card: walk the visual tree."""
    for c in root.childItems():
        if c.objectName() == name:
            return c
        found = item(c, name)
        if found is not None:
            return found
    return None


def js(expr, obj=None):
    return json.loads(ev("JSON.stringify(%s)" % expr, obj))


def cfg(expr):
    return json.loads(ev("JSON.stringify(%s)" % expr))


check(len(calls("keyboard.catalog")) == 1, "the page loads the catalog")
check(ev("Config.keyboard.layouts.length") == 1, "starts with one layout")
check(ev("indicator.visible") is False, "indicator hidden with a single layout")

# Add Russian through the picker
check(h.find(win, "addLayoutButton") is not None, "Add layout button exists")
ev("picking = true", h.find(win, "layoutList"))
QTest.qWait(50)
picker = h.find(win, "picker")
check(picker.property("visible") is True, "picker opens")
res = js("results.map(l => l.name)", picker)
check("us" not in res and "ru" in res, "picker hides layouts already configured")
h.find(win, "pickerSearch").setProperty("text", "russ")
QTest.qWait(50)
check(js("results.map(l => l.name)", picker) == ["ru"], "search filters by description")
ev("picked('ru')", picker)
QTest.qWait(50)
layouts = cfg("Array.from(Config.keyboard.layouts)")
check([l["layout"] for l in layouts] == ["us", "ru"], "adding ru writes keyboard.layouts")
check("keyboard" in cfg("Config.saved"), "keyboard domain saved")
check(ev("picking", h.find(win, "layoutList")) is False, "picking a layout closes the picker")

# Indicator: appears with two layouts, shows RU on a layout event, click -> keyboard.next
check(ev("indicator.visible") is True, "indicator shows with two layouts")
check(cfg("KeyboardService.shortLabel") == "EN", "before any layout event the label is the first layout (EN)")
ev("BackendService.emit('keyboard.layout', {name: 'Russian', index: 1, code: 'ru', short: 'RU'})")
QTest.qWait(80)
check(h.find(win, "layoutLabel").property("text") == "RU", "indicator shows RU after the keyboard.layout event")
ev("KeyboardService.next()")
check(len(calls("keyboard.next")) == 1, "next calls keyboard.next")
before = len(calls("keyboard.next"))
QTest.mouseClick(win, Qt.LeftButton, Qt.NoModifier, QPoint(40, 1518))
QTest.qWait(80)
check(len(calls("keyboard.next")) == before + 1, "clicking the indicator calls keyboard.next")

# showIndicator off hides it
ev("Config.keyboard.showIndicator = false")
check(ev("indicator.visible") is False, "indicator follows keyboard.showIndicator")
ev("Config.keyboard.showIndicator = true")

# Reorder, variant, remove
ev("page.setLayouts([{layout: 'ru', variant: ''}, {layout: 'us', variant: ''}])")
check([l["layout"] for l in cfg("Array.from(Config.keyboard.layouts)")] == ["ru", "us"], "reorder writes the new order")

# Options: switch bind chips and toggles
ev("page.setOptions('caps:escape', true)")
check(cfg("Array.from(Config.keyboard.options)") == ["caps:escape"], "toggle writes keyboard.options")
tog = item(page, "quick:caps:escape")
check(tog is not None and tog.property("checked") is True, "quick toggle reflects the option")
h.find(win, "bindChips").selected.emit("super_space")
check(ev("Config.keyboard.switchBind") == "super_space", "chip picks the switch bind")
ev("page.setOptions('caps:escape', false)")
check(cfg("Array.from(Config.keyboard.options)") == [], "toggle off removes it")

# All options by group
ev("showAll = true", h.find(win, "optionsCard"))
QTest.qWait(50)
check(js("groups.map(g => g.name)", h.find(win, "optionsCard")) == ["caps", "compose"], "all options lists catalog groups (switching handled by chips)")
ev("openGroup = 'caps'", h.find(win, "optionsCard"))
QTest.qWait(50)
check(item(page, "opt:caps:swapescape") is not None, "open group lists its options")

# Repeat sliders
h.find(win, "rateSlider").moved.emit(40)
check(ev("Config.keyboard.repeatRate") == 40, "rate slider writes repeatRate")

# debounced apply
QTest.qWait(900)
check(len(calls("keyboard.apply")) >= 1, "changes are applied through keyboard.apply")

if failures:
    sys.exit(1)
print("ok")
