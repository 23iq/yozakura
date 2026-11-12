#!/usr/bin/env python3
"""The staging shared by the separate Settings window, the separate setup
wizard and the main shell (performance.separateWindows), offscreen.

Three scenes, each its own engine like its own process: the main shell, a
Settings window and a wizard window, each with the real PreviewSink and
GlobalStates (snapshot machinery) over a typed Config whose saves are
recorded as "files". A small model of the daemon's `preview` service
(backend/pkg/svc/preview, tested in Go) relays between them: one staging,
the whole of it ended by Apply or Discard of any owner, discarded when the
last window is gone, replayed to a process that subscribes later.

In-process there is one Config and one set of snapshots: what Settings and
the wizard stage are the same unsaved changes. Checked here, in both orders
and with a crash: a window shows what the other staged as unsaved; Apply
in one keeps everything (nothing comes back on a later Discard of the
other), Discard in one restores everything; a window crashing while the
other runs leaves the staging to that one; the last window gone discards
it; never is a value left live, unwritten and with no window to discard it.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from qmlharness import REPO, Harness, hard_exit, process_role_qml  # noqa: E402
from settings_env import DEFAULT_PALETTE, colors_qml, config_qml, load_defaults  # noqa: E402

from waits import settle  # noqa: E402

failures: list[str] = []


def check(cond: bool, msg: str) -> None:
    if not cond:
        failures.append(msg)
        print("FAIL:", msg)


BACKEND = """pragma Singleton
QtObject {
    property var calls: []
    property var cbs: []
    property bool socketAvailable: true
    // answers the test gives: method -> result (null: no answer)
    property var answers: ({})
    property var held: []
    function addSubscription(s, cb) { cbs = cbs.concat([{ "s": s, "cb": cb }]); return cbs.length }
    function call(m, p, cb) {
        calls = calls.concat([{ "method": m, "params": p || null }]);
        if (cb) held = held.concat([{ "method": m, "params": p || null, "cb": cb }]);
    }
    function answer(i, result, error) { const h = held[i]; if (h && h.cb) h.cb(result, error || null) }
    function emit(service, data) {
        const group = service.split(".")[0];
        cbs.forEach(c => { if (c.s.indexOf(group) >= 0) c.cb(service, data); });
    }
}"""

DOMAINS = load_defaults()


def config_with_disk() -> str:
    text = config_qml(DOMAINS, """
    property var disk: ({})
    property QtObject loader: QtObject {
        function writeAdapter() { root.saved.push("theme"); root.disk["theme"] = JSON.stringify(root.theme) }
    }""")
    for n in DOMAINS:
        text = text.replace(f'saved.push("{n}") }}', f'saved.push("{n}"); disk["{n}"] = JSON.stringify({n}) }}')
    return text


def scene(name: str, role: str):
    h = Harness(name)
    qs = h.root / "qs"
    (qs / "config").mkdir(parents=True, exist_ok=True)
    (qs / "config" / "Config.qml").write_text(config_with_disk())
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
    h.module("qs.modules.globals", {"ProcessRole": process_role_qml(role)})
    h.module("qs.modules.services", {
        "BackendService": BACKEND,
        "StateService": "pragma Singleton\nQtObject { property bool initialized: true; function get(k, d) { return d } function set(k, v) {} }",
        "YozdService": "pragma Singleton\nQtObject { property var focusedMonitor: null; property string compositorName: \"\" }",
        "LockscreenService": "pragma Singleton\nQtObject { property bool locked: false; property bool visible: false }",
        "Visibilities": "pragma Singleton\nQtObject { property string currentActiveModule: \"\"; property var reservations: ({}); "
                        "function getForActive() { return null } }",
    })
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
import "../qs/modules/settings/ConfigWrite.js" as ConfigWrite
Item {
    // what SettingsStore.set does in a window: stage here, relay the value
    function stageHere(key, value) {
        ConfigWrite.assign(Config, key, value, PreviewSink.stage);
        BackendService.call("preview.set", { "owner": ProcessRole.role, "key": key, "value": value });
    }
    // SettingsStore.discard in a window
    function discardHere() {
        const had = GlobalStates.themeHasChanges || GlobalStates.shellHasChanges || GlobalStates.compositorHasChanges;
        PreviewSink.discard();
        if (had) BackendService.call("preview.discard", { "owner": ProcessRole.role });
    }
    readonly property bool unsaved: GlobalStates.themeHasChanges || GlobalStates.shellHasChanges || GlobalStates.compositorHasChanges
    Component.onCompleted: PreviewSink.link()
}""", auto_stub=False)
    settle()
    return h, root


class Proc:
    def __init__(self, name: str, role: str):
        self.role = role
        self.h, self.root = scene(f"preview-staging-{name}", role)
        self.seen = 0

    def ev(self, expr):
        return self.h.eval(self.root, expr)

    def emit(self, service, data):
        self.ev(f"BackendService.emit({json.dumps(service)}, {json.dumps(data)})")

    def new_calls(self):
        calls = json.loads(self.ev("JSON.stringify(BackendService.calls)"))
        out = calls[self.seen:]
        self.seen = len(calls)
        return out


