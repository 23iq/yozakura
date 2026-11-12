#!/usr/bin/env python3
"""Onboarding summary step (StepFinish) fits its card, offscreen.

At 1920x1080, in every visual language (tests/lib/languages.py), the
summary, the only-shell choice (offered: Hyprland) and the update channel
fit the step's Flickable unscrolled: the caption under them is never cut
above the buttons and no scrollbar shows. At 1280x720 the summary fits too
(no logo); with the only-shell details expanded it scrolls, with the
scrollbar shown.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from exclusive_env import PLAN, STATUS_OFF  # noqa: E402
from languages import LANGUAGES  # noqa: E402
from onboarding_env import OnboardingEnv  # noqa: E402

from PySide6.QtTest import QTest  # noqa: E402

failures: list[str] = []


def check(cond: bool, msg: str) -> None:
    if not cond:
        failures.append(msg)
        print("FAIL:", msg)


FIND = ("(function f(it) { if (it.objectName === %s) return it;"
        " for (const c of it.children) { const r = f(c); if (r) return r; } return null; })(this)")

h = None
for language in LANGUAGES:
    env = OnboardingEnv(f"onboarding-fit-{language}", overrides={"theme": {"animDuration": 0, "language": language}},
                        replies={"exclusive.status": STATUS_OFF, "exclusive.plan": PLAN})
    h = env.h
    win = h.load("""
import QtQuick
import QtQuick.Window
import qs.modules.onboarding
import qs.modules.services
Window {
    width: 1920; height: 1080; visible: true
    readonly property var wizard: flow.wizard
    OnboardingFlow { id: flow; objectName: "flow"; anchors.fill: parent }
}""", auto_stub=False)
    h.eval(win, "ExclusiveService.refresh()")
    h.eval(win, "wizard.go(wizard.count - 1)")
    QTest.qWait(300)
    step = h.find(win, "stepLoader")

    def item(name, step=step, h=h):
        return h.eval(step, FIND % json.dumps(name))

    def fit(item=item, h=h):
        """The flickable, the height of its content column and its own."""
        flick = item("finishFlick")
        return flick, h.eval(flick, "contentItem.children[0].implicitHeight"), h.eval(flick, "height")

    for (w, hh) in ((1920, 1080), (1280, 720)):
        win.setWidth(w)
        win.setHeight(hh)
        QTest.qWait(200)
        tag = f"{language} {w}x{hh}"
        check(h.eval(win, "wizard.step.id") == "finish", f"{tag}: on the summary step")
        check(h.eval(item("exclusiveLoader"), "active") is True, f"{tag}: the only-shell choice is offered")
        check(h.eval(item("updateChannel"), "visible") is True, f"{tag}: the update channel is shown")
        flick, column, height = fit()
        check(column <= height, f"{tag}: the summary does not fit: content {column} > viewport {height}")
        check(h.eval(flick, "contentY") == 0, f"{tag}: scrolled")

    # 720p with the only-shell details open: it scrolls, and says so
    h.eval(win, 'wizard.remember("exclusive", true)')
    QTest.qWait(300)
    flick, column, height = fit()
    if column > height:
        check(h.eval(flick, "ScrollBar.vertical.policy === ScrollBar.AlwaysOn") is True,
              f"{language} 1280x720 expanded: no scrollbar while content {column} > viewport {height}")
    win.close()

if h is not None and h.type_errors:
    failures.append("type errors: " + "; ".join(h.type_errors))
print("onboarding-finish-fit:", "FAIL" if failures else "ok", f"({len(failures)} failure(s))")
sys.exit(1 if failures else 0)
