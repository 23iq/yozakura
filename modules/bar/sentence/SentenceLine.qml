pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.components.kit
import "Sentence.js" as Sentence

// The sentence typeset as one line: fragments (Sentence.build) joined by
// the separator, data in full ink and the template's own words a step
// quieter. Each fragment is an InlineLink (hover underline, Tab focus,
// Enter). Fragments that do not fit in `budget` px drop by `priority`;
// the first one left leads the sentence (capitalized). Shared by the bar
// module and the settings preview.
Item {
    id: root

    property var fragments: []
    property var priority: Sentence.DEFAULT_PRIORITY
    property real budget: 0
    property string separator: "dash"
    property string textFont: Type.bodyFont
    property int textSize: Type.size("body")
    property int textWeight: Font.Normal
    property color ink: Type.text
    property bool interactive: true

    // Measured widths of the fragments, in sentence order
    property var widths: []
    readonly property var ids: root.fragments.map(f => f.id)
    readonly property real gap: sepMetrics.advanceWidth + root.sepBefore + root.sepAfter
    readonly property var keep: Sentence.fit(root.ids, root.widths, root.priority, root.budget, root.gap)
    readonly property int lead: Sentence.leadIndex(root.keep)
    readonly property int shownCount: root.keep.filter(k => k).length
    readonly property string glyph: Sentence.separatorGlyph(root.separator)
    readonly property bool hugs: Sentence.separatorHugs(root.separator)
    readonly property real space: spaceMetrics.advanceWidth
    // Room around the separator: a comma hugs the fragment before it
    readonly property real sepBefore: root.hugs ? 0 : Space.s
    readonly property real sepAfter: Space.s
    readonly property color softInk: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.62)
    readonly property color sepInk: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.36)

    signal activated(var fragment, Item item, int button)

    implicitWidth: row.implicitWidth
    implicitHeight: Math.max(row.implicitHeight, root.textSize)

    // Fragment widths as the delegates report them, flushed once per tick
    property var _reported: []

    function report(index: int, width: real): void {
        root._reported[index] = width;
        Qt.callLater(root.measure);
    }

    function measure(): void {
        const out = [];
        for (let i = 0; i < root.fragments.length; i++)
            out.push(root._reported[i] || 0);
        root.widths = out;
    }

    onFragmentsChanged: Qt.callLater(root.measure)

    TextMetrics {
        id: sepMetrics
        font.family: root.textFont
        font.pixelSize: root.textSize
        text: root.glyph
    }
    FontMetrics {
        id: lineMetrics
        font.family: root.textFont
        font.pixelSize: root.textSize
    }
    TextMetrics {
        id: spaceMetrics
        font.family: root.textFont
        font.pixelSize: root.textSize
        text: " "
    }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter

        Repeater {
            model: root.fragments

            delegate: Row {
                id: piece
                required property var modelData
                required property int index
                readonly property real linkWidth: link.implicitWidth
                readonly property bool isLead: piece.index === root.lead

                visible: root.keep[piece.index] === true
                onLinkWidthChanged: root.report(piece.index, piece.linkWidth)
                Component.onCompleted: root.report(piece.index, piece.linkWidth)

                // The separator before every kept fragment but the lead
                Text {
                    visible: !piece.isLead
                    anchors.verticalCenter: parent.verticalCenter
                    leftPadding: root.sepBefore
                    rightPadding: root.sepAfter
                    text: root.glyph
                    font.family: root.textFont
                    font.pixelSize: root.textSize
                    font.weight: root.textWeight
                    color: root.sepInk
                }

                InlineLink {
                    id: link
                    objectName: "sentence:" + piece.modelData.id
                    anchors.verticalCenter: parent.verticalCenter
                    ink: root.ink
                    focusable: root.interactive
                    enabled: root.interactive
                    buttons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                    // Just under the baseline, clear of the descenders' bulk
                    underlineY: lineMetrics.ascent + Math.round(lineMetrics.descent * 0.4)
                    Accessible.name: piece.modelData.text
                    onClicked: button => root.activated(piece.modelData, link, button)

                    Row {
                        id: words

                        Repeater {
                            model: piece.modelData.segments

                            delegate: Text {
                                required property var modelData
                                required property int index
                                readonly property string raw: modelData.text
                                readonly property string shown: piece.isLead && index === 0 ? Sentence.capitalizeFirst(raw.trim()) : raw.trim()
                                leftPadding: /^\s/.test(raw) ? root.space : 0
                                rightPadding: /\s$/.test(raw) ? root.space : 0
                                text: shown
                                textFormat: Text.PlainText
                                font.family: root.textFont
                                font.pixelSize: root.textSize
                                font.weight: root.textWeight
                                font.features: ({
                                        "tnum": 1
                                    })
                                color: modelData.value ? root.ink : root.softInk
                            }
                        }
                    }
                }
            }
        }
    }
}
