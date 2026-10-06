import QtQuick
import qs.modules.globals
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config

// One workspace frame of the overview filmstrip: wallpaper, number, click and
// drop target. Windows are drawn above it by OverviewStrip (OverviewWindow).
Item {
    id: root

    readonly property var motion: Motion
    property int workspaceId: 1
    property real emphasis: 1
    property bool selected: false
    property bool dropHover: false
    property color ringColor: Styling.srItem("overprimary")

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

    TintedWallpaper {
        id: wallpaper
        anchors.fill: parent
        radius: Styling.radius(2)
        tintEnabled: GlobalStates.wallpaperManager ? GlobalStates.wallpaperManager.tintEnabled : false
        source: {
            if (!GlobalStates.wallpaperManager)
                return "";
            const path = GlobalStates.wallpaperManager.getLockscreenFramePath(GlobalStates.wallpaperManager.currentWallpaper);
            return path ? "file://" + path : "";
        }
    }

    Rectangle {
        id: ring
        anchors.fill: parent
        radius: Styling.radius(2)
        color: "transparent"
        border.width: root.selected || root.dropHover ? 2 : 0
        border.color: root.selected ? root.ringColor : Colors.outline

        Behavior on border.width {
            enabled: root.motion.enter.duration > 0
            NumberAnimation {
                duration: root.motion.enter.duration
                easing.type: root.motion.enter.easing
            }
        }
    }

    Text {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 8
        z: 100000
        text: root.workspaceId
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-1)
        font.weight: root.selected ? Font.Bold : Font.Medium
        color: root.selected ? root.ringColor : Colors.overSurfaceVariant
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onClicked: root.picked()
        onDoubleClicked: root.opened()
    }

    DropArea {
        anchors.fill: parent
        onEntered: root.dragEntered()
        onExited: root.dragExited()
    }
}
