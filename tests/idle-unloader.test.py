"""IdleUnloader: fires unload() once idle for `delay`, never while in use or disabled."""
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402
from PySide6.QtCore import QCoreApplication, QElapsedTimer  # noqa: E402

h = Harness("idle-unloader")
h.copy("modules/components/IdleUnloader.qml", siblings=False)
root = h.load(
    """Item {
        id: top
        property int fired: 0
        property alias u: u
        IdleUnloader { id: u; delay: 60; onUnload: top.fired++ }
    }"""
)


def pump(ms):
    t = QElapsedTimer()
    t.start()
    while t.elapsed() < ms:
        QCoreApplication.processEvents()
        time.sleep(0.001)


def fired():
    return root.property("fired")


def set_u(prop, value):
    h.eval(root, f"u.{prop} = {str(value).lower()}")


pump(120)
assert fired() == 0, "not idle: must not fire"

set_u("idle", True)
pump(30)
assert fired() == 0, "fired before the delay"
set_u("idle", False)
pump(100)
assert fired() == 0, "use before the delay cancels it"

set_u("idle", True)
pump(150)
assert fired() == 1, "fires once after the delay"

set_u("idle", False)
set_u("active", False)
set_u("idle", True)
pump(150)
assert fired() == 1, "disabled: never fires"

set_u("active", True)
pump(150)
assert fired() == 2, "re-enabled while idle fires"
print("ok")
