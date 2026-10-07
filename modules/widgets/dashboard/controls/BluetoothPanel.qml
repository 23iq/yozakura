pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit

// Bluetooth devices (dashboard home details, bento quick controls, the
// settings Connect page), from the kit: the on/off switch and actions
// (open the manager, scan), then one BluetoothDeviceItem per device.
// Opening only refreshes the list; discovery stops on close.
Item {
    id: root

    property int maxContentWidth: 480
    readonly property int contentWidth: Math.min(width, maxContentWidth)
    readonly property real sideMargin: (width - contentWidth) / 2

    Timer {
        interval: 300
        running: BluetoothService.enabled
        onTriggered: BluetoothService.updateDevices()
    }

    Component.onDestruction: BluetoothService.stopDiscovery()

    DeviceListHeader {
        id: header
        objectName: "bluetoothHeader"
        x: root.sideMargin
        width: root.contentWidth
        checked: BluetoothService.enabled
        status: BluetoothService.discovering ? I18n.t("bluetooth.scanning") : ""
        actions: [
            {
                icon: Icons.popOpen,
                tooltip: I18n.t("bluetooth.open_manager"),
                onClicked: () => Quickshell.execDetached(["blueman-manager"])
            },
            {
                icon: Icons.sync,
                tooltip: I18n.t("bluetooth.scan"),
                enabled: BluetoothService.enabled,
                loading: BluetoothService.discovering || BluetoothService.isUpdating,
                onClicked: () => BluetoothService.startDiscovery()
            }
        ]
        onToggled: value => {
            BluetoothService.setEnabled(value);
            if (value)
                BluetoothService.startDiscovery();
        }
    }

    ListView {
        id: list
        objectName: "deviceList"
        anchors.fill: parent
        anchors.topMargin: header.height + Space.s
        clip: true
        spacing: Space.xs / 2
        boundsBehavior: Flickable.StopAtBounds
        model: BluetoothService.friendlyDeviceList

        delegate: BluetoothDeviceItem {
            required property var modelData
            x: root.sideMargin
            width: root.contentWidth
            device: modelData
        }

        KitText {
            anchors.centerIn: parent
            visible: list.count === 0 && !BluetoothService.discovering
            role: "caption"
            text: BluetoothService.enabled ? I18n.t("bluetooth.no_devices") : I18n.t("bluetooth.disabled")
        }
    }
}
