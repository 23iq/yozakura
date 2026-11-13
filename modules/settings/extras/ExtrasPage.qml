pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.settings
import QtQuick.Effects
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.stages
import qs.modules.extras
import "../../extras/ExtrasModel.js" as ExtrasModel

// Settings > Apps > Extras, in the list form of the page template: a short
// band (how much of the catalog is installed as a ring, the installed apps
// as chips, the install running now with its progress) over one tall card
// holding the optional-software catalog (CatalogHost: category chips, the
// grid, notices and the install bar; it scrolls inside the card). Installs
// run in the backend queue; the page only selects and reports.
FittedFrame {
    id: page
    listForm: true
    hasHint: false

    required property var category
    readonly property var entries: ExtrasService.catalog ? (ExtrasService.catalog.entries || []) : []
    readonly property var installed: page.entries.filter(e => ExtrasModel.cardState(ExtrasService.status[e.id], ExtrasService.progress[e.id]) === "installed")
    readonly property var running: ExtrasService.activeJobs.length > 0 ? ExtrasService.activeJobs[0] : null

    // SettingsShell reveal() hook (search jumps): one page, nothing to scroll to.
    function reveal(section, entry) {
    }

    Item {
        id: hero
        objectName: "pageHero"
        x: page.margin
        y: Space.s
        width: page.width - page.margin * 2
        height: page.bandH

        Stage {
            id: band
            calm: true
            objectName: "pageStage"
            anchors.fill: parent
            stageHeight: page.bandH

            RectangularShadow {
                z: -1
                anchors.fill: parent
                radius: Look.radius("surface", parent.height)
                offset: Qt.vector2d(0, Space.m)
                blur: Space.xxl
                color: Qt.alpha(Colors.shadow, 0.45)
            }

            // how much of the catalog is on this machine
            Ring {
                id: ring
                objectName: "extrasRing"
                x: Space.xl
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(band.height * 0.62)
                height: width
                thickness: Space.stroke + 2
                value: page.entries.length > 0 ? page.installed.length / page.entries.length : 0
                KitText {
                    role: "title"
                    tabular: true
                    text: page.installed.length
                }
            }
            Column {
                x: ring.x + ring.width + Space.l
                anchors.verticalCenter: parent.verticalCenter
                width: band.width - x - side.width - Space.xl * 2
                spacing: Space.s
                KitText {
                    role: "title"
                    text: I18n.t("prefs.extras.installed_of", page.installed.length, page.entries.length)
                }
                // the installed apps
                Flow {
                    width: parent.width
                    height: Math.min(implicitHeight, Space.chip * 2 + Space.xs)
                    clip: true
                    spacing: Space.xs
                    Repeater {
                        model: page.installed
                        delegate: Chip {
                            required property var modelData
                            dense: true
                            quiet: true
                            icon: Icons[modelData.icon] ?? ""
                            text: modelData.name
                        }
                    }
                }
            }

            // the install running now
            Column {
                id: side
                objectName: "extrasRunning"
                anchors.right: parent.right
                anchors.rightMargin: Space.xl
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(band.width * 0.26)
                spacing: Space.s
                visible: page.running !== null
                KitText {
                    width: parent.width
                    role: "body"
                    elide: Text.ElideRight
                    text: page.running ? I18n.t("prefs.extras.installing", ExtrasService.displayName(page.running.id || "")) : ""
                }
                ProgressLine {
                    readonly property real percent: page.running && page.running.percent !== undefined ? page.running.percent : -1
                    width: parent.width
                    indeterminate: percent < 0
                    value: Math.max(0, percent) / 100
                }
            }
        }
    }

    // the catalog: one tall card, it scrolls inside
    Card {
        id: card
        objectName: "settingsSection:catalog"
        readonly property bool fixed: true
        x: page.margin
        y: hero.y + hero.height + page.gap
        width: page.width - page.margin * 2
        height: page.height - y - Space.l
        padding: Space.s
        shadow: true

        CatalogHost {
            id: host
            objectName: "extrasCatalog"
            width: card.contentWidth
            height: card.height - card.padding * 2
            mode: "settings"
            sideMargin: Space.l
            topMargin: Space.l
            maxContentWidth: card.contentWidth
        }
    }
}
