pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.components
import qs.modules.components.kit

// The top row of a device panel (Wi-Fi, Bluetooth, mixer, effects), from
// the kit: the on/off Switch (`showSwitch`) with a quiet status, an
// optional `leading` control (the mixer's output / input switch) and the
// panel's actions as icon buttons at the right. The host names the panel,
// so there is no title.
// actions: [{icon, tooltip, enabled, loading, onClicked}]
Item {
    id: root

    property bool checked: false
    property bool showSwitch: true
    property Component leading: null
    property string status: ""
    property var actions: []

    signal toggled(bool value)

    implicitHeight: Math.max(Space.controlS, lead.implicitHeight)

    Row {
        id: lead
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Space.m

        Switch {
            objectName: "panelSwitch"
            visible: root.showSwitch
            anchors.verticalCenter: parent.verticalCenter
            checked: root.checked
            onToggled: value => root.toggled(value)
        }

        Loader {
            anchors.verticalCenter: parent.verticalCenter
            active: root.leading !== null
            visible: active
            sourceComponent: root.leading
        }

        KitText {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.status !== ""
            role: "caption"
            text: root.status
        }
    }

    Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Space.xs

        Repeater {
            model: root.actions

            IconButton {
                id: action
                required property var modelData
                size: "s"
                icon: action.modelData.icon
                enabled: action.modelData.enabled !== false
                opacity: enabled ? (action.modelData.loading ? 0.6 : 1) : 0.38
                onClicked: action.modelData.onClicked()

                StyledToolTip {
                    visible: action.hovered
                    tooltipText: action.modelData.tooltip ?? ""
                }
            }
        }
    }
}
