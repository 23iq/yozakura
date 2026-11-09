pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.components
import qs.modules.services
import qs.modules.theme
import qs.modules.components.kit
import "WidgetRegistry.js" as Registry

// Edit desktop toolbar: add a widget of any registered type (quiet kit
// chips), finish editing (the toolbar's one primary action).
StyledRect {
    id: root

    signal addRequested(string type)
    signal doneRequested

    variant: "popup"
    glassSurface: "widgets"
    enableShadow: true
    radius: Look.radius("surface", height)
    implicitWidth: row.implicitWidth + Space.m * 2
    implicitHeight: Space.chip + Space.m * 2

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Space.xs

        KitText {
            anchors.verticalCenter: parent.verticalCenter
            leftPadding: Space.s
            rightPadding: Space.s
            text: I18n.t("desktop.widgets.edit_title")
            font.weight: Look.activeLabelWeight
            color: root.item
        }

        Repeater {
            model: Registry.types
            Chip {
                id: addButton
                required property var modelData
                anchors.verticalCenter: parent.verticalCenter
                quiet: true
                icon: Icons.plus
                text: I18n.t(modelData.labelKey)
                Accessible.role: Accessible.Button
                Accessible.name: I18n.t("desktop.widgets.add") + " " + I18n.t(modelData.labelKey)
                onClicked: root.addRequested(addButton.modelData.id)
            }
        }

        Item {
            width: Space.s
            height: 1
        }

        Chip {
            anchors.verticalCenter: parent.verticalCenter
            primary: true
            text: I18n.t("desktop.widgets.done")
            Accessible.role: Accessible.Button
            Accessible.name: text
            onClicked: root.doneRequested()
        }
    }
}
