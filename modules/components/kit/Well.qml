import QtQuick
import qs.modules.components.kit

// An inset "screen" behind a readout (segment digits, a gauge): the
// language's well fill (Look.wellFill) with an inner shadow along the top
// edge (Look.wellEdge) so it reads as recessed into the surface. Children
// go inside, centered by the caller. Radius: the small control radius.
Rectangle {
    id: root

    radius: Look.chipRadius(root.height)
    color: Look.wellFill

    Rectangle {
        objectName: "wellEdge"
        visible: Look.wellEdge.a > 0
        x: root.radius
        y: 0
        width: Math.max(0, root.width - root.radius * 2)
        height: Space.hairline
        color: Look.wellEdge
    }
}
