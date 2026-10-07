import QtQuick
import qs.modules.components.kit

// The standard way a screen groups related content: an optional
// SectionLabel (`label`, with a quiet `actionText` -> `actionTriggered()`)
// over the content, laid out vertically with Space.m spacing.
//
//   Group {
//       label: "Notifications"; actionText: "Clear"
//       onActionTriggered: clearAll()
//       ListRow { width: parent.width; ... }
//   }
//
// The box comes from the visual language (Look / VisualLanguage.kit):
//   ink    no box: label + content; `divider: true` draws a hairline above
//   glass  a frosted translucent card, light top edge and a faint outline
//   tiles  a solid square-ish tile, separated from its neighbours by gaps
// `padding` is the inner padding of the box (0 when there is none).
// `fill: true` stretches the box to the Group's height (a bento tile) and
// `bodyHeight` is then the room left for the content under the label;
// `bare: true` drops the box (a host that already draws the surface).
Item {
    id: root

    property string label: ""
    property string actionText: ""
    property bool divider: false
    property bool fill: false
    property bool bare: false
    property int padding: root.bare ? 0 : Look.groupPadding
    default property alias content: body.data
    readonly property bool boxed: Look.groupBoxed && !root.bare
    readonly property real bodyHeight: root.fill ? Math.max(0, box.height - root.padding * 2 - body.y) : body.implicitHeight
    readonly property bool ruled: root.divider && Look.groupDivider

    signal actionTriggered

    implicitWidth: inner.implicitWidth + root.padding * 2
    implicitHeight: box.y + (root.fill ? inner.implicitHeight + root.padding * 2 : box.height)

    Divider {
        id: rule
        objectName: "groupRule"
        width: parent.width
        visible: root.ruled
    }

    // The language's group box (not a theme variant, so a plain Rectangle).
    Rectangle {
        id: box
        objectName: "groupBox"
        y: root.ruled ? Space.l + rule.height : 0
        width: parent.width
        height: root.fill ? Math.max(0, root.height - y) : inner.implicitHeight + root.padding * 2
        radius: Look.groupRadius
        color: root.bare ? "transparent" : Look.groupFill
        border.width: !root.bare && Look.groupOutline.a > 0 ? Space.hairline : 0
        border.color: Look.groupOutline

        // Light catching the top edge (glass).
        Rectangle {
            visible: !root.bare && Look.groupHighlight.a > 0
            x: box.radius
            y: box.border.width
            width: box.width - box.radius * 2
            height: Space.hairline
            color: Look.groupHighlight
        }

        Column {
            id: inner
            x: root.padding
            y: root.padding
            width: box.width - root.padding * 2
            spacing: Space.m

            SectionLabel {
                objectName: "groupLabel"
                width: parent.width
                visible: root.label !== ""
                text: root.label
                action: root.actionText
                onTriggered: root.actionTriggered()
            }

            Column {
                id: body
                width: parent.width
                spacing: Space.m
            }
        }
    }
}
