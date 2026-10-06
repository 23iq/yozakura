pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.aicenter.common

// "— history compacted —" divider of a compacted HTTP chat. Messages above
// it are no longer sent to the model; click to read the summary it got
// instead.
ColumnLayout {
    id: root
    objectName: "compactedMarker"

    property string summary: ""
    property bool expanded: false

    spacing: 6

    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        StyledRect {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            variant: "internalbg"
        }
        StyledRect {
            implicitWidth: label.implicitWidth + 20
            implicitHeight: label.implicitHeight + 8
            radius: height / 2
            variant: hover.hovered ? "focus" : "common"
            HoverHandler {
                id: hover
                cursorShape: Qt.PointingHandCursor
            }
            TapHandler {
                onTapped: root.expanded = !root.expanded
            }
            RowLayout {
                id: label
                anchors.centerIn: parent
                spacing: 6
                Text {
                    text: Icons.arrowsInSimple
                    font.family: Icons.font
                    font.pixelSize: BarLook.font(-4)
                    color: Colors.outline
                }
                Text {
                    text: I18n.t("ai.history_compacted")
                    font.family: Config.theme.font
                    font.pixelSize: BarLook.font(-3)
                    color: Colors.overSurfaceVariant
                }
                Text {
                    text: root.expanded ? Icons.caretUp : Icons.caretDown
                    font.family: Icons.font
                    font.pixelSize: BarLook.font(-5)
                    color: Colors.outline
                }
            }
        }
        StyledRect {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            variant: "internalbg"
        }
    }

    StyledRect {
        Layout.fillWidth: true
        visible: root.expanded
        variant: "internalbg"
        radius: Styling.radius(-4)
        implicitHeight: body.implicitHeight + 2 * BarLook.pad
        ColumnLayout {
            id: body
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: BarLook.pad
            spacing: 6
            Text {
                Layout.fillWidth: true
                text: I18n.t("ai.history_compacted_desc")
                wrapMode: Text.Wrap
                font.family: Config.theme.font
                font.pixelSize: BarLook.font(-4)
                color: Colors.outline
            }
            Text {
                Layout.fillWidth: true
                text: root.summary
                wrapMode: Text.Wrap
                textFormat: Text.MarkdownText
                font.family: Config.theme.font
                font.pixelSize: BarLook.font(-2)
                color: Colors.overSurfaceVariant
            }
        }
    }
}
