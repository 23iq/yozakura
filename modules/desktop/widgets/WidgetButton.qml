import QtQuick
import qs.modules.theme
import qs.config

// Round icon button used inside desktop widgets and their edit chrome.
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
        radius: width / 2
        color: area.containsMouse || root.activeFocus ? root.hoverFill : root.fill
        scale: area.pressed ? 0.92 : 1
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
        text: Icons[root.icon] ?? root.icon
        font.family: Icons.font
        font.pixelSize: Math.round(root.size * root.iconScale)
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
