pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.components
import qs.modules.services
import qs.modules.theme
import qs.config
import "WidgetRegistry.js" as Registry

// Edit desktop toolbar: add a widget of any registered type, finish editing.
StyledRect {
    id: root

    signal addRequested(string type)
    signal doneRequested

    variant: "popup"
    glassSurface: "widgets"
    enableShadow: true
    radius: height / 2
    implicitWidth: row.implicitWidth + 16
    implicitHeight: 52

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4

        Text {
            anchors.verticalCenter: parent.verticalCenter
            leftPadding: 10
            rightPadding: 10
            text: I18n.t("desktop.widgets.edit_title")
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(0)
            font.weight: Font.DemiBold
            color: root.item
        }

        Repeater {
            model: Registry.types
            Item {
                id: addButton
                required property var modelData
                width: addRow.implicitWidth + 20
                height: 36
                anchors.verticalCenter: parent.verticalCenter
                Accessible.role: Accessible.Button
                Accessible.name: I18n.t("desktop.widgets.add") + " " + I18n.t(modelData.labelKey)

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: addArea.containsMouse ? Qt.rgba(root.item.r, root.item.g, root.item.b, 0.12) : "transparent"
                }
                Row {
                    id: addRow
                    anchors.centerIn: parent
                    spacing: 6
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Icons.plus
                        font.family: Icons.font
                        font.pixelSize: Styling.fontSize(-2)
                        color: Colors.primary
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.t(addButton.modelData.labelKey)
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-1)
                        color: root.item
                    }
                }
                MouseArea {
                    id: addArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.addRequested(addButton.modelData.id)
                }
            }
        }

        Item {
            width: 8
            height: 1
        }

        Item {
            width: doneText.implicitWidth + 32
            height: 36
            anchors.verticalCenter: parent.verticalCenter
            Accessible.role: Accessible.Button
            Accessible.name: doneText.text

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: doneArea.containsMouse ? Qt.lighter(Colors.primary, 1.1) : Colors.primary
            }
            Text {
                id: doneText
                anchors.centerIn: parent
                text: I18n.t("desktop.widgets.done")
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-1)
                font.weight: Font.DemiBold
                color: Colors.overPrimary
            }
            MouseArea {
                id: doneArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.doneRequested()
            }
        }
    }
}
