pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Particles
import qs.config
import qs.modules.theme
import qs.modules.components.signatures
import qs.modules.components.kit

// Signature (theme.signatures.petals): a few sakura petals, or maple leaves
// (theme.signatures.petalShape "leaf"), falling slowly behind the lock screen
// content. At most `cap` alive at once, palette colors; no particle system
// exists while the signature is off or quiet, or the motion profile is off
// (even when the profile does not drive the shell's own durations).
// Petal spin is a share of `lifeMs` (Motion has no ambient token).
Loader {
    id: root

    readonly property int cap: 40
    readonly property int lifeMs: 20000
    // One full turn takes 0.45-0.9 of this (petals), leaves turn slower.
    readonly property int spinMs: lifeMs
    readonly property bool leaves: (Config.theme.signatures || {}).petalShape === "leaf"
    readonly property bool motionOff: !!Config.motionProfile && !!Config.motionProfile.disabled

    anchors.fill: parent
    active: Signatures.petals && !motionOff

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
            size: Space.s
            sizeVariation: Space.xs
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
                width: Space.s
                height: Math.round(Space.s * 0.66)
                radius: height / 2
                color: Qt.alpha(sky.tints[pick], 0.45)
                rotation: Math.random() * 360
                RotationAnimator on rotation {
                    from: petalItem.rotation
                    to: petalItem.rotation + (Math.random() < 0.5 ? -360 : 360)
                    duration: Math.round(root.spinMs * (0.45 + Math.random() * 0.45))
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
                size: Space.s + Math.random() * Space.s * 0.75
                color: Qt.alpha(sky.tints[pick], 0.6)
                rotation: Math.random() * 360
                RotationAnimator on rotation {
                    from: leafItem.rotation
                    to: leafItem.rotation + (Math.random() < 0.5 ? -200 : 200)
                    duration: Math.round(root.spinMs * (0.35 + Math.random() * 0.35))
                    loops: Animation.Infinite
                }
            }
        }
    }
}
