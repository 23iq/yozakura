#!/usr/bin/env python3
"""Onboarding Apps, AI & voice and summary steps (modules/onboarding), offscreen.

Apps: the first visit pre-checks the recommended apps that are missing (only
apps, never agents), the selection is remembered and wins on a revisit,
Install queues it through extras.install and the wizard records the queued
ids. AI: agents and local AI sections from the catalog, the cloud provider
row, the Ollama "pull a model" chips (only once Ollama is installed) with
their live progress. Summary: the chosen prompt, live install progress and
the background note, the Hyprland-only exclusive toggle (enabled on finish),
"Start using" completes the wizard and clears the saved state while installs
keep running.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from exclusive_env import PLAN, STATUS_OFF  # noqa: E402
from onboarding_env import OnboardingEnv  # noqa: E402

from PySide6.QtTest import QTest  # noqa: E402

failures: list[str] = []


def check(cond: bool, msg: str) -> None:
    if not cond:
        failures.append(msg)
        print("FAIL:", msg)


CATALOG = {
    "categories": [
        {"id": "agents", "name": "extras.cat.agents", "icon": "robot"},
        {"id": "localai", "name": "extras.cat.localai", "icon": "brain"},
        {"id": "gpu", "name": "extras.cat.gpu", "icon": "cpu"},
        {"id": "browsers", "name": "extras.cat.browsers", "icon": "globe"},
        {"id": "chat", "name": "extras.cat.chat", "icon": "chatDots"},
        {"id": "games", "name": "extras.cat.games", "icon": "gamepad"},
    ],
    "entries": [
        {"id": "claude-code", "category": "agents", "name": "Claude Code", "icon": "robot", "recommended": True},
        {"id": "ollama", "category": "localai", "name": "Ollama", "icon": "brain"},
        {"id": "voice", "category": "gpu", "name": "Local voice (whisper)", "icon": "mic"},
        {"id": "firefox", "category": "browsers", "name": "Firefox", "icon": "firefox", "recommended": True},
        {"id": "vesktop", "category": "chat", "name": "Vesktop", "icon": "chatDots", "recommended": True},
        {"id": "steam", "category": "games", "name": "Steam", "icon": "gamepad"},
    ],
}
STATUS = {e["id"]: {"id": e["id"], "state": "missing"} for e in CATALOG["entries"]}
STATUS["firefox"] = {"id": "firefox", "state": "installed", "source": "pkg"}

env = OnboardingEnv("onboarding-apps-ui", overrides={"theme": {"animDuration": 0}},
                    replies={"extras.catalog": {**CATALOG, "platform": {"distro": "arch"}}, "extras.status": STATUS,
                             "extras.ollamaPull": {"jobs": [{"id": "ollama-1", "kind": "ollama", "entries": []}]},
                             "exclusive.status": STATUS_OFF,
                             "providers.ollama.probe": {"reachable": True, "models": [{"id": "gemma3:latest"}]}, "exclusive.plan": PLAN, "exclusive.enable": STATUS_OFF})
h = env.h
win = h.load("""
import QtQuick
import QtQuick.Window
import qs.modules.onboarding
import qs.modules.services
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
}""", auto_stub=False)


def ev(expr):
    return h.eval(win, expr)


def vfind(name):
    """Find by objectName through visual children (Repeater/Loader items)."""
    start = h.find(win, "stepLoader")
    return h.eval(start, "(function f(it) { if (it.objectName === %s) return it;"
                         " for (const c of it.children) { const r = f(c); if (r) return r; } return null; })(this)"
                  % json.dumps(name))


STEPS = ["welcome", "displays", "look", "terminal", "apps", "ai", "keybinds", "finish"]


def go(step_id):
    ev(f'wizard.go({STEPS.index(step_id)})')
    QTest.qWait(60)


def calls(method):
    return json.loads(ev(f"JSON.stringify(BackendService.calls.filter(c => c.method === '{method}').map(c => c.params))"))


ev("OnboardingService.open()")
ev("flowLoader.active = true")
QTest.qWait(50)

# ---- Apps --------------------------------------------------------------------
go("apps")
check(vfind("card-vesktop") is not None and vfind("card-steam") is not None, "apps show the app categories")
check(vfind("card-claude-code") is None, "agents are not on the apps step")
check(json.loads(ev("JSON.stringify(wizard.choices.apps)")) == ["vesktop"],
      "first visit pre-checks the recommended missing app only (not installed firefox, not the agent)")
h.eval(vfind("card-steam"), "toggled()")
check(sorted(json.loads(ev("JSON.stringify(wizard.choices.apps)"))) == ["steam", "vesktop"], "the selection is remembered")
h.eval(vfind("card-vesktop"), "toggled()")
go("ai")
go("apps")
check(json.loads(ev("JSON.stringify(wizard.choices.apps)")) == ["steam"], "a revisit keeps the remembered selection")
check(h.eval(vfind("card-vesktop"), "selected") is False and h.eval(vfind("card-steam"), "selected") is True,
      "the cards show the remembered selection, no second preselection")
ev('wizard.remember("apps", ["firefox", "steam"])')
go("ai")
go("apps")
check(json.loads(ev("JSON.stringify(wizard.choices.apps)")) == ["steam"], "a restored pick installed meanwhile is dropped")
h.eval(vfind("card-vesktop"), "toggled()")
h.eval(vfind("installButton"), "clicked()")
inst = calls("extras.install")
check(len(inst) == 1 and inst[0]["ids"] == ["vesktop", "steam"], f"Install queues the selection, got {inst}")
check(json.loads(ev("JSON.stringify(wizard.installs)")) == ["vesktop", "steam"], "the wizard records what it queued")
ev('BackendService.emit("extras.progress", {job: "j1", kind: "system", entries: ["vesktop", "steam"], state: "running", percent: 30, phase: ""})')

# ---- AI & voice ----------------------------------------------------------------
go("ai")
check(vfind("aiMaster") is not None and vfind("aiProviders") is not None, "master switch and cloud provider row")
check(vfind("card-claude-code") is not None and vfind("card-ollama") is not None and vfind("card-voice") is not None,
      "agents and local AI / voice cards")
check(vfind("card-vesktop") is None, "apps are not on the AI step")
check(h.eval(vfind("installBar"), "shown") is True, "the running install shows in the AI step bar too")
check(vfind("pullChip:llama3.2") is None, "no model chips while Ollama is missing")
h.eval(vfind("aiMaster"), "toggled(false)")
check(ev("Config.ai.enabled") is False, "the master switch writes ai.enabled")
h.eval(vfind("aiMaster"), "toggled(true)")
ev('BackendService.emit("extras.status", Object.assign({}, ExtrasService.status, {ollama: {id: "ollama", state: "installed"}}))')
QTest.qWait(60)
check(len(calls("providers.ollama.probe")) == 1, "the pull row probes the Ollama server")
check(h.eval(vfind("pullChip:gemma3"), "phase") == "done", "a model pulled before is marked done")
row = h.eval(vfind("pullChip:gemma3"), "parent.parent.parent")
h.eval(row, "probe = ({reachable: false, models: []})")
check("ollama serve" in h.eval(vfind("pullHint"), "text"), "a stopped server gets the start hint")
h.eval(row, "probe = ({reachable: true, models: [{id: 'gemma3:latest'}]})")
chip = vfind("pullChip:llama3.2")
check(chip is not None and vfind("pullChip:qwen2.5-coder") is not None and vfind("pullChip:gemma3") is not None,
      "installed Ollama offers llama3.2 / qwen2.5-coder / gemma3")
if chip is not None:
    check(h.eval(chip, "phase") == "idle", "chip starts idle")
    h.eval(chip, "activate()")
    check(calls("extras.ollamaPull") == [{"model": "llama3.2"}], "a chip queues ollama pull through the backend")
    check(h.eval(chip, "phase") == "pulling", "the chip shows the pull right away")
    h.eval(chip, "activate()")
    check(len(calls("extras.ollamaPull")) == 1, "a running pull is not queued twice")
    ev('BackendService.emit("extras.progress", {job: "ollama-1", kind: "ollama", entries: [], state: "running", percent: 40, phase: ""})')
    QTest.qWait(30)
    check(h.eval(chip, "phase") == "pulling" and h.eval(chip, "pull.percent") == 40, "live pull progress")
    ev('BackendService.emit("extras.progress", {job: "ollama-1", kind: "ollama", entries: [], state: "done", percent: 100, phase: ""})')
    QTest.qWait(30)
    check(h.eval(chip, "phase") == "done", "the chip is done when the pull finishes")

# ---- Summary ---------------------------------------------------------------------
ev("TerminalLookService.presets = [{id: 'plain', name: 'Plain', description: '', nerdFont: false, lines: 1}];"
   " Config.terminal.prompt = 'plain'; Config.terminal.enabled = true; Config.general.terminal = 'kitty'")
go("finish")
QTest.qWait(60)
term = vfind("summary:terminal")
check(term is not None and h.eval(term, "value") == "kitty · Plain", f"summary shows terminal + prompt, got {term and h.eval(term, 'value')}")
apps = vfind("summary:apps")
check(apps is not None and h.eval(apps, "busy") is True, "apps card shows live progress while installing")
check(apps is not None and h.eval(apps, "value") == "2 installing", f"apps card counts the queued apps, got {apps and h.eval(apps, 'value')}")
ev('BackendService.emit("extras.progress", {job: "j2", kind: "flatpak", entries: ["steam"], state: "failed", percent: 0, phase: "", reason: "network"})')
ev("ExtrasService.offline = false")
QTest.qWait(30)
apps = vfind("summary:apps")
check(h.eval(apps, "value") == "1 failed · 1 installing", f"failures show while others install, got {h.eval(apps, 'value')}")
check(h.eval(vfind("backgroundNote"), "visible") is True, "installs-continue note while installing")
check(h.eval(h.find(win, "onboardingNext"), "visible") is False, "the summary has its own Start button")
# exclusive mode: only on Hyprland with a reported status
toggle = vfind("exclusiveToggle")
check(toggle is not None, "Hyprland: the only-shell toggle is offered")
check(h.eval(vfind("exclusiveSteps"), "visible") is False, "steps hidden until switched on")
h.eval(toggle, "toggled(true)")
QTest.qWait(30)
check(ev("wizard.choices.exclusive") is True and h.eval(vfind("exclusiveSteps"), "visible") is True,
      "switched on: remembered, the steps show")
check(calls("exclusive.enable") == [], "nothing is enabled before finishing")
ev('ExclusiveService.status = Object.assign({}, ExclusiveService.status, {compositor: ""})')
QTest.qWait(30)
check(vfind("exclusiveToggle") is None, "no toggle without a Hyprland status")
ev('ExclusiveService.status = Object.assign({}, ExclusiveService.status, {compositor: "hyprland"})')
QTest.qWait(30)

closed = []


def reopen_at_finish():
    ev("flowLoader.active = false")
    ev("OnboardingService.open()")
    ev("flowLoader.active = true")
    QTest.qWait(50)
    h.find(win, "flow").closeRequested.connect(lambda: (closed.append(1), ev("OnboardingService.complete()")))
    go("finish")
    QTest.qWait(30)


h.find(win, "flow").closeRequested.connect(lambda: (closed.append(1), ev("OnboardingService.complete()")))
ev("wizard.skipRequested = true")
h.eval(h.find(win, "skipConfirm"), "clicked()")
QTest.qWait(30)
check(closed == [1] and calls("exclusive.enable") == [], "Skip on the summary never enables exclusive mode")
reopen_at_finish()
h.eval(vfind("exclusiveToggle"), "toggled(true)")
ev('BackendService.replies = Object.assign({}, BackendService.replies, {"exclusive.enable": {error: "config errors: monitor"}})')
h.eval(vfind("finishStart"), "clicked()")
QTest.qWait(30)
check(closed == [1, 1], "Start using finishes the wizard")
check(len(calls("exclusive.enable")) == 1, "Start applies the only-shell choice, once")
sent = json.loads(ev("JSON.stringify(Notifications.sent)"))
check(len(sent) == 1 and "only shell" in sent[0]["summary"] and "config errors: monitor" in sent[0]["body"],
      f"a failed enable after the wizard closed is notified, got {sent}")
check(ev("StateService.state.onboarding") is None, "finishing clears the saved wizard state")

# Enter on the summary means Start (ruling C-3): applies the toggle, only when on.
from PySide6.QtCore import Qt  # noqa: E402

ev('BackendService.replies = Object.assign({}, BackendService.replies, {"exclusive.enable": ' + json.dumps(STATUS_OFF) + '})')


def press_enter():
    h.find(win, "flow").forceActiveFocus()
    QTest.keyClick(win, Qt.Key_Return)
    QTest.qWait(30)


reopen_at_finish()
press_enter()
check(closed == [1, 1, 1] and len(calls("exclusive.enable")) == 1, "Enter with the toggle off finishes without enabling")
reopen_at_finish()
h.eval(vfind("exclusiveToggle"), "toggled(true)")
press_enter()
check(closed == [1, 1, 1, 1] and len(calls("exclusive.enable")) == 2, "Enter with the toggle on enables exactly once")
# a running exclusive call: the enable waits for it instead of being dropped
reopen_at_finish()
h.eval(vfind("exclusiveToggle"), "toggled(true)")
ev("ExclusiveService.busy = true")
press_enter()
check(len(calls("exclusive.enable")) == 2, "nothing is sent while another exclusive call runs")
ev("ExclusiveService.busy = false")
QTest.qWait(30)
check(len(calls("exclusive.enable")) == 3, "the enable runs once the other call is done")
check(calls("extras.cancel") == [] and ev("ExtrasService.busy") is True, "installs keep running after the wizard")

if h.type_errors:
    failures.append("type errors: " + "; ".join(h.type_errors))
print("onboarding-apps-ui:", "FAIL" if failures else "ok", f"({len(failures)} failure(s))")
h.exit(1 if failures else 0)
