"""The wizard's kit wrappers (modules/onboarding): FocusChip (a kit Chip the
keyboard reaches: Tab, Enter / Space, focus ring) and ChoiceRow (a kit
ListRow: check / toggle / link / none ends, the whole row acts, keys too)."""
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
REPO = Path(__file__).resolve().parents[1]
from lib.kit_env import KitEnv  # noqa: E402
from PySide6.QtCore import QPoint, Qt  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

SCENE = """import QtQuick
import QtQuick.Window
import qs.modules.theme
import qs.modules.components.kit
import qs.modules.onboarding
Window {
    width: 500; height: 400; visible: true
    property int clicks: 0
    property int rowClicks: 0
    property var toggles: []
    Column {
        width: 400
        spacing: 4
        FocusChip { objectName: "chip"; text: "Continue"; primary: true
                    onClicked: parent.Window.window.clicks++ }
        ChoiceRow { objectName: "check"; width: parent.width; icon: "monitor"; title: "Pick"; subtitle: "one"
                    onClicked: parent.Window.window.rowClicks++ }
        ChoiceRow { objectName: "toggle"; width: parent.width; mode: "toggle"; title: "Fish"; badge: "busy"
                    onToggled: v => { const t = parent.Window.window.toggles.slice(); t.push(v);
                                      parent.Window.window.toggles = t } }
        ChoiceRow { objectName: "none"; width: parent.width; mode: "none"; title: "Status" }
    }
}"""

env = KitEnv("onboarding-kit", overrides={"theme": {"animDuration": 0}})
ONBOARDING = env.root / "qs/modules/onboarding"
ONBOARDING.mkdir(parents=True, exist_ok=True)
for name in ("FocusChip", "ChoiceRow"):
    shutil.copy(REPO / "modules/onboarding" / f"{name}.qml", ONBOARDING)
env._qmldir(ONBOARDING, "qs.modules.onboarding")
h = env.h
win = env.load(SCENE)
ev = h.eval
chip, check, toggle, none = (h.find(win, n) for n in ("chip", "check", "toggle", "none"))

# FocusChip: Enter / Space click, focus shows the hover look and a ring.
ev(chip, "forceActiveFocus()")
QTest.keyClick(win, Qt.Key_Return)
QTest.keyClick(win, Qt.Key_Space)
assert ev(win, "clicks") == 2, ev(win, "clicks")
assert ev(chip, "highlighted") is True
assert ev(chip, "activeFocusOnTab") is True

# Tab walks chip -> check row -> toggle row, skipping the status-only row.
QTest.keyClick(win, Qt.Key_Tab)
assert ev(check, "activeFocus") is True
assert ev(check, "highlighted") is True
QTest.keyClick(win, Qt.Key_Tab)
assert ev(toggle, "activeFocus") is True
assert ev(none, "activeFocusOnTab") is False

# Check row: Enter clicks; checked = selected (accent tint).
ev(check, "forceActiveFocus()")
QTest.keyClick(win, Qt.Key_Return)
assert ev(win, "rowClicks") == 1
assert ev(check, "selected") is False
ev(check, "checked = true")
assert ev(check, "selected") is True

# Toggle row: Space and a click on the row flip it (never `clicked` as a pick).
ev(toggle, "forceActiveFocus()")
QTest.keyClick(win, Qt.Key_Space)
assert ev(win, "JSON.stringify(toggles)") == "[true]", ev(win, "JSON.stringify(toggles)")
ev(toggle, "checked = true")
x = ev(toggle, "mapToItem(null, width / 3, height / 2).x")
y = ev(toggle, "mapToItem(null, width / 3, height / 2).y")
QTest.mouseClick(win, Qt.LeftButton, Qt.NoModifier, QPoint(int(x), int(y)))
assert ev(win, "JSON.stringify(toggles)") == "[true,false]", ev(win, "JSON.stringify(toggles)")
assert ev(toggle, "selected") is False

# Dimmed / disabled rows ignore keys.
ev(toggle, "enabled = false")
ev(toggle, "activate()")
assert ev(win, "toggles.length") == 2

print("onboarding-kit: ok")
