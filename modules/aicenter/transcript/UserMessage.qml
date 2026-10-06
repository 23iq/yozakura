pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.aicenter.common
import qs.modules.aicenter.chat

// What the user sent: a soft bubble on the right (ai.appearance.messageStyle
// "bubble") or a flat full-width block, with its attachments.
Item {
    id: root

    property string text: ""
    property var attachments: []
    property double ts: 0

    readonly property string initial: (Quickshell.env("USER") || "?").charAt(0).toUpperCase()
    readonly property real maxBubble: BarLook.bubbles ? width * 0.86 : width

    implicitHeight: row.implicitHeight

    RowLayout {
        id: row
        width: parent.width
        layoutDirection: BarLook.bubbles ? Qt.RightToLeft : Qt.LeftToRight
        spacing: 8

        StyledRect {
            visible: BarLook.avatars
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: 26
            Layout.preferredHeight: 26
            variant: "focus"
            radius: height / 2
            Text {
                anchors.centerIn: parent
                text: root.initial
                font.family: Config.theme.font
                font.pixelSize: BarLook.font(-2)
                font.weight: Font.DemiBold
                color: Colors.overSurface
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            AttachmentStrip {
                attachments: root.attachments
                Layout.alignment: BarLook.bubbles ? Qt.AlignRight : Qt.AlignLeft
                Layout.maximumWidth: root.maxBubble
            }

            StyledRect {
                id: bubble
                visible: root.text.length > 0
                Layout.alignment: BarLook.bubbles ? Qt.AlignRight : Qt.AlignLeft
                Layout.fillWidth: !BarLook.bubbles
                Layout.preferredWidth: BarLook.bubbles ? Math.min(root.maxBubble - (BarLook.avatars ? 34 : 0), body.implicitWidth + 2 * BarLook.pad) : -1
                implicitHeight: body.implicitHeight + BarLook.pad
                variant: BarLook.bubbles ? "focus" : "internalbg"
                radius: Styling.radius(BarLook.bubbles ? 2 : -4)
                // Hairline edge: keeps the bubble readable on low-contrast palettes.
                border.width: 1
                border.color: Qt.rgba(Colors.outlineVariant.r, Colors.outlineVariant.g, Colors.outlineVariant.b, 0.45)
                TextEdit {
                    id: body
                    x: BarLook.pad
                    y: BarLook.pad / 2
                    width: Math.min(implicitWidth, bubble.width - 2 * BarLook.pad)
                    text: root.text
                    wrapMode: TextEdit.Wrap
                    readOnly: true
                    selectByMouse: true
                    textFormat: TextEdit.PlainText
                    font.family: Config.theme.font
                    font.pixelSize: BarLook.font(0)
                    color: Colors.overSurface
                    selectionColor: Colors.primary
                    selectedTextColor: Colors.overPrimary
                }
            }

            Text {
                visible: BarLook.timestamps && root.ts > 0
                Layout.alignment: BarLook.bubbles ? Qt.AlignRight : Qt.AlignLeft
                text: BarLook.time(root.ts)
                font.family: Config.theme.font
                font.pixelSize: BarLook.font(-4)
                color: Colors.outline
            }
        }
    }
}
