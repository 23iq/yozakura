import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.config
import "../Ui.js" as Ui

// A titled settings card (the SettingsSection look) for the hand-written
// Mods page. Children stack in a padded column; `trailing` items sit at the
// right of the title line.
Column {
    id: card

    property string title: ""
    default property alias content: body.data
    property alias trailing: trailingRow.data

    spacing: 10

    Item {
        visible: card.title !== "" || trailingRow.children.length > 0
        width: parent.width
        height: Math.max(titleText.implicitHeight, trailingRow.implicitHeight)

        Text {
            id: titleText
            anchors.verticalCenter: parent.verticalCenter
            leftPadding: 6
            text: card.title.toUpperCase()
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-3)
            font.weight: Font.Bold
            font.letterSpacing: 1.4
            color: Ui.alpha(Colors.overSurfaceVariant, 0.85)
        }

        Row {
            id: trailingRow
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Metrics.spacing
        }
    }

    StyledRect {
        id: surface
        variant: "pane"
        width: parent.width
        height: body.implicitHeight + Metrics.padding * 2
        radius: Styling.radius(4)
        enableShadow: false

        // Hairline outline, as on the schema sections.
        Rectangle {
            anchors.fill: parent
            radius: surface.radius
            color: "transparent"
            border.width: 1
            border.color: Ui.alpha(Colors.outlineVariant, 0.55)
            z: 10
        }

        Column {
            id: body
            x: Metrics.padding + 4
            y: Metrics.padding
            width: parent.width - x * 2
            spacing: Metrics.spacing + 4
        }
    }
}
