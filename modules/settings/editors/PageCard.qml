import QtQuick
import qs.modules.components.kit

// A card of a hand-written page's row (Displays, Keyboard): the same box as
// a schema section in the row (kit Card, its title on the left and the
// current value on the right) with its content filling the rest of the
// card (`room` = the height left under the heading).
Card {
    id: card

    property string title: ""
    property string value: ""
    default property alias body: content.data
    // a card of a fitted page's row (tests/settings-fit.test.py)
    readonly property bool fittedCard: true
    readonly property real room: Math.max(0, card.height - card.padding * 2 - heading.height - card.spacing)

    padding: Look.boxPadding + Space.s
    spacing: Space.s

    Item {
        id: heading
        width: card.contentWidth
        height: Math.max(titleText.implicitHeight, valueText.implicitHeight)
        KitText {
            id: titleText
            width: parent.width - (valueText.text !== "" ? valueText.implicitWidth + Space.m : 0)
            role: "title"
            // a translated title wraps, whole (the card's room shrinks)
            wrapMode: Text.WordWrap
            elide: Text.ElideNone
            text: card.title
        }
        KitText {
            id: valueText
            anchors.right: parent.right
            anchors.verticalCenter: titleText.verticalCenter
            role: "secondary"
            text: card.value
        }
    }
    Item {
        id: content
        width: card.contentWidth
        height: card.room
    }
}
