import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.modules.components.kit
import "ExtrasUi.js" as Ui

// Banner of the catalog (offline, refused installs, errors and the
// multilib confirm): tinted icon disc, title, message and (as children)
// its action buttons, which wrap under the text on narrow widths.
// `tone`: "info", "warning" or "error".
StyledRect {
    id: root

    property string tone: "info"
    property string icon: "info"
    property string title: ""
    property string message: ""
    default property alias actions: actionRow.data

    readonly property color accent: root.tone === "error" ? Type.danger : (root.tone === "warning" ? Colors.warning : Type.secondary)
    readonly property bool stacked: root.width < 560
    readonly property int pad: Look.surfacePadding

    variant: "pane"
    // floats over the scrolled grid (CatalogHost): opaque, lifted
    backgroundOpacity: 1
    radius: Look.radius("box")
    enableShadow: true
    implicitHeight: (root.stacked ? textCol.implicitHeight + actionRow.implicitHeight + Space.m : Math.max(textCol.implicitHeight, actionRow.implicitHeight)) + root.pad * 2

    // Tone outline and tint over the opaque pane.
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: Ui.alpha(root.accent, 0.1)
        border.width: Space.hairline
        border.color: Ui.alpha(root.accent, 0.45)
        z: 10
    }

    Icon {
        id: badge
        x: root.pad
        y: root.pad
        width: Space.controlS
        height: Space.controlS
        icon: Icons[root.icon] ?? ""
        role: "title"
        color: root.accent
    }

    Column {
        id: textCol
        anchors.left: badge.right
        anchors.leftMargin: Space.s
        anchors.right: root.stacked ? parent.right : actionRow.left
        anchors.rightMargin: root.pad
        y: root.pad + Math.max(0, (badge.height - implicitHeight) / 2)
        spacing: Space.xs

        KitText {
            width: parent.width
            role: "body"
            text: root.title
            font.weight: Look.activeLabelWeight
            wrapMode: Text.WordWrap
        }
        KitText {
            width: parent.width
            visible: text !== ""
            role: "secondary"
            text: root.message
            wrapMode: Text.WordWrap
        }
    }

    Row {
        id: actionRow
        x: root.stacked ? textCol.x : root.width - width - root.pad
        y: root.stacked ? textCol.y + textCol.implicitHeight + Space.m : (root.height - height) / 2
        spacing: Space.s
    }
}
