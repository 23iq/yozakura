pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import "../lib/Diff.js" as Diff
import "../lib/Highlight.js" as Highlight
import "../lib/Markdown.js" as Markdown

// Unified diff with line numbers, +/- tinting and syntax highlighting of the
// code itself (language from the file path). maxRows caps very long diffs
// (expandable).
StyledRect {
    id: root

    property string diff: ""
    property string path: ""
    property int maxRows: 400
    property bool showHeader: true
    property bool expanded: false

    readonly property var files: Diff.parse(diff, path)
    readonly property var allRows: Diff.rows(files)
    readonly property var rows: expanded ? allRows : allRows.slice(0, maxRows)
    readonly property var stats: Diff.stats(files)
    readonly property string lang: Highlight.languageForPath(path || (files.length > 0 ? files[0].path : ""))
    readonly property int gutter: Math.max(2, String(allRows.reduce((m, r) => Math.max(m, r.oldNo, r.newNo), 1)).length)

    variant: "internalbg"
    radius: Styling.radius(-6)
    implicitHeight: col.implicitHeight
    clip: true

    function _line(r) {
        if (r.kind === "hunk" || r.kind === "note")
            return Markdown.escapeHtml(r.text);
        return Highlight.toHtml(Highlight.tokenizeLine(r.text, root.lang, Highlight.newState()), Highlight.paletteFrom(Colors));
    }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 0

        RowLayout {
            visible: root.showHeader
            Layout.fillWidth: true
            Layout.leftMargin: 10
            Layout.rightMargin: 4
            Layout.topMargin: 4
            Layout.bottomMargin: 2
            spacing: 8

            Text {
                text: Icons.gitDiff
                font.family: Icons.font
                font.pixelSize: 13
                color: Colors.outline
            }
            Text {
                text: root.files.length === 1 ? (root.files[0].path || root.path) : I18n.t("ai.files_changed").replace("%1", root.files.length)
                font.family: Config.theme.monoFont
                font.pixelSize: Styling.monoFontSize(-3)
                color: Colors.overSurface
                elide: Text.ElideMiddle
                Layout.fillWidth: true
            }
            Text {
                text: "+" + root.stats.added
                font.family: Config.theme.monoFont
                font.pixelSize: Styling.monoFontSize(-3)
                color: Colors.success
            }
            Text {
                text: "−" + root.stats.removed
                font.family: Config.theme.monoFont
                font.pixelSize: Styling.monoFontSize(-3)
                color: Colors.error
            }
            CopyButton {
                copyText: root.diff
            }
        }

        Column {
            Layout.fillWidth: true
            Layout.bottomMargin: 6

            Repeater {
                model: root.rows

                delegate: Rectangle {
                    id: entry
                    required property var modelData
                    width: col.width
                    height: lineText.implicitHeight + 2
                    color: entry.modelData.kind === "add" ? Qt.rgba(Colors.success.r, Colors.success.g, Colors.success.b, 0.14) : (entry.modelData.kind === "del" ? Qt.rgba(Colors.error.r, Colors.error.g, Colors.error.b, 0.14) : "transparent")

                    Text {
                        id: nums
                        x: 6
                        width: (root.gutter * 2 + 2) * font.pixelSize * 0.6
                        y: 1
                        text: entry.modelData.kind === "hunk" ? "" : ((entry.modelData.oldNo || "") + "").padStart(root.gutter) + " " + ((entry.modelData.newNo || "") + "").padStart(root.gutter)
                        font.family: Config.theme.monoFont
                        font.pixelSize: Styling.monoFontSize(-3)
                        color: Colors.outline
                        opacity: 0.7
                    }
                    Text {
                        id: sign
                        anchors.left: nums.right
                        anchors.leftMargin: 4
                        y: 1
                        width: 10
                        text: entry.modelData.kind === "add" ? "+" : (entry.modelData.kind === "del" ? "−" : "")
                        font.family: Config.theme.monoFont
                        font.pixelSize: Styling.monoFontSize(-2)
                        color: entry.modelData.kind === "add" ? Colors.success : Colors.error
                    }
                    Text {
                        id: lineText
                        anchors.left: sign.right
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        y: 1
                        text: root._line(entry.modelData)
                        textFormat: Text.RichText
                        wrapMode: Text.WrapAnywhere
                        font.family: Config.theme.monoFont
                        font.pixelSize: Styling.monoFontSize(-2)
                        font.italic: entry.modelData.kind === "note"
                        color: entry.modelData.kind === "hunk" || entry.modelData.kind === "note" ? Colors.outline : Colors.overSurface
                    }
                }
            }
        }

        Text {
            visible: !root.expanded && root.allRows.length > root.rows.length
            Layout.leftMargin: 12
            Layout.bottomMargin: 8
            text: I18n.t("ai.show_more_lines").replace("%1", root.allRows.length - root.rows.length)
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            color: Colors.primary
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.expanded = true
            }
        }
    }
}
