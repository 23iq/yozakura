#!/usr/bin/env python3
"""Onboarding wizard (modules/onboarding), offscreen.

Every step of the 8-step flow loads; Continue / Back / dots / Esc navigate
and finish; the welcome language chips write system.language; the displays
step offers the refresh upgrade (live apply, wizard steps aside for the
keep prompt, keep saves) and pre-fills the keyboard; the look step tabs and
preset pick; the terminal step writes general.terminal and terminal.prompt;
the keybind tour completes on GlobalShortcuts.commandRan (and peeks); the
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


# DP-1 runs at 60 Hz but can do 165; HDMI-A-1 already runs at its best.
OUTPUTS = [
    {"id": "AOC-Q27-1", "name": "DP-1", "make": "AOC", "model": "Q27G2", "enabled": True,
     "width": 2560, "height": 1440, "refresh": 60, "x": 0, "y": 0, "scale": 1, "transform": 0, "vrr": False,
     "physical_width_mm": 597, "physical_height_mm": 336,
     "modes": [{"width": 2560, "height": 1440, "refresh": r} for r in (165, 144, 60)]
              + [{"width": 1920, "height": 1080, "refresh": 60}]},
    {"id": "LG-27GL-2", "name": "HDMI-A-1", "make": "LG", "model": "27GL850", "enabled": True,
     "width": 1920, "height": 1080, "refresh": 144, "x": 2560, "y": 0, "scale": 1, "transform": 0, "vrr": False,
     "physical_width_mm": 598, "physical_height_mm": 336,
     "modes": [{"width": 1920, "height": 1080, "refresh": r} for r in (144, 60)]},
]
env = OnboardingEnv("onboarding-ui", overrides={"theme": {"animDuration": 0}}, outputs=OUTPUTS,
                    replies={"displays.apply": {"session": "s1", "revertIn": 15, "live": True}, "displays.keep": {}})
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


def vfind(root, name):
    """Like h.find, through visual children too (Repeater delegates have no QObject parent)."""
    try:
        return h.find(root, name)
    except AssertionError:
        pass
    start = root if root is not win else h.find(win, "stepLoader")
    return h.eval(start, "(function f(it) { if (it.objectName === %s) return it;"
                         " for (const c of it.children) { const r = f(c); if (r) return r; } return null; })(this)"
                  % json.dumps(name))


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
check(seen == ["welcome", "displays", "look", "terminal", "apps", "ai", "keybinds", "finish"], f"the 8-step flow, saw {seen}")

# Back and dot navigation
ev("wizard.back()")
check(step_id() == seen[-2], "back goes to the previous step")
ev("wizard.go(1)")
check(step_id() == seen[1], "go(1) jumps to the second step")
check(ev("wizard.direction") == -1, "jumping back slides from the left")

# Welcome: the language chips write system.language and are remembered.
ev("wizard.go(0)")
QTest.qWait(30)
h.eval(h.find(win, "languageChips"), 'selected("ru")')
check(ev("Config.system.language") == "ru" and ev("wizard.choices.language") == "ru", "language chip writes system.language")
h.eval(h.find(win, "languageChips"), 'selected("auto")')

# Displays: the 60 Hz monitor offers its 165 Hz; the other one looks good.
ev(f"wizard.go({seen.index('displays')})")
QTest.qWait(50)
dp = vfind(win, "monitorCard:DP-1")
hdmi = vfind(win, "monitorCard:HDMI-A-1")
check(dp is not None and hdmi is not None, "one card per monitor")
up = vfind(dp, "upgradeButton")
check(up is not None and h.eval(up, "visible") is True and "165" in h.eval(up, "text"), "60 Hz monitor offers 'Use 165 Hz'")
check(h.eval(vfind(hdmi, "upgradeButton"), "visible") is False, "no upgrade on a monitor at its best rate")
check(h.eval(vfind(hdmi, "looksGood"), "visible") is True, "a monitor with nothing to improve says it looks good")
check(h.eval(vfind(dp, "looksGood"), "visible") is False, "the upgradable one does not")
win_src = (Path(__file__).resolve().parents[1] / "modules/onboarding/OnboardingWindow.qml").read_text()
import re  # noqa: E402
wvis = re.search(r"^\s*visible: (.+)$", win_src, re.M).group(1)
wprobe = h.load("import QtQuick\nimport qs.modules.services\nQtObject {\n    property bool vis: " + wvis + "\n}", auto_stub=False)
check(h.eval(wprobe, "vis") is True, "wizard window mapped before the change")
h.eval(up, "clicked()")
QTest.qWait(30)
applied = json.loads(ev("JSON.stringify(BackendService.calls.filter(c => c.method === 'displays.apply').map(c => c.params.outputs))"))
check(len(applied) == 1, f"Use 165 Hz runs displays.apply once, got {applied}")
if applied:
    dp1 = [o for o in applied[0] if o["name"] == "DP-1"]
    other = [o for o in applied[0] if o["name"] == "HDMI-A-1"]
    check(dp1 and dp1[0]["refresh"] == 165 and dp1[0]["width"] == 2560, f"DP-1 goes to 165 Hz, got {dp1}")
    check(other and other[0]["refresh"] == 144, "the other monitor keeps its mode")
check(ev("DisplaysService.pending") is True, "the change is pending (keep/revert prompt)")
check(h.eval(wprobe, "vis") is False, "the wizard steps aside while the keep prompt is up")
check(ev("wizard.choices.displays['DP-1'].refresh") == 165, "the chosen mode is remembered")
ev("DisplaysService.keep()")
saved = json.loads(ev("JSON.stringify(Config.displays.monitors)"))
check(any(m.get("name") == "DP-1" and m.get("refresh") == 165 for m in saved), f"Keep saves the layout, got {saved}")
ev('DisplaysService._onSession({session: "s1", state: "kept", remaining: 0, live: true})')
QTest.qWait(30)
check(h.eval(wprobe, "vis") is True, "the wizard comes back after Keep")
h.eval(vfind(dp, "moreButton"), "clicked()")
QTest.qWait(30)
check(vfind(dp, "monitorDetails") is not None, "More expands the full editor inline")

# Keyboard: first visit pre-fills us + the locale layout (only over the default).
step = loader.property("item")
ev('Config.keyboard.layouts = [{layout: "us", variant: ""}]; wizard.remember("keyboardSeeded", false)')
h.eval(step, 'seedKeyboard("ru_RU")')
check(json.loads(ev("JSON.stringify(Config.keyboard.layouts.map(l => l.layout))")) == ["us", "ru"], "ru_RU pre-fills us,ru")
check(ev("wizard.choices.keyboardSeeded") is True, "pre-fill happens once")
ev('Config.keyboard.layouts = [{layout: "us", variant: ""}]')
h.eval(step, 'seedKeyboard("ru_RU")')
check(json.loads(ev("JSON.stringify(Config.keyboard.layouts.map(l => l.layout))")) == ["us"], "a second visit does not pre-fill again")
h.eval(h.find(win, "layoutPicker"), 'picked("de")')
check(json.loads(ev("JSON.stringify(Config.keyboard.layouts.map(l => l.layout))")) == ["us", "de"], "the picker adds a layout")
check(json.loads(ev("JSON.stringify(wizard.choices.keyboard)")) == ["us", "de"], "layouts are remembered")
QTest.qWait(30)
check(vfind(win, "layoutChip:de") is not None, "layout chips show the new layout")

# Look: Style / Wallpaper tabs; picking a preset applies it; "keep" restores.
ev(f"wizard.go({seen.index('look')})")
QTest.qWait(50)
check(h.find(win, "lookPeek") is not None, "Preview on desktop is offered")
check(h.eval(h.find(win, "lookStyle"), "visible") is True and h.eval(h.find(win, "lookWallpaper"), "visible") is False, "Style tab first")
h.eval(h.find(win, "lookTabs"), 'picked("wallpaper")')
QTest.qWait(30)
check(ev("wizard.choices.lookTab") == "wallpaper", "the tab is remembered")
check(h.eval(h.find(win, "lookStyle"), "visible") is False and h.eval(h.find(win, "lookWallpaper"), "visible") is True, "Wallpaper tab shows")
h.eval(h.find(win, "lookTabs"), 'picked("style")')
names = json.loads(ev("JSON.stringify(PresetsService.presets.map(p => p.name))"))
check(len(names) > 0, "built-in presets listed")
grid = h.find(win, "presetGrid")
check(grid is not None and grid.property("count") == len(names) + 1, "gallery = keep-current + every preset")
ev(f'wizard.choosePreset({json.dumps(names[0])})')
check(json.loads(ev("JSON.stringify(PresetsService.loaded)")) == [names[0]], "picking a preset loads it")
ev('wizard.initialPreset = "Orig"')
ev('wizard.choosePreset("")')
check(json.loads(ev("JSON.stringify(PresetsService.loaded)"))[-1] == "Orig", "keep-current re-applies the initial preset")

# Terminal: detected terminal chips, "Other…", the prompt gallery.
ev("TerminalLookService.presets = [{id: 'sakura-powerline', name: 'Sakura', description: 'x', nerdFont: true, lines: 1},"
   " {id: 'plain', name: 'Plain', description: 'y', nerdFont: false, lines: 1}]")
ev(f"wizard.go({seen.index('terminal')})")
ev('wizard.detected = Object.assign({}, wizard.detected, {terminals: ["foot", "kitty"]})')
QTest.qWait(50)
check(h.find(win, "terminalPeek") is not None, "Preview on desktop is offered")
h.eval(h.find(win, "terminalChips"), 'selected("foot")')
check(ev("Config.general.terminal") == "foot" and ev("wizard.choices.terminal") == "foot", "terminal chip writes general.terminal")
other = h.find(win, "terminalOther")
h.eval(other, 'text = "  wezterm "; accepted()')
check(ev("Config.general.terminal") == "wezterm", "Other… writes any terminal command")
card = vfind(win, "promptCard:plain")
check(card is not None, "prompt gallery shows the presets")
if card is not None:
    h.eval(card, "clicked()")
check(ev("Config.terminal.prompt") == "plain" and ev("wizard.choices.prompt") == "plain", "picking a prompt writes terminal.prompt and is remembered")
check(h.find(win, "fishDefault") is not None, "Make fish my default shell row")
check(json.loads(ev("JSON.stringify(TerminalLookService.chosen)")) == ["plain"], "the gallery turns the prompt on through enablePrompt")
check(h.eval(h.find(win, "nerdNotice"), "visible") is False, "no Nerd Font notice when one is installed")
ev("TerminalLookService.nerdFontAvailable = false; TerminalLookService.enablePrompt('sakura-powerline')")
check(h.eval(h.find(win, "nerdNotice"), "visible") is True, "a Nerd Font prompt without the font shows the notice")
ev("TerminalLookService.nerdFontAvailable = true")

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
ev(f"wizard.go({seen.index('look')})")
ev(f'wizard.choosePreset({json.dumps(names[0])})')
ev('wizard.remember("lookTab", "wallpaper")')
flow = start_flow("OnboardingService.close(); OnboardingService.open()")
check(ev("wizard.chosenPreset") == names[0] and step_id() == "look", "the preset choice is restored")
check(ev("wizard.choices.lookTab") == "wallpaper", "the look tab choice comes back")
QTest.qWait(50)
check(h.eval(h.find(win, "lookWallpaper"), "visible") is True, "the resumed look step shows the remembered tab")

# toggle while peeking comes back to the wizard instead of closing it
ev("OnboardingService.peek = true")
ev("OnboardingService.toggle()")
check(ev("OnboardingService.peek") is False and ev("OnboardingService.visible") is True, "toggle while peeking returns to the wizard")
ev("OnboardingService.toggle()")
check(ev("OnboardingService.visible") is False, "toggle on the open wizard closes it")
check(json.loads(ev("JSON.stringify(StateService.state.onboarding.step)")) == "look", "closing keeps the progress for the next open")

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
# OnboardingWindow's own `visible` binding (the layer window is not loadable offscreen)
winsrc = (Path(__file__).resolve().parents[1] / "modules/onboarding/OnboardingWindow.qml").read_text()
vis = re.search(r"^\s*visible: (.+)$", winsrc, re.M).group(1)
vprobe = h.load("import QtQuick\nimport qs.modules.services\nQtObject {\n    property bool vis: " + vis + "\n}", auto_stub=False)
ev("OnboardingService.peek = true")
check(h.eval(vprobe, "vis") is False, "wizard window is unmapped while peeking")
h.eval(h.find(pwin, "peekBack"), "clicked()")
check(h.eval(vprobe, "vis") is True, "wizard window is mapped again after Back to setup")
check("mask: Region" in (Path(__file__).resolve().parents[1] / "modules/onboarding/OnboardingPeekPill.qml").read_text(), "pill window masks input to the pill")
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
