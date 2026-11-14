pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.components.kit
import qs.modules.settings.editors
import "DisplayFormat.js" as DisplayFormat

// The selected monitor's scale as "Aa" that grows with it, one tile per
// common step (DisplayFormat.scaleOptions, up to 200 %, plus the current
// one when it is custom); the suggested step carries a sparkle. A click
// patches the draft (Apply makes it live).
Row {
    id: root

    property var options: []
    property real value: 1
    signal selected(real value)

    readonly property var shown: root.options.filter(o => o.value <= 2 || DisplayFormat.sameNumber(o.value, root.value))
    readonly property real maxValue: root.shown.reduce((m, o) => Math.max(m, o.value), 1)

    // The sample: "Aa" while the biggest step's still fits its tile at a
    // readable size, else "A" (narrow tiles); every step grows from one base
    // size, so a narrow tile scales them all down alike and never clips.
    // Widths per pixel of font size, measured in the real font (bold: the
    // chosen step's weight).
    readonly property real tileW: (root.width - root.spacing * (root.shown.length - 1)) / Math.max(1, root.shown.length)
    // the picture area of a tile (PickTile: Space.s a side)
    readonly property real room: root.tileW - Space.s * 2
    readonly property real pairW: Math.max(0.5, pair.implicitWidth / Math.max(1, pair.font.pixelSize))
    readonly property real oneW: Math.max(0.3, one.implicitWidth / Math.max(1, one.font.pixelSize))
    readonly property bool compact: root.room / (root.pairW * root.growth(root.maxValue)) < Type.size("caption") * 0.85
    readonly property string sample: root.compact ? "A" : "Aa"
    readonly property real base: Math.min(Type.size("caption"), root.room / ((root.compact ? root.oneW : root.pairW) * root.growth(root.maxValue)))

    KitText {
        id: pair
        visible: false
        role: "body"
        font.pixelSize: Type.size("display")
        font.weight: Type.weight("title")
        text: "Aa"
    }
    KitText {
        id: one
        visible: false
        role: "body"
        font.pixelSize: Type.size("display")
        font.weight: Type.weight("title")
        text: "A"
    }

    // the glyph's size relative to the caption size at a scale
    function growth(v) {
        return 0.7 + v * 0.5;
    }

    spacing: Space.s

    Repeater {
        model: root.shown
        delegate: PickTile {
            id: step
            required property var modelData
            objectName: "scaleStep:" + modelData.value
            width: root.tileW
            height: root.height
            chosen: DisplayFormat.sameNumber(modelData.value, root.value)
            caption: modelData.label
            onClicked: root.selected(step.modelData.value)

            KitText {
                anchors.centerIn: parent
                role: "body"
                // grows with the step from one base size (see `base`)
                font.pixelSize: Math.max(1, Math.floor(root.base * root.growth(step.modelData.value)))
                font.weight: step.chosen ? Type.weight("title") : Type.weight("body")
                color: step.chosen ? Type.accent : Type.text
                text: root.sample
            }
            Icon {
                visible: step.modelData.max === true
                anchors.right: parent.right
                anchors.top: parent.top
                icon: Icons.sparkle
                role: "caption"
                tone: "accent"
            }
        }
    }
}
