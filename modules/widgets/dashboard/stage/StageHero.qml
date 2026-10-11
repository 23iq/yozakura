import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.widgets.dashboard.home
import qs.config
import "StageModel.js" as StageModel

// The hero block of the stage home, the left column's main surface: the
// player (StageHeroPlayer) or, with nothing playing, the greeting and the
// large clock (StageHeroIdle), cross-faded. While a cover shows (and
// layout.dashboard.heroTint), ONE tone taken from the art (StageTone)
// floods the block: StageModel.floodTone makes it deep (dark theme) or pale
// (light theme) and saturated, StageModel.tintAlpha holds it back so the
// text keeps its contrast; over it the art, blurred, and a scrim at the
// bottom. The tone cross-fades with the track. Where groups have no box
// (ink), the hero still draws its own faint rounded panel: it is the one
// surface that stands out. With nothing playing a quiet wash of the
// accent (well under the player's flood) keeps it calm, so play and the on
// tiles stay the focal points. Player and idle share one natural height
// and cross-fade with a short rise: starting / stopping never reflows.
Group {
    id: root

    readonly property bool playing: MprisController.activePlayer !== null
    readonly property bool tintOn: Config.layout.dashboard.heroTint ?? true
    readonly property url artUrl: root.playing ? (MprisController.activePlayer?.trackArtUrl ?? "") : ""
    // The art's tone ({r, g, b} or null).
    readonly property var toneRgb: tone.tone
    // Idle (nothing playing) the accent floods the hero instead.
    readonly property var accentRgb: ({
            "r": Type.accent.r,
            "g": Type.accent.g,
            "b": Type.accent.b
        })
    readonly property var sourceRgb: root.playing ? root.toneRgb : root.accentRgb
    readonly property bool tinted: root.tintOn && root.sourceRgb !== null
    readonly property var baseRgb: ({
            "r": Colors.background.r,
            "g": Colors.background.g,
            "b": Colors.background.b
        })
    readonly property var inkRgb: ({
            "r": Type.text.r,
            "g": Type.text.g,
            "b": Type.text.b
        })
    // The art's tone as a deep (dark theme) or pale (light theme) flood.
    readonly property var floodRgb: StageModel.floodTone(root.sourceRgb, StageModel.luminance(root.baseRgb) < 0.4 ? 0.26 : 0.84, 0.42)
    readonly property real alpha: root.tinted ? (root.playing ? StageModel.tintAlpha(root.floodRgb, root.baseRgb, root.inkRgb, 0.95, 4.5) : Look.tonalStrength / 2) : 0
    readonly property real naturalHeight: root.padding * 2 + player.naturalHeight
    // The first focus on open (play), none while idle.
    readonly property Item focusTarget: root.playing ? player.focusTarget : null

    // 1 = player, 0 = idle (animated): the leaving one clears out early, the
    // arriving one comes in late, so they barely overlap.
    property real playT: root.playing ? 1 : 0

    Behavior on playT {
        enabled: Motion.glide.duration > 0
        NumberAnimation {
            duration: Motion.glide.duration
        }
    }

    readonly property bool ownBox: !Look.groupBoxed
    readonly property real boxRadius: Look.groupRadius || Space.controlRadius

    fill: true
    // Natural, not the filled height (a filled Group would echo its height).
    implicitHeight: root.naturalHeight
    padding: Math.max(Look.groupPadding, Space.l)

    Item {
        width: parent.width
        height: root.bodyHeight

        StageTone {
            id: tone
            source: root.tintOn ? root.artUrl : ""
        }

        Rectangle {
            objectName: "heroPanel"
            x: -root.padding
            y: -root.padding
            width: parent.width + root.padding * 2
            height: parent.height + root.padding * 2
            radius: root.boxRadius
            visible: root.ownBox
            color: Type.placeholder
        }

        Item {
            id: wash
            objectName: "heroTint"
            x: -root.padding
            y: -root.padding
            width: parent.width + root.padding * 2
            height: parent.height + root.padding * 2
            opacity: root.tinted ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                enabled: Motion.glide.duration > 0
                NumberAnimation {
                    duration: Motion.glide.duration
                    easing.type: Motion.glide.easing
                }
            }

            HomeArtGlow {
                anchors.fill: parent
                radius: root.boxRadius
                source: root.tinted && root.playing ? root.artUrl : ""
                strength: root.alpha * 0.55
                saturation: 0.7
            }

            Rectangle {
                anchors.fill: parent
                radius: root.boxRadius
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: Qt.rgba(tint.color.r, tint.color.g, tint.color.b, root.alpha)
                    }
                    GradientStop {
                        position: 1
                        color: Qt.rgba(tint.color.r, tint.color.g, tint.color.b, root.alpha * 0.8)
                    }
                }
            }

            // Legibility scrim under the timeline and the transport.
            Rectangle {
                anchors.fill: parent
                radius: root.boxRadius
                gradient: Gradient {
                    GradientStop {
                        position: 0.45
                        color: "transparent"
                    }
                    GradientStop {
                        position: 1
                        color: Qt.alpha(Colors.background, 0.32)
                    }
                }
            }
            // The tone, animated on track change.
            QtObject {
                id: tint
                property color color: root.floodRgb ? Qt.rgba(root.floodRgb.r, root.floodRgb.g, root.floodRgb.b, 1) : Type.placeholder

                Behavior on color {
                    enabled: Motion.glide.duration > 0
                    ColorAnimation {
                        duration: Motion.glide.duration
                    }
                }
            }
        }

        StageHeroPlayer {
            id: player
            objectName: "heroPlayer"
            anchors.fill: parent
            opacity: Math.max(0, (root.playT - 0.35) / 0.65)
            visible: opacity > 0
            transform: Translate {
                y: (1 - player.opacity) * Space.m
            }
        }

        StageHeroIdle {
            id: idle
            objectName: "heroIdle"
            anchors.fill: parent
            opacity: 1 - Math.min(1, root.playT * 1.6)
            visible: opacity > 0
            transform: Translate {
                y: (1 - idle.opacity) * Space.m
            }
        }
    }
}
