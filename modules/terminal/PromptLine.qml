pragma ComponentBehavior: Bound

import QtQuick
import "TermModel.js" as TermModel

// One terminal line of styled spans ({text, fg, bg, bold, italic,
// underline}, from `term.preview`) drawn like kitty: a run of one style is
// a Text over its background, runs sit on whole pixels so powerline
// segments touch without seams. Empty fg = the terminal foreground.
Item {
    id: root

    property var spans: []
    property string fontFamily: "monospace"
    property real pixelSize: 14
    property color foreground: "white"
    // Cell height (the line pitch); defaults to the font's.
    property real lineHeight: Math.ceil(regular.height)

    // The fonts are passed so the layout follows font changes (advanceWidth
    // is a method: bindings do not see what it reads).
    readonly property var runs: root.layout(root.spans, regular.font, boldM.font, italicM.font, boldItalic.font)
    readonly property real contentWidth: root.runs.length > 0 ? root.runs[root.runs.length - 1].x + root.runs[root.runs.length - 1].width : 0

    function layout(spans) {
        return TermModel.layoutRuns(TermModel.spansToRuns(spans), root.measure);
    }

    function measure(text, bold, italic) {
        const m = bold ? (italic ? boldItalic : boldM) : (italic ? italicM : regular);
        return m.advanceWidth(text);
    }

    implicitWidth: root.contentWidth
    implicitHeight: root.lineHeight

    FontMetrics {
        id: regular
        font.family: root.fontFamily
        font.pixelSize: root.pixelSize
    }
    FontMetrics {
        id: boldM
        font.family: root.fontFamily
        font.pixelSize: root.pixelSize
        font.bold: true
    }
    FontMetrics {
        id: italicM
        font.family: root.fontFamily
        font.pixelSize: root.pixelSize
        font.italic: true
    }
    FontMetrics {
        id: boldItalic
        font.family: root.fontFamily
        font.pixelSize: root.pixelSize
        font.bold: true
        font.italic: true
    }

    Repeater {
        model: root.runs

        delegate: Item {
            id: run
            required property var modelData
            x: modelData.x
            width: modelData.width
            height: root.lineHeight

            Rectangle {
                anchors.fill: parent
                visible: run.modelData.bg !== ""
                color: run.modelData.bg || "transparent"
            }
            Text {
                y: Math.round((root.lineHeight - regular.height) / 2)
                text: run.modelData.text
                textFormat: Text.PlainText
                color: run.modelData.fg || root.foreground
                font.family: root.fontFamily
                font.pixelSize: root.pixelSize
                font.bold: run.modelData.bold
                font.italic: run.modelData.italic
                font.underline: run.modelData.underline
            }
        }
    }
}
