"""The wheel over a slider (kit WheelGuard.js), on the real kit controls: on
a page that scrolls the wheel scrolls the page and the slider under the
pointer stays where it was; once the slider was pressed (it takes the focus:
LineSlider through WheelGuard.claim, onto the focusable control wrapping it
when there is one, LevelSlider the same way, Knob itself) the wheel steps it;
a slider outside a scrolling view (a bar popup) takes the wheel on hover,
and a press there leaves the focus where it was (LineSlider, LevelSlider)."""
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
    width: 400; height: 460; visible: true
    Flickable {
        objectName: "page"
        width: 400; height: 300
        contentHeight: 1200
        clip: true
        Column {
            y: 20
            spacing: 20
            LineSlider { objectName: "bare"; width: 300; value: 0.5 }
            Item {
                objectName: "holder"
                width: 300; height: 40
                activeFocusOnTab: true
                LineSlider { objectName: "wrapped"; width: 300; value: 0.5 }
            }
            LevelSlider { objectName: "level"; width: 300; value: 0.5 }
            Knob { objectName: "knob"; value: 0.5 }
        }
    }
    Item { objectName: "other"; focus: true }
    LineSlider { objectName: "loose"; y: 340; width: 300; value: 0.5 }
    LevelSlider { objectName: "looseLevel"; y: 370; width: 300; value: 0.5 }
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


def center(item) -> QPointF:
    p = h.eval(item, "mapToItem(null, width / 2, height / 2)")
    return QPointF(p.x(), p.y())


_stamp = [1000]


def wheel(item, dy: int = 120) -> None:
    pos = center(item)
    e = QWheelEvent(pos, pos, QPoint(0, 0), QPoint(0, dy), Qt.NoButton, Qt.NoModifier, Qt.NoScrollPhase, False)
    _stamp[0] += 1000  # a fresh gesture each time (Flickable times its wheel velocity)
    e.setTimestamp(_stamp[0])
    QCoreApplication.sendEvent(win, e)
    QTest.qWait(30)


def press(item) -> None:
    p = center(item)
    pt = QPoint(int(p.x()), int(p.y()))
    QTest.mouseClick(win, Qt.LeftButton, Qt.NoModifier, pt)
    QTest.qWait(30)


page = get("page")


def scrolls_page_not(name: str) -> None:
    """Hover only: the page scrolls, the control keeps its value."""
    item = get(name)
    ev(page, "cancelFlick(); contentY = 0")
    QTest.qWait(30)
    before = ev(item, "value")
    wheel(item, -120)
    check(abs(ev(item, "value") - before) < 1e-6, f"{name}: scrolling past it leaves it alone ({ev(item, 'value')})")
    check(ev(page, "contentY") > 0, f"{name}: ...and the page scrolls")


def press_takes_wheel(name: str, focus_on: str) -> None:
    """A press focuses it (or its wrapper), then the wheel steps it."""
    item = get(name)
    ev(page, "cancelFlick(); contentY = 0")
    QTest.qWait(30)
    press(item)
    check(ev(get(focus_on), "activeFocus") is True, f"{name}: a press gives {focus_on} the focus")
    before = ev(item, "value")
    y0 = ev(page, "contentY")
    wheel(item, 120)
    check(abs(ev(item, "value") - before) > 1e-6, f"{name}: once pressed the wheel steps it")
    check(abs(ev(page, "contentY") - y0) < 1e-6, f"{name}: ...and the page stays")


for name in ("bare", "wrapped", "level", "knob"):
    scrolls_page_not(name)
press_takes_wheel("bare", "bare")
press_takes_wheel("wrapped", "holder")
press_takes_wheel("level", "level")
press_takes_wheel("knob", "knob")

# Outside a scrolling view: the wheel adjusts on hover, a press leaves the focus.
ev(get("other"), "forceActiveFocus()")
loose = get("loose")
wheel(loose)
check(abs(ev(loose, "value") - 0.5) > 1e-6, "a slider outside a scrolling view takes the wheel")
press(loose)
check(ev(get("other"), "activeFocus") is True, "a press outside a scrolling view leaves the focus alone")
looseLevel = get("looseLevel")
press(looseLevel)
check(ev(get("other"), "activeFocus") is True, "a level slider pressed outside a scrolling view leaves the focus alone")

if failures:
    sys.exit(1)
print("kit-wheel: ok")
