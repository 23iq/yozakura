pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.config
import "../lib/Markdown.js" as Markdown
import "../../globals/Urls.js" as Urls

// Renders assistant markdown: prose via Text.MarkdownText, fenced code via
// CodeBlock (diff fences via DiffView), inline <think> via ThinkingBlock.
ColumnLayout {
    id: root

    property string text: ""
    property bool streaming: false
    property color textColor: Colors.overBackground
    property int fontSize: Styling.fontSize(0)
    readonly property var segments: Markdown.segments(text)

    spacing: 8

    Repeater {
        model: root.segments

        delegate: Loader {
            id: entry
            required property var modelData
            required property int index
            Layout.fillWidth: true
            sourceComponent: entry.modelData.type === "code" ? (entry.modelData.language === "diff" ? diffC : codeC) : (entry.modelData.type === "thinking" ? thinkC : textC)

            Component {
                id: textC
                TextEdit {
                    text: entry.modelData.content
                    textFormat: TextEdit.MarkdownText
                    readOnly: true
                    selectByMouse: true
                    wrapMode: TextEdit.Wrap
                    color: root.textColor
                    selectionColor: Colors.primary
                    selectedTextColor: Colors.overPrimary
                    font.family: Config.theme.font
                    font.pixelSize: root.fontSize
                    onLinkActivated: link => {
                        if (Urls.isWeb(link))
                            Qt.openUrlExternally(link);
                    }

                    HoverHandler {
                        enabled: parent.hoveredLink.length > 0
                        cursorShape: Qt.PointingHandCursor
                    }
                }
            }
            Component {
                id: codeC
                CodeBlock {
                    code: entry.modelData.content
                    language: entry.modelData.language
                    streaming: entry.modelData.open && root.streaming
                }
            }
            Component {
                id: diffC
                DiffView {
                    diff: entry.modelData.content
                    maxRows: 60
                }
            }
            Component {
                id: thinkC
                ThinkingBlock {
                    text: entry.modelData.content
                    streaming: entry.modelData.open && root.streaming
                }
            }
        }
    }
}
