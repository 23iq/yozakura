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
FittedFrame {
    id: root

    required property var category
    // a narrow window: the hero keeps the height its actions need and the
    // strip card a height of its own under it; the page scrolls (never a
    // card drawn over the stage)
    stackable: true
    stackedHeight: row.y + row.height + root.pad
    // the preset on the stage ("" = the active one, else the first)
    property string highlighted: ""
    readonly property var presets: PresetStudio.presets || []
    readonly property var shown: PresetModel.byName(root.presets, root.highlighted) || PresetModel.byName(root.presets, PresetStudio.active) || root.presets[0] || null
    readonly property bool locked: PresetStudio.trial !== null || PresetStudio.edit !== null
    readonly property var manager: GlobalStates.wallpaperManager
    readonly property string wallpaperFile: root.manager ? (root.manager.currentWallpaper || "") : ""
    readonly property string wallpaper: root.manager && root.wallpaperFile && root.manager.getDisplaySource ? root.manager.getDisplaySource(root.wallpaperFile) : root.wallpaperFile

    signal action(string name, string id)
    signal openPreset(string name)
    signal saveRequested
    signal mixRequested
    signal importRequested
    signal browseRequested
    // the action column beside the stage: wide enough for two buttons a line
    readonly property real actionsW: Math.round(Math.min(Space.px(300), Math.max(Space.px(240), root.width * 0.25)))

    Component.onCompleted: SchemePreviews.refresh()

    // ---- the hero: the stage and the preset's actions beside it -----------
    Item {
        id: hero
        HoverHandler {
            id: heroHover
        }
        objectName: "pageHero"
        x: root.margin
        y: Space.s
        width: root.width - root.margin * 2
        height: root.stacked ? Math.max(side.y + side.height, stage.height) : root.layoutH - y - hint.height - Space.s - root.gap - root.rowH - Space.l

        Stage {
            id: stage
            objectName: "pageStage"
            readonly property real room: hero.width - root.actionsW - root.gap
            height: Math.round(Math.max(Space.px(160), Math.min(root.stacked ? Space.px(560) : hero.height, room * 9 / 16, Space.px(560))))
            width: Math.round(Math.min(room, height * 16 / 9))
            x: (hero.width - (width + root.gap + root.actionsW)) / 2
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

        PresetSide {
            id: side
            objectName: "presetSide"
            x: stage.x + stage.width + root.gap
            width: root.actionsW
            y: Space.s
            shown: root.shown
            locked: root.locked
            autoSaveEntry: (((root.category.sections || [])[0] || {}).entries || [])[0] || ({})
            onAction: (name, id) => root.action(name, id)
            onOpenPreset: name => root.openPreset(name)
            onSaveRequested: root.saveRequested()
            onMixRequested: root.mixRequested()
            onImportRequested: root.importRequested()
            onBrowseRequested: root.browseRequested()
        }
    }

    // the instruction: only while the pointer is over the stage
    HoverHint {
        id: hint
        shown: heroHover.hovered
        x: root.margin
        y: hero.y + hero.height + Space.s
        width: root.width - root.margin * 2
        // one line on a fitted page: a long translation shrinks a little
        // in a narrow window rather than losing its end
        fontSizeMode: Text.HorizontalFit
        minimumPixelSize: Math.round(Type.size("caption") * 0.85)
        text: I18n.t("prefs.presets.hero_hint")
    }

    // ---- the row: every preset, and the studio's settings -----------------
    Item {
        id: row
        x: root.margin
        y: root.stacked ? hint.y + hint.height + root.gap : root.layoutH - root.rowH - Space.l
        width: root.width - root.margin * 2
        height: root.stacked ? root.cardRowHeight : root.rowH

        Card {
            id: stripCard
            objectName: "settingsSection:presets_gallery"
            readonly property bool fixed: true
            width: row.width
            height: row.height
            padding: Look.boxPadding + Space.s
            spacing: Space.s

            KitText {
                id: heading
                role: "title"
                text: I18n.t("prefs.presets.gallery")
            }

            Item {
                id: stripArea
                width: stripCard.contentWidth
                height: stripCard.height - stripCard.padding * 2 - heading.implicitHeight - stripCard.spacing
                readonly property real cardH: height - Space.s * 2
                // 16:10 pictures; a few presets narrow down (to 5:4) so the
                // strip fits whole and never scrolls
                readonly property real fitW: (width - Space.m * Math.max(0, root.presets.length - 1)) / Math.max(1, root.presets.length)
                readonly property real cardW: Math.round(Math.min(cardH * 16 / 10, Math.max(cardH * 5 / 4, fitW)))

                // no preset yet: while the list loads, quiet placeholders
                // the size of the cards (a slow pulse; none with animations
                // off); once it failed or came back empty, say so
                readonly property bool waiting: root.presets.length === 0 && PresetStudio.error === "" && !stripArea.gaveUp && (PresetStudio.loading || !PresetStudio.loaded)
                // a list that never comes (no backend) is a failure too
                readonly property bool failed: PresetStudio.error !== "" || stripArea.gaveUp
                property bool gaveUp: false
                Timer {
                    interval: 8000
                    running: stripArea.waiting
                    onTriggered: stripArea.gaveUp = true
                }
                Row {
                    objectName: "presetStripLoading"
                    y: Space.s
                    spacing: Space.m
                    visible: stripArea.waiting
                    Repeater {
                        model: Math.max(1, Math.min(5, Math.floor((stripArea.width + Space.m) / (stripArea.cardH * 16 / 10 + Space.m))))
                        delegate: Mark {
                            width: Math.round(stripArea.cardH * 16 / 10)
                            height: stripArea.cardH
                            radius: Look.radius("box", height)
                            color: Look.raisedFill(false)
                            SequentialAnimation on opacity {
                                running: stripArea.waiting && Motion.base > 0
                                loops: Animation.Infinite
                                NumberAnimation {
                                    from: 1
                                    to: 0.5
                                    duration: Motion.palette
                                    easing.type: Easing.InOutSine
                                }
                                NumberAnimation {
                                    from: 0.5
                                    to: 1
                                    duration: Motion.palette
                                    easing.type: Easing.InOutSine
                                }
                            }
                        }
                    }
                }
                Column {
                    objectName: "presetStripEmpty"
                    anchors.centerIn: parent
                    width: Math.min(parent.width, Space.px(420))
                    spacing: Space.s
                    visible: root.presets.length === 0 && !stripArea.waiting
                    KitText {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        role: "body"
                        wrapMode: Text.WordWrap
                        text: stripArea.failed ? I18n.t("prefs.presets.load_failed") : I18n.t("prefs.presets.empty")
                    }
                    KitText {
                        width: parent.width
                        visible: PresetStudio.error !== ""
                        horizontalAlignment: Text.AlignHCenter
                        role: "caption"
                        color: Type.muted
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        text: PresetStudio.error
                    }
                    PillButton {
                        objectName: "presetRetry"
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: stripArea.failed
                        kind: "tonal"
                        icon: Icons.arrowsClockwise
                        text: I18n.t("prefs.presets.retry")
                        onClicked: {
                            PresetStudio.error = "";
                            stripArea.gaveUp = false;
                            PresetStudio.refresh();
                        }
                    }
                }

                // the strip runs on under the card's sides: a masked fade on
                // the side that has more (never painted over the card)
                EdgeFade {
                    anchors.fill: parent
                    horizontal: true
                    start: flick.interactive && flick.contentX > 1 ? Space.xxl : 0
                    end: flick.interactive && flick.contentX < flick.contentWidth - flick.width - 1 ? Space.xxl : 0

                    Flickable {
                        id: flick
                        objectName: "presetStrip"
                        anchors.fill: parent
                        contentWidth: strip.width
                        interactive: contentWidth > width
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        flickableDirection: Flickable.HorizontalFlick
                        // the preset on the stage in view (centred when it can be)
                        function reveal() {
                            const i = root.presets.indexOf(root.shown);
                            if (i < 0 || width <= 0)
                                return;
                            // the least scroll that shows it whole (at rest the
                            // strip starts flush at the card's inset)
                            const w = stripArea.cardW;
                            const left = i * (w + Space.m);
                            if (left < contentX)
                                contentX = Math.max(0, left);
                            else if (left + w > contentX + width)
                                contentX = Math.min(left + w - width, Math.max(0, contentWidth - width));
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
                            y: Space.s
                            spacing: Space.m
                            Repeater {
                                model: root.presets
                                delegate: ChoiceCard {
                                    id: card
                                    required property var modelData
                                    objectName: "presetPick:" + modelData.name
                                    width: stripArea.cardW
                                    previewHeight: stripArea.cardH
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
                }
            }
        }
    }
}
