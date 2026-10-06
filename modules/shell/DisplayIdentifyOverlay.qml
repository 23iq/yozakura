import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules.services
import qs.modules.globals

// Shows the identify number on one screen for as long as
// DisplaysService.identified names it: a small centred, click-through window.
PanelWindow {
    id: root

    property ShellScreen targetScreen
    property bool shown: false
    // Kept while fading out
    property var lastEntry: null
    readonly property var entry: (DisplaysService.identified || []).find(e => e.name === (root.targetScreen ? root.targetScreen.name : "")) ?? null

    screen: targetScreen
    visible: entry !== null || card.opacity > 0
    implicitWidth: 360
    implicitHeight: 360
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: Brand.namespace("displays-identify")
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}

    onEntryChanged: {
        if (entry !== null)
            lastEntry = entry;
        root.shown = entry !== null;
    }
    Component.onCompleted: Qt.callLater(() => {
        root.lastEntry = root.entry;
        root.shown = root.entry !== null;
    })

    DisplayIdentifyCard {
        id: card
        anchors.centerIn: parent
        entry: root.lastEntry
        shown: root.shown
    }
}
