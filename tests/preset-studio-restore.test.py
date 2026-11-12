#!/usr/bin/env python3
"""PresetStudio, offscreen: commands that bring back the config from before
a session, and the settings window's undo history.

* Cancelling a preset edit and reverting a trial write a live change still
  waiting for its coalesced write (SettingsStore.flush) before the backend
  restores the files, so the restore replaces it instead of the pending
  write landing on top (tests/config-file-restore.test.py shows why); the
  wizard's staging is dropped first, never applied.
* Every command that rewrites the config (apply, try, trial keep / revert,
  edit save / cancel) clears the undo history: its steps describe the
  config from before.

The real PresetStudio over a stub SettingsStore that logs the calls.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from qmlharness import Harness, hard_exit  # noqa: E402

from waits import wait_until  # noqa: E402

failures: list[str] = []


def check(cond: bool, msg: str) -> None:
    print(("PASS " if cond else "FAIL ") + msg)
    if not cond:
        failures.append(msg)


h = Harness("preset-studio-restore")
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
    "PreviewSink": "pragma Singleton\nQtObject { property bool applying: false }",
})
h.copy("modules/settings/store/PresetStudio.qml", "qs/modules/settings/store")
h.module("qs.modules.settings.store", {
    "SettingsStore": """pragma Singleton
QtObject {
    property bool hasChanges: false
    property var log: []
    function note(what) { log = log.concat([what]) }
    function apply() { hasChanges = false; note("apply") }
    function discard() { hasChanges = false; note("discard") }
    function flush() { if (hasChanges) apply(); note("flush") }
    function clearHistory() { note("clearHistory") }
}""",
})

root = h.load("""
import QtQuick
import qs.modules.settings.store
Item {
    Component.onCompleted: PresetStudio.runner = function (a, cb) {
        SettingsStore.note("run " + a.join(" "));
        cb(true, "", "");
    }
}""", auto_stub=False)


def ev(expr):
    return h.eval(root, expr)


def log():
    out = json.loads(ev("JSON.stringify(SettingsStore.log)"))
    ev("SettingsStore.log = []")
    return [x for x in out if not x.startswith("run list") and not x.startswith("run aspects")
            and not x.startswith("run try --status") and not x.startswith("run edit --status")]


def session(kind, name):
    ev(f"PresetStudio.{kind} = {{ preset: '{name}' }}")
    log()


# cancel an edit: flush, then restore, then the history goes
session("edit", "Mine")
ev("PresetStudio.finishEdit(false, false)")
got = log()
check(got[:3] == ["flush", "run edit --cancel", "clearHistory"], f"edit cancel: write pending edits, restore, clear history: {got}")

# with the wizard's staging: dropped, never applied
session("edit", "Mine")
ev("SettingsStore.hasChanges = true")
ev("PresetStudio.finishEdit(false, false)")
got = log()
check(got[:4] == ["discard", "flush", "run edit --cancel", "clearHistory"] and "apply" not in got,
      f"edit cancel with staged choices: discarded, not applied: {got}")

# revert a trial
session("trial", "Sakura")
ev("PresetStudio.endTrial(false)")
got = log()
check(got[:3] == ["flush", "run try --revert", "clearHistory"], f"trial revert: write pending edits, restore, clear history: {got}")

# keeping / saving / applying clear the history too
session("trial", "Sakura")
ev("PresetStudio.endTrial(true)")
got = log()
check(got[:3] == ["flush", "run try --keep", "clearHistory"], f"trial keep clears the history: {got}")
session("edit", "Mine")
ev("PresetStudio.finishEdit(true, true)")
got = log()
check(got[:3] == ["flush", "run edit --save --keep", "clearHistory"], f"edit save: {got}")
ev("PresetStudio.trial = null; PresetStudio.edit = null; PresetStudio.pending = ''")
ev("PresetStudio.apply('Sakura')")
check(wait_until(lambda: "clearHistory" in json.loads(ev("JSON.stringify(SettingsStore.log)"))), "apply clears the history")
got = log()
check(got.index("run apply Sakura --json") < got.index("clearHistory"), f"...after the files are written: {got}")

if failures:
    print(f"{len(failures)} failure(s)")
    hard_exit(1)
print("preset-studio-restore: ok")
hard_exit(0)
