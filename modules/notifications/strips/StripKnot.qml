import QtQuick
import qs.modules.theme
import qs.modules.components.kit
import "StripLayout.js" as StripLayout

// The knot at the end of the strip row (StripsView's footer): a small bead
// on a short thread counting the popups that wait behind the strips, "+3".
Item {
    id: root

    property string edge: "top"
    property int count: 0
    property real crossExtent: 0
    property bool thread: true

    readonly property bool row: StripLayout.isRow(root.edge)
    readonly property int bead: Space.controlS
    readonly property int string_: root.thread ? Space.m : Space.xs

    visible: root.count > 0
    // Length along the row (StripsView adds it up)
    readonly property real span: root.visible ? root.bead + Space.s : 0
    width: root.row ? root.span : root.crossExtent
    height: root.row ? root.crossExtent : root.span

    Rectangle {
        visible: root.thread
        x: root.row ? root.bead / 2 + Space.s : (root.edge === "right" ? root.width - root.string_ : 0)
        y: root.row ? (root.edge === "bottom" ? root.height - root.string_ : 0) : root.bead / 2 + Space.s
        width: root.row ? Space.hairline : root.string_
        height: root.row ? root.string_ : Space.hairline
        color: Type.muted
    }

    Surface {
        objectName: "stripKnot"
        x: root.row ? Space.s : (root.edge === "right" ? root.width - root.string_ - width : root.string_)
        y: root.row ? (root.edge === "bottom" ? root.height - root.string_ - height : root.string_) : Space.s
        width: root.bead
        height: root.bead
        radius: root.bead / 2
        floating: true
        glassSurface: "popups"
        padding: 0

        KitText {
            anchors.centerIn: parent
            role: "caption"
            font.weight: Font.DemiBold
            text: "+" + root.count
        }
    }
}
