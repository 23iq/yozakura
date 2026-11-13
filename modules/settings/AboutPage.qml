import QtQuick
import QtQuick.Effects
import Quickshell
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.stages
import qs.modules.settings.store
import qs.config
import qs.modules.globals

// About, composed like the other pages: the identity scene on the stage
// (a plain card fill, no wallpaper: About is not a desktop page; the mark glowing, the name, the version, one line about
// it), then one row of cards: the version and its updates, the useful
// places (setup again, the config folder, the source) and the legal notes.
FittedFrame {
    id: page
    stackable: true
    stackedHeight: cards.y + cards.height + page.pad
    hasHint: false

    required property var category

    // the identity scene
    Stage {
        id: scene
        readonly property bool fittedHero: true
        objectName: "aboutScene"
        calm: true
        readonly property real room: page.height - Space.s - page.gap - page.rowH - page.pad
        x: Math.round((page.width - width) / 2)
        y: Space.s
        height: Math.round(Math.max(Space.px(160), Math.min(scene.room, (page.width - page.margin * 2) * 9 / 16, Space.px(560))))
        width: Math.round(Math.min(page.width - page.margin * 2, height * 16 / 9))

        Column {
            anchors.centerIn: parent
            width: parent.width * 0.8
            spacing: Space.m

            // the mark, with a soft glow
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.round(scene.height * 0.32)
                height: width
                Image {
                    id: logo
                    anchors.fill: parent
                    source: Qt.resolvedUrl("../../assets/yozakura/yozakura-icon.svg")
                    sourceSize.width: width * 2
                    sourceSize.height: height * 2
                    fillMode: Image.PreserveAspectFit
                    mipmap: true
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        brightness: 1.0
                        colorization: 1.0
                        colorizationColor: Type.accent
                        shadowEnabled: true
                        shadowColor: Type.accent
                        shadowBlur: 1.0
                        shadowOpacity: 0.6
                    }
                }
            }
            KitText {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                role: "display"
                text: Brand.displayName
            }
            KitText {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                role: "body"
                wrapMode: Text.WordWrap
                text: I18n.t("prefs.about.blurb")
            }
        }
    }

    // the row of cards
    Flow {
        id: cards
        objectName: "aboutRow"
        x: page.margin
        // stacked (narrow window): under the hint, one card a line
        y: page.stacked ? scene.y + scene.height + page.gap : page.height - page.rowH - page.pad
        width: page.width - page.margin * 2
        spacing: page.gap
        // whole pixels: three fractional widths can add up past the row and
        // wrap the last card out of sight
        readonly property real cardW: page.stacked ? width : Math.floor((width - spacing * 2) / 3)

        // the version and its updates
        Card {
            width: cards.cardW
            height: page.rowH
            readonly property bool fittedCard: true
            Title {
                text: I18n.t("prefs.about.card.version")
            }
            KitText {
                role: "display"
                font.pixelSize: Type.size("display") * 0.8
                text: Config.version
            }
            KitText {
                width: parent.width
                role: "secondary"
                elide: Text.ElideRight
                text: UpdateService.updateAvailable === true && (UpdateService.lastDetectedVersion ?? "") !== "" ? I18n.t("prefs.updates.available", UpdateService.lastDetectedVersion) : I18n.t("prefs.updates.stage.up_to_date")
            }
            PillButton {
                objectName: "aboutUpdates"
                icon: "downloadSimple"
                text: I18n.t("prefs.about.updates")
                onClicked: SettingsStore.navigate("updates")
            }
        }

        // useful places
        Card {
            width: cards.cardW
            height: page.rowH
            readonly property bool fittedCard: true
            Title {
                text: I18n.t("prefs.about.card.places")
            }
            spacing: Space.s
            PillButton {
                objectName: "aboutRunSetup"
                icon: "seal"
                text: I18n.t("onboarding.run_again")
                onClicked: {
                    GlobalStates.settingsWindowVisible = false;
                    OnboardingService.open();
                }
            }
            PillButton {
                icon: "folder"
                text: I18n.t("prefs.about.open_config")
                onClicked: Quickshell.execDetached(ProcessRole.detached(["xdg-open", Config.configDir]))
            }
            PillButton {
                icon: "code"
                text: I18n.t("prefs.about.source")
                onClicked: Quickshell.execDetached(ProcessRole.detached(["xdg-open", Brand.repoUrl]))
            }
        }

        // the legal notes (NOTICE opens inside the card)
        Card {
            id: legalCard
            width: cards.cardW
            height: page.rowH
            readonly property bool fittedCard: true
            Title {
                text: I18n.t("prefs.about.card.legal")
            }
            KitText {
                role: "display"
                font.pixelSize: Type.size("display") * 0.8
                text: "AGPL-3.0"
            }
            KitText {
                width: parent.width
                role: "secondary"
                wrapMode: Text.WordWrap
                text: I18n.t("prefs.about.free")
            }
            Flickable {
                width: legalCard.contentWidth
                height: Math.max(Space.xl, legalCard.height - legalCard.padding * 2 - y)
                contentWidth: width
                contentHeight: legal.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                LegalNotice {
                    id: legal
                    width: parent.width
                }
            }
        }
    }

    // a card's title, as on the other pages' cards
    component Title: KitText {
        role: "title"
    }
}
