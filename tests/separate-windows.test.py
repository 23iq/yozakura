#!/usr/bin/env python3
"""Separate Settings / wizard windows, main shell side, offscreen.

The real SeparateWindows + PreviewSink + GlobalStates (snapshot machinery)
over a typed Config with every default domain and a fake BackendService
that records calls and lets the test push the daemon's `windows` and
`preview` events (backend/pkg/svc/windows, backend/pkg/svc/preview).

Preview relay: a staged value from the Settings process is applied to the
in-memory Config through the GlobalStates snapshot (staged, auto-save
paused); discard (Discard, closing, the process dying) restores what was
there; commit (Apply: the window wrote the files) keeps the values and
drops the snapshots without restoring; an unstaged key is refused.

Window flow with performance.separateWindows off: nothing is asked of the
daemon, the in-process window is used. On: opening asks windows.open with
the page and the target screen, the flag mirrors the process, a toggle off
asks windows.close and keeps the flag up until the process is gone, a page
asked while it runs raises it, a start failure falls back to the
in-process window, a window open in-process stays in-process when the
setting changes. The wizard: the same, and a closed (or crashed) wizard
never auto-shows again this session. Relays: only allowed wallpaper
methods reach the main shell's manager.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from qmlharness import REPO, Harness, hard_exit  # noqa: E402
from settings_env import colors_qml, config_qml, load_defaults, DEFAULT_PALETTE  # noqa: E402

from waits import pump, settle  # noqa: E402

failures: list[str] = []


def check(cond: bool, msg: str) -> None:
    if not cond:
        failures.append(msg)
        print("FAIL:", msg)


BACKEND = """pragma Singleton
QtObject {
    property var calls: []
    property var subs: []
    property var cbs: []
    // windows.open answers with this error (null: ok)
    property var openError: null
    property bool socketAvailable: true
    // false: windows.open is not answered until answerHeld()
    property bool answerOpen: true
    property var held: null
    function answerHeld() { const h = held; held = null; if (h) h({ "result": "started" }, null) }
    function addSubscription(s, cb) { subs = subs.concat(s); cbs = cbs.concat([{ "s": s, "cb": cb }]); return cbs.length }
    function call(m, p, cb) {
        calls = calls.concat([{ "method": m, "params": p || null }]);
        if (cb && m === "windows.open" && !answerOpen) { held = cb; return }
        if (cb) Qt.callLater(() => cb(m === "windows.open" && openError ? null : { "result": "ok" }, m === "windows.open" ? openError : null));
    }
    function notify(m, p) { call(m, p) }
    function emit(service, data) {
        const group = service.split(".")[0];
        cbs.forEach(c => { if (c.s.indexOf(group) >= 0) c.cb(service, data); });
    }
    function last(m) { const l = calls.filter(c => c.method === m); return l.length ? l[l.length - 1].params : null }
    function count(m) { return calls.filter(c => c.method === m).length }
}"""

h = Harness("separate-windows")
qs = h.root / "qs"
domains = load_defaults()
(qs / "config").mkdir(parents=True, exist_ok=True)
(qs / "config" / "Config.qml").write_text(config_qml(domains))
(qs / "config" / "ColorSpec.js").write_text((REPO / "config/ColorSpec.js").read_text())
h.module("qs.config", {})
h.module("qs.modules.theme", {"Colors": colors_qml(DEFAULT_PALETTE)})
h.module("Quickshell", {
    "Singleton": "QtObject { default property list<QtObject> data }",
    "Quickshell": "pragma Singleton\nQtObject { property var screens: []; function env(n) { return \"\" } }",
})
h.module("Quickshell.Io", {
    "Process": "QtObject { property var command; property bool running; property var stdout; signal exited(int code) }",
    "StdioCollector": "QtObject { property string text; signal streamFinished() }",
})
h.copy("modules/globals/GlobalStates.qml", "qs/modules/globals", siblings=False)
h.module("qs.modules.globals", {})
h.module("qs.modules.services", {
    "BackendService": BACKEND,
    "StateService": "pragma Singleton\nQtObject { property bool initialized: true; function get(k, d) { return d } function set(k, v) {} }",
    "YozdService": "pragma Singleton\nQtObject { property var focusedMonitor: null; property string compositorName: \"\" }",
    "Visibilities": "pragma Singleton\nQtObject { property string currentActiveModule: \"\"; property var reservations: ({}); "
                    "function getForActive() { return null } }",
    "LockscreenService": "pragma Singleton\nQtObject { property bool locked: false; property bool visible: false }",
    "OnboardingService": """pragma Singleton
