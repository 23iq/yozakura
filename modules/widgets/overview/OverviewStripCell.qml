pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.globals
import qs.modules.theme
import qs.modules.components
import qs.modules.components.kit
import qs.modules.services
import qs.config
import qs.modules.desktop.panorama

// One workspace frame of the overview filmstrip: wallpaper, number, click and
// drop target. Windows are drawn above it by OverviewStrip (OverviewWindow).
Item {
    id: root

    readonly property var motion: Motion
    property int workspaceId: 1
    property real emphasis: 1
    property bool selected: false
    property bool dropHover: false
    // Scroll style: this workspace's frame of the panorama wallpaper.
    property string panoramaSource: ""
    property int slotCount: 1
    property real screenW: 1920
    property real screenH: 1080

    signal picked
    signal opened
    signal dragEntered
    signal dragExited

    opacity: emphasis

    Behavior on opacity {
        enabled: root.motion.morph.duration > 0
        NumberAnimation {
            duration: root.motion.morph.duration
            easing.type: root.motion.morph.easing
        }
    }

    Loader {
        anchors.fill: parent
        active: root.panoramaSource !== ""
        sourceComponent: slice
    }

    Component {
        id: slice
        PanoramaSlice {
            sourceFile: root.panoramaSource
            slotIndex: root.workspaceId - 1
            slotCount: root.slotCount
            screenW: root.screenW
            screenH: root.screenH
        }
    }

    TintedWallpaper {
        id: wallpaper
        anchors.fill: parent
        visible: root.panoramaSource === ""
        radius: Look.radius("box")
        tintEnabled: GlobalStates.wallpaperManager ? GlobalStates.wallpaperManager.tintEnabled : false
        source: {
            if (!GlobalStates.wallpaperManager || root.panoramaSource !== "")
                return "";
            const path = GlobalStates.wallpaperManager.getLockscreenFramePath(GlobalStates.wallpaperManager.currentWallpaper);
            return path ? "file://" + path : "";
        }
    }

    WorkspaceRing {
        id: ring
        anchors.fill: parent
        active: root.selected
        target: root.dropHover

        Behavior on border.width {
            enabled: root.motion.enter.duration > 0
            NumberAnimation {
                duration: root.motion.enter.duration
                easing.type: root.motion.enter.easing
            }
        }
    }

    KitText {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: Space.s
        z: 100000
        role: "secondary"
        tabular: true
        text: root.workspaceId
        font.weight: root.selected ? Font.Bold : Font.Medium
        color: root.selected ? Type.accent : Type.secondary
    }

    // `picked` waits out the double-click interval, so a double click is one
    // `opened` and never a pick first (a second `workspace N` on the now
    // focused N would toggle back with workspace_back_and_forth).
    Timer {
        id: pickTimer
        interval: Qt.styleHints.mouseDoubleClickInterval
        onTriggered: root.picked()
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onClicked: pickTimer.restart()
        onDoubleClicked: {
            pickTimer.stop();
            root.opened();
        }
    }

    DropArea {
        anchors.fill: parent
        onEntered: root.dragEntered()
        onExited: root.dragExited()
    }
}
