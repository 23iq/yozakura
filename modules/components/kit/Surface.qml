import QtQuick
import qs.modules.components
import qs.modules.components.kit

// The one box of a window or popup: the theme's "popup" (or "bg") surface
// with the language's padding (Look.surfacePadding: Space.l in ink, tighter
// around glass cards and tiles; `variant: "bg"` for a full window). Children
// go inside the padded body; the implicit size follows them. `floating`
// (OSDs over any content) takes the language's floating box (Look.float):
// frosted translucent glass with a hairline edge, a solid tile in tiles.
StyledRect {
    id: root

    property int padding: Look.surfacePadding
    property bool floating: false
    readonly property bool ownBox: root.floating && Look.floatBoxed
    default property alias content: body.data

    variant: "popup"
    radius: Space.surfaceRadius
    implicitWidth: body.childrenRect.width + root.padding * 2
    implicitHeight: body.childrenRect.height + root.padding * 2
    backgroundOpacity: root.ownBox ? 0 : -1
    enableBorder: !root.ownBox

    Rectangle {
        objectName: "floatBox"
        anchors.fill: parent
        z: -1
        visible: root.ownBox
        radius: root.radius
        color: Look.floatFill
        border.width: Look.floatOutline.a > 0 ? Space.hairline : 0
        border.color: Look.floatOutline

        // Light catching the top edge (glass)
        Rectangle {
            visible: Look.floatHighlight.a > 0
            x: parent.radius
            y: parent.border.width
            width: Math.max(0, parent.width - parent.radius * 2)
            height: Space.hairline
            color: Look.floatHighlight
        }
    }

    Item {
        id: body
        anchors.fill: parent
        anchors.margins: root.padding
    }
}
