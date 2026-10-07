pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Particles
import qs.config
import qs.modules.theme
import qs.modules.components.signatures

// Signature (theme.signatures.petals): a few sakura petals, or maple leaves
// (theme.signatures.petalShape "leaf"), falling slowly behind the lock screen
// content. At most `cap` alive at once, palette colors; no particle system
// exists while the signature is off or quiet.
Loader {
    id: root

    readonly property int cap: 40
    readonly property int lifeMs: 20000
    readonly property bool leaves: (Config.theme.signatures || {}).petalShape === "leaf"

    anchors.fill: parent
    active: Signatures.petals

    sourceComponent: Item {
        id: sky

        readonly property var tints: [Colors.primary, Colors.tertiary, Colors.secondary]

        ParticleSystem {
            id: system
            running: true
        }

        Emitter {
            system: system
            width: sky.width
            height: 1
            y: -12
            emitRate: root.cap / (root.lifeMs / 1000) * 0.9
            lifeSpan: root.lifeMs
            lifeSpanVariation: 4000
            maximumEmitted: root.cap
            size: 9
            sizeVariation: 4
            velocity: AngleDirection {
                angle: 90
                angleVariation: 12
                magnitude: sky.height / (root.lifeMs / 1000) * 1.15
                magnitudeVariation: 10
            }
        }

        Wander {
            system: system
            xVariance: 14
            pace: 40
        }

        ItemParticle {
            system: system
            fade: true
            delegate: root.leaves ? leaf : petal
        }

        Component {
            id: petal

            Rectangle {
                id: petalItem
                readonly property int pick: Math.floor(Math.random() * sky.tints.length)
                width: 9
                height: 6
                radius: height / 2
                color: Qt.alpha(sky.tints[pick], 0.45)
                rotation: Math.random() * 360
                RotationAnimator on rotation {
                    from: petalItem.rotation
                    to: petalItem.rotation + (Math.random() < 0.5 ? -360 : 360)
                    duration: 9000 + Math.random() * 9000
                    loops: Animation.Infinite
                }
            }
        }

        Component {
            id: leaf

            MapleLeaf {
                id: leafItem
                readonly property int pick: Math.floor(Math.random() * sky.tints.length)
                objectName: "mapleLeaf"
                size: 10 + Math.random() * 6
                color: Qt.alpha(sky.tints[pick], 0.6)
                rotation: Math.random() * 360
                RotationAnimator on rotation {
                    from: leafItem.rotation
                    to: leafItem.rotation + (Math.random() < 0.5 ? -200 : 200)
                    duration: 7000 + Math.random() * 7000
                    loops: Animation.Infinite
                }
            }
        }
    }
}
