"""Only one PomodoroSync registers the `pomodoro` IPC target.

Every bar clock has a PomodoroSync (one per screen and bar layout); each
used to register the target, and Quickshell warned for every one after the
first. Now only the owner's IpcHandler is enabled (a disabled IpcHandler
does not register), the next one takes over when the owner goes away, and
the owner's handler still answers `check` and `stop` as before.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402

h = Harness("pomodoro-ipc-owner")
h.module("Quickshell.Io", {"IpcHandler": "QtObject { property string target; property bool enabled: true }"})
h.singleton(
    "qs.modules.services",
    "TimersService",
    """QtObject {
        property var pomodoro: ({ id: "p1", state: "running", pomodoro: { phase: "work" } })
        property var cancelled: []
        function cancel(id) { cancelled = cancelled.concat([id]); }
    }""",
)
h.singleton("qs.modules.services", "MprisController", "QtObject { property var filteredPlayers: [] }")
h.singleton(
    "qs.config",
    "Config",
    "QtObject { property QtObject system: QtObject { property QtObject pomodoro: QtObject { property bool syncSpotify: false } } }",
)
h.copy("modules/bar/clock/PomodoroSync.qml", siblings=False)

root = h.load("""
import QtQuick
import qs.modules.services
Item {
    id: top
    property bool showSecond: true
    PomodoroSync { objectName: "a"; property int asked: 0; onRequestPanel: asked++ }
    Loader {
        active: top.showSecond
        sourceComponent: PomodoroSync { objectName: "b"; property int asked: 0; onRequestPanel: asked++ }
    }
    PomodoroSync { objectName: "c"; property int asked: 0; onRequestPanel: asked++ }
}
""")

syncs = {name: h.find(root, name) for name in ("a", "b", "c")}


def owners():
    return [name for name, o in syncs.items() if h.eval(o, "ipc.enabled")]


assert len(owners()) == 1, f"exactly one PomodoroSync registers, got {owners()}"
owner = syncs[owners()[0]]
assert h.eval(owner, "ipc.target") == "pomodoro"

# the owner's handler does what `qs ipc call pomodoro ...` did
h.eval(owner, "ipc.check()")
assert h.eval(owner, "asked") == 1, "check opens the clock panel"
h.eval(owner, "ipc.stop()")
assert h.eval(root, "JSON.stringify(TimersService.cancelled)") == '["p1"]', "stop cancels the running pomodoro"

# the owner going away hands the target over to exactly one of the others
from PySide6.QtCore import QCoreApplication, QEvent  # noqa: E402

name = owners()[0]
if name == "b":
    h.eval(root, "showSecond = false")
else:
    syncs[name].deleteLater()
    QCoreApplication.sendPostedEvents(None, QEvent.Type.DeferredDelete)
QCoreApplication.processEvents()
del syncs[name]
assert len(owners()) == 1, f"one of the others takes the target over, got {owners()}"
print("pomodoro-ipc-owner: PASS")
