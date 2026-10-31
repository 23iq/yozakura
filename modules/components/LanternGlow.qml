pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import qs.modules.theme

// The cursor lantern on one surface root (loaded by StyledRect while
// theme.lighting.lantern glows): one radial gradient over the surface's
// content (text, icons and edges near the pointer brighten), centred on the
// pointer and clipped by the surface's shape; redrawn only when the pointer
// moves. The pointer comes from the nearest LanternScope among the
// ancestors; without one the surface stays unlit. A neighbouring surface within the glow's
// radius catches its edge too.
Item {
    id: root

    property HoverHandler scope: null
    // Corner radii of the surface [topLeft, topRight, bottomRight, bottomLeft]
    property var radii: [0, 0, 0, 0]
    // Falloff radius: Space.controlXL (12 spacing steps, 96 px at cozy
    // density; the kit is not imported here) times the strength
    readonly property real reach: Metrics.spacing * 12 * Lighting.lanternReach
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

    // The surface's own outline (ClippingRectangle does not clip its
    // corners for every host), filled with the glow centred on the pointer
    Shape {
        anchors.fill: parent

        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: root.spot.x
                centerY: root.spot.y
                centerRadius: root.reach
                focalX: root.spot.x
                focalY: root.spot.y
                GradientStop {
                    position: 0
                    color: Qt.alpha(Lighting.lanternColor, Lighting.lanternStrength)
                }
                GradientStop {
                    position: 0.3
                    color: Qt.alpha(Lighting.lanternColor, Lighting.lanternStrength * 0.62)
                }
                GradientStop {
                    position: 0.65
                    color: Qt.alpha(Lighting.lanternColor, Lighting.lanternStrength * 0.2)
                }
                GradientStop {
                    position: 1
                    color: Qt.alpha(Lighting.lanternColor, 0)
                }
            }
            PathRectangle {
                width: root.width
                height: root.height
                topLeftRadius: root.radii[0]
                topRightRadius: root.radii[1]
                bottomRightRadius: root.radii[2]
                bottomLeftRadius: root.radii[3]
            }
        }
    }
}
