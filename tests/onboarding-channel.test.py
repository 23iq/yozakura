#!/usr/bin/env python3
"""Onboarding summary: the update channel choice (UpdateChannelChoice), offscreen.

Three rows (stable / beta / git) with one line each, stable preselected from
the default; visiting or skipping writes nothing; a click writes
system.updateChannel through the wizard (staged, saved when the wizard
ends) and is remembered; the rows are keyboard reachable (Tab, Space) and
the step count and Back are unchanged.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from onboarding_env import OnboardingEnv  # noqa: E402

from PySide6.QtCore import Qt  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

failures: list[str] = []


def check(cond: bool, msg: str) -> None:
    if not cond:
        failures.append(msg)
        print("FAIL:", msg)


env = OnboardingEnv("onboarding-channel", overrides={"theme": {"animDuration": 0}})
h = env.h
win = h.load("""
import QtQuick
import QtQuick.Window
import qs.modules.onboarding
import qs.modules.services
import qs.modules.globals
import qs.modules.settings.store
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
    start = h.find(win, "stepLoader")
    return h.eval(start, "(function f(it) { if (it.objectName === %s) return it;"
                         " for (const c of it.children) { const r = f(c); if (r) return r; } return null; })(this)"
                  % json.dumps(name))


def checked():
    return [c for c in ("stable", "beta", "git") if vfind("channel:" + c) is not None and h.eval(vfind("channel:" + c), "checked")]


closed = []


def open_at_finish():
    ev("flowLoader.active = false")
    ev("OnboardingService.open()")
    ev("flowLoader.active = true")
    QTest.qWait(50)
    h.find(win, "flow").closeRequested.connect(lambda: (closed.append(1), ev("OnboardingService.complete()")))
    ev("wizard.go(wizard.count - 1)")
    QTest.qWait(60)


open_at_finish()
check(ev("wizard.step.id") == "finish", "the channel choice is on the summary step")
check(ev("wizard.count") == 8, f"no extra step: {ev('wizard.count')}")
group = vfind("updateChannel")
check(group is not None and h.eval(group, "visible") is True, "the summary shows the update channel")
rows = {c: vfind("channel:" + c) for c in ("stable", "beta", "git")}
check(all(rows.values()), f"one row per channel: {rows}")
check(checked() == ["stable"], f"stable is preselected, got {checked()}")
for c, row in rows.items():
    sub = h.eval(row, "subtitle") if row is not None else ""
    check(isinstance(sub, str) and sub != "" and not sub.startswith("onboarding."), f"{c} has its one-line description: {sub!r}")
check(h.eval(rows["git"], "title") == "Git" and h.eval(rows["beta"], "title") == "Beta", "rows are titled by channel")
check(h.eval(group, "label") == "Updates", f"section label: {h.eval(group, 'label')!r}")

# Leaving the default and skipping writes nothing.
check(ev("SettingsStore.hasChanges") is False, "visiting the summary stages nothing")
ev("wizard.skipRequested = true")
h.eval(h.find(win, "skipConfirm"), "clicked()")
QTest.qWait(30)
check(closed == [1], "skip closes the wizard")
check(ev("Config.system.updateChannel") == "stable", "skip keeps the default channel")
check(ev("GlobalStates.applied") == 0, "skip applies (saves) nothing")

# A click on the selected default changes nothing either.
open_at_finish()
h.eval(vfind("channel:stable"), "clicked()")
check(ev("SettingsStore.hasChanges") is False, "re-picking stable stages nothing")

# Beta: written (staged), remembered, checked; Back and forth keep it.
h.eval(vfind("channel:beta"), "clicked()")
QTest.qWait(30)
check(ev("Config.system.updateChannel") == "beta", "beta writes system.updateChannel")
check(ev("wizard.choices.updateChannel") == "beta", "the choice is remembered")
check(checked() == ["beta"], f"only beta is checked, got {checked()}")
check(ev("SettingsStore.hasChanges") is True, "the change is staged like the other steps' settings")
ev("wizard.back()")
QTest.qWait(30)
check(ev("wizard.step.id") == "keybinds", "Back still goes to the previous step")
ev("wizard.next()")
QTest.qWait(60)
check(checked() == ["beta"], "beta is still selected after Back / Continue")

# Keyboard: Tab reaches the rows, Space picks.
check(all(h.eval(r, "activeFocusOnTab") for r in (vfind("channel:" + c) for c in ("stable", "beta", "git"))),
      "every row takes Tab focus")
git = vfind("channel:git")
h.eval(git, "forceActiveFocus()")
QTest.keyClick(win, Qt.Key_Space)
QTest.qWait(30)
check(ev("Config.system.updateChannel") == "git", "Space on a focused row picks it")

# Start using: the staged choice is saved.
h.eval(vfind("finishStart"), "clicked()")
QTest.qWait(30)
check(closed == [1, 1], "Start using finishes the wizard")
check(ev("Config.system.updateChannel") == "git", "the channel stays after finishing")
check(ev("GlobalStates.applied") == 1 and ev("SettingsStore.hasChanges") is False,
      "finishing applies the staged channel (system.json is written)")

if h.type_errors:
    failures.append("type errors: " + "; ".join(h.type_errors))
print("onboarding-channel:", "FAIL" if failures else "ok", f"({len(failures)} failure(s))")
h.exit(1 if failures else 0)
