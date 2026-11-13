pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.components.kit

// Card picture of a dock style (dock.theme): a close crop of the screen's
// foot over your wallpaper with the dock drawn alone, big: "default"
// stands on the edge with rounded shoulders, "floating" hovers above it as
// a pill, "integrated" sits inside a bar across the edge.
MiniScreen {
    id: root

    property var entry
    property var value: "default"
    // the screen's foot sits above the card's title (ChoiceCard inset)
    readonly property real foot: Math.round(root.height * 0.66)
    readonly property real icon: Math.round(root.height * 0.17)
    readonly property real pad: Math.round(root.icon * 0.35)
    readonly property real dockW: root.icon * 4 + root.pad * 5
    readonly property real dockH: root.icon + root.pad * 2

    // integrated: the bar across the foot, the apps inside it
    Mark {
        visible: root.value === "integrated"
        width: parent.width
        height: root.dockH
        y: root.foot - height
        radius: 0
        color: Colors.surfaceContainer
        border.width: Space.hairline
        border.color: Qt.alpha(Colors.overBackground, 0.28)
        Row {
            x: root.pad
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.pad
            Repeater {
                model: 2
                delegate: Mark {
                    width: root.icon * 0.7
                    height: root.icon * 0.3
                    color: Qt.alpha(Colors.overBackground, 0.6)
                }
            }
        }
    }

    Mark {
        id: dock
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.dockW
        height: root.dockH
        // default: on the edge, its foot cut by the picture (rounded top only)
        y: root.value === "floating" ? root.foot - height - root.pad * 1.6 : (root.value === "integrated" ? root.foot - height : root.foot - height + radius)
        radius: root.value === "integrated" ? 0 : Look.radius("box", height)
        // default: on the edge, only its top corners round (a strip of the
        // card under the screen's foot hides the bottom ones)
        color: root.value === "integrated" ? "transparent" : Colors.surfaceContainerHigh
        border.width: root.value === "integrated" ? 0 : Space.hairline
        border.color: Qt.alpha(Colors.overBackground, 0.28)

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.pad
            spacing: root.pad
            Repeater {
                model: 4
                delegate: Mark {
                    required property int index
                    width: root.icon
                    height: root.icon
                    radius: Look.radius("small", height)
                    color: Qt.alpha(Colors.overBackground, index === 0 ? 0.9 : 0.6)
                }
            }
        }
    }

    // under the screen's foot: the ground the title stands on
    Mark {
        y: root.foot
        width: parent.width
        height: parent.height - root.foot
        radius: 0
        color: Colors.surfaceContainerLow
    }
}
