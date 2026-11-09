import QtQuick
import qs.modules.theme
import qs.modules.components.kit

// Icon button of the desktop widget types: like the kit IconButton, but
// sized by the widget's scale (`size` in pixels) and drawn in the widget's
// ink (the surface's item colour); round, or the control radius in square
// languages.
Item {
    id: root

    property string icon: ""
    property string label: ""
    property color ink: Colors.overBackground
    property color fill: "transparent"
    property color hoverFill: Qt.rgba(ink.r, ink.g, ink.b, 0.14)
    property real size: 32
    property real iconScale: 0.5

    signal clicked

    implicitWidth: size
    implicitHeight: size
    opacity: enabled ? 1 : 0.35
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: label
    Keys.onSpacePressed: clicked()
    Keys.onReturnPressed: clicked()

    Rectangle {
        anchors.fill: parent
        radius: Look.buttonRadius(height)
        color: area.containsMouse || root.activeFocus ? root.hoverFill : root.fill
        scale: area.pressed ? 0.92 : 1
        Behavior on color {
            enabled: Motion.micro.duration > 0
            ColorAnimation {
                duration: Motion.micro.duration
            }
        }
        Behavior on scale {
            enabled: Motion.spring.duration > 0
            NumberAnimation {
                duration: Motion.spring.duration
                easing.type: Motion.spring.easing
            }
        }
    }

    Icon {
        anchors.centerIn: parent
        icon: Icons[root.icon] ?? root.icon
        size: Math.round(root.size * root.iconScale)
        color: root.ink
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
