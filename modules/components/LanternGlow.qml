pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import qs.modules.theme

// The cursor lantern on one surface root (loaded by StyledRect while
// theme.lighting.lantern glows): one radial gradient under the surface's
// content, centred on the pointer and clipped by the surface's shape. The
// pointer comes from the nearest LanternScope among the ancestors; without
// one the surface stays unlit. A neighbouring surface within the glow's
// radius catches its edge too.
Item {
    id: root

    property HoverHandler scope: null
    readonly property real reach: Lighting.lanternRadius
    readonly property bool tracking: root.scope !== null && root.scope.hovered
    // Last pointer position in this item's coordinates (kept while fading out)
    property point spot: Qt.point(0, 0)
    readonly property bool near: root.spot.x > -root.reach && root.spot.x < root.width + root.reach && root.spot.y > -root.reach && root.spot.y < root.height + root.reach

    function findScope(): HoverHandler {
        for (let p = root.parent; p; p = p.parent) {
            const data = p.data;
            for (let i = 0; i < data.length; i++) {
                if (data[i] && data[i].objectName === "lanternScope")
                    return data[i] as HoverHandler;
            }
        }
        return null;
    }

    Component.onCompleted: root.scope = root.findScope()

    Binding {
        target: root
        property: "spot"
        when: root.tracking
        value: root.scope ? root.mapFromItem(root.scope.parent, root.scope.point.position.x, root.scope.point.position.y) : Qt.point(0, 0)
        restoreMode: Binding.RestoreNone
    }

    opacity: root.tracking && root.near ? 1 : 0
    visible: root.opacity > 0
    Behavior on opacity {
        NumberAnimation {
            duration: Motion.glide.duration
            easing.type: Motion.glide.easing
        }
    }

    Shape {
        x: root.spot.x - root.reach
        y: root.spot.y - root.reach
        width: root.reach * 2
        height: root.reach * 2

        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: root.reach
                centerY: root.reach
                centerRadius: root.reach
                focalX: root.reach
                focalY: root.reach
                GradientStop {
                    position: 0
                    color: Qt.alpha(Lighting.lanternColor, Lighting.lanternStrength)
                }
                GradientStop {
                    position: 0.4
                    color: Qt.alpha(Lighting.lanternColor, Lighting.lanternStrength * 0.45)
                }
                GradientStop {
                    position: 1
                    color: Qt.alpha(Lighting.lanternColor, 0)
                }
            }
            PathAngleArc {
                centerX: root.reach
                centerY: root.reach
                radiusX: root.reach
                radiusY: root.reach
                startAngle: 0
                sweepAngle: 360
            }
        }
    }
}
