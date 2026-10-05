import QtQuick
import QtQuick.Layouts
import qs.config
import qs.modules.theme
import qs.modules.components

// One action row of a bar module popup: icon, label, optional shortcut hint.
StyledRect {
    id: row

    property string icon: ""
    property string label: ""
    property string hint: ""
    property bool danger: false
    signal triggered

    readonly property bool hovered: mouse.containsMouse

    variant: hovered ? (danger ? "error" : "focus") : "common"
    enableShadow: false
    radius: Styling.radius(-2)
    Layout.fillWidth: true
    Layout.preferredHeight: 34
    Layout.preferredWidth: content.implicitWidth + 28

    RowLayout {
        id: content
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 10

        Text {
            text: Icons[row.icon] ?? ""
            font.family: Icons.font
            font.pixelSize: 15
            color: row.item
        }
        Text {
            Layout.fillWidth: true
            text: row.label
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(0)
            font.weight: Font.Medium
            color: row.item
        }
        Text {
            visible: row.hint !== ""
            text: row.hint
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            color: row.item
            opacity: 0.6
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: row.triggered()
    }
}
