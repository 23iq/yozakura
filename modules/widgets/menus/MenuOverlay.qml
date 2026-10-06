pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.modules.globals
import qs.modules.services
import qs.modules.shell
import qs.modules.shell.hosts
import qs.modules.theme
import "MenuStyles.js" as MenuStyles

// Per-screen overlay for the power and tools menus when their style is not
// "notch" (HostRouter host "overlay"): one full-screen layer, one Loader
// per module (kept after first use so delayed tool actions survive the
// close). Radial styles open at the pointer (yozd cursor position; screen
// center when it cannot be read).
PanelWindow {
    id: root

    readonly property var vis: root.screen ? Visibilities.getForScreen(root.screen.name) : null
    readonly property string module: HostRouter.moduleIn(root.vis, "overlay")
    readonly property bool open: root.module !== ""
    property string shownModule: ""
    property bool cursorReady: false
    property point cursor: Qt.point(root.width / 2, root.height / 2)
    readonly property var area: EdgeService.workArea(root.screen)

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: root.open || hideTimer.running
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: Brand.namespace("menu")
    WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onOpenChanged: root.open ? root.begin() : hideTimer.restart()
    Component.onCompleted: {
        if (root.open)
            root.begin();
    }

    function begin() {
        hideTimer.stop();
        root.shownModule = root.module;
        root.cursorReady = !MenuStyles.atCursor(HostRouter.menuStyle(root.module));
        if (!root.cursorReady) {
            cursorProc.running = true;
            cursorFallback.restart();
        }
    }

    function placeAt(p) {
        if (root.cursorReady)
            return;
        if (p)
            root.cursor = Qt.point(p.x, p.y);
        root.cursorReady = true;
    }

    function close() {
        if (root.open)
            Visibilities.setActiveModule("");
    }

    Process {
        id: cursorProc
        command: Brand.daemonArgs(["system", "get-cursor-position"])
        stdout: StdioCollector {
            onStreamFinished: root.placeAt(MenuStyles.parseCursor(text, root.screen))
        }
    }

    Timer {
        id: cursorFallback
        interval: 250
        onTriggered: root.placeAt(null)
    }

    Timer {
        id: hideTimer
        interval: Motion.exit.duration + 20
    }

    FocusGrab {
        windows: [root]
        active: root.open
        onCleared: Qt.callLater(root.close)
    }

    Repeater {
        model: MenuStyles.MODULES

        delegate: Loader {
            id: slot

            required property string modelData
            readonly property string style: HostRouter.menuStyle(modelData)
            readonly property bool current: root.shownModule === modelData
            readonly property bool shown: root.open && current && root.cursorReady

            anchors.fill: parent
            active: false
            visible: current
            source: active ? MenuStyles.fileFor(modelData, style) : ""

            onCurrentChanged: {
                if (current && MenuStyles.fileFor(modelData, style) !== "")
                    active = true;
            }
            function focusItem() {
                const it = slot.item as Item;
                if (it)
                    it.forceActiveFocus();
            }

            onShownChanged: {
                if (shown)
                    Qt.callLater(slot.focusItem);
            }
            onLoaded: {
                item.cursor = Qt.binding(() => root.cursor);
                item.area = Qt.binding(() => root.area);
                item.shown = Qt.binding(() => slot.shown);
                if (slot.shown)
                    Qt.callLater(slot.focusItem);
            }

            // Every style declares `signal closeRequested`
            Connections {
                target: slot.item
                ignoreUnknownSignals: true

                function onCloseRequested() {
                    root.close();
                }
            }
        }
    }
}
