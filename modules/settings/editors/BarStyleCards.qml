pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.services
import qs.config
import qs.modules.settings.controls
import qs.modules.settings.previews
import qs.modules.settings.thumbs
import qs.modules.settings.store
import "../../bar/panels/PanelStyles.js" as PanelStyles
import "../../bar/panels/PanelLayout.js" as PanelLayout
import qs.modules.components.kit

// The bar's shape (bar.layout.style): full, floating, islands, pills,
// dock-like or none, each pictured with your modules on your bar's edge
// over your wallpaper (the top of the screen, where the bar is).
Item {
    id: root

    property var entry
    readonly property string current: Config.bar.layout && Config.bar.layout.style ? Config.bar.layout.style : "classic"
    // A strip (in a card of the page row, SettingRow.fillHeight): one
    // horizontal row of equal pictures with the title inside, scrolling
    // sideways with an edge fade when they do not fit.
    property real fillHeight: 0
    readonly property bool strip: root.fillHeight > 0
    readonly property int stripCount: PanelStyles.barStyles().length
    readonly property real stripWidth: root.stripCount * Space.px(96) + Space.m * (root.stripCount + 1) <= root.width ? (root.width - Space.m * (root.stripCount + 1)) / Math.max(1, root.stripCount) : (root.width - Space.m * 2) / (Math.max(1, Math.floor((root.width - Space.m * 2) / Space.px(110))) + 0.4) - Space.m
    readonly property int columns: root.strip ? root.stripCount : width < 300 ? 2 : 3
    readonly property real cardWidth: (grid.width - grid.columnSpacing * (root.columns - 1)) / root.columns

    implicitHeight: root.strip ? root.fillHeight : grid.implicitHeight

    function previewOf(style) {
        const p = JSON.parse(JSON.stringify(PanelLayout.fromLegacy(Config.bar)));
        p.style = style;
        p.align = PanelStyles.get(style).floating ? "center" : "fill";
        p.autohide = "never";
        return [p];
    }

    Flickable {
        id: stripFlick
        objectName: "pictureStrip"
        width: parent.width
        height: grid.height + (root.strip ? Space.m * 2 : 0)
        contentWidth: grid.width + (root.strip ? Space.m * 2 : 0)
        interactive: root.strip && contentWidth > width
        clip: root.strip
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.HorizontalFlick

        Grid {
            id: grid
            width: root.strip ? implicitWidth : stripFlick.width
            // inset: the ring, glow and lift of a picture never clip
            x: root.strip ? Space.m : 0
            y: root.strip ? Space.m : 0
            columns: root.columns
            rowSpacing: Space.l
            columnSpacing: root.strip ? Space.m : Space.l

            Repeater {
                model: PanelStyles.barStyles()

                delegate: ChoiceCard {
                    id: card
                    required property var modelData
                    objectName: "card:" + modelData.id
                    width: root.strip ? root.stripWidth : root.cardWidth
                    previewHeight: root.strip ? root.fillHeight - Space.m * 2 : Math.round(width * 0.4)
                    inset: root.strip
                    selected: root.current === modelData.id
                    title: I18n.t(modelData.label)
                    onClicked: SettingsStore.set("bar.layout.style", modelData.id)

                    // built off the frame: the cards show at once
                    Loader {
                        anchors.fill: parent
                        asynchronous: true
                        sourceComponent: Component {
                            MiniScreen {
                                id: screen
                                PanelsSchematic {
                                    anchors.fill: parent
                                    backdrop: false
                                    barOpacity: screen.barOpacity
                                    panels: root.previewOf(card.modelData.id)
                                    showWindows: false
                                    selected: -1
                                    unit: Math.round(width * 0.075)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    StripFade {
        flick: stripFlick
        visible: root.strip
    }
}
