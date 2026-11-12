pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.services
import qs.modules.settings.controls
import qs.modules.settings.previews
import "../../bar/panels/PanelStyles.js" as PanelStyles
import qs.modules.components.kit

// One card per panel style (PanelStyles.js registry), each previewing the
// selected panel's modules drawn in that style on its natural edge.
Item {
    id: root

    property var panel: null
    // A strip (in a card of the page row, SettingRow.fillHeight): one
    // horizontal row of equal pictures with the title inside, scrolling
    // sideways with an edge fade when they do not fit.
    property real fillHeight: 0
    readonly property bool strip: root.fillHeight > 0
    readonly property int stripCount: PanelStyles.STYLES.filter(s => !s.hidden).length
    readonly property real stripWidth: Math.max(root.fillHeight * 1.3, (root.width - Space.m * (root.stripCount - 1)) / Math.max(1, root.stripCount))
    readonly property int columns: root.strip ? root.stripCount : Math.max(2, Math.min(4, Math.floor(width / 180)))
    signal picked(string style)

    implicitHeight: root.strip ? root.fillHeight : grid.implicitHeight

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

    Flickable {
        id: stripFlick
        objectName: "pictureStrip"
        width: parent.width
        height: grid.height
        contentWidth: grid.width
        interactive: root.strip && contentWidth > width
        clip: root.strip
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.HorizontalFlick

        Grid {
            id: grid
            width: root.strip ? implicitWidth : stripFlick.width
            columns: root.columns
            spacing: Space.m

            Repeater {
                model: PanelStyles.STYLES.filter(s => !s.hidden)
                delegate: ChoiceCard {
                    id: card
                    required property var modelData
                    width: root.strip ? root.stripWidth : (grid.width - grid.spacing * (root.columns - 1)) / root.columns
                    previewHeight: root.strip ? root.fillHeight : Math.round(width * 9 / 16) - 8
                    inset: root.strip
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
    StripFade {
        flick: stripFlick
        visible: root.strip
    }
}
