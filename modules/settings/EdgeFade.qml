import QtQuick
import QtQuick.Effects
import qs.modules.components.kit

// Fades its content out at two opposite edges (a list that scrolls on
// under the top or the bottom, a strip that runs on sideways) by masking
// it, so the fade works over any surface: a translucent card, the
// wallpaper, a gradient (a painted fade drawn in the card fill would show
// as a second box on a translucent card). `start` / `end` are the fade
// lengths at the top / bottom (or left / right with `horizontal`); 0 = a
// hard edge. The content fills the EdgeFade; it is clipped to it.
//
//   EdgeFade { anchors.fill: parent; end: flick.atYEnd ? 0 : Space.xl
//       Flickable { id: flick; anchors.fill: parent ... } }
Item {
    id: root

    default property alias content: holder.data
    property bool horizontal: false
    property real start: 0
    property real end: 0
    readonly property real length: root.horizontal ? root.width : root.height
    readonly property bool fading: (root.start > 0 || root.end > 0) && root.length > 0

    clip: true

    Item {
        id: holder
        anchors.fill: parent
        layer.enabled: root.fading
        layer.smooth: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: mask
            // a graded mask: alpha 0..1 maps to 0..1
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }
    }

    Mark {
        id: mask
        anchors.fill: parent
        visible: false
        layer.enabled: true
        radius: 0
        gradient: Gradient {
            orientation: root.horizontal ? Gradient.Horizontal : Gradient.Vertical
            GradientStop {
                position: 0
                color: root.start > 0 ? "transparent" : "white"
            }
            GradientStop {
                position: root.length > 0 ? Math.min(0.5, root.start / root.length) : 0
                color: "white"
            }
            GradientStop {
                position: root.length > 0 ? Math.max(0.5, 1 - root.end / root.length) : 1
                color: "white"
            }
            GradientStop {
                position: 1
                color: root.end > 0 ? "transparent" : "white"
            }
        }
    }
}
