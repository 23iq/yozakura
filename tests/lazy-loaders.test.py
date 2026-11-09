"""WarmLoader and KeepAliveLoader (modules/components): items are incubated
asynchronously, a request made while loading is answered once ready (and can
be cancelled), and a kept-alive item survives closing for `keepFor` ms."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402
from PySide6.QtCore import QElapsedTimer, QTimer  # noqa: E402
from PySide6.QtQml import QQmlIncubationController  # noqa: E402

h = Harness("lazy-loaders")
h.copy("modules/components/WarmLoader.qml", "qs/modules/components")
h.copy("modules/components/KeepAliveLoader.qml", "qs/modules/components")
h.module("qs.modules.components", {})

root = h.load("""import QtQuick
import qs.modules.components
Item {
    property var got: []
    property int created: 0
    property Component heavy: Component {
        Item {
            Component.onCompleted: created++
            Repeater { model: 200; Item {} }
        }
    }
    WarmLoader { objectName: "warm"; sourceComponent: heavy }
    KeepAliveLoader { objectName: "keep"; keepFor: 150; sourceComponent: heavy }
}""", auto_stub=False)


# The shell's engine (quickshell) incubates frame by frame; the bare test
# engine would incubate synchronously without a controller.
class Incubator(QQmlIncubationController):
    def __init__(self):
        super().__init__()
        self.timer = QTimer()
        self.timer.setInterval(5)
        self.timer.timeout.connect(lambda: self.incubateFor(1))
        self.timer.start()


incubator = Incubator()
h.engine.setIncubationController(incubator)


def pump(ms):
    t = QElapsedTimer()
    t.start()
    while t.elapsed() < ms:
        h.app.processEvents()


def ev(obj, expr):
    return h.eval(obj, expr)


warm = h.find(root, "warm")
keep = h.find(root, "keep")

# WarmLoader: nothing until asked; a request while loading is answered later.
assert not ev(warm, "active") and ev(root, "created") == 0
ev(warm, "request(i => got = got.concat(['first']))")
assert ev(warm, "pending") and not ev(warm, "ready"), "loaded synchronously"
assert ev(root, "got.length") == 0
pump(200)
assert ev(warm, "ready") and ev(root, "got.join()") == "first"
# Ready: answered at once
ev(warm, "request(i => got = got.concat(['second']))")
assert ev(root, "got.join()") == "first,second"
assert ev(root, "created") == 1

# A cancelled request is never answered.
h.eval(root, "got = []")
keep2 = h.eval(root, "Qt.createQmlObject('import qs.modules.components; WarmLoader {}', this)")
h.eval(keep2, "sourceComponent = parent.heavy")
ev(keep2, "request(i => parent.got = ['late'])")
ev(keep2, "cancel()")
pump(200)
assert ev(keep2, "ready") and ev(root, "got.length") == 0, "cancelled request answered"
# warm(): loads without anyone waiting
keep3 = h.eval(root, "Qt.createQmlObject('import qs.modules.components; WarmLoader {}', this)")
h.eval(keep3, "sourceComponent = parent.heavy")
ev(keep3, "warm()")
pump(200)
assert ev(keep3, "ready")

# KeepAliveLoader: loads asynchronously when wanted, survives closing for
# keepFor, then is released; reopening inside the window reuses the item.
assert not ev(keep, "active")
h.eval(keep, "wanted = true")
assert ev(keep, "active") and ev(keep, "status") != 1, "keep-alive loaded synchronously"
pump(200)
assert ev(keep, "status") == 1
first = ev(keep, "item")
h.eval(keep, "wanted = false")
assert ev(keep, "kept") and ev(keep, "item") == first
pump(60)
h.eval(keep, "wanted = true")
assert ev(keep, "item") == first and not ev(keep, "kept"), "reopen did not reuse the item"
h.eval(keep, "wanted = false")
pump(300)
assert not ev(keep, "active") and ev(keep, "item") is None, "not released after keepFor"
# keepFor 0: released as soon as it closes
h.eval(keep, "keepFor = 0; wanted = true")
pump(200)
assert ev(keep, "status") == 1
h.eval(keep, "wanted = false")
assert not ev(keep, "active"), "keepFor 0 kept the item"
# Not allowed (e.g. resuming from suspend): not loaded even when wanted
h.eval(keep, "keepFor = 1000; allowed = false; wanted = true")
assert not ev(keep, "active")
h.eval(keep, "allowed = true")
assert ev(keep, "active")

print("lazy loaders: ok")
h.exit(0)
