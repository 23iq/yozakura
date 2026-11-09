pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.aicenter.common
import qs.modules.components.kit
import qs.modules.aicenter.markdown
import "../lib/Markdown.js" as Markdown

// An answer: flat, full-width markdown. With avatars on, the first row of
// an answer carries the avatar and the engine name; hovering shows copy /
// retry in a small floating pill.
Item {
    id: root

    property string text: ""
    property string engine: ""
    property bool streaming: false
    property bool groupStart: true
    property bool canRetry: false
    property double ts: 0

    signal retryRequested

    implicitHeight: col.implicitHeight

    HoverHandler {
        id: hover
    }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: Space.xs

        RowLayout {
            visible: root.groupStart && (BarLook.avatars || root.streaming && root.text.length === 0)
            spacing: Space.s
            StyledRect {
                visible: BarLook.avatars
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                variant: "common"
                radius: Look.radius("round", height)
                Icon {
                    role: "caption"
                    tone: "accent"
                    anchors.centerIn: parent
                    icon: Icons.sparkle
                    size: BarLook.size("caption")
                }
            }
            AiText {
                role: "caption"
                visible: BarLook.avatars && root.engine.length > 0
                text: root.engine
                font.weight: Font.Medium
            }
            Spinner {
                running: root.streaming && root.text.length === 0
                font.pixelSize: BarLook.size("caption")
            }
        }

        MarkdownView {
            visible: root.text.length > 0
            Layout.fillWidth: true
            text: root.text
            streaming: root.streaming
            fontSize: BarLook.size("body")
        }

        AiText {
            role: "caption"
            visible: BarLook.timestamps && root.ts > 0
            text: BarLook.time(root.ts)
        }
    }

    // Hover actions float over the bottom-right corner: no reserved space.
    StyledRect {
        id: actions
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: opacity > 0
        opacity: hover.hovered && !root.streaming && root.text.length > 0 ? 1 : 0
        z: 2
        variant: "popup"
        radius: Look.radius("control")
        implicitWidth: actionRow.implicitWidth + 2 * Space.xs
        implicitHeight: actionRow.implicitHeight + Space.xs
        Behavior on opacity {
            enabled: BarLook.animDuration > 0
            NumberAnimation {
                duration: BarLook.animDuration / 3
            }
        }
        Row {
            id: actionRow
            anchors.centerIn: parent
            spacing: Space.xs / 2
            CopyButton {
                copyText: Markdown.plain(root.text)
            }
            IconButton {
                visible: root.canRetry
                icon: Icons.arrowCounterClockwise
                tooltip: I18n.t("ai.retry")
                size: "xs"
                onClicked: root.retryRequested()
            }
        }
    }
}
