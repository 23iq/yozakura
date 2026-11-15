pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.components.kit

// Card picture of how the Assistant's messages look
// (ai.appearance.messageStyle): bubbles (yours on the right, filled) or
// flat text, one message under the other.
ThumbGround {
    id: root

    property var entry
    property var value: "bubble"
    readonly property bool bubbles: root.value !== "flat"
    readonly property real u: Math.min(width, height) / 10

    Column {
        x: Math.round(root.u * 0.9)
        y: Math.round(root.u * 0.9)
        width: root.width - x * 2
        spacing: Math.round(root.u * 0.7)

        // yours
        Mark {
            anchors.right: root.bubbles ? parent.right : undefined
            width: root.bubbles ? parent.width * 0.62 : parent.width
            height: Math.round(root.u * 1.9)
            radius: Math.round(root.u * 0.7)
            color: root.bubbles ? Qt.alpha(Type.accent, 0.35) : "transparent"
            Mark {
                x: root.bubbles ? Math.round(root.u * 0.6) : 0
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width * (root.bubbles ? 0.7 : 0.5)
                height: Math.max(2, Math.round(root.u * 0.4))
                color: Qt.alpha(Type.text, root.bubbles ? 0.75 : 0.9)
            }
        }
        // the answer
        Mark {
            width: root.bubbles ? parent.width * 0.82 : parent.width
            height: Math.round(root.u * 3.1)
            radius: Math.round(root.u * 0.7)
            color: root.bubbles ? Qt.alpha(Type.text, 0.12) : "transparent"
            Column {
                x: root.bubbles ? Math.round(root.u * 0.6) : 0
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(root.u * 0.45)
                Repeater {
                    model: [0.8, 0.62]
                    delegate: Mark {
                        required property real modelData
                        width: (root.width - root.u * 3) * modelData
                        height: Math.max(2, Math.round(root.u * 0.4))
                        color: Qt.alpha(Type.text, 0.45)
                    }
                }
            }
        }
    }
}
