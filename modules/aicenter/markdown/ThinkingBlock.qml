pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components.kit
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

    spacing: Space.xs

    MouseArea {
        Layout.fillWidth: true
        implicitHeight: header.implicitHeight
        cursorShape: Qt.PointingHandCursor
        onClicked: root.expanded = !root.expanded

        RowLayout {
            id: header
            width: parent.width
            spacing: Space.s

            Icon {
                role: "label"
                tone: "muted"
                icon: Icons.brain
            }
            KitText {
                role: "caption"
                text: root.streaming ? I18n.t("ai.thinking") : I18n.t("ai.thought")
                font.italic: true
            }
            Spinner {
                running: root.streaming
                font.pixelSize: Type.size("caption")
                color: Colors.outline
            }
            Icon {
                role: "label"
                tone: "muted"
                icon: root.expanded ? Icons.caretUp : Icons.caretDown
            }
            Item {
                Layout.fillWidth: true
            }
        }
    }

    KitText {
        role: "caption"
        visible: root.expanded || root.streaming
        Layout.fillWidth: true
        Layout.leftMargin: Space.l
        text: root.streaming && !root.expanded ? root.text.slice(-280) : root.text
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        maximumLineCount: root.expanded ? 400 : 3
        elide: Text.ElideLeft
    }
}
