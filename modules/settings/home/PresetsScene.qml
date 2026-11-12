pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store

// Home tile scene of Presets: a fan of preset cards in the palette's
// colours.
Item {
    id: scene

    required property Card tile
    readonly property real cardW: Math.min(scene.width * 0.52, scene.height * 1.2)

    Repeater {
        model: [Colors.primary, Colors.tertiary, Colors.secondary]
        delegate: Mark {
            id: card
            required property color modelData
            required property int index
            width: scene.cardW
            height: scene.cardW * 0.62
            radius: Look.radius("box", height)
            x: scene.width * 0.5 - width / 2 + (index - 1) * scene.cardW * 0.42
            y: scene.height * 0.18 + (index === 1 ? 0 : Space.xs)
            rotation: (index - 1) * 8 + (scene.tile.hovered ? (index - 1) * 4 : 0)
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Qt.lighter(card.modelData, 1.1)
                }
                GradientStop {
                    position: 1
                    color: Qt.darker(card.modelData, 1.35)
                }
            }
            border.width: Space.hairline
            border.color: Qt.alpha(Colors.shadow, 0.3)
            Behavior on rotation {
                enabled: Motion.spring.duration > 0
                NumberAnimation {
                    duration: Motion.spring.duration
                    easing.type: Motion.spring.easing
                    easing.overshoot: Motion.spring.overshoot
                }
            }
        }
    }
}
