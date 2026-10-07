"""Font picker of the settings font control (controls/FontPickerPopup.qml),
offscreen: the family list filters by query and "Monospace only", the
current family is the selected row, and picking a row (click or Enter)
emits familyPicked and closes the popup.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import headless  # noqa: E402

headless.ensure(gl=True)

from PySide6.QtQuick import QQuickWindow  # noqa: E402,F401
from PySide6.QtTest import QTest  # noqa: E402
from settings_env import SettingsEnv  # noqa: E402

env = SettingsEnv("font-picker-ui")
h = env.h

win = env.load("""
import QtQuick
import QtQuick.Window
import qs.modules.settings.controls
Window {
    id: w
    width: 700; height: 600; visible: true
    property string picked: ""
    FontControl {
        objectName: "control"
        width: 600
        onFamilyPicked: f => w.picked = f
    }
}""")


def check(cond: bool, what: str) -> None:
    if not cond:
        print("FAIL:", what, file=sys.stderr)
        sys.exit(1)


control = h.find(win, "control")
ev = h.eval
ev(control, "openPicker()")
QTest.qWait(300)
pk = h.find(control, "fontPicker")


def pe(expr: str):
    return ev(pk, expr)


check(pe("opened") is True, "the picker opens")
total = pe("families.length")
check(total > 0, "lists the installed families")
first = pe("families[0]")
needle = first[:3].lower()
pe(f"query = '{needle}'")
fams = json.loads(pe("JSON.stringify(families)"))
check(first in fams and all(needle in f.lower() for f in fams), f"query filters ({fams})")

pe("query = ''")
pe("monoOnly = true")
mono = pe("families.length")
check(mono < total, f"monospace only narrows the list ({mono}/{total})")

pe("monoOnly = false")
pe(f"pick('{first}')")
QTest.qWait(200)
check(ev(win, "picked") == first, "pick emits familyPicked")
check(pe("opened") is False, "pick closes the picker")
print("font-picker-ui: ok")
