import QtQuick
import qs.modules.components.kit

// The edge fades of a horizontal strip (a Flickable of pictures that does
// not fit its card): a soft fade on the side that has more, so it reads as
// "scroll for more". Lays itself over `flick`.
Item {
    id: root

    required property Flickable flick
    readonly property bool more: root.flick.contentWidth > root.flick.width + 1

    x: root.flick.x
    y: root.flick.y
    width: root.flick.width
    height: root.flick.height
    z: 2

    Mark {
        visible: root.more && root.flick.contentX > 1
        width: Space.xl
        height: parent.height
        radius: 0
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0
                color: Look.cardFill(false)
            }
            GradientStop {
                position: 1
                color: "transparent"
            }
        }
    }
    Mark {
        visible: root.more && root.flick.contentX < root.flick.contentWidth - root.flick.width - 1
        anchors.right: parent.right
        width: Space.xl
        height: parent.height
        radius: 0
        gradient: Gradient {
            orientation: Gradient.Horizontal
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
