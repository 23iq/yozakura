pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.settings
import qs.modules.settings.controls
import qs.modules.settings.previews
import qs.modules.settings.store
import qs.modules.components.surfaceeffects
import "../../components/surfaceeffects/SurfaceEffects.js" as SurfaceEffects

// Surface effect picker (theme.surfaceEffect): every registered effect
// (SurfaceEffects.js) previewed live on a mini bar + panel, with the real
// effect component at the current intensity.
Item {
    id: root

    property var entry
    readonly property string current: SettingsStore.get("theme.surfaceEffect") || SurfaceEffects.DEFAULT_ID
    readonly property var effects: SurfaceEffects.ids()
    readonly property int columns: width < 480 ? 1 : Math.min(3, effects.length)

    implicitHeight: grid.implicitHeight

    Grid {
        id: grid
        width: parent.width
        columns: root.columns
        spacing: 12

        Repeater {
            model: root.effects

            delegate: ChoiceCard {
                id: card
                required property string modelData
                width: (grid.width - grid.spacing * (root.columns - 1)) / root.columns
                previewHeight: 104
                selected: root.current === modelData
                title: I18n.t("prefs.effects." + modelData)
                subtitle: I18n.t("prefs.effects." + modelData + ".desc")
                onClicked: SettingsStore.set("theme.surfaceEffect", modelData)

                ScreenBackdrop {
                    anchors.fill: parent

                    SurfaceSample {
                        objectName: "effectBar:" + card.modelData
                        effectId: card.modelData
                        x: 8
                        y: 8
                        width: parent.width - 16
                        height: 22
                        label: "1  2  3"
                    }

                    SurfaceSample {
                        objectName: "effectPanel:" + card.modelData
                        effectId: card.modelData
                        x: parent.width * 0.18
                        y: 38
                        width: parent.width * 0.64
                        height: parent.height - 46
                        label: "Aa"
                        selection: true
                    }
                }
            }
        }
    }

    // A tiny surface (background + the effect + text, optionally a
    // selected row drawn the way the effect draws highlights).
    component SurfaceSample: Rectangle {
        id: sample

        property string effectId
        property string label
        property bool selection: false
        readonly property string highlightUrl: SurfaceFx.highlightUrlFor(effectId)

        radius: Math.min(Styling.radius(0), 10)
        color: Colors.background
        clip: true

        Loader {
            anchors.fill: parent
            active: SurfaceFx.urlFor(sample.effectId) !== ""
            source: active ? SurfaceFx.urlFor(sample.effectId) : ""
            onLoaded: {
                item.strength = Qt.binding(() => SurfaceFx.strengthFor(sample.effectId, SurfaceFx.options.intensity));
                item.cornerRadius = Qt.binding(() => sample.radius);
            }
        }

        Item {
            id: row
            visible: sample.selection
            x: 8
            y: sample.height - height - 8
            width: sample.width - 16
            height: 18

            Rectangle {
                anchors.fill: parent
                visible: sample.highlightUrl === ""
                radius: Math.min(Styling.radius(0), height / 2)
                color: Colors.primary
            }
            Loader {
                anchors.fill: parent
                active: sample.highlightUrl !== ""
                source: active ? sample.highlightUrl : ""
                onLoaded: {
                    item.fillColor = Qt.binding(() => Colors.primary);
                    item.strength = Qt.binding(() => SurfaceFx.strengthFor(sample.effectId, SurfaceFx.options.intensity));
                }
            }
            Text {
                anchors.centerIn: parent
                text: "Selected"
                font.family: Config.theme.font
                font.pixelSize: 10
                color: Colors.overPrimary
            }
        }

        Text {
            x: 8
            y: sample.selection ? 6 : (sample.height - height) / 2
            text: sample.label
            font.family: Config.theme.font
            font.pixelSize: sample.selection ? 14 : 10
            font.weight: Font.DemiBold
            color: Colors.overBackground
        }
    }
}
