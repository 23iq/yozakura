#!/usr/bin/env python3
"""Onboarding terminal step defaults (modules/onboarding/TerminalShellChoice),
offscreen.

A first run with no prompt or shell of the user's own preselects "use this
prompt in fish" and "make fish my default shell", says what Continue does,
and applies both only on Continue; unticked boxes apply nothing; a foreign
prompt preselects nothing; skipping the wizard applies nothing; a re-run
preselects nothing; a cancelled password (failed chsh) is said on the step
and the summary never claims the prompt for a shell that will not load it.
The dry run: tests/onboarding-dryrun.test.py.
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


env = OnboardingEnv("onboarding-terminal-ui", overrides={"theme": {"animDuration": 0}})
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

STEPS = ["welcome", "displays", "look", "terminal", "apps", "ai", "keybinds", "finish"]
FRESH = {"enabled": False, "engine": "starship", "fishInstalled": False, "fishIsLoginShell": False,
         "loginShell": "/bin/bash", "engineInstalled": {"starship": True, "ohmyposh": False},
         "foreignPromptInit": False}


def ev(expr):
    return h.eval(win, expr)


h.eval(win, "TerminalLookService.presets = [{id: 'sakura-powerline', name: 'Sakura Powerline', description: 'x',"
            " nerdFont: false, lines: 1}, {id: 'plain', name: 'Plain', description: 'y', nerdFont: false, lines: 1}]")


def vfind(name, start=None):
    start = start if start is not None else h.find(win, "stepLoader")
    return h.eval(start, "(function f(it) { if (it.objectName === %s) return it;"
                         " for (const c of it.children) { const r = f(c); if (r) return r; } return null; })(this)"
                  % json.dumps(name))


def prop(name, p):
    it = vfind(name)
    return None if it is None else h.eval(it, p)


def fresh_wizard(status, first_run=True):
    """A new wizard on the terminal step, with nothing applied yet."""
    ev("flowLoader.active = false")
    ev("OnboardingService.complete()")
    ev(f"Config.general.onboardingDone = {'false' if first_run else 'true'}")
    ev("Config.terminal.enabled = false; Config.terminal.prompt = 'sakura-powerline'")
    ev("TerminalLookService.chosen = []; TerminalLookService.fishDefaults = 0")
    ev("ExtrasService.jobs = ({})")
    ev(f"TerminalLookService.status = {json.dumps(status) if status else 'null'}")
    ev("OnboardingService.open()")
    ev("flowLoader.active = true")
    QTest.qWait(30)
    ev(f"wizard.go({STEPS.index('terminal')})")
    QTest.qWait(50)


def applied():
    return json.loads(ev("JSON.stringify(TerminalLookService.chosen)")), ev("TerminalLookService.fishDefaults")


# ---- first run: both preselected, said, applied on Continue ---------------
fresh_wizard(FRESH)
check(prop("promptOn", "checked") is True, "first run: 'use this prompt' is preselected")
check(prop("fishDefault", "checked") is True, "first run: 'make fish my default shell' is preselected")
plan = str(prop("shellPlan", "message") or "")
check(prop("shellPlan", "visible") is True and "password" in plan and "next login" in plan and "installed" in plan,
      f"the step says what Continue does: {plan!r}")
check(applied() == ([], 0), "nothing is applied while the step shows")
ev("wizard.back()")
check(applied() == ([], 0), "Back applies nothing")
ev("wizard.next()")
ev("wizard.next()")
check(ev("wizard.step.id") == "apps", "Continue goes on")
check(applied() == (["sakura-powerline"], 1), f"Continue switches the prompt on and asks for fish: {applied()}")
check(ev("wizard.choices.fishDefault") is True, "the login-shell request is remembered")

# The summary: pending while the chsh runs, never 'on' before fish is the
# login shell.
ev("ExtrasService.jobs = ({'login-1': {job: 'login-1', kind: 'login', entries: [], state: 'running'}})")
ev(f"wizard.go({STEPS.index('finish')})")
QTest.qWait(50)
card = vfind("summary:terminal")
check(card is not None and "setting fish" in h.eval(card, "value"), f"summary while it runs: {h.eval(card, 'value') if card else None}")

# ---- the password is cancelled: said on the step and the summary -----------
ev("ExtrasService.jobs = ({'login-1': {job: 'login-1', kind: 'login', entries: [], state: 'failed', reason: 'auth_cancelled'}})")
QTest.qWait(30)
card = vfind("summary:terminal")
value = h.eval(card, "value") if card else ""
check("login shell not changed" in value, f"the summary says the login shell did not change: {value!r}")
ev(f"wizard.go({STEPS.index('terminal')})")
QTest.qWait(50)
check(prop("loginFailed", "visible") is True, "the step says the login shell was not changed")
check(prop("fishDefault", "checked") is False, "the fish row is no longer ticked")
n = applied()[1]
ev("wizard.next()")
check(applied()[1] == n, "Continue does not ask again by itself after a failure")
ev("wizard.back()")
QTest.qWait(30)
h.eval(vfind("fishDefault"), "toggled(true)")
check(prop("loginFailed", "visible") is False, "ticking it again clears the failure")
ev("ExtrasService.jobs = ({})")
ev("wizard.next()")
check(applied()[1] == n + 1, "ticked again: Continue asks again")
ev("TerminalLookService.status = Object.assign({}, TerminalLookService.status, {fishInstalled: true, fishIsLoginShell: true, loginShell: '/usr/bin/fish'})")
ev(f"wizard.go({STEPS.index('finish')})")
QTest.qWait(50)
value = h.eval(vfind("summary:terminal"), "value")
check(value.endswith("· Sakura Powerline"), f"fish is the login shell: the summary names the prompt: {value!r}")

# ---- unticked: nothing is applied -----------------------------------------
fresh_wizard(FRESH)
h.eval(vfind("promptOn"), "toggled(false)")
h.eval(vfind("fishDefault"), "toggled(false)")
check(prop("shellPlan", "visible") is False, "nothing ticked: no plan notice")
ev("wizard.next()")
check(applied() == ([], 0), f"unticked: Continue changes nothing: {applied()}")

# Only the prompt: the step says it shows only in fish.
fresh_wizard(FRESH)
h.eval(vfind("fishDefault"), "toggled(false)")
check("only when you start fish" in str(prop("shellPlan", "message")), "prompt without fish: the step says where it shows")
ev("wizard.next()")
check(applied() == (["sakura-powerline"], 0), f"prompt only: {applied()}")
ev(f"wizard.go({STEPS.index('finish')})")
QTest.qWait(50)
check("only when you start fish" in h.eval(vfind("summary:terminal"), "value"), "summary: prompt only in fish")

# ---- a prompt of the user's own: nothing preselected ----------------------
fresh_wizard({**FRESH, "fishInstalled": True, "foreignPromptInit": True})
check(prop("promptOn", "checked") is False and prop("promptOn", "enabled") is False, "foreign prompt: the prompt is not offered")
check(prop("fishDefault", "checked") is False, "foreign prompt: fish is not preselected")
ev("wizard.next()")
check(applied() == ([], 0), "foreign prompt: Continue changes nothing")

# A shell of the user's own (zsh): nothing preselected either.
fresh_wizard({**FRESH, "loginShell": "/usr/bin/zsh"})
check(prop("promptOn", "checked") is False and prop("fishDefault", "checked") is False, "zsh user: nothing preselected")

# ---- skipping the wizard applies nothing -----------------------------------
fresh_wizard(FRESH)
check(prop("fishDefault", "checked") is True, "preselected before the skip")
ev("wizard.finish()")
check(applied() == ([], 0), "skip / close applies nothing")

# ---- a re-run (existing install) preselects nothing -----------------------
fresh_wizard(FRESH, first_run=False)
check(prop("promptOn", "checked") is False and prop("fishDefault", "checked") is False, "re-run: nothing preselected")
ev("wizard.next()")
check(applied() == ([], 0), "re-run: Continue changes nothing")

# ---- no status yet: decided once it arrives ------------------------------
fresh_wizard(None)
check(prop("fishDefault", "checked") is False, "no status: nothing preselected yet")
ev(f"TerminalLookService.status = {json.dumps(FRESH)}")
QTest.qWait(20)
check(prop("fishDefault", "checked") is True, "the defaults follow once the status arrives")

# ---- the engine has no install source here: said, with its package -------
ev("ExtrasService.status = Object.assign({}, ExtrasService.status, {starship: {id: 'starship', state: 'unavailable', reason: 'no_method'}})")
ev("TerminalLookService.status = Object.assign({}, TerminalLookService.status, {engineInstalled: {starship: false, ohmyposh: false}})")
QTest.qWait(20)
msg = str(prop("engineManual", "message"))
check(prop("engineManual", "visible") is True and "starship package" in msg, f"manual engine install is said: {msg!r}")

if failures:
    print(f"{len(failures)} failure(s)")
    h.exit(1)
print("onboarding-terminal-ui: ok")
h.exit(0)
