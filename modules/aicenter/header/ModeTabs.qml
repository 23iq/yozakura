pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config

// Chat / Agent / Shell segmented switch with a sliding highlight.
StyledRect {
    id: root

    property string mode: "chat"
    signal selected(string mode)

    readonly property var modes: [
        {
            id: "chat",
            icon: Icons.chatTeardrop,
            label: I18n.t("ai.mode_chat")
        },
        {
            id: "agent",
            icon: Icons.terminalWindow,
            label: I18n.t("ai.mode_agent")
        },
        {
            id: "shell",
            icon: Icons.command,
            label: I18n.t("ai.mode_shell")
        }
    ]
    readonly property int current: Math.max(0, modes.findIndex(m => m.id === mode))

    variant: "common"
    radius: Styling.radius(0) > 0 ? height / 2 : 0
    implicitHeight: 32
    implicitWidth: row.implicitWidth + 6

    StyledRect {
        id: highlight
        variant: "primary"
        radius: parent.radius > 0 ? height / 2 : 0
        y: 3
        height: parent.height - 6
        readonly property Item tab: {
            repeater.count; // re-evaluate once the delegates exist
            return repeater.itemAt(root.current);
        }
        x: row.x + (tab ? tab.x : 0)
        width: tab ? tab.width : 0
        Behavior on x {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration / 2
                easing.type: Easing.OutCubic
            }
        }
        Behavior on width {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration / 2
                easing.type: Easing.OutCubic
            }
        }
    }

    Row {
        id: row
        x: 3
        anchors.verticalCenter: parent.verticalCenter
        Repeater {
            id: repeater
            model: root.modes
            delegate: Item {
                id: entry
                required property var modelData
                required property int index
                readonly property bool isActive: entry.index === root.current
                width: tabRow.implicitWidth + 20
                height: 26
                Row {
                    id: tabRow
                    anchors.centerIn: parent
                    spacing: 6
                    Text {
                        text: entry.modelData.icon
                        font.family: Icons.font
                        font.pixelSize: 13
                        color: entry.isActive ? Styling.srItem("primary") : Colors.overSurface
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: entry.modelData.label
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-2)
                        font.weight: entry.isActive ? Font.DemiBold : Font.Normal
                        color: entry.isActive ? Styling.srItem("primary") : Colors.overSurface
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selected(entry.modelData.id)
                }
            }
        }
    }
}
