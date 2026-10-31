import QtQuick
import qs.modules.theme
import qs.modules.components.kit

// Transport button of the lock screen media cards: the kit IconButton's
// sizes, glyph and motion, drawn in the lock style's palette (the kit
// button follows the shell theme, the lock keeps its fixed tone).
Item {
    id: root

    property string icon: ""
    // Filled buttons (play/pause) use the accent; others are glyphs.
    property bool filled: false
    property color glyphColor: Colors.secondaryFixed
    property color accent: Colors.primaryFixedDim
    property color overAccent: Colors.overPrimaryFixed
    // Corner radius as a share of the size (0.5 = round, the kit's icon button).
    property real roundness: 0.5
    signal clicked

    implicitWidth: filled ? Space.controlS : Space.chip
    implicitHeight: implicitWidth
    opacity: enabled ? 1 : 0.35

    Rectangle {
        anchors.fill: parent
        radius: Space.round(width) > 0 ? width * root.roundness : 0
        color: root.filled ? root.accent : Qt.rgba(root.glyphColor.r, root.glyphColor.g, root.glyphColor.b, mouse.containsMouse ? 0.14 : 0)
        scale: mouse.pressed ? 0.9 : 1

        Behavior on color {
            enabled: Motion.micro.duration > 0
            ColorAnimation {
                duration: Motion.micro.duration
                easing.type: Motion.micro.easing
            }
        }
        Behavior on scale {
            enabled: Motion.spring.duration > 0
            NumberAnimation {
                duration: Motion.spring.duration
                easing.type: Motion.spring.easing
                easing.overshoot: Motion.spring.overshoot
            }
        }
    }

    Text {
        anchors.centerIn: parent
        text: root.icon
        font.family: Icons.font
        font.pixelSize: Math.min(Type.iconSize("body"), Math.round(root.width * 0.55))
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
