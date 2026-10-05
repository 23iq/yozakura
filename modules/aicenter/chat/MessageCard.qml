pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.aicenter.common
import qs.modules.aicenter.markdown
import qs.modules.aicenter.agent
import "../lib/Markdown.js" as Markdown

// One chat row: user bubble, assistant answer (thinking + markdown + tool
// calls with inline permission cards), notice or error.
Item {
    id: root

    required property int index
    required property string role
    required property string content
    required property string thinking
    required property string model
    required property string status
    required property string attachments
    required property string toolCalls
    property var session: null
    property string previousRole: ""
    property bool showThinking: true

    readonly property var atts: _parse(attachments)
    readonly property var calls: _parse(toolCalls)
    readonly property bool streaming: status === "streaming"

    implicitHeight: loader.implicitHeight + 4
    width: ListView.view ? ListView.view.width : implicitWidth

    function _parse(s) {
        try {
            return s ? JSON.parse(s) : [];
        } catch (e) {
            return [];
        }
    }

    HoverHandler {
        id: hover
    }

    Loader {
        id: loader
        width: parent.width
        sourceComponent: root.role === "user" ? userC : (root.role === "assistant" ? assistantC : (root.role === "error" ? errorC : noticeC))
    }

    Component {
        id: userC
        Item {
            implicitHeight: userCol.implicitHeight
            ColumnLayout {
                id: userCol
                anchors.right: parent.right
                anchors.rightMargin: 4
                width: Math.min(parent.width * 0.86, Math.max(bubbleText.implicitWidth + 28, strip.implicitWidth))
                spacing: 6
                AttachmentStrip {
                    id: strip
                    attachments: root.atts
                    Layout.alignment: Qt.AlignRight
                    Layout.maximumWidth: userCol.width
                }
                StyledRect {
                    visible: root.content.length > 0
                    Layout.alignment: Qt.AlignRight
                    Layout.preferredWidth: Math.min(userCol.width, bubbleText.implicitWidth + 28)
                    implicitHeight: bubbleText.implicitHeight + 18
                    variant: "primary"
                    radius: Styling.radius(2)
                    TextEdit {
                        id: bubbleText
                        x: 14
                        y: 9
                        width: Math.min(implicitWidth, userCol.width - 28)
                        text: root.content
                        wrapMode: TextEdit.Wrap
                        readOnly: true
                        selectByMouse: true
                        textFormat: TextEdit.PlainText
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(0)
                        color: Styling.srItem("primary")
                    }
                }
            }
        }
    }

    Component {
        id: assistantC
        ColumnLayout {
            spacing: 8
            RowLayout {
                // One header per answer: follow-up rounds after tool calls continue it.
                visible: root.previousRole !== "assistant"
                spacing: 6
                Text {
                    text: Icons.sparkle
                    font.family: Icons.font
                    font.pixelSize: 12
                    color: Colors.primary
                }
                Text {
                    text: root.model || "AI"
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-3)
                    font.weight: Font.Medium
                    color: Colors.outline
                }
                Spinner {
                    running: root.streaming && root.content.length === 0 && root.thinking.length === 0
                    font.pixelSize: 11
                }
                Item {
                    Layout.fillWidth: true
                }
                CopyButton {
                    copyText: Markdown.plain(root.content)
                    opacity: hover.hovered && !root.streaming ? 1 : 0
                    visible: root.content.length > 0
                }
                IconButton {
                    glyph: Icons.arrowCounterClockwise
                    tooltip: I18n.t("ai.retry")
                    size: 24
                    iconSize: 13
                    opacity: hover.hovered && !root.streaming ? 1 : 0
                    visible: root.session !== null
                    onClicked: root.session.retry(root.index)
                }
            }
            ThinkingBlock {
                visible: root.showThinking && root.thinking.length > 0
                Layout.fillWidth: true
                text: root.thinking
                streaming: root.streaming && root.content.length === 0
            }
            MarkdownView {
                visible: root.content.length > 0
                Layout.fillWidth: true
                text: root.content
                streaming: root.streaming
            }
            Repeater {
                model: root.calls
                delegate: Loader {
                    id: entry
                    required property var modelData
                    Layout.fillWidth: true
                    sourceComponent: entry.modelData.status === "ask" ? askC : toolC
                    Component {
                        id: toolC
                        ToolCard {
                            title: entry.modelData.title || entry.modelData.name
                            tool: entry.modelData.tool || entry.modelData.name
                            category: entry.modelData.category || "mcp"
                            status: entry.modelData.status
                            input: JSON.stringify(entry.modelData.args || {})
                            output: entry.modelData.result || ""
                            isError: !!entry.modelData.isError
                            compact: true
                        }
                    }
                    Component {
                        id: askC
                        PermissionCard {
                            title: entry.modelData.title || entry.modelData.name
                            tool: entry.modelData.tool || entry.modelData.name
                            category: entry.modelData.category || "mcp"
                            detail: JSON.stringify(entry.modelData.args || {}, null, 2)
                            agentLabel: root.model
                            Component.onCompleted: forceActiveFocus()
                            onDecided: decision => root.session.respond(root.index, entry.modelData.id, decision)
                        }
                    }
                }
            }
        }
    }

    Component {
        id: noticeC
        Text {
            text: root.content
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            textFormat: Text.MarkdownText
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            color: Colors.outline
        }
    }

    Component {
        id: errorC
        StyledRect {
            variant: "common"
            radius: Styling.radius(-4)
            implicitHeight: errRow.implicitHeight + 16
            border.width: 1
            border.color: Colors.error
            RowLayout {
                id: errRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: 10
                spacing: 8
                Text {
                    text: Icons.warning
                    font.family: Icons.font
                    font.pixelSize: 15
                    color: Colors.error
                }
                Text {
                    Layout.fillWidth: true
                    text: root.content
                    wrapMode: Text.Wrap
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-1)
                    color: Colors.overSurface
                }
                IconButton {
                    glyph: Icons.arrowCounterClockwise
                    tooltip: I18n.t("ai.retry")
                    visible: root.session !== null
                    onClicked: root.session.retry(root.index)
                }
            }
        }
    }
}
