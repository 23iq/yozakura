import QtQuick
import qs.modules.theme
import qs.config
import "ExtrasUi.js" as Ui

// Round selection check of a catalog card: an outlined ring that pops into
// a filled accent disc with a check mark.
Item {
    id: root

    property bool checked: false
    property bool hovered: false
    signal toggled

    implicitWidth: 26
    implicitHeight: 26
    activeFocusOnTab: true
    Accessible.role: Accessible.CheckBox
    Accessible.checked: root.checked
    Keys.onSpacePressed: root.toggled()
    Keys.onReturnPressed: root.toggled()

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: root.checked ? Colors.primary : (root.hovered ? Ui.alpha(Colors.primary, 0.12) : "transparent")
        border.width: root.checked ? 0 : (root.activeFocus ? 2 : 1.5)
        border.color: root.activeFocus ? Colors.primary : Ui.alpha(Colors.outline, root.hovered ? 0.9 : 0.6)
        scale: root.checked ? 1 : 0.92

        Behavior on color {
            enabled: Config.animDuration > 0
            ColorAnimation {
                duration: Config.animDuration / 2
            }
        }
        Behavior on scale {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutBack
                easing.overshoot: 3
            }
        }

        Text {
            anchors.centerIn: parent
            text: Icons.check
            font.family: Icons.font
            font.pixelSize: Styling.fontSize(0)
            color: Colors.overPrimary
            scale: root.checked ? 1 : 0
            Behavior on scale {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration
                    easing.type: Easing.OutBack
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -6
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
