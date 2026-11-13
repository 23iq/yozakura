pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.components.kit

// Card picture of the island's shape (notch.style): a close crop of the
// screen's top edge over your wallpaper with the island drawn alone, big:
// "attached" hangs from the edge (only its lower corners round),
// "island" floats just under it, "pill" is a smaller, fully round pill.
MiniScreen {
    id: root

    property var entry
    property var value: "attached"
    readonly property bool attached: root.value === "attached"
    readonly property bool pill: root.value === "pill"
    readonly property real h: Math.round(root.height * (root.pill ? 0.2 : 0.26))
    readonly property real r: root.pill ? root.h / 2 : Math.round(root.h * 0.45)

    Mark {
        id: island
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.round(root.width * (root.pill ? 0.34 : 0.5))
        height: root.h + (root.attached ? root.r : 0)
        // attached: its top corners are above the picture's edge
        y: root.attached ? -root.r : Math.round(root.height * 0.08)
        radius: root.r
        color: Colors.surfaceContainer
        border.width: Space.hairline
        border.color: Qt.alpha(Colors.overBackground, 0.28)

        // a word and a dot: what it shows at rest
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            y: (root.attached ? root.r : 0) + (root.h - height) / 2
            height: Math.round(root.h * 0.3)
            spacing: Math.round(root.h * 0.2)
            Mark {
                width: Math.round(root.h * 1.2)
                height: parent.height * 0.7
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.alpha(Colors.overBackground, 0.7)
            }
            Mark {
                width: parent.height
                height: parent.height
                color: Qt.alpha(Colors.overBackground, 0.7)
            }
        }
    }
}
