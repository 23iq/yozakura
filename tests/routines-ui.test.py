"""Routines UI, offscreen: the settings page (templates, cards, step
edits, save, test run report, two-click delete), the per-routine keybind
slots and the "Run routine" bind picker, on tests/lib/settings_env.py with
a RoutinesService stub that records its calls.
"""
import json
import os
import sys
from pathlib import Path

# The desktop's Controls style (e.g. KDE Breeze) warns about the TextArea
# of AiTextRow; the shell itself never loads it.
os.environ["QT_QUICK_CONTROLS_STYLE"] = "Basic"

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import headless  # noqa: E402

headless.ensure(gl=True)

from PySide6.QtCore import qInstallMessageHandler  # noqa: E402
from PySide6.QtQuick import QQuickWindow  # noqa: E402,F401
from PySide6.QtTest import QTest  # noqa: E402
from settings_env import SettingsEnv, default_binds  # noqa: E402

ROUTINES = [
    {"id": "morning", "name": "Morning", "icon": "sun", "steps": [
        {"kind": "tool", "tool": "dnd_set", "args": {"enabled": False}},
        {"kind": "action", "action": "media.play-pause", "args": {}}]},
    {"id": "night", "name": "Night", "icon": "moon", "steps": [{"kind": "delay", "ms": 1000}]},
]

binds = default_binds()
binds["custom"] = [{"name": "", "keys": [{"modifiers": ["SUPER"], "key": "F9"}],
                    "actions": [{"id": "utilities.routine", "args": {"routine": "night"}, "layouts": []}], "enabled": True}]
env = SettingsEnv("routines-ui", binds=binds)
h = env.h

errors: list[str] = []
_prev = qInstallMessageHandler(None)


def _capture(mode, ctx, msg):
    if any(s in msg for s in ("TypeError", "ReferenceError", "is not a type", "Cannot assign", "Unable to assign",
                              "failed to load", "Error:")):
        errors.append(msg)
    if _prev:
        _prev(mode, ctx, msg)


qInstallMessageHandler(_capture)

win = env.load("""
import QtQuick
import QtQuick.Window
import qs.config
import qs.modules.services
import qs.modules.keybinds
import qs.modules.settings
import qs.modules.settings.editors.keybinds
Window {
    id: w
    width: 1180; height: 900; visible: true; color: "black"
    function findItem(name, from) {
        var item = from || w.contentItem;
        if (item.objectName === name) return item;
        var kids = item.children || [];
        if (item.contentItem && item.contentItem !== item && kids.indexOf(item.contentItem) === -1)
            kids = kids.concat([item.contentItem]);
        for (var i = 0; i < kids.length; i++) { var f = findItem(name, kids[i]); if (f) return f; }
        return null;
    }
    function setRoutines(json) { RoutinesService.routines = JSON.parse(json) }
    function routines() { return JSON.stringify(RoutinesService.routines) }
    function calls() { return JSON.stringify(RoutinesService.calls) }
    function slots() { return JSON.stringify(KeybindsStore.rows.filter(r => r.kind === "slot" && r.routine).map(r => [r.uid, r.name])) }
    property string picked: ""
    SettingsShell { objectName: "shell"; anchors.fill: parent }
    RoutinePickerField { objectName: "picker"; width: 400; y: 860; routineId: "night"; onPicked: id => w.picked = id }
}""")
shell = h.find(win, "shell")


def ev(expr: str):
    return h.eval(shell, expr)


def check(cond: bool, what: str) -> None:
    if not cond:
        print("FAIL:", what, file=sys.stderr)
        sys.exit(1)


def calls() -> list:
    return json.loads(ev("w.calls()"))


ev(f"w.setRoutines({json.dumps(json.dumps(ROUTINES))})")
ev('select("routines")')
QTest.qWait(600)
check(["refresh"] in calls(), "the page refreshes the list")
for rid in ("morning", "night"):
    check(ev(f'w.findItem("routineCard:{rid}") !== null'), f"card for {rid}")
for t in ("focus", "night", "meeting", "music"):
    check(ev(f'w.findItem("template:{t}") !== null'), f"template {t}")

# Keybinds: a slot for the routine nothing runs yet (night has SUPER+F9).
slots = json.loads(ev("w.slots()"))
check(slots == [["slot:routine:morning", "Morning"]], f"routine slots {slots}")

