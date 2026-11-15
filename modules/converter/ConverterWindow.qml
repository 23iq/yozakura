import QtQuick
import Quickshell
import qs.modules.globals
import qs.modules.services
import qs.modules.components
import qs.modules.components.kit
import "ConverterModel.js" as Model

// The file converter: a compact floating toplevel (a real window, so files
// can be dragged in from a file manager), opened from the tools menu or
// `<app> run converter` (GlobalStates.converterWindowVisible) and loaded
// by URL from shell.qml only while open. Opening it again while it is open
// raises it (GlobalStates.converterRaiseRequest). A hide that comes with an
// output change (QtWayland unmaps the surface with its output) is not a
// close: the window comes back once the outputs settle, list and all.
FloatingWindow {
    id: root

    // six hero controls wide and tall: scales with the UI spacing (Space)
    implicitWidth: Space.controlXL * 6
    implicitHeight: Space.controlXL * 6
    minimumSize: Qt.size(Space.controlXL * 4, Space.controlXL * 4)
    title: I18n.t("converter.title")
    color: "transparent"
    // parked: hidden for a moment to map it again after an output loss
    visible: GlobalStates.converterWindowVisible && !root._parked

    property bool _parked: false
    // waiting for the outputs to settle before showing it again
    property bool _lost: false
    property real _hiddenAt: 0
    property real _outputsChangedAt: 0

    Connections {
        target: Quickshell
        function onScreensChanged() {
            root._outputsChangedAt = Date.now();
        }
    }

    SettleGate {
        id: outputs
        value: Quickshell.screens
        interval: 400
        onSettledChanged: {
            if (settled && root._lost)
                root._reshow();
        }
    }

    onVisibleChanged: {
        if (root.visible || root._parked || !GlobalStates.converterWindowVisible)
            return;
        // hidden from outside: decide once an output change had time to show
        root._hiddenAt = Date.now();
        hideCheck.restart();
    }

    Timer {
        id: hideCheck
        interval: 500
        onTriggered: {
            if (root.visible || !GlobalStates.converterWindowVisible)
                return;
            if (!Model.outputLoss(root._hiddenAt, root._outputsChangedAt, 1500)) {
                GlobalStates.converterWindowVisible = false;
                return;
            }
            root._lost = true;
            root._parked = true;
            if (outputs.settled)
                root._reshow();
        }
    }

    function _reshow() {
        root._lost = false;
        root._parked = true;
        Qt.callLater(() => root._parked = false);
    }

    // Bring the open window to the current workspace and focus it.
    function raise() {
        const ws = YozdService.focusedMonitor?.activeWorkspace?.id || YozdService.focusedWorkspace?.id || 0;
        const client = (YozdService.clients.values || []).find(c => c.title === root.title);
        if (!client)
            return;
        if (ws && client.workspace?.id !== ws)
            YozdService.moveToWorkspaceSilent(client.address, ws);
        YozdService.focusWindow(client.address);
    }

    Connections {
        target: GlobalStates
        function onConverterRaiseRequestChanged() {
            root.raise();
        }
    }

    Binding {
        target: GlobalStates
        property: "converterWindowActive"
        value: view.Window.active
    }

    Component.onDestruction: GlobalStates.converterWindowActive = false

    ConverterView {
        id: view
        anchors.fill: parent
        focus: true
        onCloseRequested: GlobalStates.converterWindowVisible = false
    }
}
