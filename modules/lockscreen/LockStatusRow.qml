import QtQuick
import qs.modules.theme
import qs.modules.components.kit

// Glass style status strip: user chip on one side, connectivity and battery
// on the other. Each chip is glass so it stays legible on any wallpaper;
// sizes, type and gaps are the kit's (a Chip-high pill, Type roles, Space).
Item {
    id: root

    property string username: ""
    property color textColor: Colors.secondaryFixed
    property color errorColor: Colors.error
    property color fill: Colors.shadow
    readonly property real chipHeight: Space.controlS
    readonly property real chipRadius: Space.round(chipHeight)

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
        width: userRow.implicitWidth + Space.xs + Space.m
        radius: root.chipRadius
        fill: root.fill
        ink: root.textColor
        visible: root.username !== ""

        Row {
            id: userRow
            anchors.left: parent.left
            anchors.leftMargin: Space.xs
            anchors.verticalCenter: parent.verticalCenter
            spacing: Space.s

            LockAvatar {
                width: root.chipHeight - Space.s
                height: width
                anchors.verticalCenter: parent.verticalCenter
                name: root.username
            }

            KitText {
                anchors.verticalCenter: parent.verticalCenter
                role: "secondary"
                text: root.username
                color: root.textColor
            }
        }
    }

    // Connectivity and power.
    LockGlass {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: root.chipHeight
        width: statusRow.implicitWidth + Space.l * 2
        radius: root.chipRadius
        fill: root.fill
        ink: root.textColor

        Row {
            id: statusRow
            anchors.centerIn: parent
            spacing: Space.m

            Row {
                spacing: Space.xs
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: info.networkIcon
                    font.family: Icons.font
                    font.pixelSize: Type.iconSize("caption")
                    color: root.textColor
                }
                KitText {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: text !== ""
                    role: "caption"
                    text: info.networkLabel
                    color: root.textColor
                    opacity: 0.85
                    width: Math.min(implicitWidth, Space.controlXL * 2)
                }
            }

            Row {
                spacing: Space.xs
                visible: info.batteryAvailable
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: info.batteryIcon
                    font.family: Icons.font
                    font.pixelSize: Type.iconSize("caption")
                    color: info.batteryLow ? root.errorColor : root.textColor
                }
                KitText {
                    anchors.verticalCenter: parent.verticalCenter
                    role: "caption"
                    tabular: true
                    text: info.batteryPercent + "%"
                    color: root.textColor
                    opacity: 0.85
                }
            }
        }
    }
}
