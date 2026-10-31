pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "../Registry.js" as Registry
import "../Ui.js" as Ui

// A selector shown as cards (schema `display: "cards"`): one ChoiceCard per
// option with a small picture of it, drawn by the entry's `thumb`
// (Registry.THUMBS; the thumb gets `value` = the option's value and
// `entry`). Option `description` (i18n) is the card's second line.
Item {
    id: root

    property var entry
    property var options: []
    property var value
    signal selected(var value)

    readonly property int columns: Math.max(2, Math.min(root.options.length, Math.floor(width / Space.px(150))))
    // A few options do not stretch into huge cards.
    readonly property real cardWidth: Math.min((width - grid.spacing * (columns - 1)) / columns, Space.px(220))
    readonly property string thumbUrl: entry && entry.thumb ? Qt.resolvedUrl("../" + Registry.thumb(entry.thumb)) : ""

    implicitHeight: grid.implicitHeight

    Grid {
        id: grid
        width: parent.width
        columns: root.columns
        spacing: Space.m

        Repeater {
            model: root.options

            delegate: ChoiceCard {
                id: card
                required property var modelData
                objectName: "card:" + card.modelData.value
                width: root.cardWidth
                previewHeight: Math.round(width * 0.5)
                selected: root.value === card.modelData.value
                title: I18n.t(card.modelData.label)
                subtitle: card.modelData.description ? I18n.t(card.modelData.description) : ""
                onClicked: root.selected(card.modelData.value)

                Loader {
                    anchors.fill: parent
                    source: root.thumbUrl
                    onLoaded: {
                        Ui.setIfPresent(item, "entry", root.entry);
                        Ui.setIfPresent(item, "value", card.modelData.value);
                    }
                }
            }
        }
    }
}
