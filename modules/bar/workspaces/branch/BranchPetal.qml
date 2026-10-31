import QtQuick
import QtQuick.Shapes
import qs.modules.theme
import "BranchGeometry.js" as Geo

// A petal that detached from its blossom: drifts down, turns and fades.
// Hidden at rest; drop(position) starts it from that petal position.
Item {
    id: root

    required property int index
    required property real slot
    required property string shape
    required property color color
    property real scaleFrom: 1
    property int position: 0

    readonly property var path_: Geo.fall(root.index, root.slot)

    width: root.slot
    height: root.slot
    // Opacity 0 at rest: nothing drawn.
    opacity: 0

    function drop(p) {
        root.position = p;
        fallAnim.restart();
    }

    Shape {
        id: petal
        width: root.slot
        height: root.slot
        preferredRendererType: Shape.CurveRenderer
        transformOrigin: Item.Center
        ShapePath {
            strokeWidth: -1
            fillRule: ShapePath.WindingFill
            fillColor: root.color
            PathSvg {
                path: Geo.petalsPath(root.shape, root.index, root.position, root.position + 1, root.slot / 2, root.slot / 2, Geo.bloomRadius(root.slot) * root.scaleFrom)
            }
        }
    }

    ParallelAnimation {
        id: fallAnim
        NumberAnimation {
            target: petal
            property: "x"
            from: 0
            to: root.path_.dx
            duration: Motion.emphasis.duration * 2
            easing.type: Motion.emphasis.easing
        }
        NumberAnimation {
            target: petal
            property: "y"
            from: 0
            to: root.path_.dy
            duration: Motion.emphasis.duration * 2
            easing.type: Motion.exit.easing
        }
        NumberAnimation {
            target: petal
            property: "rotation"
            from: 0
            to: root.path_.turn
            duration: Motion.emphasis.duration * 2
            easing.type: Motion.emphasis.easing
        }
        NumberAnimation {
            target: root
            property: "opacity"
            from: 1
            to: 0
            duration: Motion.emphasis.duration * 2
            easing.type: Motion.exit.easing
        }
    }
}
