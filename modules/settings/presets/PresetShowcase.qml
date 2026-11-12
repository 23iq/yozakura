pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.modules.theme
import qs.modules.globals
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings
import qs.modules.settings.store
import qs.modules.settings.stages
import qs.modules.settings.controls
import "PresetModel.js" as PresetModel

// The preset studio's gallery as one fitted screen (the page template):
// the stage is a large live miniature of the highlighted preset on your
// wallpaper (PresetMiniShell with the palette it gives), beside it its name,
// author, tags and the clear actions (Apply, Try, Edit; Save the current
// look, Mix, Import); under it one row of cards: every preset as a strip of
// pictures (the active one ringed; a click looks at it on the stage) and
// the studio's own settings. Nothing scrolls but the strip.
Item {
    id: root

    required property var category
    // the preset on the stage ("" = the active one, else the first)
    property string highlighted: ""
    readonly property var presets: PresetStudio.presets || []
    readonly property var shown: PresetModel.byName(root.presets, root.highlighted) || PresetModel.byName(root.presets, PresetStudio.active) || root.presets[0] || null
    readonly property bool locked: PresetStudio.trial !== null || PresetStudio.edit !== null
    readonly property var manager: GlobalStates.wallpaperManager
    readonly property string wallpaperFile: root.manager ? (root.manager.currentWallpaper || "") : ""
    readonly property string wallpaper: root.manager && root.wallpaperFile && root.manager.getDisplaySource ? root.manager.getDisplaySource(root.wallpaperFile) : root.wallpaperFile
    readonly property real margin: Space.xl
    readonly property real gap: Space.l
    readonly property real rowH: Look.cardRowHeight
    readonly property real sideW: Math.min(Space.px(240), root.width * 0.21)

    signal action(string name, string id)
    signal openPreset(string name)
    signal saveRequested
    signal mixRequested
    signal importRequested
    signal browseRequested

    Component.onCompleted: SchemePreviews.refresh()

    // ---- the hero: the stage and the preset's actions beside it -----------
    Item {
        id: hero
        objectName: "pageHero"
        x: root.margin
        y: Space.s
        width: root.width - root.margin * 2
        height: root.height - y - hint.height - Space.s - root.gap - root.rowH - Space.l

        Stage {
            id: stage
            objectName: "pageStage"
            readonly property real room: hero.width - root.sideW - root.gap
            height: Math.round(Math.max(Space.px(160), Math.min(hero.height, room * 9 / 16, Space.px(560))))
            width: Math.round(Math.min(room, height * 16 / 9))
            x: (hero.width - (width + root.gap + root.sideW)) / 2
            backdrop: false

            // a deep shadow under the stage
            RectangularShadow {
                z: -1
                anchors.fill: parent
                radius: Look.radius("surface", parent.height)
                offset: Qt.vector2d(0, Space.l)
                blur: Space.xxl * 2
                color: Qt.alpha(Colors.shadow, 0.55)
            }

            PresetMiniShell {
                objectName: "presetStageShell"
                anchors.fill: parent
                look: root.shown ? (root.shown.look || ({})) : ({})
                colorMap: root.shown ? PresetModel.paletteFor(root.shown.look, SchemePreviews.palettes, ColorPresetPalettes.palettes) : null
                wallpaper: root.wallpaper
            }
        }

        Column {
            id: side
            objectName: "presetSide"
            x: stage.x + stage.width + root.gap
            width: root.sideW
            y: Space.s
            spacing: Space.s

            KitText {
                objectName: "presetName"
                width: parent.width
                role: "title"
                text: root.shown ? root.shown.name : ""
                elide: Text.ElideRight
            }
            KitText {
                width: parent.width
                visible: text !== ""
                role: "secondary"
                text: root.shown && root.shown.author ? root.shown.author : ""
                elide: Text.ElideRight
            }
            Flow {
                width: parent.width
                spacing: Space.xs
                Repeater {
                    model: root.shown ? (root.shown.tags || []).slice(0, 4) : []
                    delegate: Chip {
                        required property string modelData
                        dense: true
                        quiet: true
                        enabled: false
                        text: I18n.t(PresetModel.tagLabel(modelData))
                    }
                }
            }
            Item {
                width: 1
                height: Space.s
            }
            PillButton {
                objectName: "presetApply"
                width: parent.width
                kind: "filled"
                icon: root.shown && root.shown.active ? "check" : "magicWand"
                text: root.shown && root.shown.active ? I18n.t("prefs.presets.in_use") : I18n.t("prefs.presets.apply")
                enabled: !!root.shown && !root.shown.active && !root.locked
                onClicked: root.action(root.shown.name, "apply")
            }
            PillButton {
                objectName: "presetTry"
                width: parent.width
                kind: "tonal"
                icon: "clock"
                text: I18n.t("prefs.presets.try", PresetStudio.trialSeconds)
                enabled: !!root.shown && !root.shown.active && !root.locked
                onClicked: root.action(root.shown.name, "try")
            }
            PillButton {
                objectName: "presetEdit"
                width: parent.width
                kind: "ghost"
                icon: "pencil"
                text: I18n.t("prefs.presets.edit")
                enabled: !!root.shown
                onClicked: root.openPreset(root.shown.name)
            }
        }

        // the studio's own actions: save what is on screen now (a card),
        // then mix, browse everything, import, on the stage's foot
        Card {
            objectName: "presetSaveCard"
            x: side.x
            y: studio.y - height - Space.s
            width: root.sideW
            padding: Space.s
            shadow: false
            PillButton {
                objectName: "saveCurrentLook"
                width: parent.width
                kind: "ghost"
                icon: "plus"
                text: I18n.t("prefs.presets.save_current")
                onClicked: root.saveRequested()
            }
        }
        Row {
            id: studio
            objectName: "presetStudioActions"
            x: side.x
            y: stage.height - height
            spacing: Space.xs
            IconButton {
                objectName: "presetMix"
                size: "s"
                icon: Icons.faders
                tooltip: I18n.t("prefs.presets.tab.mixer")
                onClicked: root.mixRequested()
            }
            IconButton {
                objectName: "presetBrowse"
                size: "s"
                icon: Icons.squaresFour
                tooltip: I18n.t("prefs.presets.browse")
                onClicked: root.browseRequested()
            }
            IconButton {
                objectName: "importPreset"
                size: "s"
                icon: Icons.downloadSimple
                tooltip: I18n.t("prefs.presets.import")
                onClicked: root.importRequested()
            }
        }
    }

    KitText {
        id: hint
        objectName: "heroHint"
        x: root.margin
        y: hero.y + hero.height + Space.s
        width: root.width - root.margin * 2
        horizontalAlignment: Text.AlignHCenter
        role: "secondary"
        text: I18n.t("prefs.presets.hero_hint")
    }

    // ---- the row: every preset, and the studio's settings -----------------
    Item {
        id: row
        x: root.margin
        y: root.height - root.rowH - Space.l
        width: root.width - root.margin * 2
        height: root.rowH
        readonly property real savingW: Math.round((row.width - root.gap) * 0.24)

        Card {
            id: stripCard
            objectName: "settingsSection:presets_gallery"
            readonly property bool fixed: true
            width: row.width - row.savingW - root.gap
            height: row.height
            padding: Look.boxPadding + Space.s
            spacing: Space.s

            Item {
                width: stripCard.contentWidth
                height: Math.max(heading.implicitHeight, count.implicitHeight)
                KitText {
                    id: heading
                    role: "title"
                    text: I18n.t("prefs.presets.gallery")
                }
                KitText {
                    id: count
                    anchors.right: parent.right
                    anchors.verticalCenter: heading.verticalCenter
                    role: "secondary"
                    text: PresetStudio.active ? PresetStudio.active : I18n.t("prefs.presets.custom")
                }
            }

            Item {
                width: stripCard.contentWidth
                height: stripCard.height - stripCard.padding * 2 - heading.implicitHeight - stripCard.spacing
                readonly property real cardH: height - Space.s * 2
                readonly property real cardW: Math.round(cardH * 16 / 10)

                Flickable {
                    id: flick
                    objectName: "presetStrip"
                    anchors.fill: parent
                    contentWidth: strip.width + Space.m * 2
                    interactive: contentWidth > width
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    flickableDirection: Flickable.HorizontalFlick
                    // the preset on the stage in view (centred when it can be)
                    function reveal() {
                        const i = root.presets.indexOf(root.shown);
                        if (i < 0 || width <= 0)
                            return;
                        const w = flick.parent.cardW;
                        contentX = Math.max(0, Math.min(Space.m + i * (w + Space.m) - (width - w) / 2, contentWidth - width));
                    }
                    onContentWidthChanged: Qt.callLater(flick.reveal)
                    Connections {
                        target: root
                        function onShownChanged() {
                            Qt.callLater(flick.reveal);
                        }
                    }

                    Row {
                        id: strip
                        x: Space.m
                        y: Space.s
                        spacing: Space.m
                        Repeater {
                            model: root.presets
                            delegate: ChoiceCard {
                                id: card
                                required property var modelData
                                objectName: "presetPick:" + modelData.name
                                width: flick.parent.cardW
                                previewHeight: flick.parent.cardH
                                inset: true
                                selected: !!modelData.active
                                title: modelData.name
                                onClicked: root.highlighted = card.modelData.name

                                // the preset's miniature, built off the frame
                                Loader {
                                    anchors.fill: parent
                                    asynchronous: true
                                    opacity: status === Loader.Ready ? 1 : 0
                                    sourceComponent: PresetMiniShell {
                                        look: card.modelData.look || ({})
                                        colorMap: PresetModel.paletteFor(card.modelData.look, SchemePreviews.palettes, ColorPresetPalettes.palettes)
                                        wallpaper: root.wallpaper
                                    }
                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: Motion.micro.duration
                                        }
                                    }
                                }
                                // on the stage now
                                Mark {
                                    visible: root.shown && root.shown.name === card.modelData.name && !card.selected
                                    anchors.fill: parent
                                    radius: card.radius
                                    color: "transparent"
                                    border.width: Space.stroke - 1
                                    border.color: Type.text
                                }
                            }
                        }
                    }
                }
                StripFade {
                    flick: flick
                }
            }
        }

        SettingsSection {
            objectName: "settingsSection:presets_saving"
            x: stripCard.width + root.gap
            width: row.savingW
            height: row.height
            section: (root.category.sections || [])[0] || ({
                    "id": "presets_saving",
                    "entries": []
                })
            fixed: true
        }
    }
}
