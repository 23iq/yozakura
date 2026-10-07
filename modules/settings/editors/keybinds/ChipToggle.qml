import QtQuick
import qs.modules.theme
import qs.config
import "../../Ui.js" as Ui

// Toggle chip (modifiers while recording, layout restrictions).
Item {
    id: root

    property string text: ""
    property bool checked: false
    signal toggled(bool value)

    implicitWidth: label.implicitWidth + 24
    implicitHeight: label.implicitHeight + 12
    activeFocusOnTab: true
    Keys.onSpacePressed: toggled(!checked)
    Keys.onReturnPressed: toggled(!checked)

    Accessible.role: Accessible.CheckBox
    Accessible.checked: checked
    Accessible.name: text

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Colors.primary : Ui.alpha(Colors.overBackground, area.containsMouse ? 0.1 : 0.05)
        border.width: root.activeFocus ? 2 : (root.checked ? 0 : 1)
        border.color: root.activeFocus ? Colors.primary : Ui.alpha(Colors.outline, 0.4)
        Behavior on color {
            enabled: Config.animDuration > 0
            ColorAnimation {
                duration: Motion.exit.duration
            }
        }
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-2)
        font.weight: Font.DemiBold
        color: root.checked ? Colors.overPrimary : Colors.overBackground
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
