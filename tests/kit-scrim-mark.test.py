"""Kit Scrim and Mark (modules/components/kit): the scrim dims at its
strength while shown, fades out when hidden, reports clicks only while
dismissable; a Mark is fully round by default and keeps an explicit radius."""
import functools
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from lib.kit_env import KitEnv  # noqa: E402
from PySide6.QtCore import QPoint, Qt  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

SCENE = """import QtQuick
import QtQuick.Window
import qs.modules.theme
import qs.modules.components.kit
Window {
    width: 300; height: 200; visible: true
    property int clicks: 0
    Item {
        objectName: "host"; anchors.fill: parent
        Mark { objectName: "dot"; width: 10; height: 10 }
        Mark { objectName: "bar"; width: 40; height: 6 }
        Mark { objectName: "square"; width: 40; height: 40; radius: 0 }
        Scrim { objectName: "scrim"; strength: 0.4; animated: false
                onClicked: parent.Window.window.clicks++ }
    }
}"""

FAILED = []


def check(cond, msg):
    if not cond:
        print("FAIL:", msg)
        FAILED.append(msg)


for lang in ("ink", "tiles"):
    env = KitEnv(f"kit-scrim-mark-{lang}", overrides={"theme": {"language": lang}})
    h = env.h
    win = env.load(SCENE)
    get = functools.partial(h.find, win)
    win.requestActivate()
    QTest.qWait(50)

    check(get("dot").property("radius") == 5, f"{lang}: a square Mark is a round dot")
    check(get("bar").property("radius") == 3, f"{lang}: a Mark capsule rounds its short side")
    check(get("square").property("radius") == 0, f"{lang}: an explicit radius stays")

    scrim = get("scrim")
    check(abs(scrim.property("opacity") - 0.4) < 1e-6, f"{lang}: the scrim dims at its strength")
    check(h.eval(scrim, "color.toString()") == h.eval(win, "Colors.scrim.toString()"), f"{lang}: scrim colour")
    check(scrim.property("width") == 300 and scrim.property("height") == 200, f"{lang}: the scrim fills its parent")
    QTest.mouseClick(win, Qt.LeftButton, Qt.NoModifier, QPoint(150, 150))
    check(win.property("clicks") == 1, f"{lang}: a click on the scrim is reported")
    scrim.setProperty("dismissable", False)
    QTest.mouseClick(win, Qt.LeftButton, Qt.NoModifier, QPoint(150, 150))
    check(win.property("clicks") == 1, f"{lang}: a scrim that is not dismissable lets clicks through")
    scrim.setProperty("shown", False)
    check(scrim.property("opacity") == 0, f"{lang}: hidden scrim is clear")
    win.close()

if FAILED:
    sys.exit(1)
print("kit-scrim-mark: ok")