QtObject {
    property bool visible: false
    property bool peek: false
    property bool dismissedThisSession: false
    property string screenName: "DP-2"
    property int opens: 0
    function open() { opens++; visible = true }
}""",
    "GlobalShortcuts": """pragma Singleton
QtObject {
    property int toggles: 0
    function toggleSettings() { toggles++ }
}""",
})
h.copy("modules/services/SeparateWindows.qml", "qs/modules/services", siblings=False,
       replace={"openTimeout: 3000": "openTimeout: 150"})
h.copy("modules/services/PreviewSink.qml", "qs/modules/services", siblings=False)
(qs / "modules/settings").mkdir(parents=True, exist_ok=True)
(qs / "modules/settings/ConfigWrite.js").write_text((REPO / "modules/settings/ConfigWrite.js").read_text())
h.copy("config/JsonUtil.js", "qs/config")
h.module("qs.modules.services", {})

root = h.load("""
import QtQuick
import qs.modules.services
import qs.modules.globals
import qs.config
Item {
    property var wallCalls: []
    property QtObject manager: QtObject {
        function setWallpaper(p, s) { wallCalls = wallCalls.concat([["setWallpaper", p, s || ""]]) }
        function setMatugenScheme(s) { wallCalls = wallCalls.concat([["setMatugenScheme", s]]) }
        function writeFiles() { wallCalls = wallCalls.concat([["writeFiles"]]) }
    }
    readonly property bool wanted: SeparateWindows.wanted
    Component.onCompleted: GlobalStates.wallpaperManager = manager
}""", auto_stub=False)


def ev(expr):
    return h.eval(root, expr)


def emit(service, data):
    ev(f"BackendService.emit({json.dumps(service)}, {json.dumps(data)})")
    settle()


def calls(method):
    return ev(f"BackendService.count({json.dumps(method)})")


# ---- the setting off: nothing changes ----
check(ev("SeparateWindows.wanted") is False, "off by default")
check(ev("BackendService.subs.length") == 0, "off: no daemon streams")
ev("GlobalStates.settingsCategory = 'network'")
ev("GlobalStates.settingsWindowVisible = true")
settle()
check(calls("windows.open") == 0, "off: opening Settings asks nothing of the daemon")
check(ev("SeparateWindows.settingsSeparate") is False, "off: the in-process window is used")
ev("Config.performance.separateWindows = true")
settle()
check(ev("SeparateWindows.settingsSeparate") is False, "a window open in-process stays in-process when the setting is turned on")
ev("GlobalStates.settingsWindowVisible = false")
settle()
check(ev("SeparateWindows.settingsSeparate") is True, "...and the next open is separate")
subs = json.loads(ev("JSON.stringify(BackendService.subs)"))
check("windows" in subs and "preview" in subs, f"on: subscribed to the windows and preview streams, got {subs}")

# ---- Settings as its own process ----
ev("GlobalStates.settingsTargetScreenName = 'DP-1'")
ev("GlobalStates.settingsTargetWorkspaceId = 4")
ev("GlobalStates.settingsWindowVisible = true")
settle()
check(calls("windows.open") == 1, "opening asks windows.open")
check(json.loads(ev("JSON.stringify(BackendService.last('windows.open'))")) ==
      {"kind": "settings", "page": "network", "screen": "DP-1", "workspace": 4}, "with the page, screen and workspace")
check(ev("SeparateWindows.settingsOpening") is True, "the opening pill shows at once")
emit("windows.state", {"kind": "settings", "state": "starting", "pid": 7})
check(ev("GlobalStates.settingsWindowVisible") is True and ev("SeparateWindows.settingsRunning") is True, "starting: mirrored")
emit("windows.state", {"kind": "settings", "state": "open", "pid": 7})
check(ev("SeparateWindows.settingsOpening") is False, "shown: the pill goes")
ev("GlobalStates.settingsCategory = 'sound'")
settle()
check(calls("windows.open") == 2 and json.loads(ev("JSON.stringify(BackendService.last('windows.open'))"))["page"] == "sound",
      "a page asked while it runs raises it on that page")
# a toggle off asks the window; the flag stays up while it runs
ev("GlobalStates.settingsWindowVisible = false")
settle()
check(calls("windows.close") == 1, "a toggle off asks windows.close")
check(ev("GlobalStates.settingsWindowVisible") is True, "...and the flag stays up while the process runs")
emit("windows.state", {"kind": "settings", "state": "closed"})
check(ev("GlobalStates.settingsWindowVisible") is False, "the process is gone: closed")
check(calls("windows.close") == 1, "...without asking it to close again")
# closed by the user, the process quits in a moment: the keybind raises it
ev("GlobalStates.settingsWindowVisible = true")
settle()
emit("windows.state", {"kind": "settings", "state": "open", "pid": 10})
opens = calls("windows.open")
emit("windows.state", {"kind": "settings", "state": "hiding", "pid": 10})
check(ev("GlobalStates.settingsWindowVisible") is False and ev("SeparateWindows.settingsRunning") is True,
      "hiding: the flag is down while the process still runs")
ev("GlobalStates.settingsWindowVisible = true")
settle()
check(calls("windows.open") == opens + 1, "opening it while hiding asks windows.open (the daemon raises it)")
check(ev("GlobalStates.settingsWindowVisible") is True, "...and the flag stays up")
emit("windows.state", {"kind": "settings", "state": "open", "pid": 10})
check(ev("GlobalStates.settingsWindowVisible") is True and ev("SeparateWindows.settingsOpening") is False, "shown again")
# asked while hiding, but it quit before the raise reached it: a new process
emit("windows.state", {"kind": "settings", "state": "hiding", "pid": 10})
ev("GlobalStates.settingsWindowVisible = true")
settle()
emit("windows.state", {"kind": "settings", "state": "closed"})
check(calls("windows.open") == opens + 3, "it quit before the raise: opened again")
check(ev("GlobalStates.settingsWindowVisible") is True, "...the flag stays up")
emit("windows.state", {"kind": "settings", "state": "starting", "pid": 11})
emit("windows.state", {"kind": "settings", "state": "open", "pid": 11})
ev("GlobalStates.settingsWindowVisible = false")
settle()
emit("windows.state", {"kind": "settings", "state": "closed"})
check(ev("GlobalStates.settingsWindowVisible") is False, "closed again")
# the setting turned off while one runs: it stays separate until it closes
ev("GlobalStates.settingsWindowVisible = true")
settle()
emit("windows.state", {"kind": "settings", "state": "open", "pid": 8})
ev("Config.performance.separateWindows = false")
settle()
check(ev("SeparateWindows.settingsSeparate") is True, "turned off while running: still separate")
emit("windows.state", {"kind": "settings", "state": "closed"})
check(ev("SeparateWindows.settingsSeparate") is False and ev("GlobalStates.settingsWindowVisible") is False,
      "...until it closed")
ev("Config.performance.separateWindows = true")
settle()

# a process that cannot start: the in-process window instead
ev("BackendService.openError = 'windows: settings-window.qml not found'")
ev("GlobalStates.settingsWindowVisible = true")
settle()
settle()
check(ev("SeparateWindows.settingsSeparate") is False and ev("GlobalStates.settingsWindowVisible") is True,
      "a failed start falls back to the in-process window")
check(ev("SeparateWindows.settingsOpening") is False, "...without the opening pill")
ev("GlobalStates.settingsWindowVisible = false")
ev("BackendService.openError = null")
settle()
check(ev("SeparateWindows.settingsSeparate") is True, "closed: the next open tries the process again")

# no daemon (qs -p shell.qml alone): the in-process window at once
ev("BackendService.socketAvailable = false")
opens = calls("windows.open")
ev("GlobalStates.settingsWindowVisible = true")
settle()
check(calls("windows.open") == opens, "no daemon: nothing is asked of it")
check(ev("SeparateWindows.settingsSeparate") is False and ev("GlobalStates.settingsWindowVisible") is True
      and ev("SeparateWindows.settingsOpening") is False, "...the in-process window opens at once, no pill")
ev("GlobalStates.settingsWindowVisible = false")
settle()
ev("OnboardingService.visible = true")
settle()
check(calls("windows.open") == opens and ev("SeparateWindows.wizardSeparate") is False
      and ev("OnboardingService.visible") is True, "no daemon: the wizard opens in-process too")
ev("OnboardingService.visible = false")
settle()
ev("BackendService.socketAvailable = true")
# the daemon does not answer: in-process after the bound; a late answer closes that window
ev("BackendService.answerOpen = false")
ev("GlobalStates.settingsWindowVisible = true")
settle()
check(calls("windows.open") == opens + 1 and ev("SeparateWindows.settingsOpening") is True, "asked, waiting")
pump(400)
check(ev("SeparateWindows.settingsSeparate") is False and ev("GlobalStates.settingsWindowVisible") is True,
      "no answer in time: the in-process window opens")
closes = calls("windows.close")
ev("BackendService.answerHeld()")
settle()
check(calls("windows.close") == closes + 1, "...and the window started late is closed again")
ev("BackendService.answerOpen = true")
ev("GlobalStates.settingsWindowVisible = false")
settle()

# ---- staged previews ----
pos = ev("Config.bar.position")
rnd = ev("Config.theme.roundness")
emit("preview.set", {"owner": "settings", "key": "bar.position", "value": "left" if pos != "left" else "right"})
moved = ev("Config.bar.position")
check(moved != pos, "a staged value previews on the desktop")
check(ev("GlobalStates.shellHasChanges") is True and ev("GlobalStates.shellSnapshot !== null") is True,
      "...staged through the shell snapshot (auto-save paused)")
emit("preview.set", {"owner": "settings", "key": "theme.roundness", "value": rnd + 3})
check(ev("Config.theme.roundness") == rnd + 3 and ev("GlobalStates.themeHasChanges") is True, "theme values too")
lang = ev("Config.general.language") if "language" in domains.get("general", {}) else None
emit("preview.set", {"owner": "settings", "key": "general.onboardingDone", "value": "x"})
check(ev("Config.general.onboardingDone") != "x", "an unstaged key is refused (it would be written here)")
emit("preview.discard", {"owner": "settings"})
check(ev("Config.bar.position") == pos and ev("Config.theme.roundness") == rnd, "discard restores the values")
check(ev("GlobalStates.shellHasChanges") is False and ev("GlobalStates.themeHasChanges") is False, "...and unstages")
saved_before = ev("Config.saved.length")
emit("preview.set", {"owner": "settings", "key": "bar.position", "value": moved})
emit("preview.set", {"owner": "settings", "key": "notch.activities", "value": [{"id": "media"}]})
emit("preview.commit", {"owner": "settings"})
check(ev("Config.bar.position") == moved, "commit keeps the previewed values")
check(ev("GlobalStates.shellHasChanges") is False and ev("GlobalStates.shellSnapshot") is None, "...drops the snapshot")
check(ev("Config.saved.length") == saved_before, "...and writes nothing here (the window wrote the files)")

# ---- the wizard ----
ev("OnboardingService.visible = true")
settle()
check(json.loads(ev("JSON.stringify(BackendService.last('windows.open'))")) == {"kind": "onboarding", "screen": "DP-2"},
      "the wizard opens as its own process on its screen")
emit("windows.state", {"kind": "onboarding", "state": "open", "pid": 9})
relay = json.loads(ev("JSON.stringify(BackendService.last('windows.relay'))"))
check(relay and relay["to"] == "onboarding" and relay["data"] == {"panelOpen": False, "bottomZone": 0},
      f"it is told the main shell's panel state, got {relay}")
ev("Visibilities.currentActiveModule = 'launcher'")
settle()
relay = json.loads(ev("JSON.stringify(BackendService.last('windows.relay'))"))
check(relay["data"]["panelOpen"] is True, "...again when a panel opens (keybind tour)")
emit("windows.state", {"kind": "onboarding", "state": "closed"})
check(ev("OnboardingService.visible") is False and ev("OnboardingService.dismissedThisSession") is True,
      "a closed or crashed wizard is closed and never auto-shown again this session")

# ---- what a window asks of the main shell ----
emit("windows.relay", {"to": "shell", "topic": "wallpaper.call", "data": {"method": "setWallpaper", "args": ["/w/a.png", "DP-1"]}})
emit("windows.relay", {"to": "shell", "topic": "wallpaper.call", "data": {"method": "writeFiles", "args": []}})
emit("windows.relay", {"to": "settings", "topic": "wallpaper.call", "data": {"method": "setMatugenScheme", "args": ["x"]}})
check(json.loads(ev("JSON.stringify(wallCalls)")) == [["setWallpaper", "/w/a.png", "DP-1"]],
      "only allowed wallpaper methods addressed to the shell run")
emit("windows.relay", {"to": "shell", "topic": "onboarding.open", "data": {}})
check(ev("OnboardingService.opens") == 1, "Settings > About opens the wizard through the main shell")
emit("windows.relay", {"to": "shell", "topic": "settings.open", "data": {"page": "specials"}})
check(ev("GlobalStates.settingsCategory") == "specials" and ev("GlobalShortcuts.toggles") == 1,
      "the wizard's summary links open Settings on their page")

if failures:
    print(f"{len(failures)} failure(s)")
    hard_exit(1)
print("separate-windows: ok")
hard_exit(0)
