pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.aicenter.common

// Collapsible reasoning ("thinking") text. Collapsed by default once done.
ColumnLayout {
    id: root

    property string text: ""
    property bool streaming: false
    property bool expanded: false

    spacing: 4

    MouseArea {
        Layout.fillWidth: true
        implicitHeight: header.implicitHeight
        cursorShape: Qt.PointingHandCursor
        onClicked: root.expanded = !root.expanded

        RowLayout {
            id: header
            width: parent.width
            spacing: 6

            Text {
                text: Icons.brain
                font.family: Icons.font
                font.pixelSize: 13
                color: Colors.outline
            }
            Text {
                text: root.streaming ? I18n.t("ai.thinking") : I18n.t("ai.thought")
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
                font.italic: true
                color: Colors.outline
            }
            Spinner {
                running: root.streaming
                font.pixelSize: 11
                color: Colors.outline
            }
            Text {
                text: root.expanded ? Icons.caretUp : Icons.caretDown
                font.family: Icons.font
                font.pixelSize: 10
                color: Colors.outline
            }
            Item {
                Layout.fillWidth: true
            }
        }
    }

    Text {
        visible: root.expanded || root.streaming
        Layout.fillWidth: true
        Layout.leftMargin: 19
        text: root.streaming && !root.expanded ? root.text.slice(-280) : root.text
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        maximumLineCount: root.expanded ? 400 : 3
        elide: Text.ElideLeft
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-2)
        color: Colors.outline
    }
}
