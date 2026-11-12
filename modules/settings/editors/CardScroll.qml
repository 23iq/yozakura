import QtQuick
import qs.modules.components.kit

// The content of a row card that may be taller than the card (a hand-
// written page's list or options): it scrolls inside the card, with a fade
// at the foot while more is below. One child, laid out at the card's width.
Item {
    id: root

    default property alias content: column.data

    clip: true

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.height
        interactive: contentHeight > height + 1
        boundsBehavior: Flickable.StopAtBounds
        Column {
            id: column
            width: flick.width
        }
    }

    Mark {
        visible: flick.interactive && flick.contentY < flick.contentHeight - flick.height - 1
        anchors.bottom: parent.bottom
        width: parent.width
        height: Space.l
        radius: 0
        gradient: Gradient {
            GradientStop {
                position: 0
                color: "transparent"
            }
            GradientStop {
                position: 1
                color: Look.cardFill(false)
            }
        }
    }
}
