pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "../connect/ConnectModel.js" as ConnectModel

// The Sound page's band (list form): what you hear and what hears you, as
// two big volume sliders under their device's name; the icon mutes.
// One fill tone: the live meter of what is playing (the visualizer's
// levels, read only while the page is shown) is a thin line of its own
// under the output slider, never a second fill inside it; the volume goes
// to 150 %, so a tick on the track marks 100 % (past it the sound is
// amplified). Changes apply at once.
Stage {
    id: band
    objectName: "soundBand"

    readonly property var sink: Audio.sink ?? null
    readonly property var source: Audio.source ?? null
    // the loudest visualizer bar, while this band is on screen (Settings in
    // its own process, performance.separateWindows, runs a second cava for
    // as long as the Sound tab shows: same config, same runtime file;
    // accepted, a level meter is worth one short-lived capture)
    readonly property bool metering: band.visible && CavaService.available !== false
    readonly property real level: band.metering && CavaService.values ? Math.min(1, Math.max.apply(null, [0].concat(CavaService.values))) : -1

    onMeteringChanged: CavaService.setConsumer("settingsSound", band.metering)
    Component.onCompleted: CavaService.setConsumer("settingsSound", band.metering)
    Component.onDestruction: CavaService.setConsumer("settingsSound", false)

    stageHeight: Space.px(150)

    Row {
        anchors.centerIn: parent
        width: parent.width - Space.xxl * 2
        spacing: Space.xxl

        Channel {
            objectName: "soundOutput"
            width: (parent.width - parent.spacing) / 2
            title: I18n.t("prefs.sound.output")
            device: band.sink ? Audio.friendlyDeviceName(band.sink) : I18n.t("prefs.sound.no_device")
            node: band.sink
            icon: Audio.volumeIcon(band.sink?.audio?.volume ?? 0, band.sink?.audio?.muted ?? false)
            level: band.level
            onVolumeSet: v => Audio.setVolume(v)
            onMuteClicked: Audio.toggleMute()
        }
        Channel {
            objectName: "soundInput"
            width: (parent.width - parent.spacing) / 2
            title: I18n.t("prefs.sound.input")
            device: band.source ? Audio.friendlyDeviceName(band.source) : I18n.t("prefs.sound.no_device")
            node: band.source
            icon: band.source?.audio?.muted ? Icons.micSlash : Icons.mic
            onVolumeSet: v => Audio.setMicVolume(v)
            onMuteClicked: Audio.toggleMicMute()
        }
    }

    // One side: "Output · Speakers" over a big slider.
    component Channel: Column {
        id: ch
        property string title: ""
        property string device: ""
        property var node: null
        property string icon: ""
        // the live meter (0..1, -1 = none)
        property real level: -1
        readonly property real volume: Number(ch.node?.audio?.volume ?? 0)
        readonly property bool muted: ch.node?.audio?.muted === true
        signal volumeSet(real value)
        signal muteClicked

        spacing: Space.s
        Row {
            spacing: Space.s
            KitText {
                anchors.baseline: deviceName.baseline
                role: "secondary"
                text: ch.title
            }
            KitText {
                id: deviceName
                role: "title"
                text: ch.device
            }
        }
        LevelSlider {
            id: slider
            objectName: ch.objectName + "Slider"
            width: ch.width
            height: Space.controlM + Space.s
            enabled: ch.node !== null
            from: 0
            to: 1.5
            step: 0.05
            value: ch.volume
            icon: ch.icon
            iconClickable: true
            dimmed: ch.muted
            valueText: ConnectModel.percent(ch.volume)
            onMoved: v => ch.volumeSet(v)
            onIconClicked: ch.muteClicked()

            // 100 %: a quiet notch line inside the track (past it the sound
            // is amplified), named on hover; none when the range ends at 100 %
            Item {
                id: full
                objectName: "fullMark"
                visible: slider.to > 1.001
                x: Math.round(slider.cap + slider.span / slider.to - width / 2)
                width: Space.l
                height: slider.height
                Mark {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    width: Space.hairline
                    height: parent.height - Space.s * 2
                    radius: 0
                    color: Qt.alpha(Type.text, 0.35)
                }
                HoverHandler {
                    id: fullHover
                }
                Tooltip {
                    text: "100 %"
                    shown: fullHover.hovered
                }
            }
            // the live meter of what is playing: a thin line along the
            // track's own foot, inside its rounded ends
            Item {
                objectName: ch.objectName + "Meter"
                visible: ch.level >= 0
                readonly property real level: Math.max(0, ch.level)
                x: Math.round(slider.cap / 2)
                width: slider.width - slider.cap
                height: Space.hairline * 2
                y: slider.height - Space.xs - height
                Mark {
                    width: Math.round(parent.width * parent.level)
                    height: parent.height
                    color: Type.secondary
                }
            }
        }
    }
}
