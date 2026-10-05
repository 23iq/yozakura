import QtQuick
import qs.modules.theme
import qs.config

// Small heading inside a step: icon + title, optional hint line below.
Column {
    id: root

    property string icon: ""
    property string text: ""
    property string hint: ""

    spacing: 3
    bottomPadding: 4

    Row {
        spacing: 8
        Text {
            visible: root.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: Icons[root.icon] ?? ""
            font.family: Icons.font
            font.pixelSize: Styling.fontSize(1)
            color: Colors.primary
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(1)
            font.weight: Font.DemiBold
            color: Colors.overBackground
        }
    }
    Text {
        visible: root.hint !== ""
        width: root.width
        text: root.hint
        wrapMode: Text.WordWrap
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-2)
        color: Colors.overSurfaceVariant
    }
}
