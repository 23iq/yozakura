import QtQuick
import qs.modules.theme
import qs.modules.components.kit

// Round selection check of a catalog card: an outlined ring that pops into
// a filled accent disc (selected) with a check mark.
Item {
    id: root

    property bool checked: false
    property bool hovered: false
    signal toggled

    implicitWidth: Space.chip - Space.xs
    implicitHeight: Space.chip - Space.xs
    activeFocusOnTab: true
    Accessible.role: Accessible.CheckBox
    Accessible.checked: root.checked
    Keys.onSpacePressed: root.toggled()
    Keys.onReturnPressed: root.toggled()

    Rectangle {
        anchors.fill: parent
        radius: Look.radius("round", height)
        color: root.checked ? Type.accent : (root.hovered ? Look.alpha("primary", 0.12) : "transparent")
        border.width: root.checked ? 0 : Space.stroke - 1
        border.color: root.hovered ? Type.secondary : Type.muted
        scale: root.checked ? 1 : 0.92

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
                easing.overshoot: 3
            }
        }

        Icon {
            anchors.centerIn: parent
            icon: Icons.check
            tone: "accentInk"
            scale: root.checked ? 1 : 0
            Behavior on scale {
                enabled: Motion.spring.duration > 0
                NumberAnimation {
                    duration: Motion.spring.duration
                    easing.type: Motion.spring.easing
                }
            }
        }
    }

    FocusRing {
        shown: root.activeFocus
        radius: Look.radius("round", root.height + Space.stroke * 2)
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -Space.s
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
