"""Settings sidebar footer for the active preset (PresetStatusFooter).

Hidden with no active preset; shows the name and the change count; the
primary action is "Save to preset" for a user preset and "Save as new
preset" for a built-in one, none when nothing changed; the actions reach
PresetStatusService (stubbed in settings_env, calls recorded).
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from settings_env import SettingsEnv  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

env = SettingsEnv("preset-status-footer")
h = env.h
win = env.load("""
import QtQuick
import QtQuick.Window
import qs.modules.services
import qs.modules.settings
Window {
    width: 1100; height: 720; visible: true
    function setStatus(s) { PresetStatusService.status = s }
    function calls() { return PresetStatusService.calls.join(",") }
    SettingsShell { objectName: "shell"; anchors.fill: parent }
}
""")
shell = h.find(win, "shell")
footer = h.find(win, "presetStatusFooter")
save = h.find(footer, "presetStatusSave")


def status(**kw):
    s = {"active": "", "owned": False, "official": False, "changed": 0, "changes": []}
    s.update(kw)
    h.eval(win, f"setStatus({json.dumps(s)})")
    QTest.qWait(30)


status()
assert not footer.property("shown"), "no active preset: footer hidden"

changes = [{"key": "theme.roundness", "a": 7, "b": 3}]
status(active="Mine", owned=True, changed=1, changes=changes)
assert footer.property("shown")
assert footer.property("action") == "save"
assert save.property("visible")
caption = h.find(footer, "presetStatusCaption").property("text")
assert "1" in caption, caption
assert h.find(footer, "presetStatusName").property("text") == "Mine"

status(active="Mine", owned=True, changed=0)
assert footer.property("action") == "", "in sync: no primary action"
assert not save.property("visible")

status(active="Night", official=True, changed=2, changes=changes * 2)
assert footer.property("action") == "saveAs", "a built-in is never written"

# Actions reach the service; "changes" opens the sheet.
h.eval(shell, 'presetAction("revert")')
h.eval(shell, 'presetAction("changes")')
assert h.find(win, "presetChangesSheet").property("open")
status(active="Mine", owned=True, changed=1, changes=changes)
h.eval(shell, 'presetAction("save")')
QTest.qWait(50)
calls = h.eval(win, "calls()")
assert calls.split(",") == ["revert", "save"], calls

# During a try/edit session nothing is offered.
status(active="Mine", owned=True, changed=1, changes=changes, session="try")
assert footer.property("action") == "", "no save while a session is open"
print("ok")
