import QtQuick
import qs.modules.theme
import qs.config

// Round transport button for the lock screen media cards.
Item {
    id: root

    property string icon: ""
    // Filled buttons (play/pause) use the accent; others are glyphs.
    property bool filled: false
    property color glyphColor: Colors.secondaryFixed
    property color accent: Colors.primaryFixedDim
    property color overAccent: Colors.overPrimaryFixed
    // Corner radius as a share of the size (0.5 = circle).
    property real roundness: 0.5
    signal clicked

    implicitWidth: filled ? 34 : 30
    implicitHeight: implicitWidth
    opacity: enabled ? 1 : 0.35

    Rectangle {
        anchors.fill: parent
        radius: width * root.roundness
        color: root.filled ? root.accent : Qt.rgba(root.glyphColor.r, root.glyphColor.g, root.glyphColor.b, mouse.containsMouse ? 0.14 : 0)
        scale: mouse.pressed ? 0.9 : 1

        Behavior on color {
            enabled: Config.animDuration > 0
            ColorAnimation {
                duration: Motion.exit.duration
            }
        }
        Behavior on scale {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Motion.exit.duration
                easing.type: Motion.morph.easing
            }
        }
    }

    Text {
        anchors.centerIn: parent
        text: root.icon
        font.family: Icons.font
        font.pixelSize: root.filled ? 16 : 17
        color: root.filled ? root.overAccent : root.glyphColor
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
