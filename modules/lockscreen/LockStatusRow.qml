import QtQuick
import qs.modules.services
import qs.modules.theme
import qs.config

// Glass style status strip: user chip on one side, connectivity and battery
// on the other. Each chip is glass so it stays legible on any wallpaper.
Item {
    id: root

    property string username: ""
    property color textColor: Colors.secondaryFixed
    property color errorColor: Colors.error
    property color fill: Colors.shadow
    readonly property real chipHeight: 36
    readonly property real chipRadius: Config.roundness > 0 ? (chipHeight / 2) * Math.min(1, Config.roundness / 16) : 0

    implicitHeight: chipHeight

    LockStatusInfo {
        id: info
    }

    // User chip: avatar and name.
    LockGlass {
        id: userChip
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        height: root.chipHeight
        width: userRow.implicitWidth + 8 + 16
        radius: root.chipRadius
        fill: root.fill
        ink: root.textColor
        visible: root.username !== ""

        Row {
            id: userRow
            anchors.left: parent.left
            anchors.leftMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            LockAvatar {
                width: root.chipHeight - 8
                height: width
                anchors.verticalCenter: parent.verticalCenter
                ink: root.textColor
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.username
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(0)
                font.weight: Font.DemiBold
                color: root.textColor
            }
        }
    }

    // Connectivity and power.
    LockGlass {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: root.chipHeight
        width: statusRow.implicitWidth + 32
        radius: root.chipRadius
        fill: root.fill
        ink: root.textColor

        Row {
            id: statusRow
            anchors.centerIn: parent
            spacing: 14

            Row {
                spacing: 7
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: info.networkIcon
                    font.family: Icons.font
                    font.pixelSize: 16
                    color: root.textColor
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: text !== ""
                    text: info.networkLabel
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-1)
                    font.weight: Font.Medium
                    color: root.textColor
                    opacity: 0.85
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, 160)
                }
            }

            Row {
                spacing: 6
                visible: info.batteryAvailable
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: info.batteryIcon
                    font.family: Icons.font
                    font.pixelSize: 16
                    color: info.batteryLow ? root.errorColor : root.textColor
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: info.batteryPercent + "%"
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-1)
                    font.weight: Font.Medium
                    color: root.textColor
                    opacity: 0.85
                }
            }
        }
    }
}
