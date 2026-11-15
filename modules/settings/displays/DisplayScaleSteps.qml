pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.editors
import "DisplayFormat.js" as DisplayFormat

// The selected monitor's scale as a strip of equal, compact step tiles
// (DisplayFormat.scaleSteps: the common steps up to 200 %, plus the current
// one when it is custom and the suggested one when it is bigger): each one
// "Aa" at the size text gets at that step, its percentage under it. The
// suggested step carries a sparkle badge on its corner and the line under the
// strip names it. The strip is as tall as it needs (`implicitHeight`): the
// card never stretches it. A click patches the draft (Apply makes it live).
Column {
    id: root

    property var options: []
    property real value: 1
    signal selected(real value)

    readonly property var shown: DisplayFormat.scaleSteps(root.options, root.value)
    readonly property var suggested: root.options.find(o => o.max === true) ?? null
    // the suggestion badge (PickTile's check badge size)
    readonly property real badge: Math.round(Type.iconSize("caption") * 1.4)
    readonly property real maxValue: root.shown.reduce((m, o) => Math.max(m, o.value), 1)

    readonly property real tileW: (root.width - steps.spacing * (root.shown.length - 1)) / Math.max(1, root.shown.length)
    // the picture box of a tile: about square, from a small control to a big one
    readonly property real boxH: Math.round(Math.max(Space.controlM, Math.min(Space.controlL, root.tileW * 0.9)))
    // the picture area of a tile (PickTile: Space.s a side)
    readonly property real room: root.tileW - Space.s * 2
    // The sample: "Aa" while the biggest step's still fits its tile at a
    // readable size, else "A" (narrow tiles); every step grows from one base
    // size, so a narrow tile scales them all down alike and never clips.
    // Widths per pixel of font size, measured in the real font (bold: the
    // chosen step's weight).
    readonly property real pairW: Math.max(0.5, pair.implicitWidth / Math.max(1, pair.font.pixelSize))
    readonly property real oneW: Math.max(0.3, one.implicitWidth / Math.max(1, one.font.pixelSize))
    readonly property bool compact: root.room / (root.pairW * root.growth(root.maxValue)) < Type.size("caption") * 0.85
    readonly property string sample: root.compact ? "A" : "Aa"
    readonly property real base: Math.min(Type.size("body"), root.room / ((root.compact ? root.oneW : root.pairW) * root.growth(root.maxValue)), (root.boxH - Space.s * 2) / (0.8 * root.growth(root.maxValue)))

    // the glyph's size relative to the caption size at a scale
    function growth(v) {
        return 0.7 + v * 0.5;
    }

    spacing: Space.m

    KitText {
        id: pair
        visible: false
        role: "body"
        font.pixelSize: Type.size("display")
        font.weight: Type.weight("title")
        text: "Aa"
    }
    // a tile's caption line (PickTile's), for the tile height
    KitText {
        id: captionMeasure
        visible: false
        role: "secondary"
        text: "100%"
    }
    KitText {
        id: one
        visible: false
        role: "body"
        font.pixelSize: Type.size("display")
        font.weight: Type.weight("title")
        text: "A"
    }

    Row {
        id: steps
        objectName: "scaleStrip"
        width: root.width
        spacing: Space.s
        // room for the suggestion's badge over a tile's corner
        topPadding: Math.round(root.badge * 0.35)

        Repeater {
            model: root.shown
            delegate: Item {
                id: cell
                required property var modelData
                width: root.tileW
                height: root.boxH + Space.s + captionMeasure.implicitHeight

                PickTile {
                    id: step
                    objectName: "scaleStep:" + cell.modelData.value
                    anchors.fill: parent
                    chosen: DisplayFormat.sameNumber(cell.modelData.value, root.value)
                    caption: cell.modelData.label
                    onClicked: root.selected(cell.modelData.value)

                    KitText {
                        anchors.centerIn: parent
                        role: "body"
                        // grows with the step from one base size (see `base`)
                        font.pixelSize: Math.max(1, Math.floor(root.base * root.growth(cell.modelData.value)))
                        font.weight: step.chosen ? Type.weight("title") : Type.weight("body")
                        color: step.chosen ? Type.accent : Type.text
                        text: root.sample
                    }
                }
                // the suggested step: a sparkle badge on the tile's top-left
                // corner (the chosen one's check sits on the right one)
                Mark {
                    objectName: "scaleSuggested"
                    visible: cell.modelData.max === true
                    width: root.badge
                    height: width
                    x: -width * 0.35
                    y: -width * 0.35
                    z: 3
                    color: Qt.rgba(Look.cardFill(false).r, Look.cardFill(false).g, Look.cardFill(false).b, 1)
                    border.width: Space.hairline
                    border.color: Type.accent
                    Icon {
                        anchors.centerIn: parent
                        icon: Icons.sparkle
                        role: "caption"
                        tone: "accent"
                    }
                }
            }
        }
    }

    // what the sparkle means, said once under the strip
    Row {
        objectName: "scaleLegend"
        visible: root.suggested !== null
        width: root.width
        spacing: Space.s
        // the glyph on the first line; a long translation wraps, whole
        Icon {
            id: legendIcon
            y: Math.round((legendText.lineHeight0 - height) / 2)
            icon: Icons.sparkle
            role: "caption"
            tone: "accent"
        }
        KitText {
            id: legendText
            // the height of one line (the glyph centres on the first)
            readonly property real lineHeight0: legendText.lineCount > 0 ? legendText.implicitHeight / legendText.lineCount : legendText.implicitHeight
            width: parent.width - legendIcon.width - parent.spacing
            role: "caption"
            color: Type.secondary
            wrapMode: Text.WordWrap
            elide: Text.ElideNone
            text: root.suggested ? I18n.t("prefs.displays.scale_suggested", root.suggested.label) : ""
        }
    }
}
