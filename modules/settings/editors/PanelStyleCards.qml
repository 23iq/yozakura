pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.services
import qs.modules.settings.controls
import qs.modules.settings.previews
import "../../bar/panels/PanelStyles.js" as PanelStyles

// One card per panel style (PanelStyles.js registry), each previewing the
// selected panel's modules drawn in that style on its natural edge.
Item {
    id: root

    property var panel: null
    readonly property int columns: width < 520 ? 2 : 4
    signal picked(string style)

    implicitHeight: grid.implicitHeight

    function previewOf(style) {
        if (!panel)
            return [];
        const meta = PanelStyles.get(style);
        const p = JSON.parse(JSON.stringify(panel));
        p.style = style;
        if (meta.edges.indexOf(p.edge) === -1)
            p.edge = meta.edges[0];
        p.autohide = "never";
        return [p];
    }

    Grid {
        id: grid
        width: parent.width
        columns: root.columns
        spacing: 10

        Repeater {
            model: PanelStyles.STYLES.filter(s => !s.hidden)
            delegate: ChoiceCard {
                id: card
                required property var modelData
                width: (grid.width - grid.spacing * (root.columns - 1)) / root.columns
                previewHeight: Math.round(width * 9 / 16) - 8
                selected: root.panel !== null && root.panel.style === modelData.id
                icon: modelData.icon
                title: I18n.t(modelData.label)
                subtitle: I18n.t(modelData.desc)
                onClicked: root.picked(modelData.id)

                PanelsSchematic {
                    anchors.fill: parent
                    panels: root.previewOf(card.modelData.id)
                    showWindows: false
                    selected: -1
                    // Exaggerated so the style reads at card size
                    unit: Math.max(8, Math.round(width * 0.075))
                }
            }
        }
    }
}
