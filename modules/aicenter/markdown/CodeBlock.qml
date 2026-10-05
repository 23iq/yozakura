pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.config
import "../lib/Highlight.js" as Highlight

// Fenced code with palette-driven highlighting, language label and copy.
StyledRect {
    id: root

    property string code: ""
    property string language: ""
    property bool streaming: false
    readonly property string lang: Highlight.language(language)

    variant: "common"
    radius: Styling.radius(-6)
    border.width: 1
    border.color: Qt.rgba(Colors.outlineVariant.r, Colors.outlineVariant.g, Colors.outlineVariant.b, 0.5)
    implicitHeight: col.implicitHeight
    clip: true

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 12
            Layout.rightMargin: 4
            Layout.topMargin: 2
            spacing: 6

            Text {
                text: root.language || "text"
                font.family: Config.theme.monoFont
                font.pixelSize: Styling.monoFontSize(-3)
                color: Colors.outline
                Layout.fillWidth: true
            }

            CopyButton {
                copyText: root.code
                visible: !root.streaming
            }
        }

        TextEdit {
            id: body
            Layout.fillWidth: true
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            Layout.bottomMargin: 10
            readOnly: true
            selectByMouse: true
            textFormat: TextEdit.RichText
            wrapMode: TextEdit.WrapAnywhere
            font.family: Config.theme.monoFont
            font.pixelSize: Styling.monoFontSize(-2)
            color: Colors.overSurface
            selectionColor: Colors.primary
            selectedTextColor: Colors.overPrimary
            text: Highlight.highlight(root.code, root.lang, Highlight.paletteFrom(Colors))
        }
    }
}
