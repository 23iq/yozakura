"""Bar islands do not animate their first layout, and the digital clock face
keeps one width while its digits tick (9:59 -> 10:00)."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

h = Harness("bar-island-stable")
h.singleton("qs.config", "Config", "QtObject { property int roundness: 0; property int animDuration: 200 }")
h.singleton("qs.modules.theme", "Motion",
            "QtObject { property var morph: ({ duration: 200, easing: Easing.Linear, overshoot: 1 }) }")
h.copy("modules/bar/BarIsland.qml", siblings=False)
h.stub("IslandShape", "Item { property string edge; property real bodyLength; property real bodyThickness;"
       " property real fillet; property real bodyRadius; property bool startFlush; property bool endFlush;"
       " property real localHeight: 0; property real bodyOffset: 0 }")
h.copy("modules/bar/clock/faces/Digital.qml", siblings=False)

root = h.load("""
import QtQuick
Item {
    width: 400; height: 100
    property var barRoot: ({ orientation: "horizontal", barPosition: "top" })
    BarIsland {
        objectName: "isl"
        barRoot: parent.barRoot
        layoutItem: Item { id: probe; implicitWidth: 80; implicitHeight: 20 }
    }
    Item {
        id: holder
        property var clk: ({ parts: { hours: "9", minutes: "59", suffix: "" }, textColor: "white",
                             fontFamily: "sans", fontSize: 14, fontWeight: Font.Medium })
        Digital { objectName: "face"; clock: holder.clk }
    }
}
""")
isl = h.find(root, "isl")
# first layout snaps: no animation was running when the body length first arrived
assert h.eval(isl, "bodyLength") == 88, h.eval(isl, "bodyLength")
assert h.eval(isl, "settled") is False
QTest.qWait(250)
assert h.eval(isl, "settled") is True

face = h.find(root, "face")
w1 = h.eval(face, "implicitWidth")
h.eval(root, "holder.clk = ({ parts: { hours: '10', minutes: '00', suffix: '' }, textColor: 'white', fontFamily: 'sans', fontSize: 14, fontWeight: Font.Medium })")
QTest.qWait(20)
w2 = h.eval(face, "implicitWidth")
assert abs(w1 - w2) < 0.5, (w1, w2)
print("ok")
