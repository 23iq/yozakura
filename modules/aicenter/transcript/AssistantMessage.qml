pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.aicenter.common
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
        spacing: 4

        RowLayout {
            visible: root.groupStart && (BarLook.avatars || root.streaming && root.text.length === 0)
            spacing: 6
            StyledRect {
                visible: BarLook.avatars
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                variant: "common"
                radius: height / 2
                Text {
                    anchors.centerIn: parent
                    text: Icons.sparkle
                    font.family: Icons.font
                    font.pixelSize: BarLook.font(-3)
                    color: Colors.primary
                }
            }
            Text {
                visible: BarLook.avatars && root.engine.length > 0
                text: root.engine
                font.family: Config.theme.font
                font.pixelSize: BarLook.font(-3)
                font.weight: Font.Medium
                color: Colors.outline
            }
            Spinner {
                running: root.streaming && root.text.length === 0
                font.pixelSize: BarLook.font(-3)
            }
        }

        MarkdownView {
            visible: root.text.length > 0
            Layout.fillWidth: true
            text: root.text
            streaming: root.streaming
            fontSize: BarLook.font(0)
        }

        Text {
            visible: BarLook.timestamps && root.ts > 0
            text: BarLook.time(root.ts)
            font.family: Config.theme.font
            font.pixelSize: BarLook.font(-4)
            color: Colors.outline
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
        radius: Styling.radius(-4)
        implicitWidth: actionRow.implicitWidth + 6
        implicitHeight: actionRow.implicitHeight + 4
        Behavior on opacity {
            enabled: BarLook.animDuration > 0
            NumberAnimation {
                duration: BarLook.animDuration / 3
            }
        }
        Row {
            id: actionRow
            anchors.centerIn: parent
            spacing: 2
            CopyButton {
                copyText: Markdown.plain(root.text)
            }
            IconButton {
                visible: root.canRetry
                glyph: Icons.arrowCounterClockwise
                tooltip: I18n.t("ai.retry")
                size: 24
                iconSize: 13
                onClicked: root.retryRequested()
            }
        }
    }
}
