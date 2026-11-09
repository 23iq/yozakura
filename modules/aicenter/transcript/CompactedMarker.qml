pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components.kit
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

    spacing: Space.s

    RowLayout {
        Layout.fillWidth: true
        spacing: Space.s
        // Hairlines either side of the pill; where the language has no
        // dividers they still hold the pill centred.
        Divider {
            Layout.fillWidth: true
            visible: true
            opacity: Look.dividers ? 1 : 0
        }
        StyledRect {
            implicitWidth: label.implicitWidth + 2 * Space.s
            implicitHeight: label.implicitHeight + 2 * Space.xs
            radius: Look.radius("round", height)
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
                spacing: Space.s
                Icon {
                    role: "caption"
                    tone: "muted"
                    icon: Icons.arrowsInSimple
                    size: BarLook.size("caption")
                }
                AiText {
                    role: "caption"
                    text: I18n.t("ai.history_compacted")
                    color: Type.secondary
                }
                Icon {
                    role: "caption"
                    tone: "muted"
                    icon: root.expanded ? Icons.caretUp : Icons.caretDown
                    size: BarLook.size("caption")
                }
            }
        }
        // Hairlines either side of the pill; where the language has no
        // dividers they still hold the pill centred.
        Divider {
            Layout.fillWidth: true
            visible: true
            opacity: Look.dividers ? 1 : 0
        }
    }

    StyledRect {
        Layout.fillWidth: true
        visible: root.expanded
        variant: "internalbg"
        radius: Look.radius("control")
        implicitHeight: body.implicitHeight + 2 * BarLook.pad
        ColumnLayout {
            id: body
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: BarLook.pad
            spacing: Space.s
            AiText {
                role: "caption"
                Layout.fillWidth: true
                text: I18n.t("ai.history_compacted_desc")
                wrapMode: Text.Wrap
            }
            AiText {
                role: "caption"
                Layout.fillWidth: true
                text: root.summary
                wrapMode: Text.Wrap
                textFormat: Text.MarkdownText
                color: Type.secondary
            }
        }
    }
}
