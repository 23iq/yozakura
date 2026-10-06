import QtQuick
import qs.modules.components

// The one box of a window or popup: the theme's "popup" (or "bg") surface
// with the standard padding (`variant: "bg"` for a full window). Children
// go inside the padded body; the implicit size follows them.
StyledRect {
    id: root

    property int padding: Space.l
    default property alias content: body.data

    variant: "popup"
    radius: Space.surfaceRadius
    implicitWidth: body.childrenRect.width + root.padding * 2
    implicitHeight: body.childrenRect.height + root.padding * 2

    Item {
        id: body
        anchors.fill: parent
        anchors.margins: root.padding
    }
}
