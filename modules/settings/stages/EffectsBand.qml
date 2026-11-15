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
    // a narrow window: the two sides stack and the tile takes its own width
    readonly property bool compact: band.width < Space.px(900)

    Grid {
        id: sides
        objectName: "effectsSides"
        x: Space.xxl
        width: (tile.visible ? tile.x : band.width - Space.xxl) - x - Space.xl
        anchors.verticalCenter: parent.verticalCenter
        columns: band.compact ? 1 : 2
        columnSpacing: Space.xxl
        rowSpacing: Space.s

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
                // each side has half the room (a column: all of it)
                width: band.compact ? sides.width : (sides.width - sides.columnSpacing) / 2
                spacing: Space.m
                Icon {
                    id: sideIcon
                    anchors.verticalCenter: parent.verticalCenter
                    icon: side.modelData.icon
                    role: band.compact ? "title" : "display"
                    tone: band.on ? "accent" : "muted"
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: side.width - sideIcon.width - side.spacing
                    KitText {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        role: "secondary"
                        text: I18n.t(side.modelData.label)
                    }
                    KitText {
                        // the preset's name is data: it may elide
                        width: Math.min(implicitWidth, parent.width)
                        elide: Text.ElideRight
                        role: band.compact ? "body" : "title"
                        font.weight: Font.DemiBold
                        text: !band.available ? I18n.t("prefs.effects.missing") : (side.modelData.preset || I18n.t("prefs.effects.none"))
                    }
                }
            }
        }
    }

    Tile {
        id: tile
        objectName: "effectsTile"
        visible: band.available
        anchors.right: parent.right
        anchors.rightMargin: Space.xxl
        anchors.verticalCenter: parent.verticalCenter
        width: band.compact ? implicitWidth : Space.controlXL * 2
        icon: Icons.waveform
        text: I18n.t("prefs.effects.effects")
        subtext: I18n.t(band.on ? "prefs.net.on" : "prefs.net.off")
        active: band.on
        onClicked: EasyEffectsService.setBypass(band.on)
    }
}
