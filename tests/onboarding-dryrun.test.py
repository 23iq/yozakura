#!/usr/bin/env python3
"""Onboarding dry run (`<app> onboarding --dry-run`), offscreen.

The real BackendService over a fake socket (Quickshell.Io Socket stub that
records every request line and answers reads) with DryRun active: the badge
shows on the card and the peek pill; "Use 165 Hz" + Keep and an app install
are journaled and answered by DryRunBackend.js (session countdown ticks,
install progress, the <PREFIX>DRYRUN_FAIL list) while no mutating request
ever reaches the socket (fail closed: unknown methods are mocked too);
reads still do. The summary's update channel pick only changes the dry
run's config copy.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
sys.path.insert(0, str(Path(__file__).resolve().parent))
from extras_env import CATALOG, PLATFORM, STATUS  # noqa: E402
from onboarding_env import OnboardingEnv  # noqa: E402
from qmlharness import REPO, dryrun_qml  # noqa: E402

from waits import settle, wait_until  # noqa: E402

failures: list[str] = []


def check(cond: bool, msg: str) -> None:
    if not cond:
        failures.append(msg)
        print("FAIL:", msg)


OUTPUTS = [
    {"id": "AOC-Q27-1", "name": "DP-1", "make": "AOC", "model": "Q27G2", "enabled": True,
     "width": 2560, "height": 1440, "refresh": 60, "x": 0, "y": 0, "scale": 1, "transform": 0, "vrr": False,
     "physical_width_mm": 597, "physical_height_mm": 336,
     "modes": [{"width": 2560, "height": 1440, "refresh": r} for r in (165, 144, 60)]},
]
ids = [e["id"] for e in CATALOG["entries"]]
OK_ID, FAIL_ID = ids[0], ids[1]
READS = {"displays.list": OUTPUTS, "displays.conflicts": [],
         "extras.catalog": {**CATALOG, "platform": PLATFORM}, "extras.status": STATUS,
         "keyboard.catalog": {"layouts": [], "options": [], "groups": []},
         "exclusive.status": {"active": False, "compositor": "hyprland", "reason": ""}}

# Socket stub: one shared wire records every request line and answers from READS.
WIRE = """pragma Singleton
QtObject {
    property var sent: []
    property var params: []
    property var replies: (%s)
    function send(sock, line) {
        const msg = JSON.parse(line);
        sent = sent.concat([msg.method]);
        params = params.concat([msg.params || null]);
        if (msg.method === "subscribe")
            return;
        const r = replies[msg.method];
        Qt.callLater(() => sock.parser.read(JSON.stringify({id: msg.id, result: r === undefined ? null : r})));
    }
}""" % json.dumps(READS)
SOCKET = """QtObject {
    id: s
    property string path
    property bool connected: false
    property var parser
    signal connectionStateChanged()
    signal error(var e)
    onConnectedChanged: connectionStateChanged()
    function write(line) { Wire.send(s, line.trim()) }
    function flush() {}
}"""

env = OnboardingEnv("onboarding-dryrun", overrides={"theme": {"animDuration": 0}}, outputs=OUTPUTS)
h = env.h
h.module("Quickshell.Io", {"Wire": WIRE, "Socket": SOCKET})
h.module("qs.modules.globals", {"DryRun": dryrun_qml({"DRYRUN": "1", "DRYRUN_FAIL": FAIL_ID})})
services = env.root / "qs/modules/services"
for lib in ("DryRunBackend.js", "DryRunMethods.js"):
    (services / lib).write_text((REPO / "modules/services" / lib).read_text())
# The fake install's pace (4 s in 500 ms steps; DryRunBackend.js's own timing
# is covered by its .test.cjs) is not under test here: run it 4x faster.
dry = (services / "DryRunBackend.js").read_text()
assert "var INSTALL_MS = 4000;\nvar INSTALL_STEP_MS = 500;" in dry
(services / "DryRunBackend.js").write_text(dry.replace("var INSTALL_MS = 4000;\nvar INSTALL_STEP_MS = 500;",
                                                         "var INSTALL_MS = 1000;\nvar INSTALL_STEP_MS = 125;"))
backend = (REPO / "modules/services/BackendService.qml").read_text().replace("pragma Singleton\n", "")
h.module("qs.modules.services", {"BackendService": "pragma Singleton\n" + backend})

win = h.load("""
import QtQuick
import QtQuick.Window
import Quickshell.Io
import qs.modules.onboarding
import qs.modules.services
import qs.modules.globals
import qs.config
Window {
    width: 1400; height: 900; visible: true
    readonly property var wizard: OnboardingService.wizard
    property alias flowLoader: lf
    Loader {
        id: lf
        anchors.fill: parent
        active: false
        sourceComponent: OnboardingFlow { objectName: "flow" }
    }
    PeekPill { objectName: "pill"; shown: true }
}""", auto_stub=False)


def ev(expr):
    return h.eval(win, expr)


def vfind(name, start=None):
    start = start if start is not None else h.find(win, "stepLoader")
    return h.eval(start, "(function f(it) { if (it.objectName === %s) return it;"
                         " for (const c of it.children) { const r = f(c); if (r) return r; } return null; })(this)"
                  % json.dumps(name))


def sent():
    return json.loads(ev("JSON.stringify(Wire.sent)"))


def journal():
    return json.loads(ev("JSON.stringify(DryRun.lines)"))


STEPS = ["welcome", "displays", "look", "terminal", "apps", "ai", "keybinds", "finish"]
ev("OnboardingService.open()")
ev("flowLoader.active = true")
wait_until(lambda: h.find(win, "flow") is not None)
settle()

# Badge on the card header and on the peek pill.
flow = h.find(win, "flow")
badge = h.eval(flow, "(function f(it) { if (it.objectName === 'dryRunBadge') return it;"
                     " for (const c of it.children) { const r = f(c); if (r) return r; } return null; })(this)")
check(badge is not None and h.eval(badge, "visible") is True, "the card header shows the dry-run badge")
check(badge is not None and "nothing is changed" in h.eval(badge, "text"), "badge text")
pill_badge = vfind("dryRunBadge", h.find(win, "pill"))
check(pill_badge is not None and h.eval(pill_badge, "visible") is True, "the peek pill shows the dry-run badge")

# Displays: Use 165 Hz -> journaled, fake countdown, Keep -> journaled; nothing reaches the socket.
ev(f"wizard.go({STEPS.index('displays')})")
wait_until(lambda: "displays.list" in sent() and vfind("upgradeButton", vfind("monitorCard:DP-1")) is not None)
check("displays.list" in sent(), "reads still go to the backend")
up = vfind("upgradeButton", vfind("monitorCard:DP-1"))
check(up is not None, "the 60 Hz monitor offers its upgrade")
if up is not None:
    h.eval(up, "clicked()")
wait_until(lambda: "apply display DP-1 2560x1440@165" in journal() and ev("DisplaysService.pending") is True)
check("apply display DP-1 2560x1440@165" in journal(), f"apply is journaled, got {journal()}")
check(ev("DisplaysService.pending") is True, "the fake session is pending")
wait_until(lambda: ev("DisplaysService.session.remaining") <= 14)  # the fake countdown ticks each second
check(ev("DisplaysService.session.remaining") in (13, 14), f"countdown ticks, got {ev('DisplaysService.session.remaining')}")
ev("DisplaysService.keep()")
wait_until(lambda: ev("DisplaysService.session.state") == "kept")
check(ev("DisplaysService.session.state") == "kept", "Keep ends the fake session")
check("keep display change" in journal(), "keep is journaled")
check(any(m.get("name") == "DP-1" and m.get("refresh") == 165 for m in json.loads(ev("JSON.stringify(Config.displays.monitors)"))),
      "the kept layout is saved (to the dry run's config copy)")
check(not {"displays.apply", "displays.keep"} & set(sent()), f"no display change reached the backend: {sent()}")

# Install: queued, fake progress to 100 %, then installed; the fail list fails.
ev("ExtrasService.load()")
settle()
ev(f'ExtrasService.install(["{OK_ID}", "{FAIL_ID}"])')
wait_until(lambda: f"install {OK_ID}, {FAIL_ID}" in journal() and ev(f'ExtrasService.cardState("{OK_ID}")') == "installing")
check(f"install {OK_ID}, {FAIL_ID}" in journal(), f"install is journaled, got {journal()}")
check(ev(f'ExtrasService.cardState("{OK_ID}")') == "installing", "the card shows the fake install")
wait_until(lambda: ev(f'ExtrasService.status["{OK_ID}"].state') == "installed"
           and ev(f'ExtrasService.progress["{FAIL_ID}"].state') == "failed")
check(ev(f'ExtrasService.status["{OK_ID}"].state') == "installed", "after the fake progress it is installed")
check(ev(f'ExtrasService.progress["{FAIL_ID}"].state') == "failed"
      and ev(f'ExtrasService.progress["{FAIL_ID}"].reason') == "network", "the fail list fails with reason network")
check("extras.install" not in sent(), f"no install reached the backend: {sent()}")

# Identify: numbers only in this instance; a status refresh is not forced.
ev("DisplaysService.identify()")
wait_until(lambda: ev("DisplaysService.identified.length") == 1)
check(ev("DisplaysService.identified.length") == 1, "identify shows the numbers here")
check("displays.identify" not in sent(), "identify never reaches the backend (it would draw on the real shell)")
ev("ExtrasService.refresh()")
wait_until(lambda: "extras.status" in sent())
settle()
status_params = json.loads(ev("JSON.stringify(Wire.params.filter((p, i) => Wire.sent[i] === 'extras.status'))"))
check(status_params and all(not (p or {}).get("refresh") for p in status_params), f"no forced re-detection: {status_params}")

# Update channel (summary): a pick changes the dry run's config copy only.
ev(f"wizard.go({STEPS.index('finish')})")
wait_until(lambda: vfind("channel:beta") is not None)
settle()  # the summary's own reads (extras / exclusive status) first
before = list(sent())
row = vfind("channel:beta")
check(row is not None, "the summary offers the update channel")
if row is not None:
    h.eval(row, "clicked()")
settle()
check(ev("Config.system.updateChannel") == "beta", "the channel pick is written (to the dry run's config copy)")
check(sent()[len(before):] == [], f"the channel pick sends nothing to the backend: {sent()[len(before):]}")

# Fail closed: a method not known as a read is mocked, journaled, never sent.
ev('BackendService.call("nightlight.set", {"enabled": true}, () => {})')
ev('BackendService.call("weather.get", {}, () => {})')
wait_until(lambda: "weather.get" in sent() and "unmocked call nightlight.set" in journal())
check("nightlight.set" not in sent(), f"an unknown method never reaches the backend: {sent()}")
check("unmocked call nightlight.set" in journal(), f"it is journaled, got {journal()}")
check("weather.get" in sent(), "a known read still does")

if h.type_errors:
    failures.append("type errors: " + "; ".join(h.type_errors))
print("onboarding-dryrun:", "FAIL" if failures else "ok", f"({len(failures)} failure(s))")
h.exit(1 if failures else 0)
