"""The wheel over a slider (kit WheelGuard.js): on a page that scrolls the
wheel scrolls the page, the slider under the pointer stays where it was;
once the slider holds the focus (clicked, or Tab) the wheel steps it; a
slider outside a scrolling view (a bar popup) takes the wheel as before."""
import functools
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from lib.kit_env import KitEnv  # noqa: E402
from PySide6.QtCore import QCoreApplication, QPoint, QPointF, Qt  # noqa: E402
from PySide6.QtGui import QWheelEvent  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

SCENE = """import QtQuick
import QtQuick.Window
import qs.modules.components.kit
Window {
    width: 400; height: 300; visible: true
    Flickable {
        objectName: "page"
        width: 400; height: 200
        contentHeight: 900
        clip: true
        Column {
            y: 40
            Item {
                objectName: "holder"
                width: 300; height: 40
                activeFocusOnTab: true
                LineSlider { objectName: "inPage"; width: 300; value: 0.5 }
            }
        }
    }
    LineSlider { objectName: "loose"; y: 240; width: 300; value: 0.5 }
}"""

env = KitEnv("kit-wheel")
h = env.h
win = env.load(SCENE)
get = functools.partial(h.find, win)
ev = h.eval
failures = 0


def check(ok: bool, what: str) -> None:
    global failures
    if not ok:
        failures += 1
        print("FAIL:", what)


def wheel(item, dy: int = -120) -> None:
    p = h.eval(item, "mapToItem(null, width / 2, height / 2)")
    pos = QPointF(p.x(), p.y())
    e = QWheelEvent(pos, pos, QPoint(0, 0), QPoint(0, dy), Qt.NoButton, Qt.NoModifier, Qt.NoScrollPhase, False)
    QCoreApplication.sendEvent(win, e)
    QTest.qWait(30)


page = get("page")
in_page = get("inPage")
loose = get("loose")

wheel(in_page)
check(abs(ev(in_page, "value") - 0.5) < 1e-6, f"scrolling past a slider leaves it alone ({ev(in_page, 'value')})")
check(ev(page, "contentY") > 0, "...and the page scrolls")

ev(get("holder"), "forceActiveFocus()")
QTest.qWait(30)
wheel(in_page)
check(abs(ev(in_page, "value") - 0.5) > 1e-6, "a focused slider takes the wheel")

wheel(loose)
check(abs(ev(loose, "value") - 0.5) > 1e-6, "a slider outside a scrolling view takes the wheel")

if failures:
    sys.exit(1)
print("kit-wheel: ok")
