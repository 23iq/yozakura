pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store
import qs.modules.widgets.presets.store
import qs.modules.widgets.presets
import "../../widgets/presets/GalleryTabs.js" as GalleryTabs

// A part tab of the settings gallery (Layout | Style | Palette): the cards
// of the popup switcher (GalleryTabs.js, PresetGalleryCard). A click
// applies the part, which changes only its own keys.
Column {
    id: root

    property string tab: "layout"
    property string query: ""
    property int hot: -1 // hovered card
    readonly property var cards: GalleryTabs.cards(root.tab, {
        "presets": PresetStudio.presets,
        "parts": PresetParts.parts
    }, root.query)
    readonly property int columns: Math.max(1, Math.floor((width + Space.l) / (Metrics.rowHeight * 5 + Space.l)))
    readonly property int cardW: Math.floor((width - Space.l * (root.columns - 1)) / root.columns)

    spacing: Space.l

    Flow {
        id: grid
        width: parent.width
        spacing: Space.l

        Repeater {
            model: root.cards

            delegate: PresetGalleryCard {
                required property var modelData
                required property int index
                objectName: "partCard:" + modelData.key
                card: modelData
                width: root.cardW
                height: Math.round((width - Metrics.spacing * 2) * 10 / 16) + Metrics.rowHeight
                selected: root.hot === index || (root.hot < 0 && modelData.active)
                onHovered: root.hot = index
                onClicked: PresetParts.apply(modelData)
            }
        }
    }

    KitText {
        width: parent.width
        visible: root.cards.length === 0
        horizontalAlignment: Text.AlignHCenter
        role: "secondary"
        text: PresetParts.error !== "" ? PresetParts.error : (PresetParts.loaded ? I18n.t("presets.parts.empty") : "")
    }
}
