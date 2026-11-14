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
    // the loudest visualizer bar, while this band is on screen
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
            height: Math.max(Space.controlL, Math.round(band.height * 0.3))
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

            // 100 %: where amplification starts
            Mark {
                objectName: "fullMark"
                x: Math.round(slider.cap + slider.span / slider.to - width / 2)
                y: Math.round(slider.height * 0.25)
                width: Space.hairline * 2
                height: Math.round(slider.height * 0.5)
                color: Type.secondary
                opacity: 0.7
            }
        }
        // the live meter: a thin line under the slider's track
        Item {
            objectName: ch.objectName + "Meter"
            visible: ch.level >= 0
            x: slider.cap
            width: slider.span
            height: Space.xs
            readonly property real level: Math.max(0, ch.level)
            Mark {
                width: parent.width
                height: parent.height
                color: Look.raisedFill(false)
            }
            Mark {
                width: Math.round(parent.width * parent.level)
                height: parent.height
                color: Type.secondary
            }
        }
    }
}
