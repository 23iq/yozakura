#!/usr/bin/env python3
"""PresetStudio.afterFlush, offscreen: a preset command that must see the
staged settings edits (save preset, a trial's backup) runs only once they
are written.

The real PresetStudio over a stub SettingsStore and PreviewSink. In-process
Apply writes at once and the command runs after the short delay (250 ms),
as before. In a separate window (performance.separateWindows) Apply is
answered later (PreviewSink.applying: the main shell writes, or the window
after its timeout): the command waits for that answer, then the delay, and
never runs while it is pending. Nothing staged: the command runs at once.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from qmlharness import Harness, hard_exit  # noqa: E402

from waits import pump, wait_until  # noqa: E402

failures: list[str] = []


def check(cond: bool, msg: str) -> None:
    if not cond:
        failures.append(msg)
        print("FAIL:", msg)


h = Harness("preset-studio-flush")
h.module("Quickshell", {
    "Singleton": "QtObject { default property list<QtObject> data }",
    "Quickshell": "pragma Singleton\nQtObject { function env(n) { return \"\" } }",
})
h.module("Quickshell.Io", {
    "Process": "QtObject { property var command; property bool running; property var stdout; property var stderr; signal exited(int code) }",
    "StdioCollector": "QtObject { property string text }",
})
h.module("qs.modules.globals", {})
h.module("qs.modules.services", {
    "I18n": "pragma Singleton\nQtObject { function t(k) { return k } function tn(k, n) { return k } }",
    # a window's applyOwn: pending until the test answers (applying = false)
    "PreviewSink": "pragma Singleton\nQtObject { property bool applying: false }",
})
h.copy("modules/settings/store/PresetStudio.qml", "qs/modules/settings/store")
h.module("qs.modules.settings.store", {
    "SettingsStore": """pragma Singleton
import qs.modules.services
QtObject {
    property bool hasChanges: false
    property bool separate: false
    property int applies: 0
    function apply() {
        applies++;
        hasChanges = false;
        if (separate)
            PreviewSink.applying = true;
    }
    function discard() { hasChanges = false }
}""",
})

root = h.load("""
import QtQuick
import qs.modules.services
import qs.modules.settings.store
Item {
    property var ran: []
    Component.onCompleted: PresetStudio.runner = function (a, cb) { cb(true, "", "") }
    function flush(tag) { PresetStudio.afterFlush(() => { ran = ran.concat([tag]) }) }
}""", auto_stub=False)


def ev(expr):
    return h.eval(root, expr)


def ran():
    return json.loads(ev("JSON.stringify(ran)"))


# nothing staged: at once
ev("flush('clean')")
check(ran() == ["clean"], f"nothing staged: the command runs at once, got {ran()}")

# in-process: Apply writes at once, the command follows after the delay
ev("SettingsStore.hasChanges = true")
ev("flush('in-process')")
check(ev("SettingsStore.applies") == 1, "staged edits are applied first")
check(wait_until(lambda: ran() == ["clean", "in-process"]), f"in-process: the command runs after the delay, got {ran()}")

# a separate window: the command waits for the apply's answer
ev("SettingsStore.separate = true; SettingsStore.hasChanges = true")
ev("flush('window')")
check(ev("PreviewSink.applying") is True, "the window's Apply is pending")
pump(800)
check(ran() == ["clean", "in-process"], f"...the command does not run while the answer is pending, got {ran()}")
ev("PreviewSink.applying = false")
pump(100)
check(ran() == ["clean", "in-process"], "...nor right when it comes (the write settles first)")
check(wait_until(lambda: ran() == ["clean", "in-process", "window"]), f"...then it runs, got {ran()}")

if failures:
    print(f"{len(failures)} failure(s)")
    hard_exit(1)
print("preset-studio-flush: ok")
hard_exit(0)
