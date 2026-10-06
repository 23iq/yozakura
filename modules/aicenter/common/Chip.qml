pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.config

// Pill used for model/agent switchers, context attachments and suggestions.
// Given less than its implicit width (Layout.fillWidth + maximumWidth:
// implicitWidth in a row) the label elides instead of overflowing.
AbstractButton {
    id: root

    property string glyph: ""
    property url image: ""
    property string label: ""
    property string trailingIcon: ""
    property bool active: false
    property bool closable: false
    property string variant: active ? "primary" : "common"
    property int maxLabelWidth: 220
    property bool mono: false

    signal closeClicked

    implicitHeight: 28
    implicitWidth: row.implicitWidth + 20
    focusPolicy: Qt.NoFocus
    hoverEnabled: true

    background: StyledRect {
        variant: root.hovered && !root.active ? "focus" : root.variant
        radius: Styling.radius(0) > 0 ? height / 2 : 0
        enableBorder: true
    }

    contentItem: Item {
        RowLayout {
            id: row
            anchors.centerIn: parent
            width: Math.min(implicitWidth, parent.width)
            spacing: 6

            Image {
                visible: root.image.toString().length > 0
                source: root.image
                sourceSize: Qt.size(14, 14)
                Layout.preferredWidth: 14
                Layout.preferredHeight: 14
            }

            Text {
                visible: root.glyph.length > 0 && root.image.toString().length === 0
                text: root.glyph
                font.family: Icons.font
                font.pixelSize: 13
                color: Styling.srItem(root.variant)
            }

            Text {
                text: root.label
                visible: text.length > 0
                font.family: root.mono ? Config.theme.monoFont : Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
                font.weight: Font.Medium
                color: Styling.srItem(root.variant)
                elide: Text.ElideMiddle
                Layout.fillWidth: true
                Layout.maximumWidth: root.maxLabelWidth
            }

            Text {
                visible: root.trailingIcon.length > 0 && !root.closable
                text: root.trailingIcon
                font.family: Icons.font
                font.pixelSize: 11
                color: Styling.srItem(root.variant)
                opacity: 0.7
            }

            Text {
                visible: root.closable
                text: Icons.cancel
                font.family: Icons.font
                font.pixelSize: 11
                color: Styling.srItem(root.variant)
                opacity: closeArea.containsMouse ? 1 : 0.6
                MouseArea {
                    id: closeArea
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    onClicked: root.closeClicked()
                }
            }
        }
    }
}
