pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.globals
import qs.modules.settings
import qs.modules.settings.store
import "PresetModel.js" as PresetModel
import "../Ui.js" as Ui

// Mixer: build a new preset by taking each aspect (layout, colors & glass,
// windows & motion, desktop, lockscreen) from any preset, preview the
// combination live, then save it (`preset mix`).
Item {
    id: root

    property var sources: ({})
    readonly property bool wide: width >= 860
    readonly property var look: PresetModel.composeLook(PresetStudio.aspects, PresetStudio.presets, sources, PresetStudio.active)
    readonly property var manager: GlobalStates.wallpaperManager
    readonly property string wallpaper: manager && manager.currentWallpaper && manager.getDisplaySource ? manager.getDisplaySource(manager.currentWallpaper) : ""

    signal askName(string suggestion, var sources)

    implicitHeight: wide ? Math.max(list.implicitHeight, preview.implicitHeight) : list.implicitHeight + preview.implicitHeight + 20

    function reset() {
        sources = PresetModel.defaultSources(PresetStudio.aspects, PresetStudio.presets, PresetStudio.active);
    }

    function setSource(id, name) {
        const s = Object.assign({}, sources);
        s[id] = name;
        sources = s;
    }

    Component.onCompleted: {
        reset();
        SchemePreviews.refresh();
    }
    Connections {
        target: PresetStudio
        function onAspectsChanged() {
            if (Object.keys(root.sources).length === 0)
                root.reset();
        }
        function onPresetsChanged() {
            if (Object.keys(root.sources).length === 0)
                root.reset();
        }
    }

    Column {
        id: preview
        x: root.wide ? root.width - width : 0
        width: root.wide ? Math.round(root.width * 0.46) : root.width
        spacing: 12

        ClippingRectangle {
            width: parent.width
            height: Math.round(width * 9 / 16)
            radius: Math.min(Styling.radius(4), 20)
            color: Colors.surfaceContainerHigh
            border.width: 1
            border.color: Ui.alpha(Colors.outlineVariant, 0.6)
            PresetMiniShell {
                objectName: "mixerPreview"
                anchors.fill: parent
                look: root.look
                colorMap: PresetModel.paletteFor(root.look, SchemePreviews.palettes)
                wallpaper: root.wallpaper
            }
        }
        Text {
            width: parent.width
            text: I18n.t("prefs.presets.mixer.preview_hint")
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            color: Colors.overSurfaceVariant
            wrapMode: Text.WordWrap
        }
        Row {
            spacing: 8
            PillButton {
                objectName: "mixerCreate"
                kind: "filled"
                icon: "plus"
                text: I18n.t("prefs.presets.mixer.create")
                enabled: PresetStudio.presets.length > 0
                onClicked: root.askName(PresetModel.uniqueName(PresetStudio.presets, I18n.t("prefs.presets.mixer.default_name")), root.sources)
            }
            PillButton {
                kind: "tonal"
                icon: "shuffle"
                text: I18n.t("prefs.presets.mixer.shuffle")
                onClicked: root.sources = PresetModel.shuffle(PresetStudio.aspects, PresetStudio.presets)
            }
            PillButton {
                kind: "ghost"
                icon: "arrowCounterClockwise"
                text: I18n.t("prefs.presets.mixer.reset")
                onClicked: root.reset()
            }
        }
    }

    Column {
        id: list
        y: root.wide ? 0 : preview.height + 20
        width: root.wide ? root.width - preview.width - 24 : root.width
        spacing: 10

        Repeater {
            model: PresetStudio.aspects
            delegate: Rectangle {
                id: row
                required property var modelData
                width: list.width
                height: Math.max(76, rowText.implicitHeight + 28)
                radius: Math.min(Styling.radius(3), 18)
                color: Colors.surfaceContainer
                border.width: 1
                border.color: Ui.alpha(Colors.outlineVariant, 0.5)
                objectName: "mixerAspect:" + modelData.id

                Rectangle {
                    id: tile
                    x: 14
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40
                    height: 40
                    radius: Math.min(Styling.radius(2), 14)
                    color: Ui.alpha(Colors.primary, 0.14)
                    Text {
                        anchors.centerIn: parent
                        text: Icons[PresetModel.aspectIcon(row.modelData.id)] ?? ""
                        font.family: Icons.font
                        font.pixelSize: 19
                        color: Colors.primary
                    }
                }
                Column {
                    id: rowText
                    anchors.left: tile.right
                    anchors.leftMargin: 12
                    anchors.right: picker.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Text {
                        width: parent.width
                        text: I18n.t("prefs.presets.aspect." + row.modelData.id)
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(0)
                        font.weight: Font.DemiBold
                        color: Colors.overBackground
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: I18n.t("prefs.presets.aspect." + row.modelData.id + ".desc")
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-2)
                        color: Colors.overSurfaceVariant
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                }
                PresetPicker {
                    id: picker
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(200, row.width * 0.42)
                    value: root.sources[row.modelData.id] || ""
                    onPicked: v => root.setSource(row.modelData.id, v)
                }
            }
        }
    }
}
