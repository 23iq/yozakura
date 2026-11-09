"""DisplayOverlays: overlay windows wait for the outputs to settle.

The keep/revert prompt and the identify numbers are created only once the
outputs (list and geometry) have held still, only on a screen that is still
there, and the prompt also waits out the moment its apply returns (when the
compositor starts changing outputs). It goes away at once when the session
ends.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402

from PySide6.QtCore import QCoreApplication, QElapsedTimer  # noqa: E402

h = Harness("display-overlays-settle")
h.module("Quickshell", {
    "Quickshell": "pragma Singleton\nQtObject { property var screens: [] }",
    "Scope": "Item {}",
    "ShellScreen": "QtObject { property string name; property int x; property int y; property int width: 1920; property int height: 1080 }",
})
h.singleton("qs.modules.services", "DisplaysService", """QtObject {
    property var session: ({state: "idle", live: true})
    readonly property bool pending: session.state === "pending"
    property var identified: []
}""")
h.copy("modules/components/SettleGate.qml", "qs/modules/components", siblings=False)
h.module("qs.modules.components", {})
overlays = h.copy("modules/shell/DisplayOverlays.qml", siblings=False)
for name in ("DisplayConfirmOverlay", "DisplayIdentifyOverlay"):
    (overlays.parent / f"{name}.qml").write_text("import QtQuick\nItem { property var targetScreen }\n")

root = h.load("""import QtQuick
import Quickshell
import qs.modules.services
Item {
    id: top
    property alias a: a
    property alias b: b
    ShellScreen { id: a; name: "A" }
    ShellScreen { id: b; name: "B"; x: 1920 }
    property var overlay: null
    function make() {
        Quickshell.screens = [a, b];
        overlay = comp.createObject(top, {modelData: b});
    }
    Component { id: comp; DisplayOverlays {} }
    function loaded(i) {
        const ls = [];
        for (const c of overlay.children) if (c.setSource !== undefined) ls.push(c);
        return ls[i].item !== null;
    }
}""", auto_stub=False)


def pump(ms):
    t = QElapsedTimer()
    t.start()
    while t.elapsed() < ms:
        QCoreApplication.processEvents()


def ev(expr):
    return h.eval(root, expr)


ev("make()")
o = ev("overlay")
assert o is not None
# Created in the middle of output churn: nothing until the outputs settle.
ev('DisplaysService.identified = ["B"]')
assert ev("loaded(1)") is False, "identify window created before the outputs settled"
pump(500)
assert ev("loaded(1)") is True, "identify window not created after settling"
ev("DisplaysService.identified = []")
pump(800)
assert ev("loaded(1)") is False

# The prompt waits for the apply moment to settle too, even with stable outputs.
ev('DisplaysService.session = {state: "pending", live: true}')
pump(50)
assert ev("loaded(0)") is False, "prompt created right when the apply returned"
# A mode change on this output restarts the wait.
pump(200)
ev("b.width = 2560")
pump(300)
assert ev("loaded(0)") is False, "prompt created while the output geometry changed"
pump(300)
assert ev("loaded(0)") is True, "prompt never came up"
# Kept/reverted: gone at once.
ev('DisplaysService.session = {state: "kept", live: true}')
assert ev("loaded(0)") is False, "prompt outlived its session"

# Its screen unplugged: nothing is created on it.
ev("Quickshell.screens = [a]")
ev('DisplaysService.identified = ["A"]')
pump(600)
assert ev("loaded(1)") is False, "overlay created on a screen that is gone"

print("display-overlays-settle: ok")
h.exit(0)
