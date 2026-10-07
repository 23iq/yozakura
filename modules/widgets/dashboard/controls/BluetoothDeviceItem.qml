pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "DeviceGlyphs.js" as DeviceGlyphs

// One Bluetooth device as a kit ListRow: its kind's glyph, the name with
// its state and battery, the connected one selected. A click unfolds
// Forget (paired devices) and Connect / Disconnect (the primary action).
Column {
    id: root

    required property BluetoothDevice device
    property bool expanded: false
    readonly property bool connected: root.device?.connected ?? false

    spacing: Space.xs

    ListRow {
        objectName: "deviceRow"
        width: parent.width
        title: root.device?.name ?? ""
        subtitle: DeviceGlyphs.bluetoothStatus(root.connected, root.device?.paired ?? false, root.device?.batteryAvailable ? root.device.battery : -1, {
            "connected": I18n.t("bluetooth.connected"),
            "paired": I18n.t("bluetooth.paired"),
            "notPaired": I18n.t("bluetooth.not_paired")
        })
        selected: root.connected
        leading: Component {
            Text {
                text: Icons[DeviceGlyphs.bluetoothGlyph(root.device?.icon)] || Icons.bluetooth
                font.family: Icons.font
                font.pixelSize: Type.iconSize("body")
                color: root.connected ? Type.accent : Type.secondary
            }
        }
        onClicked: root.expanded = !root.expanded
    }

    Row {
        anchors.right: parent.right
        spacing: Space.s
        visible: root.expanded

        Chip {
            objectName: "forgetChip"
            visible: root.device?.paired ?? false
            icon: Icons.trash
            text: I18n.t("bluetooth.forget")
            onClicked: root.device?.forget()
        }

        Chip {
            objectName: "connectChip"
            primary: !root.connected
            icon: root.connected ? Icons.cancel : Icons.link
            text: root.connected ? I18n.t("bluetooth.disconnect") : I18n.t("bluetooth.connect")
            onClicked: {
                if (root.connected)
                    root.device.disconnect();
                else
                    root.device.connect();
            }
        }
    }
}
