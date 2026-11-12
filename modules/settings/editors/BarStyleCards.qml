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
    readonly property int columns: width < 520 ? 2 : 3
    readonly property real cardWidth: (grid.width - grid.columnSpacing * (root.columns - 1)) / root.columns

    implicitHeight: grid.implicitHeight

    function previewOf(style) {
        const p = JSON.parse(JSON.stringify(PanelLayout.fromLegacy(Config.bar)));
        p.style = style;
        p.align = PanelStyles.get(style).floating ? "center" : "fill";
        p.autohide = "never";
        return [p];
    }

    Grid {
        id: grid
        width: parent.width
        columns: root.columns
        rowSpacing: Space.l
        columnSpacing: Space.l

        Repeater {
            model: PanelStyles.barStyles()

            delegate: ChoiceCard {
                id: card
                required property var modelData
                objectName: "card:" + modelData.id
                width: root.cardWidth
                previewHeight: Math.round(width * 0.4)
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
