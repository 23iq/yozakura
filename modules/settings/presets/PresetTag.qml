import QtQuick
import qs.modules.components.kit

// A preset's tag ("Dark", "Frame"): a read-only label in a small outlined
// pill, so it reads as a tag in every visual language (a quiet Chip is bare
// text in the unboxed ones and looks clickable in the boxed ones).
Mark {
    id: root

    property string text: ""

    implicitWidth: label.implicitWidth + Space.m * 2
    implicitHeight: label.implicitHeight + Space.xs * 2
    radius: Look.radius("chip", height)
    color: Look.raisedFill(false)
    border.width: Space.hairline
    border.color: Look.cardEdge

    Accessible.role: Accessible.StaticText
    Accessible.name: root.text

    KitText {
        id: label
        anchors.centerIn: parent
        role: "caption"
        color: Type.secondary
        text: root.text
    }
}