# Bind picker: one chip per routine, picking emits the id.
check(ev('w.findItem("routineChip:night").checked') is True, "current routine chip checked")
ev('w.findItem("routineChip:morning").toggled(true)')
check(ev("w.picked") == "morning", "picker emits the routine id")

# Template -> new expanded card with its steps; Save writes it.
ev('w.findItem("template:night").clicked()')
QTest.qWait(150)
new = 'w.findItem("routineCard:new")'
check(ev(f"{new} !== null && {new}.expanded"), "a template opens a new expanded card")
check(ev(f"{new}.routine.steps.length") == 3, "template steps")
check(ev(f"{new}.problems.length") == 0, "template is valid")
ev('w.findItem("saveRoutine", w.findItem("routineCard:new")).clicked()')
QTest.qWait(150)
saves = [c for c in calls() if c[0] == "save"]
check(len(saves) == 1 and saves[0][2] == "", f"saved as new {saves}")
check(any(r["name"] == "Night" and len(r["steps"]) == 3 for r in json.loads(ev("w.routines()"))), "list updated")

# Edit a saved routine: a draft (dirty) until Save, step edits apply.
card = 'w.findItem("routineCard:morning")'
ev(f'w.findItem("toggleRoutine", {card}).clicked()')
QTest.qWait(150)
check(ev(f"{card}.expanded"), "card expands")
ev(f'w.findItem("addStep:delay", {card}).clicked()')
QTest.qWait(100)
check(ev(f"{card}.dirty") is True, "edit makes a draft")
check(ev(f"{card}.routine.steps.length") == 3, "delay step added")
step = f'w.findItem("routineStep:2", {card})'
check(ev(f"{step} !== null"), "step row rendered")
ev(f'{step}.patched({{"ms": 2500}})')
ev(f'w.findItem("routineStep:0", {card}).moved(1)')
QTest.qWait(100)
kinds = ev(f'JSON.stringify({card}.routine.steps.map(s => s.kind))')
check(json.loads(kinds) == ["action", "tool", "delay"], f"reordered {kinds}")
check(ev(f"{card}.routine.steps[2].ms") == 2500, "delay edited")

# An invalid step blocks Save.
ev(f'w.findItem("routineStep:1", {card}).patched({{"tool": "routine_run"}})')
QTest.qWait(50)
check(ev(f"{card}.problems.length") == 1, "blocked tool is a problem")
check(ev(f'w.findItem("saveRoutine", {card}).enabled') is False, "save disabled while invalid")
ev(f'w.findItem("routineStep:1", {card}).patched({{"tool": "volume_set", "args": {{"percent": 30}}}})')
QTest.qWait(50)

# Test run: the draft is run quietly and its report is shown.
ev('RoutinesService.nextReport = {"ok": false, "steps": [{"index": 0, "label": "Play/Pause", "status": "ok"}, '
   '{"index": 1, "label": "Tool volume_set", "status": "failed", "error": "no sink"}, '
   '{"index": 2, "label": "Wait 2.5s", "status": "skipped"}]}')
ev(f'w.findItem("testRoutine", {card}).clicked()')
QTest.qWait(150)
tests = [c for c in calls() if c[0] == "test"]
check(len(tests) == 1 and len(tests[0][1]["steps"]) == 3, "test run sends the draft")
check(ev(f'w.findItem("routineReport", {card}).visible') is True, "report shown")
check(ev(f'w.findItem("routineReport", {card}).summary.done') == 1, "report summary")

ev(f'w.findItem("saveRoutine", {card}).clicked()')
QTest.qWait(150)
saves = [c for c in calls() if c[0] == "save"]
check(saves[-1][2] == "morning" and len(saves[-1][1]["steps"]) == 3, "save replaces the routine")
check(ev(f"{card}.dirty") is False, "saved card is clean")

# Delete needs a second click.
ev(f'w.findItem("deleteRoutine", {card}).clicked()')
QTest.qWait(50)
check(not any(c[0] == "delete" for c in calls()), "first click only arms")
check(ev(f"{card}.armed") is True, "armed")
ev(f'w.findItem("deleteRoutine", {card}).clicked()')
QTest.qWait(150)
check(["delete", "morning"] in calls(), "second click deletes")

out = Path(sys.argv[1]) if len(sys.argv) > 1 else None
if out:
    out.mkdir(parents=True, exist_ok=True)
    win.grabWindow().save(str(out / "routines-settings.png"))

check(not errors, "QML errors: " + "\n".join(errors[:5]))
print("routines-ui: ok")
