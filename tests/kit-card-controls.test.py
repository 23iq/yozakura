"""Kit Card: a control inside an interactive card gets its own clicks (the
remove button of a bar in Settings > Bar used to select the bar instead),
a click elsewhere on the card is the card's, and the card stays hovered
while the pointer is over the control (a HoverHandler, not a MouseArea the
control covers)."""
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
    width: 400; height: 200; visible: true
    property int cardClicks: 0
    property int buttonClicks: 0
    Card {
        objectName: "card"
        x: 20; y: 20; width: 300
        interactive: true
        onClicked: cardClicks++
        Item {
            width: parent.width; height: 40
            IconButton {
                objectName: "remove"
                anchors.right: parent.right
                icon: Icons.trash
                tooltip: "Remove"
                onClicked: buttonClicks++
            }
        }
    }
}"""

env = KitEnv("kit-card-controls")
h = env.h
win = env.load(SCENE)
card = h.find(win, "card")
remove = h.find(win, "remove")


def centre(item):
    p = h.eval(item, "mapToItem(null, width / 2, height / 2)")
    return QPoint(int(p.x()), int(p.y()))


# enter the window first (offscreen, the first move only enters it)
QTest.mouseMove(win, QPoint(380, 180))
QTest.qWait(50)
QTest.mouseMove(win, QPoint(40, 50))
QTest.qWait(50)
QTest.mouseMove(win, QPoint(45, 52))
QTest.qWait(50)
assert card.property("hovered"), "the pointer on the card hovers it"
QTest.mouseMove(win, centre(remove))
QTest.qWait(30)
assert card.property("hovered"), "the card stays hovered over its control"

QTest.mouseClick(win, Qt.LeftButton, Qt.NoModifier, centre(remove))
QTest.qWait(30)
assert win.property("buttonClicks") == 1, "the control inside the card gets the click"
assert win.property("cardClicks") == 0, "a click on the control is not the card's"

edge = h.eval(card, "mapToItem(null, 12, height / 2)")
QTest.mouseClick(win, Qt.LeftButton, Qt.NoModifier, QPoint(int(edge.x()), int(edge.y())))
QTest.qWait(30)
assert win.property("cardClicks") == 1, "a click beside the control is the card's"
assert win.property("buttonClicks") == 1

print("kit-card-controls: ok")
