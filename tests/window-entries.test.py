#!/usr/bin/env python3
"""settings-window.qml and onboarding-window.qml, the separate window
processes' root files (performance.separateWindows), offscreen.

Each root file is loaded as the daemon starts it (ProcessRole from
<PREFIX>ROLE / WINDOW_*) over stubbed Quickshell and services, its window
file replaced by a stand-in:
- Settings: opens on the page, screen and workspace it was given, with the
  remote wallpaper manager installed; reports windows.ready once its window
  shows and runs the command the daemon kept while it started (the answer
  to windows.ready); a later open raises it on the new page (placement
  again), a close from the main shell closes it, and once closed it
  reports hiding and quits (after a grace period for the last writes); a
  reopen to ask about unsaved changes reports nothing, a raise while hiding
  shows it again (no quit) and it reports ready again.
- Wizard: opens (resuming) once the config and the saved progress are read,
  on the screen it was given; reports windows.ready; takes the main shell's
  panel / bar state for the tour and the peek pill; raise brings it back
  from a peek, close closes it; closed, it reports hiding and quits once no
  exclusive-mode switch is pending; a raise while hiding opens it again.
- Started by hand (no role): both refuse and quit at once, loading nothing.
- Compile cost: a root file names no window or page type (they are loaded
  by URL), and the separate Settings window loads its content by URL.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from qmlharness import REPO, Harness, hard_exit, process_role_qml  # noqa: E402

from waits import pump, settle, wait_until  # noqa: E402

failures: list[str] = []


def check(cond: bool, msg: str) -> None:
    if not cond:
        failures.append(msg)
        print("FAIL:", msg)


BACKEND = """pragma Singleton
QtObject {
    property var calls: []
    property var cbs: []
    // the answer to windows.ready (the command kept while it started)
    property var readyResult: ({ "ok": true })
    function addSubscription(s, cb) { cbs = cbs.concat([{ "s": s, "cb": cb }]); return cbs.length }
    function call(m, p, cb) {
        calls = calls.concat([{ "method": m, "params": p || null }]);
        if (cb && m === "windows.ready") { const r = readyResult; readyResult = { "ok": true }; Qt.callLater(() => cb(r, null)); }
    }
    function emit(service, data) {
        const group = service.split(".")[0];
        cbs.forEach(c => { if (c.s.indexOf(group) >= 0) c.cb(service, data); });
    }
    function count(m) { return calls.filter(c => c.method === m).length }
}"""
PREVIEW = "pragma Singleton\nQtObject { property int links: 0; property bool applying: false; function link() { links++ } }"
QUICKSHELL = """pragma Singleton
QtObject {
    property var screens: [{ "name": "DP-1" }, { "name": "HDMI-A-1" }]
}"""


def common(h: Harness, role: str, env: dict):
    h.module("Quickshell", {"Quickshell": QUICKSHELL, "ShellRoot": "Item {}"})
    h.module("qs.modules.globals", {
        "ProcessRole": process_role_qml(role, env),
        "GlobalStates": """pragma Singleton
QtObject {
    property var wallpaperManager: null
    property bool settingsWindowVisible: false
    property string settingsCategory: "appearance"
    property string settingsTargetScreenName: ""
    property int settingsTargetWorkspaceId: 0
}""",
    })
    h.module("qs.modules.theme", {"FontRegistry": "pragma Singleton\nQtObject { property int count: 3 }"})
    h.module("qs.modules.widgets.dashboard.wallpapers", {"RemoteWallpapers": "QtObject { property bool remote: true }"})


# ---------------------------------------------------------------- Settings
WINDOW = """import QtQuick
Item {
    property var targetScreen: null
    property int placements: 0
    function preparePlacement() { placements++ }
}"""
env_s = {"WINDOW_PAGE": "network", "WINDOW_SCREEN": "HDMI-A-1", "WINDOW_WORKSPACE": "3"}


def settings_scene(name: str, role: str):
    h = Harness(name)
    common(h, role, env_s)
    h.module("qs.modules.services", {"BackendService": BACKEND, "PreviewSink": PREVIEW})
    h.copy("settings-window.qml", "app", replace={"interval: 1000": "interval: 200"})
    (h.root / "app/modules/settings").mkdir(parents=True, exist_ok=True)
    (h.root / "app/modules/settings/SettingsWindowSeparate.qml").write_text(WINDOW)
    return h


def load_entry(h: Harness, file: str):
    # the root file as a component of a harness item (ShellRoot is an Item stub)
    comp_dir = h.root / "app"
    (comp_dir / "Entry.qml").write_text((comp_dir / file).read_text())
    quits: list[int] = []
    h.engine.quit.connect(lambda: quits.append(1))
    root = h.load("""import QtQuick
