pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.components.kit
import qs.modules.settings.previews

// Card picture of how voice input starts (voice.activation): a keycap over
// a time line. Hold to talk: the key stays down while the waveform runs.
// Toggle: a tap starts it, a tap (or a pause) ends it.
ScreenBackdrop {
    id: root

    property var entry
    property var value: "push-to-talk"
    readonly property bool hold: root.value !== "toggle"
    readonly property real u: Math.min(width, height) / 10

    // the key
    Mark {
        id: key
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(root.u * 1.4)
        width: Math.round(root.u * 3)
        height: width
        radius: Math.round(root.u * 0.6)
        color: Colors.surfaceContainerHighest
        border.width: Space.hairline
        border.color: Qt.alpha(Colors.outlineVariant, 0.8)
        KitText {
            anchors.centerIn: parent
            role: "title"
            font.pixelSize: Math.round(root.u * 1.3)
            text: "M"
        }
        Icon {
            anchors.left: parent.right
            anchors.leftMargin: Math.round(root.u * 0.3)
            anchors.top: parent.top
            icon: root.hold ? Icons.hand : Icons.mouseLeftClick
            size: Math.round(root.u * 1.2)
            tone: "accent"
        }
    }

    // the time line: the key's presses under the waveform
    Item {
        id: line
        x: Math.round(root.u * 1.2)
        width: root.width - root.u * 2.4
        y: key.y + key.height + root.u * 1.1
        height: Math.round(root.u * 2.2)

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            height: Math.round(root.u * 1.3)
            spacing: Math.max(1, Math.round(root.u * 0.18))
            Repeater {
                model: 14
                delegate: Mark {
                    required property int index
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(2, Math.round(root.u * 0.22))
                    height: Math.max(width, Math.round(root.u * 1.3 * (0.3 + 0.7 * Math.abs(Math.sin(index * 1.3 + 0.4)))))
                    color: Type.accent
                }
            }
        }
        // held: one long press under it all
        Mark {
            visible: root.hold
            anchors.bottom: parent.bottom
            width: parent.width
            height: Math.max(3, Math.round(root.u * 0.35))
            color: Qt.alpha(Type.text, 0.8)
        }
        // toggle: two taps, at the start and the end
        Repeater {
            model: root.hold ? [] : [0, 1]
            delegate: Mark {
                required property int modelData
                anchors.bottom: parent.bottom
                x: modelData === 0 ? 0 : line.width - width
                width: Math.max(4, Math.round(root.u * 0.7))
                height: Math.max(3, Math.round(root.u * 0.35))
                color: Qt.alpha(Type.text, 0.8)
            }
        }
    }
}
