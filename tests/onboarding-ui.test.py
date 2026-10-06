#!/usr/bin/env python3
"""Onboarding wizard (modules/onboarding), offscreen.

Every step loads; Continue / Back / dots / Esc navigate and finish; a preset
pick applies it; terminal/language picks write their keys; the keybind tour
completes on GlobalShortcuts.commandRan (and steps the window aside); the
general.json "existing install" rule of Config.qml.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
sys.path.insert(0, str(Path(__file__).resolve().parent))
from onboarding_env import OnboardingEnv  # noqa: E402

from PySide6.QtTest import QTest  # noqa: E402

failures: list[str] = []


def check(cond: bool, msg: str) -> None:
    if not cond:
        failures.append(msg)
        print("FAIL:", msg)


env = OnboardingEnv("onboarding-ui", overrides={"theme": {"animDuration": 0}})
h = env.h
win = h.load("""
import QtQuick
import QtQuick.Window
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
}""", auto_stub=False)


def start_flow(expr="OnboardingService.open()"):
    """(Re)open the wizard like the shell does and instantiate the card."""
    h.eval(win, "flowLoader.active = false")
    h.eval(win, expr)
    h.eval(win, "flowLoader.active = true")
    QTest.qWait(50)
    return h.find(win, "flow")


flow = start_flow()


def ev(expr):
    return h.eval(win, expr)


def step_id():
    return ev("wizard.step.id")


steps = json.loads(ev("JSON.stringify(wizard.count)"))
check(steps >= 7, f"expected >= 7 steps, got {steps}")
check(step_id() == "welcome", "starts on welcome")

loader = h.find(win, "stepLoader")
seen = []
for i in range(steps):
    QTest.qWait(30)
    check(h.eval(loader, "status === Loader.Ready") is True, f"step {step_id()} loaded")
    check(loader.property("item") is not None, f"step {step_id()} has an item")
    seen.append(step_id())
    if i < steps - 1:
        ev("wizard.next()")
check(seen[-1] == "finish", f"last step is finish, saw {seen}")

# Back and dot navigation
ev("wizard.back()")
check(step_id() == seen[-2], "back goes to the previous step")
ev("wizard.go(1)")
check(step_id() == seen[1], "go(1) jumps to the second step")
check(ev("wizard.direction") == -1, "jumping back slides from the left")

# Preset step: picking applies through PresetsService; "keep" restores.
ev(f"wizard.go({seen.index('preset')})")
QTest.qWait(50)
names = json.loads(ev("JSON.stringify(PresetsService.presets.map(p => p.name))"))
check(len(names) > 0, "built-in presets listed")
grid = h.find(win, "presetGrid")
check(grid is not None and grid.property("count") == len(names) + 1, "gallery = keep-current + every preset")
ev(f'wizard.choosePreset({json.dumps(names[0])})')
check(json.loads(ev("JSON.stringify(PresetsService.loaded)")) == [names[0]], "picking a preset loads it")
ev('wizard.initialPreset = "Orig"')
ev('wizard.choosePreset("")')
check(json.loads(ev("JSON.stringify(PresetsService.loaded)"))[-1] == "Orig", "keep-current re-applies the initial preset")

# System step: terminal + language picks write the config.
ev(f"wizard.go({seen.index('system')})")
ev('wizard.detected = wizard.detected.constructor === Object ? Object.assign({}, wizard.detected, {terminals: ["foot", "kitty"]}) : wizard.detected')
QTest.qWait(30)
check(h.find(win, "terminalList").property("count") >= 2, "detected terminals listed")
ev('wizard.set("general.terminal", "foot")')
check(ev("Config.general.terminal") == "foot", "terminal written")
ev('wizard.set("system.language", "ru")')
check(ev("Config.system.language") == "ru", "language written")

# AI step renders with detected agents.
ev(f"wizard.go({seen.index('ai')})")
ev('wizard.detected = Object.assign({}, wizard.detected, {agents: {claude: "/usr/bin/claude"}})')
QTest.qWait(30)
check(h.find(win, "aiMaster") is not None, "AI master toggle present")
check(h.find(win, "voiceSetup") is not None, "voice setup offered")
check(h.find(win, "aiProviders") is not None, "Connect a provider row offered")
check(ev("wizard.ollama.state") == "missing", "no binary and no probe answer: Ollama missing")
ev('wizard.ollamaProbe = ({reachable: true, models: [{id: "qwen3", capabilities: ["completion"]}]})')
check(ev("wizard.ollama.state") == "running" and ev("wizard.ollama.count") == 1, "a reachable server means Ollama runs (no key)")
ev("wizard.probeOllama()")
check(ev("BackendService.calls.some(c => c.method === 'providers.ollama.probe')"), "Ollama is detected by probing the server")

# Keybind tour: commandRan completes the matching task and steps aside.
ev(f"wizard.go({seen.index('keybinds')})")
QTest.qWait(30)
check(ev("wizard.activeTask.id") == "cheatsheet", "tour starts with the cheatsheet")
ev('GlobalShortcuts.run("keybinds")')
check(ev("wizard.tour.cheatsheet") == "done", "pressing the cheatsheet bind completes the task")
check(ev("OnboardingService.peek") is True, "wizard peeks (pill) while the panel is open")
ev('Visibilities.currentActiveModule = "keybinds"')
QTest.qWait(1400)
check(ev("OnboardingService.peek") is True, "stays peeking while the panel is open")
ev('Visibilities.currentActiveModule = ""')
QTest.qWait(600)
check(ev("OnboardingService.peek") is False, "comes back when the panel closes")
ev('GlobalShortcuts.run("dashboard")')
check(ev("wizard.activeTask.id") == "launcher", "unrelated commands do not complete tasks")
ev('wizard.markTask("launcher", "skipped")')
ev('GlobalShortcuts.run("overview")')
ev('GlobalShortcuts.run("assistant")')
check(ev("wizard.tourComplete") is True, "tour completes when every task is done or skipped")

# ---- Esc / Skip setup asks first ------------------------------------------
from PySide6.QtCore import Qt  # noqa: E402

closed = []
flow.closeRequested.connect(lambda: closed.append(1))
ev("wizard.go(0)")
flow.forceActiveFocus()
QTest.keyClick(win, Qt.Key_Escape)
check(ev("wizard.skipRequested") is True, "Esc asks 'Skip setup?' instead of dismissing")
check(closed == [], "Esc alone never ends the setup")
QTest.qWait(30)
panel = h.find(win, "skipConfirmPanel")
check(panel is not None and ev("wizard.skipRequested") is True, "confirmation card is rendered in the card")
QTest.keyClick(win, Qt.Key_Return)
check(ev("wizard.skipRequested") is False and step_id() == "welcome", "Return on the focused 'Keep going' closes the confirm without advancing")
QTest.keyClick(win, Qt.Key_Escape)
QTest.keyClick(win, Qt.Key_Escape)
check(ev("wizard.skipRequested") is False, "Esc again dismisses the confirmation")
ev("wizard.skipRequested = true")
h.eval(h.find(win, "skipKeepGoing"), "clicked()")
check(ev("wizard.skipRequested") is False and closed == [], "Keep going closes the confirm and stays in the wizard")
h.eval(h.find(win, "onboardingSkipAll"), "clicked()")
check(ev("wizard.skipRequested") is True, "the header Skip setup button asks too")
h.eval(h.find(win, "skipConfirm"), "clicked()")
check(closed == [1], "confirming Skip ends the setup")

# ---- persisted, resumable state --------------------------------------------
ev("OnboardingService.complete()")
check(ev("StateService.state.onboarding") is None, "complete() clears the persisted wizard")
flow = start_flow()
ev("wizard.go(3)")
saved = json.loads(ev("JSON.stringify(StateService.state.onboarding)"))
check(saved["step"] == seen[3], f"progress is stored by step id, got {saved}")
ev('wizard.set("general.terminal", "foot"); wizard.remember("note", 7)')
check(json.loads(ev("JSON.stringify(StateService.state.onboarding.choices.note)")) == 7, "remembered choices are persisted")
# shell reload: the card and the wizard are recreated, the state stays on disk
flow = start_flow("OnboardingService.close(); OnboardingService.open()")
check(step_id() == seen[3] and ev("wizard.index") == 3, "reload resumes at the same step")
check(ev("wizard.choices.note") == 7 and ev("OnboardingService.peek") is False, "choices come back, peek is reset")
check(h.eval(h.find(win, "stepLoader"), "status === Loader.Ready") is True, "the resumed step loads")
# a step id the registry no longer has falls back to the first step
ev('StateService.state = ({onboarding: {step: "gone", choices: {}}})')
flow = start_flow("OnboardingService.close(); OnboardingService.open()")
check(step_id() == "welcome", "unknown saved step falls back to the first")
flow = start_flow(f'OnboardingService.openAt("{seen[2]}")')
check(step_id() == seen[2], "openAt jumps to a step id")
# preset choice survives a resume
ev(f"wizard.go({seen.index('preset')})")
ev(f'wizard.choosePreset({json.dumps(names[0])})')
flow = start_flow("OnboardingService.close(); OnboardingService.open()")
check(ev("wizard.chosenPreset") == names[0] and step_id() == "preset", "the preset choice is restored")

# toggle while peeking comes back to the wizard instead of closing it
ev("OnboardingService.peek = true")
ev("OnboardingService.toggle()")
check(ev("OnboardingService.peek") is False and ev("OnboardingService.visible") is True, "toggle while peeking returns to the wizard")
ev("OnboardingService.toggle()")
check(ev("OnboardingService.visible") is False, "toggle on the open wizard closes it")
check(json.loads(ev("JSON.stringify(StateService.state.onboarding.step)")) == "preset", "closing keeps the progress for the next open")

# ---- peek pill + service fixes ----------------------------------------------
flow = start_flow("OnboardingService.close(); OnboardingService.open()")
ev("OnboardingService.peek = true")
pwin = h.load("""
import QtQuick
import QtQuick.Window
import qs.modules.onboarding
Window { width: 700; height: 160; visible: true
    PeekPill { objectName: "pill"; anchors.centerIn: parent; shown: true } }""", auto_stub=False)
QTest.qWait(50)
label = h.find(pwin, "peekLabel")
check(label is not None and h.eval(label, "text") == f"Setup · step {ev('wizard.index') + 1}/{ev('wizard.count')}", "pill shows 'Setup · step N/M'")
h.eval(h.find(pwin, "peekBack"), "clicked()")
check(ev("OnboardingService.peek") is False and ev("OnboardingService.visible") is True, "Back to setup leaves peek, wizard stays open")
# open() while visible neither resets nor overwrites progress
ev("wizard.go(2)")
ev("OnboardingService.peek = true")
ev("OnboardingService.open()")
check(ev("OnboardingService.peek") is False and ev("wizard.index") == 2, "open() while visible returns from peek and keeps the step")
check(json.loads(ev("JSON.stringify(StateService.state.onboarding.step)")) == seen[2], "saved progress was not overwritten")
# open() before StateService is ready waits for it, then restores
ev("OnboardingService.close()")
ev("StateService.initialized = false")
ev("OnboardingService.open()")
check(ev("OnboardingService.visible") is False, "open() before StateService is initialized defers")
ev("StateService.initialized = true")
check(ev("OnboardingService.visible") is True and ev("wizard.index") == 2, "deferred open runs and restores the saved step")
# a user close stops the auto-show for the session
ev("OnboardingService.close()")
check(ev("OnboardingService.dismissedThisSession") is True and ev("OnboardingService.autoShow.running") is False, "auto-show does not reopen after a close")

# ---- Config.qml: general.json from before the wizard = existing install ----
cfg = (Path(__file__).resolve().parents[1] / "config/Config.qml").read_text()
start = cfg.index("function markOnboardedIfLegacy(loader)")
body = cfg[start:cfg.index("\n    }\n", start) + 6]
probe = h.load("import QtQuick\nQtObject {\n"
               "    property string t: ''\n"
               "    function text() { return t }\n"
               "    function setText(v) { t = v }\n"
               "    " + body.replace("loader.", "this.").replace("function markOnboardedIfLegacy(loader)",
                                                                    "function mark()") + "\n}", auto_stub=False)
for raw, want in [('{"terminal": "kitty"}', True), ('{"terminal": "kitty", "onboardingDone": false}', False),
                  ("", None), ("not json", None)]:
    h.eval(probe, f"t = {json.dumps(raw)}")
    h.eval(probe, "mark()")
    after = h.eval(probe, "t")
    got = json.loads(after).get("onboardingDone") if after.strip().startswith("{") else None
    check(got == want, f"legacy rule for {raw!r}: want {want}, got {got}")

if h.type_errors:
    failures.append("type errors: " + "; ".join(h.type_errors))
print("onboarding-ui:", "FAIL" if failures else "ok", f"({len(failures)} failure(s))")
h.exit(1 if failures else 0)