import qs.modules.globals
import qs.modules.services
Item {
    property alias entry: entry
    Entry { id: entry }
}""", auto_stub=False)
    settle()
    return root, quits


h = settings_scene("window-entries-settings", "settings")
root, quits = load_entry(h, "settings-window.qml")


def ev(expr):
    return h.eval(root, expr)


check(ev("GlobalStates.settingsCategory") == "network", "opens on the page it was given")
check(ev("GlobalStates.settingsTargetScreenName") == "HDMI-A-1" and ev("GlobalStates.settingsTargetWorkspaceId") == 3,
      "...on its screen and workspace")
check(ev("GlobalStates.settingsWindowVisible") is True, "the window is shown")
check(ev("GlobalStates.wallpaperManager && GlobalStates.wallpaperManager.remote") is True, "the remote wallpaper manager is installed")
check(ev("entry.win !== null && entry.win.targetScreen && entry.win.targetScreen.name === 'HDMI-A-1'") is True,
      "the window is loaded on the target screen")
check(json.loads(ev("JSON.stringify(BackendService.cbs.map(c => c.s))")) == [["windows"]], "it listens to the windows stream only")
check(ev("PreviewSink.links") == 1, "...and links the shared staging")
ev("BackendService.readyResult = { ok: true, command: { kind: 'settings', action: 'raise', page: 'about' } }")
ev("entry.win.visible = false")
ev("entry.win.visible = true")
settle()
check(ev("BackendService.count('windows.ready')") == 1, "shown: windows.ready, once")
check(ev("GlobalStates.settingsCategory") == "about" and ev("entry.win.placements") == 1,
      "the open asked while it started is run once shown")
ev("entry.win.visible = false")
ev("entry.win.visible = true")
check(ev("BackendService.count('windows.ready')") == 1, "...not again")
ev("BackendService.emit('windows.command', { kind: 'onboarding', action: 'close' })")
check(ev("GlobalStates.settingsWindowVisible") is True, "a command for another window is ignored")
ev("BackendService.emit('windows.command', { kind: 'settings', action: 'raise', page: 'sound', screen: 'DP-1', workspace: 0 })")
check(ev("GlobalStates.settingsCategory") == "sound" and ev("GlobalStates.settingsTargetScreenName") == "DP-1",
      "raise: the new page and screen")
check(ev("GlobalStates.settingsTargetWorkspaceId") == 3, "...a missing workspace keeps the last one")
check(ev("entry.win.placements") == 2, "...and the window is placed and focused again")
ev("GlobalStates.settingsWindowVisible = false; GlobalStates.settingsWindowVisible = true")  # unsaved changes: it asks
settle()
check(ev("BackendService.count('windows.hiding')") == 0, "reopened at once to ask: not hiding")
ev("BackendService.emit('windows.command', { kind: 'settings', action: 'close' })")
check(ev("GlobalStates.settingsWindowVisible") is False, "close from the main shell closes it")
settle()
check(ev("BackendService.count('windows.hiding')") == 1, "closed: it reports hiding")
pump(80)
ev("BackendService.emit('windows.command', { kind: 'settings', action: 'raise', page: 'keybinds' })")
check(ev("GlobalStates.settingsWindowVisible") is True and ev("GlobalStates.settingsCategory") == "keybinds",
      "a raise while hiding shows it again on the page")
pump(300)
check(quits == [], "...and it keeps running")
ev("entry.win.visible = false")
ev("entry.win.visible = true")
settle()
check(ev("BackendService.count('windows.ready')") == 2, "...and reports ready again")
ev("PreviewSink.applying = true")  # an Apply waits for the main shell
ev("GlobalStates.settingsWindowVisible = false")
pump(450)
check(quits == [], "closed while an Apply waits for its answer: still running")
ev("PreviewSink.applying = false")
wait_until(lambda: quits != [])
check(quits != [], "closed: it quits")

# started by hand: refuses
h2 = settings_scene("window-entries-settings-norole", "")
root2, quits2 = load_entry(h2, "settings-window.qml")
check(quits2 != [], "no settings role: quits at once")
check(h2.eval(root2, "entry.win") is None and h2.eval(root2, "GlobalStates.settingsWindowVisible") is False
      and h2.eval(root2, "PreviewSink.links") == 0, "...loading nothing")

# ---------------------------------------------------------------- wizard
ONBOARDING = """pragma Singleton
QtObject {
    property bool visible: false
    property bool peek: false
    property bool shellPanelOpen: false
    property string screenName: "DP-1"
    property int opens: 0
    property QtObject wizard: QtObject { property bool _exclusivePending: false }
    function open() { opens++; peek = false; visible = true }
    function close() { visible = false }
}"""


def wizard_scene(name: str, role: str):
    h = Harness(name)
    common(h, role, {"WINDOW_SCREEN": "HDMI-A-1"})
    h.module("qs.modules.services", {
        "BackendService": BACKEND,
        "PreviewSink": PREVIEW,
        "OnboardingService": ONBOARDING,
        "StateService": "pragma Singleton\nQtObject { property bool initialized: false }",
        "ExclusiveService": "pragma Singleton\nQtObject { property bool busy: false }",
        "Visibilities": "pragma Singleton\nQtObject { property var reservations: ({}); "
                        "function registerReservation(n, r) { const m = Object.assign({}, reservations); m[n] = r; reservations = m } }",
    })
    h.singleton("qs.config", "Config", "QtObject { property bool initialLoadComplete: true }")
    h.copy("onboarding-window.qml", "app", replace={"interval: 1000": "interval: 100"})
    (h.root / "app/modules/onboarding").mkdir(parents=True, exist_ok=True)
    for f in ("OnboardingWindow", "OnboardingPeekPill"):
        (h.root / f"app/modules/onboarding/{f}.qml").write_text("import QtQuick\nItem { objectName: \"%s\" }" % f)
    return h


h3 = wizard_scene("window-entries-wizard", "onboarding")
root3, quits3 = load_entry(h3, "onboarding-window.qml")


def ew(expr):
    return h3.eval(root3, expr)


pump(150)
check(ew("OnboardingService.opens") == 0, "waits for the saved progress")
ew("StateService.initialized = true")
wait_until(lambda: ew("OnboardingService.opens") == 1)
check(ew("OnboardingService.visible") is True and ew("OnboardingService.screenName") == "HDMI-A-1",
      "opens (resuming) on the screen it was given")
check(ew("BackendService.count('windows.ready')") == 1, "shown: windows.ready")
check(ew("PreviewSink.links") == 1, "it links the shared staging")
ew("BackendService.emit('windows.relay', { to: 'onboarding', topic: 'shell.state', data: { panelOpen: true, bottomZone: 48 } })")
check(ew("OnboardingService.shellPanelOpen") is True, "takes the main shell's panel state (keybind tour)")
check(ew("Visibilities.reservations['HDMI-A-1'].bottomZone") == 48, "...and its bottom bar (peek pill)")
ew("BackendService.emit('windows.relay', { to: 'settings', topic: 'shell.state', data: { panelOpen: false } })")
check(ew("OnboardingService.shellPanelOpen") is True, "a relay for another window is ignored")
ew("OnboardingService.peek = true")
ew("BackendService.emit('windows.command', { kind: 'onboarding', action: 'raise' })")
check(ew("OnboardingService.peek") is False, "raise: back from the peek")
ew("BackendService.emit('windows.command', { kind: 'onboarding', action: 'close' })")
check(ew("OnboardingService.visible") is False and ew("BackendService.count('windows.hiding')") == 1,
      "close: closed, reports hiding")
pump(40)
ew("BackendService.emit('windows.command', { kind: 'onboarding', action: 'raise' })")
check(ew("OnboardingService.visible") is True, "a raise while hiding opens it again")
pump(200)
check(quits3 == [] and ew("BackendService.count('windows.ready')") == 2, "...keeps running and reports ready again")
ew("ExclusiveService.busy = true")
ew("BackendService.emit('windows.command', { kind: 'onboarding', action: 'close' })")
check(ew("OnboardingService.visible") is False, "close: closed")
pump(350)
check(quits3 == [], "an exclusive-mode switch is pending: still running")
ew("ExclusiveService.busy = false")
wait_until(lambda: quits3 != [])
check(quits3 != [], "...then it quits")

h4 = wizard_scene("window-entries-wizard-norole", "")
root4, quits4 = load_entry(h4, "onboarding-window.qml")
h4.eval(root4, "StateService.initialized = true")
pump(150)
check(quits4 != [] and h4.eval(root4, "OnboardingService.opens") == 0, "no wizard role: quits, opens nothing")

# Whatever a root file names statically compiles when it loads: only the
# small singletons; the window, the wizard and the pages are loaded by URL.
for rel in ("settings-window.qml", "onboarding-window.qml"):
    text = (REPO / rel).read_text()
    check("qs.modules.settings" not in text and "qs.modules.onboarding" not in text,
          f"{rel}: imports neither the settings nor the onboarding module")
sep = (REPO / "modules/settings/SettingsWindowSeparate.qml").read_text()
check("SettingsShell {" not in sep and 'source: "SettingsShell.qml"' in sep,
      "the separate Settings window loads its content by URL (the frame maps first)")

if failures:
    print(f"{len(failures)} failure(s)")
    hard_exit(1)
print("window-entries: ok")
hard_exit(0)
