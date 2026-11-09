pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components.kit
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
    radius: Look.radius("small")
    border.width: 1
    border.color: Look.alpha("outlineVariant", 0.5)
    implicitHeight: col.implicitHeight
    clip: true

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Space.m
            Layout.rightMargin: Space.xs
            Layout.topMargin: Space.xs / 2
            spacing: Space.s

            KitText {
                role: "caption"
                text: root.language || "text"
                font.family: Type.monoFont
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
            Layout.leftMargin: Space.m
            Layout.rightMargin: Space.m
            Layout.bottomMargin: Space.s
            readOnly: true
            selectByMouse: true
            textFormat: TextEdit.RichText
            wrapMode: TextEdit.WrapAnywhere
            font.family: Config.theme.monoFont
            font.pixelSize: Type.size("caption")
            color: Colors.overSurface
            selectionColor: Colors.primary
            selectedTextColor: Colors.overPrimary
            text: Highlight.highlight(root.code, root.lang, Highlight.paletteFrom(Colors))
        }
    }
}
