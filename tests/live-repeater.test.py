"""A Repeater inside an asynchronously built view (WarmLoader, KeepAliveLoader,
LivePart) reports its `count` before its delegates exist, and `itemAt()` is
not reactive: a binding that read it stayed null / 0 until something else
woke it (the dashboard tabs lost their pill until the tab changed).
LiveRepeater.liveItemAt() is the reactive read; bindings must use it."""
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from lib.kit_env import KitEnv  # noqa: E402
from PySide6.QtCore import QTimer  # noqa: E402
from PySide6.QtQml import QQmlIncubationController  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

REPO = Path(__file__).resolve().parents[1]

SCENE = """import QtQuick
import QtQuick.Window
import qs.modules.components
import qs.modules.components.kit
Window {
    id: win
    width: 500; height: 200; visible: true
    property var names: [{ name: "segA", text: "One" }, { name: "segB", text: "Two" }, { name: "segC", text: "Three" }]
    property alias seg: segLoader.item
    property alias list: listLoader.item
    function pill() {
        for (const c of win.seg.children)
            if (c.objectName === "segmentPill")
                return c;
        return null;
    }
    Loader {
        id: segLoader
        asynchronous: true
        active: false
        sourceComponent: Segmented { currentIndex: 1; model: win.names }
    }
    Loader {
        id: listLoader
        asynchronous: true
        active: false
        sourceComponent: Item {
            property int wanted: 1
            readonly property Item current: rep.liveItemAt(wanted)
            readonly property real total: {
                let w = 0;
                for (let i = 0; i < rep.count; i++) {
                    const it = rep.liveItemAt(i);
                    if (it)
                        w += it.width;
                }
                return w;
            }
            property alias model: rep.model
            LiveRepeater {
                id: rep
                model: 3
                Item { required property int index; objectName: "row" + index; width: 10 }
            }
        }
    }
    function start() { segLoader.active = true; listLoader.active = true; }
}"""


class Slices(QQmlIncubationController):
    """Incubates in short slices between events, as the shell's controller."""

    def __init__(self):
        super().__init__()
        self.timer = QTimer()
        self.timer.setInterval(1)
        self.timer.timeout.connect(lambda: self.incubateFor(1))
        self.timer.start()


env = KitEnv("live-repeater")
h = env.h
slices = Slices()
h.engine.setIncubationController(slices)
win = env.load(SCENE)
h.eval(win, "start()")
for _ in range(200):
    QTest.qWait(10)
    if h.eval(win, "seg !== null && list !== null && seg.count === 3"):
        break
QTest.qWait(100)
assert h.eval(win, "seg !== null && list !== null"), "the views were built"

# Segmented: the pill finds the current segment once the delegates exist.
assert h.eval(win, "seg.currentItem !== null"), "currentItem follows the delegates created after count"
assert h.eval(win, "seg.currentItem.objectName") == "segB"
assert h.eval(win, "pill().visible") is True
assert abs(h.eval(win, "pill().width - seg.currentItem.width")) < 1
expected = "Math.ceil(Space.xs * 2 + seg.currentItem.implicitWidth + seg.currentItem.parent.children[0].implicitWidth + seg.currentItem.parent.children[2].implicitWidth)"
assert h.eval(win, f"seg.naturalWidth === {expected}"), "naturalWidth counts every segment"

# LiveRepeater: reads follow items as they come and go.
assert h.eval(win, "list.current !== null && list.current.objectName") == "row1"
assert h.eval(win, "list.total") == 30
h.eval(win, "list.model = 1")
QTest.qWait(50)
assert h.eval(win, "list.current") is None and h.eval(win, "list.total") == 10
h.eval(win, "list.model = 2")
QTest.qWait(50)
assert h.eval(win, "list.current.objectName") == "row1" and h.eval(win, "list.total") == 20

# No binding goes back to the plain read (one-line property bindings; the
# multi-line ones in the shell were converted with them).
binding = re.compile(r"^\s*(?:readonly\s+)?property\s+[\w.<>]+\s+\w+\s*:.*\.itemAt\(")
bad = [f"{f.relative_to(REPO)}:{n}"
       for f in (REPO / "modules").rglob("*.qml")
       for n, line in enumerate(f.read_text().splitlines(), 1) if binding.search(line)]
assert not bad, f"bind to LiveRepeater.liveItemAt(), not itemAt(): {bad}"

print("live-repeater: ok")
