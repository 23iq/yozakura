"""Load the actual strip window layer and resolve its theme motion binding."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402

h = Harness("overview-strip-windows")
h.singleton("qs.modules.theme", "Motion", """QtObject {
    property QtObject morph: QtObject { property int duration: 200; property int easing: 1 }
}""")
h.singleton("Quickshell.Wayland", "ToplevelManager", """QtObject {
    property QtObject toplevels: QtObject { property var values: [] }
}""")
# No windows are needed to check the actual file's import and motion binding.
h.stub("OverviewWindow", """Item {
    property var windowData; property var toplevel
    property real availableWorkspaceWidth; property real availableWorkspaceHeight
    property var monitorData; property string barPosition; property int barReserved
    property bool isSearchMatch; property bool isSearchSelected
    property int xOffset; property int yOffset
    signal dragStarted; signal dragFinished(int targetWorkspace)
    signal windowClicked; signal windowClosed
}""")
h.singleton("qs.config", "Config", "QtObject {}")
h.singleton("qs.modules.globals", "GlobalStates", "QtObject {}")
h.singleton("qs.modules.services", "YozdService", "QtObject {}")
h.copy("modules/widgets/overview/OverviewStripWindows.qml", siblings=False)
root = h.load("""import QtQuick
Item {
    width: 800; height: 300
    property int monitorId: 0
    property var windowList: []
    OverviewStripWindows { objectName: "windows"; strip: parent }
}""")
windows = h.find(root, "windows")
assert h.eval(windows, "motion !== undefined && motion !== null"), "strip window layer must resolve Motion"
assert h.eval(windows, "motion.morph.duration") == 200
print("overview-strip-windows: ok")
h.exit(0)
