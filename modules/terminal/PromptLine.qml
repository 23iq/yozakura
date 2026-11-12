pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.components.kit
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

            Mark {
                anchors.fill: parent
                radius: 0
                visible: run.modelData.bg !== ""
                color: run.modelData.bg || "transparent"
            }
            // block elements: boxes per cell, the rest of the run's
            // characters in the font (TermModel.blockBoxes)
            readonly property bool blocks: TermModel.hasBlocks(run.modelData.text)
            readonly property var chars: run.blocks ? Array.from(run.modelData.text) : []
            Repeater {
                model: run.chars
                delegate: Item {
                    id: cellItem
                    required property string modelData
                    required property int index
                    readonly property var boxes: TermModel.blockBoxes(modelData)
                    x: Math.round(cellItem.index * run.width / run.chars.length)
                    width: Math.round((cellItem.index + 1) * run.width / run.chars.length) - x
                    height: root.lineHeight
                    Repeater {
                        model: cellItem.boxes || []
                        delegate: Mark {
                            required property var modelData
                            radius: 0
                            x: Math.round(modelData[0] * cellItem.width)
                            y: Math.round(modelData[1] * cellItem.height)
                            width: Math.round(modelData[2] * cellItem.width) - x
                            height: Math.round(modelData[3] * cellItem.height) - y
                            color: run.modelData.fg || root.foreground
                        }
                    }
                    KitText {
                        visible: !cellItem.boxes
                        y: Math.round((root.lineHeight - regular.height) / 2)
                        text: cellItem.modelData
                        color: run.modelData.fg || root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: root.pixelSize
                        font.weight: run.modelData.bold ? Font.Bold : Font.Normal
                    }
                }
            }
            KitText {
                visible: !run.blocks
                y: Math.round((root.lineHeight - regular.height) / 2)
                text: run.modelData.text
                color: run.modelData.fg || root.foreground
                font.family: root.fontFamily
                font.pixelSize: root.pixelSize
                font.weight: run.modelData.bold ? Font.Bold : Font.Normal
                font.italic: run.modelData.italic
                font.underline: run.modelData.underline
            }
        }
    }
}
