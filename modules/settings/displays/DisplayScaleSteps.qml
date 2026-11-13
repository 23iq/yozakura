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

    spacing: Space.s

    Repeater {
        model: root.shown
        delegate: PickTile {
            id: step
            required property var modelData
            objectName: "scaleStep:" + modelData.value
            width: (root.width - root.spacing * (root.shown.length - 1)) / Math.max(1, root.shown.length)
            height: root.height
            chosen: DisplayFormat.sameNumber(modelData.value, root.value)
            caption: modelData.label
            onClicked: root.selected(step.modelData.value)

            KitText {
                anchors.centerIn: parent
                role: "body"
                font.pixelSize: Math.round(Type.size("caption") * (0.7 + step.modelData.value * 0.5))
                font.weight: step.chosen ? Type.weight("title") : Type.weight("body")
                color: step.chosen ? Type.accent : Type.text
                text: "Aa"
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
