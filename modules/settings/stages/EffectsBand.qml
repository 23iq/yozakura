pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit

// The Effects tab's band (list form): the presets EasyEffects runs now on
// what you hear and on your microphone, and the effects themselves as one
// big tile (off = bypassed). Polls EasyEffects only while shown.
Stage {
    id: band
    objectName: "effectsBand"

    readonly property bool available: EasyEffectsService.available === true
    readonly property bool on: band.available && EasyEffectsService.bypassed !== true

    onVisibleChanged: EasyEffectsService.setConsumer("settingsEffects", band.visible)
    Component.onCompleted: EasyEffectsService.setConsumer("settingsEffects", band.visible)
    Component.onDestruction: EasyEffectsService.setConsumer("settingsEffects", false)

    stageHeight: Space.px(150)

    Row {
        x: Space.xxl
        anchors.verticalCenter: parent.verticalCenter
        spacing: Space.xxl

        Repeater {
            model: [
                {
                    "icon": Icons.speakerHigh,
                    "label": "prefs.effects.on_output",
                    "preset": EasyEffectsService.activeOutputPreset
                },
                {
                    "icon": Icons.mic,
                    "label": "prefs.effects.on_input",
                    "preset": EasyEffectsService.activeInputPreset
                }
            ]
            delegate: Row {
                id: side
                required property var modelData
                spacing: Space.m
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: side.modelData.icon
                    role: "display"
                    tone: band.on ? "accent" : "muted"
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    KitText {
                        role: "secondary"
                        text: I18n.t(side.modelData.label)
                    }
                    KitText {
                        role: "title"
                        text: !band.available ? I18n.t("prefs.effects.missing") : (side.modelData.preset || I18n.t("prefs.effects.none"))
                    }
                }
            }
        }
    }

    Tile {
        objectName: "effectsTile"
        visible: band.available
        anchors.right: parent.right
        anchors.rightMargin: Space.xxl
        anchors.verticalCenter: parent.verticalCenter
        width: Space.controlXL * 2
        icon: Icons.waveform
        text: I18n.t("prefs.effects.effects")
        subtext: I18n.t(band.on ? "prefs.net.on" : "prefs.net.off")
        active: band.on
        onClicked: EasyEffectsService.setBypass(band.on)
    }
}
