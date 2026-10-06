#!/usr/bin/env python3
"""Settings > Mods page (modules/settings/mods), offscreen.

The real page components and ModsModel.js run against a scripted
ModsService that records every call.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from settings_env import SettingsEnv  # noqa: E402

from PySide6.QtTest import QTest  # noqa: E402

failures: list[str] = []


def check(cond: bool, msg: str) -> None:
    if not cond:
        failures.append(msg)
        print("FAIL:", msg)


MODS = [
    {"id": "clock-tweaks", "name": "Clock Tweaks", "version": "1.2.0", "order": 1, "enabled": True, "valid": True,
     "compatible": True, "source": "https://example.com/clock.git", "author": "Ana", "license": "MIT",
     "affectedFiles": ["modules/bar/clock/Clock.qml"], "hasSettings": True},
    {"id": "aurora", "name": "Aurora", "version": "0.3.0", "order": 0, "enabled": False, "valid": True,
     "compatible": True, "source": "/home/u/mods/aurora", "dependencyState": [{"id": "base-kit", "enabled": False, "installed": False}]},
    {"id": "broken", "name": "Broken", "version": "", "order": 2, "enabled": False, "valid": False, "compatible": True,
     "error": "manifest missing"},
]

MODS_SERVICE = """pragma Singleton
import QtQuick
QtObject {
    signal installed(string source)
    property var calls: []
    property var mods: (%s)
    property string baseVersion: "0.1.1"
    property string baseRevision: "0123456789abcdef"
    property string activeGeneration: "g3"
    property string previousGeneration: "g2"
    property bool generationCurrent: true
    property string generationError: ""
    property bool busy: false
    property bool loaded: true
    property bool restartRequired: false
    property bool bypassVersionCheck: false
    property bool modsEnabled: true
    property string errorMessage: ""
    property string statusMessage: ""
    property string statusMessageKey: ""
    property var settingsFields: [
        {"key": "seconds", "type": "boolean", "label": "Show seconds"},
        {"key": "style", "type": "enum", "label": "Style", "options": [{"value": "a", "label": "A"}, {"value": "b", "label": "B"}]},
        {"key": "size", "type": "integer", "label": "Size"}
    ]
    property var settingsValues: ({"seconds": false, "style": "a", "size": 12})
    property bool settingsBusy: false
    function rec(m, a) { calls = calls.concat([{"method": m, "args": a}]) }
    function refresh() { rec("refresh", []) }
    function install(s) { rec("install", [s]) }
    function installDependencies(id) { rec("installDependencies", [id]) }
    function setEnabled(id, e) { rec("setEnabled", [id, e]) }
    function update(id, e) { rec("update", [id, e]) }
    function remove(id, e) { rec("remove", [id, e]) }
    function move(id, d) { rec("move", [id, d]) }
    function moveTo(id, p) { rec("moveTo", [id, p]) }
    function rebuild() { rec("rebuild", []) }
    function setBypassVersionCheck(e) { rec("setBypassVersionCheck", [e]) }
    function setModsEnabled(e) { rec("setModsEnabled", [e]) }
    function rollback() { rec("rollback", []) }
    function restart() { rec("restart", []) }
    function loadSettings(id) { rec("loadSettings", [id]) }
    function setSetting(id, k, v) { rec("setSetting", [id, k, v]) }
}""" % json.dumps(MODS)

env = SettingsEnv("mods-ui", overrides={"theme": {"animDuration": 0}})
h = env.h
h.module("qs.modules.services", {"ModsService": MODS_SERVICE})
win = h.load("""
import QtQuick
import QtQuick.Window
import qs.modules.settings.mods
import qs.modules.services
Window {
    width: 1000; height: 2400; visible: true
    ModsEditor { id: page; objectName: "page"; anchors.fill: parent
        category: ({"id": "mods", "icon": "puzzlePiece", "title": "prefs.cat.mods", "description": "prefs.cat.mods.desc"}) }
}""", auto_stub=False)
page = h.find(win, "page")
QTest.qWait(80)


def ev(expr, obj=None):
    return h.eval(obj or page, expr)


def js(expr, obj=None):
    return json.loads(ev("JSON.stringify(%s)" % expr, obj))


def calls(method):
    return js("ModsService.calls.filter(c => c.method === '%s').map(c => c.args)" % method)


def reset_calls():
    ev("ModsService.calls = []")


check(len(calls("refresh")) >= 1, "the page refreshes the mod state on open")
check(ev("page.effectiveId") == "clock-tweaks", "an unknown selection falls back to the first mod")
check(calls("loadSettings")[-1:] == [["clock-tweaks"]], "the selected mod's settings are loaded")

# Selecting another mod loads its settings
ev("page.selectedId = 'aurora'")
check(ev("page.effectiveId") == "aurora", "selection follows selectedId")
check(calls("loadSettings")[-1:] == [["aurora"]], "selecting a mod loads its settings")

# Enabling asks for trust first, then enables
reset_calls()
ev("page.toggle(page.selectedMod)")
check(ev("page.confirmKind") == "enable" and ev("page.confirmSource") == "/home/u/mods/aurora", "enable opens the trust prompt")
check(calls("setEnabled") == [], "nothing is enabled before confirming")
ev("page.runConfirmed()")
check(calls("setEnabled") == [["aurora", True]], "confirming enables the mod")
check(ev("page.confirmKind") == "", "the prompt closes")

# Disabling is immediate
reset_calls()
ev("page.toggle(ModsService.mods[0])")
check(calls("setEnabled") == [["clock-tweaks", False]] and ev("page.confirmKind") == "", "disabling needs no prompt")

# Install: prompt, cancel, prompt, confirm
reset_calls()
ev("page.askConfirm('install', null, 'https://example.com/x.git')")
ev("page.closeConfirm()")
check(calls("install") == [], "cancelling installs nothing")
ev("page.askConfirm('install', null, 'https://example.com/x.git')")
ev("page.runConfirmed()")
check(calls("install") == [["https://example.com/x.git"]], "confirming installs the source")

# List: count, sort, search
lst = h.find(win, "modsList")
check(js("mods.map(m => m.id)", lst) == ["aurora", "broken", "clock-tweaks"], "the list sorts by name")
ev("sortMode = 'loadOrder'", lst)
check(js("mods.map(m => m.id)", lst) == ["aurora", "clock-tweaks", "broken"] and ev("reorderable", lst) is True,
      "load-order view sorts by order and allows dragging")
ev("searchQuery = 'clock'", lst)
check(js("mods.map(m => m.id)", lst) == ["clock-tweaks"] and ev("reorderable", lst) is False,
      "a search filters and disables reordering")
ev("searchQuery = ''; sortMode = 'name'", lst)

# Details: required mods, remove needs a second click
details = h.find(win, "modsDetails")
ev("page.selectedId = 'aurora'")
check(ev("visible", details) is True and ev("mod.id", details) == "aurora", "details show the selected mod")
reset_calls()
ev("removeArmed = true", details)
ev("page.selectedId = 'clock-tweaks'")
check(ev("removeArmed", details) is False, "switching mods disarms Remove")

form_fields = js("ModsService.settingsFields.map(f => f.key)")
check(form_fields == ["seconds", "style", "size"], "settings fields are exposed")

# Banner priorities
banner = h.find(win, "modsBanner")
check(ev("visible", banner) is False, "no banner when all is well")
ev("ModsService.restartRequired = true")
check(ev("visible", banner) is True and ev("message", banner) == ev("I18n.t('mods.restart_required')"), "restart banner")
ev("ModsService.generationCurrent = false; ModsService.generationError = 'stale'")
check(ev("alarming", banner) is True and "stale" in ev("message", banner), "a stale generation outranks the restart")
ev("ModsService.errorMessage = 'boom'")
check(ev("message", banner) == "boom", "an error outranks everything")

if failures:
    print(f"{len(failures)} failure(s)")
    h.exit(1)
print("mods-ui: ok")
h.exit(0)
