import QtQuick
import qs.modules.theme
import qs.config
import "../../Ui.js" as Ui

// Small "+ text" action link (add a key, an action, a bind).
Item {
    id: root

    property string text: ""
    property string icon: "plus"
    signal clicked

    implicitWidth: row.implicitWidth + 16
    implicitHeight: row.implicitHeight + 10
    activeFocusOnTab: true
    Keys.onReturnPressed: clicked()
    Keys.onSpacePressed: clicked()

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Ui.alpha(Colors.primary, area.containsMouse ? 0.14 : 0)
        border.width: root.activeFocus ? 2 : 0
        border.color: Colors.primary
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Icons[root.icon] ?? ""
            font.family: Icons.font
            font.pixelSize: Styling.fontSize(-2)
            color: Colors.primary
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            font.weight: Font.DemiBold
            color: Colors.primary
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
