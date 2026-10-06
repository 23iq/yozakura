pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Particles
import qs.config
import qs.modules.theme
import qs.modules.components.signatures

// Signature (theme.signatures.petals): a few sakura petals falling slowly
// behind the lock screen content. At most `cap` alive at once, palette
// colors; no particle system exists while the signature is off or quiet.
Loader {
    id: root

    readonly property int cap: 40
    readonly property int lifeMs: 20000

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
            delegate: Rectangle {
                id: petal
                readonly property int pick: Math.floor(Math.random() * sky.tints.length)
                width: 9
                height: 6
                radius: height / 2
                color: Qt.alpha(sky.tints[pick], 0.45)
                rotation: Math.random() * 360
                RotationAnimator on rotation {
                    from: petal.rotation
                    to: petal.rotation + (Math.random() < 0.5 ? -360 : 360)
                    duration: 9000 + Math.random() * 9000
                    loops: Animation.Infinite
                }
            }
        }
    }
}