class Daemon:
    """backend/pkg/svc/preview: one shared staging."""

    def __init__(self, procs):
        self.procs = procs
        self.staged: list[dict] = []

    def broadcast(self, service, data):
        for p in self.procs:
            p.emit(service, data)
        settle()

    def pump(self):
        moved = True
        while moved:
            moved = False
            for p in self.procs:
                for c in p.new_calls():
                    moved = True
                    m, par = c["method"], c["params"]
                    if m == "preview.set":
                        self.staged = [e for e in self.staged if not (e["owner"] == par["owner"] and e["key"] == par["key"])]
                        self.staged.append(par)
                        self.broadcast("preview.set", par)
                    elif m in ("preview.commit", "preview.discard"):
                        self.staged = []
                        self.broadcast(m, {"owner": par["owner"]})

    def gone(self, proc, others_running):
        self.procs.remove(proc)
        if not others_running and self.staged:
            self.staged = []
            self.broadcast("preview.discard", {"owner": proc.role})

    def join(self, proc):
        self.procs.append(proc)
        for e in self.staged:
            proc.emit("preview.set", e)
        settle()


main = Proc("main", "")
settings = Proc("settings", "settings")
wizard = Proc("wizard", "onboarding")

rnd = main.ev("Config.theme.roundness")
pos = main.ev("Config.bar.position")
moved = "left" if pos != "left" else "right"


def stage_both(d: Daemon):
    wizard.ev(f"stageHere('theme.roundness', {rnd + 5})")
    d.pump()
    settings.ev(f"stageHere('bar.position', '{moved}')")
    d.pump()


def reset():
    for p in (main, settings, wizard):
        p.ev(f"Config.theme.roundness = {rnd}; Config.bar.position = '{pos}'")
        p.ev("PreviewSink.drop(); Config.saved = []; Config.disk = ({})")
        p.new_calls()


# ---- one staging: each window shows what the other staged ----
d = Daemon([main, settings, wizard])
stage_both(d)
for p, name in ((main, "main shell"), (settings, "Settings"), (wizard, "wizard")):
    check(p.ev("Config.theme.roundness") == rnd + 5 and p.ev("Config.bar.position") == moved,
          f"{name}: both windows' staged values are live")
    check(p.ev("unsaved") is True, f"{name}: staged (unsaved, nothing written)")
    check(p.ev("Config.saved.length") == 0, f"{name}: nothing written while staged")

# ---- Settings applies, the wizard discards after it: nothing comes back ----
# (the window writes the files: SettingsStore.apply)
settings.ev("GlobalStates.applyThemeChanges(); GlobalStates.applyShellChanges(); GlobalStates.applyCompositorChanges()")
settings.ev("BackendService.call('preview.commit', { owner: 'settings' })")
d.pump()
for p, name in ((main, "main shell"), (wizard, "wizard")):
    check(p.ev("unsaved") is False, f"Settings applied: {name} has no unsaved changes left")
    check(p.ev("Config.theme.roundness") == rnd + 5 and p.ev("Config.bar.position") == moved,
          f"Settings applied: {name} keeps both values")
disk = json.loads(settings.ev("JSON.stringify(Config.disk)"))
check(json.loads(disk.get("theme", "{}")).get("roundness") == rnd + 5 and json.loads(disk.get("bar", "{}")).get("position") == moved,
      "Settings' Apply wrote the wizard's value too (as in-process)")
wizard.ev("discardHere()")
d.pump()
check(main.ev("Config.theme.roundness") == rnd + 5, "the wizard's later Discard restores nothing: it was applied")
d.gone(wizard, others_running=True)
d.gone(settings, others_running=False)
check(main.ev("Config.theme.roundness") == rnd + 5 and main.ev("unsaved") is False,
      "both windows gone: the applied values stay, nothing staged")
d.procs = [main, settings, wizard]
reset()

# ---- Settings discards, the wizard applies after it: nothing to apply ----
stage_both(d)
settings.ev("discardHere()")
d.pump()
for p, name in ((main, "main shell"), (settings, "Settings"), (wizard, "wizard")):
    check(p.ev("Config.theme.roundness") == rnd and p.ev("Config.bar.position") == pos,
          f"Settings discarded: {name} is back to the values from before (the wizard's too, as in-process)")
    check(p.ev("unsaved") is False, f"Settings discarded: {name} has nothing staged")
check(wizard.ev("GlobalStates.themeHasChanges") is False, "...so the wizard's finish has nothing to apply")
check(main.ev("Config.saved.length") == 0, "...and nothing was written")
reset()

# ---- a window crashes while the other runs: the other keeps the staging ----
stage_both(d)
d.gone(settings, others_running=True)
check(main.ev("Config.bar.position") == moved and main.ev("unsaved") is True,
      "Settings crashed, the wizard runs: the staging stays live")
check(wizard.ev("unsaved") is True and wizard.ev("Config.bar.position") == moved,
      "...shown by the wizard as its own unsaved changes (it can apply or discard them)")
# the last window gone: discarded everywhere
d.gone(wizard, others_running=False)
check(main.ev("Config.bar.position") == pos and main.ev("Config.theme.roundness") == rnd and main.ev("unsaved") is False,
      "the last window gone: the staging is discarded, nothing left live and unwritten")
d.procs = [main]
reset()

# ---- a window opened later sees what is staged ----
wizard.ev(f"stageHere('theme.roundness', {rnd + 7})")
d.procs = [main, wizard]
d.pump()
late = Proc("settings-late", "settings")
late.ev("Config.initialLoadComplete = false")
d.join(late)
check(late.ev("unsaved") is False, "events wait until the window has read its config")
late.ev("Config.initialLoadComplete = true")
settle()
check(late.ev("Config.theme.roundness") == rnd + 7 and late.ev("unsaved") is True,
      "a window opened later shows the staging as unsaved")
# its own echo is ignored
late.ev("Config.bar.position = 'bottom'")
late.emit("preview.set", {"owner": "settings", "key": "bar.position", "value": "top"})
check(late.ev("Config.bar.position") == "bottom", "a window ignores its own relayed values")

if failures:
    print(f"{len(failures)} failure(s)")
    hard_exit(1)
print("preview-staging: ok")
hard_exit(0)
