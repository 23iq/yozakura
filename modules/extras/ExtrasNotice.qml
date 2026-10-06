import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.config
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

    readonly property color accent: root.tone === "error" ? Colors.error : (root.tone === "warning" ? Colors.tertiary : Colors.primary)
    readonly property bool stacked: root.width < 560

    variant: "pane"
    // floats over the scrolled grid (CatalogHost): opaque, lifted
    backgroundOpacity: 1
    radius: Styling.radius(4)
    enableShadow: true
    implicitHeight: (root.stacked ? textCol.implicitHeight + actionRow.implicitHeight + 14 : Math.max(textCol.implicitHeight, actionRow.implicitHeight)) + 34

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: Ui.alpha(root.accent, 0.1)
        border.width: 1
        border.color: Ui.alpha(root.accent, 0.45)
        z: 10
    }

    Rectangle {
        id: badge
        x: 18
        y: 17
        width: 38
        height: 38
        radius: width / 2
        color: Ui.alpha(root.accent, 0.2)
        Text {
            anchors.centerIn: parent
            text: Icons[root.icon] ?? ""
            font.family: Icons.font
            font.pixelSize: Styling.fontSize(3)
            color: root.accent
        }
    }

    Column {
        id: textCol
        anchors.left: badge.right
        anchors.leftMargin: 14
        anchors.right: root.stacked ? parent.right : actionRow.left
        anchors.rightMargin: 18
        y: 17 + Math.max(0, (38 - implicitHeight) / 2)
        spacing: 3

        Text {
            width: parent.width
            text: root.title
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(0)
            font.weight: Font.DemiBold
            color: Colors.overBackground
            wrapMode: Text.WordWrap
        }
        Text {
            width: parent.width
            visible: text !== ""
            text: root.message
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            color: Colors.overSurfaceVariant
            wrapMode: Text.WordWrap
            textFormat: Text.PlainText
        }
    }

    Row {
        id: actionRow
        x: root.stacked ? textCol.x : root.width - width - 18
        y: root.stacked ? textCol.y + textCol.implicitHeight + 14 : (root.height - height) / 2
        spacing: 8
    }
}
