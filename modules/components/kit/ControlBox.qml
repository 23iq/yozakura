import QtQuick
import qs.modules.components.kit

// The rest / hover box of a kit control in the current visual language
// (Look.controlFill / controlEdge). Fills its parent behind the content; the
// parent StyledRect draws only the accent looks. Set `radius` to the parent's.
Rectangle {
    id: root

    property bool shown: true
    property bool hovered: false

    anchors.fill: parent
    z: -1
    visible: root.shown && Look.boxedControls
    color: Look.controlFill(root.hovered)
    border.width: Look.controlEdge.a > 0 ? Space.hairline : 0
    border.color: Look.controlEdge
}
