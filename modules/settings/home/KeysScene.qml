pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store

// Home tile scene of Keys: keycaps of a shortcut, its key lit in the accent.
Flow {
    id: scene

    required property Card tile

    spacing: Space.s
    Repeater {
        model: ["Super", "Space", "⇧", "Alt", "C", "Tab"]
        delegate: Mark {
            id: cap
            required property string modelData
            readonly property bool lit: modelData === "C"
            width: Math.max(Space.controlL * 0.75, capText.implicitWidth + Space.l * 2) * (modelData === "Space" ? 1.6 : 1)
            height: Space.controlL * 0.75
            radius: Look.radius("box", height)
            color: cap.lit ? Type.accent : Look.raisedFill(false)
            border.width: Space.hairline
            border.color: Qt.alpha(Colors.shadow, 0.35)
            KitText {
                id: capText
                anchors.centerIn: parent
                role: "body"
                font.weight: Font.DemiBold
                color: cap.lit ? Colors.overPrimary : Type.text
                text: cap.modelData
            }
        }
    }
}
