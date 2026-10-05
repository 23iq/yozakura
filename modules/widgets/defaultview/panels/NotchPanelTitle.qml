import QtQuick
import qs.config
import qs.modules.theme

// Title row of a notch panel: accent glyph + title + optional summary on
// the right, and optional trailing controls (children).
Item {
    id: title

    property string icon: ""
    property string text: ""
    property string summary: ""
    property color accent: Colors.primary
    property real unit: 4

    default property alias actions: actionsRow.data

    implicitHeight: Math.max(titleText.implicitHeight, actionsRow.implicitHeight, glyph.implicitHeight)

    Text {
        id: glyph
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: title.icon
        visible: text !== ""
        font.family: Icons.font
        font.pixelSize: Styling.fontSize(2)
        color: title.accent
    }
    Text {
        id: titleText
        anchors.left: glyph.visible ? glyph.right : parent.left
        anchors.leftMargin: glyph.visible ? title.unit * 2 : 0
        anchors.right: summaryText.left
        anchors.rightMargin: title.unit * 2
        anchors.verticalCenter: parent.verticalCenter
        text: title.text
        textFormat: Text.PlainText
        elide: Text.ElideRight
        color: Colors.overBackground
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(0)
        font.weight: Font.Bold
    }
    Text {
        id: summaryText
        anchors.right: actionsRow.left
        anchors.rightMargin: actionsRow.implicitWidth > 0 ? title.unit * 2 : 0
        anchors.verticalCenter: parent.verticalCenter
        text: title.summary
        textFormat: Text.PlainText
        color: Colors.overSurfaceVariant
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-2)
        font.features: ({
                "tnum": 1
            })
    }
    Row {
        id: actionsRow
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: title.unit
    }
}
