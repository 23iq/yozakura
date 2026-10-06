pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.services
import qs.config
import qs.modules.settings.controls
import qs.modules.settings.previews
import qs.modules.settings.store
import "../../bar/panels/PanelStyles.js" as PanelStyles
import "../../bar/panels/PanelLayout.js" as PanelLayout

// The bar's look (bar.layout.style): full, floating, islands, pills,
// dock-like or none, each previewed with your modules on your bar's edge.
Item {
    id: root

    property var entry
    readonly property string current: Config.bar.layout && Config.bar.layout.style ? Config.bar.layout.style : "classic"
    readonly property int columns: width < 520 ? 2 : 3

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
        spacing: 10

        Repeater {
            model: PanelStyles.barStyles()

            delegate: ChoiceCard {
                id: card
                required property var modelData
                width: (grid.width - grid.spacing * (root.columns - 1)) / root.columns
                previewHeight: Math.round(width * 9 / 16) - 8
                selected: root.current === modelData.id
                icon: modelData.icon
                title: I18n.t(modelData.label)
                subtitle: I18n.t(modelData.desc)
                onClicked: SettingsStore.set("bar.layout.style", modelData.id)

                PanelsSchematic {
                    anchors.fill: parent
                    panels: root.previewOf(card.modelData.id)
                    showWindows: false
                    selected: -1
                    unit: Math.max(8, Math.round(width * 0.075))
                }
            }
        }
    }
}
