pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.components
import "PictureGrid.js" as PictureGrid

// The one grid of single-choice pictures: a ChoiceCard per option (the
// picture is the card; its name under it; the chosen one ringed, with a
// check badge and its name in the active weight), laid out by
// PictureGrid.js: balanced rows (no orphan), every row reaching the card's
// edge, a short last row centred, every card of the grid as tall as the
// tallest (a name on two lines never breaks the row's line).
//
//   ChoiceGrid {
//       width: parent.width
//       options: [{value, label (i18n key), description}]
//       value: current
//       picture: Component { Item { required property var option ... } }
//       onSelected: v => SettingsStore.set(key, v)
//   }
//
// `thumb` (a URL) instead of `picture` loads a settings thumb by URL,
// asynchronously, with `entry` and the option's `value` (CardSelector).
// Use it for any "pick one of these looks" choice; a list of named things
// (a resolution, a profile) is a list or a Segmented, not this.
Item {
    id: root

    property var options: []
    property var value
    // false: labels are display text already
    property bool translate: true
    property Component picture: null
    property url thumb: ""
    property var entry: null
    // the picture's height over its width, or a fixed `previewHeight`
    property real aspect: 0.6
    property real previewHeight: -1
    // about how wide a card is (columns), and the soft cap of a short row
    property real minWidth: Space.px(96)
    property real maxWidth: Space.px(190)
    readonly property real gap: Space.m
    readonly property int count: root.options ? root.options.length : 0
    // the columns every picture grid of the card shares (one cell size per
    // card: SettingsSection.pictureColumns, PictureGrid.shared); 0: its own
    property int sharedColumns: 0
    readonly property int columns: root.sharedColumns > 0 ? root.sharedColumns : PictureGrid.columns(root.width, root.gap, root.count, root.minWidth)
    readonly property real cardWidth: PictureGrid.cardWidth(root.width, root.gap, root.columns, root.maxWidth)
    readonly property int rows: Math.ceil(root.count / Math.max(1, root.columns))
    // the tallest card (its name may take two lines): every card that tall
    readonly property real cardHeight: {
        let h = 0;
        for (let i = 0; i < cards.count; i++) {
            const it = cards.liveItemAt(i);
            if (it)
                h = Math.max(h, it.implicitHeight);
        }
        return h;
    }
    readonly property var places: PictureGrid.places(root.count, root.columns, root.cardWidth, root.cardHeight, root.gap)

    signal selected(var value)

    implicitHeight: root.rows > 0 ? root.rows * root.cardHeight + (root.rows - 1) * root.gap : 0

    LiveRepeater {
        id: cards
        model: root.options

        delegate: ChoiceCard {
            id: card
            required property var modelData
            required property int index
            readonly property var place: root.places[card.index] || ({
                    "x": 0,
                    "y": 0
                })
            objectName: "card:" + card.modelData.value
            x: card.place.x
            y: card.place.y
            width: root.cardWidth
            height: root.cardHeight
            previewHeight: root.previewHeight >= 0 ? root.previewHeight : Math.round(root.cardWidth * root.aspect)
            selected: root.value === card.modelData.value
            title: root.translate ? I18n.t(card.modelData.label) : String(card.modelData.label)
            subtitle: card.modelData.description ? (root.translate ? I18n.t(card.modelData.description) : String(card.modelData.description)) : ""
            onClicked: root.selected(card.modelData.value)

            // a picture by component
            Loader {
                anchors.fill: parent
                active: root.picture !== null
                sourceComponent: root.picture
                onLoaded: {
                    if ("option" in item)
                        item.option = card.modelData;
                    if ("value" in item)
                        item.value = card.modelData.value;
                }
            }
            // a thumb by URL: built off the frame, fades in when ready
            Loader {
                anchors.fill: parent
                active: root.thumb.toString() !== ""
                asynchronous: true
                opacity: status === Loader.Ready ? 1 : 0
                Behavior on opacity {
                    enabled: Motion.micro.duration > 0
                    NumberAnimation {
                        duration: Motion.micro.duration
                    }
                }
                Component.onCompleted: if (active)
                    setSource(root.thumb, {
                        "entry": root.entry,
                        "value": card.modelData.value
                    })
            }
        }
    }
}
