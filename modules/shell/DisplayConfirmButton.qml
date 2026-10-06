import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.config
import "../settings/Ui.js" as Ui

// Large action button of the display confirm card, with a key cap hint.
// `primary` is the filled, default-focused choice.
Item {
    id: root

    property string text: ""
    property string keyHint: ""
    property string icon: ""
    property bool primary: false
    signal clicked

    implicitWidth: row.implicitWidth + 48
    implicitHeight: 52
    activeFocusOnTab: true

    Keys.onReturnPressed: root.clicked()
    Keys.onEnterPressed: root.clicked()
    Keys.onSpacePressed: root.clicked()

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.primary ? (area.containsMouse ? Ui.mix(Colors.primary, Colors.overPrimary, 0.12) : Colors.primary) : Ui.alpha(Colors.overBackground, area.containsMouse ? 0.14 : 0.08)
        border.width: root.activeFocus ? 3 : 1
        border.color: root.activeFocus ? (root.primary ? Ui.alpha(Colors.overPrimary, 0.55) : Colors.primary) : Ui.alpha(Colors.outline, 0.35)
        Behavior on color {
            enabled: Config.animDuration > 0
            ColorAnimation {
                duration: Config.animDuration / 2
            }
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 10

        Text {
            visible: root.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: Icons[root.icon] ?? ""
            font.family: Icons.font
            font.pixelSize: Styling.fontSize(2)
            color: root.primary ? Colors.overPrimary : Colors.overBackground
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(1)
            font.weight: Font.Bold
            color: root.primary ? Colors.overPrimary : Colors.overBackground
        }
        Rectangle {
            visible: root.keyHint !== ""
            anchors.verticalCenter: parent.verticalCenter
            width: hint.implicitWidth + 14
            height: 22
            radius: Math.min(Styling.radius(-2), 8)
            color: "transparent"
            border.width: 1
            border.color: Ui.alpha(root.primary ? Colors.overPrimary : Colors.overBackground, 0.45)
            Text {
                id: hint
                anchors.centerIn: parent
                text: root.keyHint
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
                color: Ui.alpha(root.primary ? Colors.overPrimary : Colors.overBackground, 0.8)
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
