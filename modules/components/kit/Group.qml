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
Item {
    id: root

    property string label: ""
    property string actionText: ""
    property bool divider: false
    property int padding: Look.groupPadding
    default property alias content: body.data
    readonly property bool boxed: Look.groupBoxed
    readonly property bool ruled: root.divider && Look.groupDivider
    // Height the group adds around its content (rule, box padding, label):
    // content that fills a given height sizes itself to height - chrome.
    readonly property real chrome: box.y + root.padding * 2 + (root.label !== "" ? labelItem.implicitHeight + inner.spacing : 0)

    signal actionTriggered

    implicitWidth: inner.implicitWidth + root.padding * 2
    implicitHeight: box.y + box.height

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
        height: inner.implicitHeight + root.padding * 2
        radius: Look.groupRadius
        color: Look.groupFill
        border.width: Look.groupOutline.a > 0 ? Space.hairline : 0
        border.color: Look.groupOutline

        // Light catching the top edge (glass).
        Rectangle {
            visible: Look.groupHighlight.a > 0
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
                id: labelItem
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
