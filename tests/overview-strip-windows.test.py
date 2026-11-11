"""The strip's window layer: it resolves its theme motion binding, and a
preview lives as long as its window (OverviewWindowRows): the compositor
pushes the whole window list on every event, which must update the previews
in place, not rebuild them (a rebuilt preview loses a click in progress)."""
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
h.stub("OverviewWindow", dest="qs/modules/widgets/overview", body="""Item {
    objectName: "preview"
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
# (OverviewWindowRows brings the kit's KeyedSync.js along by its relative import)
OVERVIEW = "qs/modules/widgets/overview"
h.copy("modules/widgets/overview/OverviewWindowRows.qml", OVERVIEW, siblings=False)
h.copy("modules/widgets/overview/OverviewStripWindows.qml", OVERVIEW, siblings=False)
h.module("qs.modules.widgets.overview", {})
root = h.load("""import QtQuick
import qs.modules.widgets.overview
Item {
    width: 800; height: 300
    property int monitorId: 0
    property var windowList: []
    property real previewScale: 0.15; property real workspaceImplicitWidth: 288; property real workspaceImplicitHeight: 162
    property var monitorData: null; property string barPosition: "top"; property int barReserved: 0
    property real cellW: 296; property real workspaceSpacing: 8; property real workspacePadding: 8
    property int selected: 1; property int draggingFromWorkspace: -1
    function isWindowMatched(address) { return false }
    function isWindowSelected(address) { return false }
    OverviewStripWindows { objectName: "windows"; strip: parent }
    function win(address, title) {
        return { address: address, title: title, class: "app", monitor: 0, workspace: { id: 1 } };
    }
    function previews() {
        const out = [];
        const items = children[0].children;
        for (let i = 0; i < items.length; i++) {
            if (items[i].objectName === "preview")
                out.push(items[i]);
        }
        return out;
    }
    // "address=title" of every preview, in order
    function shown() { return previews().map(p => p.windowData.address + "=" + p.windowData.title).join(" ") }
    property var kept: null
}""")
windows = h.find(root, "windows")
assert h.eval(windows, "motion !== undefined && motion !== null"), "strip window layer must resolve Motion"
assert h.eval(windows, "motion.morph.duration") == 200


def ev(expr):
    return h.eval(root, expr)


ev('windowList = [win("0xa", "Terminal"), win("0xb", "Browser")]')
assert ev("shown()") == "0xa=Terminal 0xb=Browser", ev("shown()")
ev("kept = previews()")
# The list is pushed again with one title changed: the same previews, new data.
ev('windowList = [win("0xa", "Terminal"), win("0xb", "Browser - loading")]')
assert ev("shown()") == "0xa=Terminal 0xb=Browser - loading", ev("shown()")
assert ev("previews()[0] === kept[0] && previews()[1] === kept[1]"), "a title change rebuilt the previews"
# A new window gets a preview, the others keep theirs.
ev('windowList = [win("0xc", "Editor"), win("0xa", "Terminal"), win("0xb", "Browser")]')
assert ev("shown()") == "0xc=Editor 0xa=Terminal 0xb=Browser", ev("shown()")
assert ev("previews()[1] === kept[0] && previews()[2] === kept[1]"), "a new window rebuilt the other previews"
# A closed window takes only its own preview with it.
ev('windowList = [win("0xc", "Editor"), win("0xb", "Browser")]')
assert ev("shown()") == "0xc=Editor 0xb=Browser", ev("shown()")
assert ev("previews()[1] === kept[1]"), "a closed window rebuilt the other previews"
# A window on another monitor has no preview here.
ev('windowList = [win("0xb", "Browser"), Object.assign(win("0xd", "Far"), { monitor: 1 })]')
assert ev("shown()") == "0xb=Browser", ev("shown()")
print("overview-strip-windows: ok")
h.exit(0)
