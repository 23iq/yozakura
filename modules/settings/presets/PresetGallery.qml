pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.settings.controls
import qs.modules.settings.store
import "PresetModel.js" as PresetModel
import "../Ui.js" as Ui

// Gallery: search, filter chips and a responsive grid of preset cards.
Column {
    id: root

    property string query: ""
    property string filter: "all"
    readonly property var shown: PresetModel.filter(PresetStudio.presets, query, filter)
    readonly property int columns: Math.max(1, Math.floor((width + grid.spacing) / (250 + grid.spacing)))

    signal openPreset(string name)
    signal cardAction(string name, string id)

    spacing: 16

    Row {
        width: parent.width
        spacing: 10

        TextControl {
            id: search
            objectName: "presetSearch"
            width: Math.min(320, parent.width - filters.width - 10)
            placeholder: I18n.t("prefs.presets.search")
            Connections {
                target: search.input
                function onTextChanged() {
                    root.query = search.input.text;
                }
            }
        }

        Row {
            id: filters
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Repeater {
                model: PresetModel.FILTERS
                Rectangle {
                    id: chip
                    required property string modelData
                    readonly property bool on: root.filter === modelData
                    width: chipText.implicitWidth + 24
                    height: 30
                    radius: height / 2
                    color: on ? Ui.alpha(Colors.primary, 0.18) : (chipArea.containsMouse ? Ui.alpha(Colors.overBackground, 0.08) : "transparent")
                    border.width: 1
                    border.color: on ? Ui.alpha(Colors.primary, 0.6) : Ui.alpha(Colors.outline, 0.3)
                    Text {
                        id: chipText
                        anchors.centerIn: parent
                        text: I18n.t("prefs.presets.filter." + chip.modelData)
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-2)
                        font.weight: chip.on ? Font.Bold : Font.Normal
                        color: chip.on ? Colors.primary : Colors.overSurfaceVariant
                    }
                    MouseArea {
                        id: chipArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.filter = chip.modelData
                    }
                }
            }
        }
    }

    Flow {
        id: grid
        width: parent.width
        spacing: 14

        Repeater {
            model: root.shown
            delegate: PresetCard {
                required property var modelData
                preset: modelData
                width: Math.floor((grid.width - grid.spacing * (root.columns - 1)) / root.columns)
                onOpened: root.openPreset(modelData.name)
                onAction: id => root.cardAction(modelData.name, id)
            }
        }

        // Skeleton cards while the list loads.
        Repeater {
            model: PresetStudio.loaded ? 0 : root.columns
            Rectangle {
                width: Math.floor((grid.width - grid.spacing * (root.columns - 1)) / root.columns)
                height: width * 9 / 16 + 80
                radius: Math.min(Styling.radius(4), 22)
                color: Colors.surfaceContainer
                opacity: 0.6
            }
        }
    }

    Text {
        visible: PresetStudio.loaded && root.shown.length === 0
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        topPadding: 30
        text: root.query ? I18n.t("prefs.presets.no_match", root.query) : I18n.t("prefs.presets.empty")
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-1)
        color: Colors.overSurfaceVariant
        wrapMode: Text.WordWrap
    }
}
