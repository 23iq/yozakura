pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings
import qs.modules.settings.connect
import "ConnectModel.js" as ConnectModel

// Bluetooth > the picked device: its glyph in a ring that is its battery
// (when it reports one), its name and state, and what you can do with it:
// Connect / Disconnect, Pair a new one, Forget a known one.
Item {
    id: root

    property var entry
    property real fillHeight: 0
    readonly property var device: ConnectModel.pick(BluetoothService.friendlyDeviceList || [], "address", ConnectState.device, "connected")
    readonly property bool hasBattery: !!root.device && root.device.connected && Number(root.device.battery) >= 0

    objectName: "bluetoothDetails"
    // the facts, then the actions under them: never over the last fact
    readonly property real contentHeight: facts.y + facts.height + Space.m + actions.height
    implicitHeight: Math.max(root.fillHeight > 0 ? root.fillHeight : Space.controlL * 3, root.device ? root.contentHeight : 0)

    KitText {
        visible: !root.device
        role: "secondary"
        text: I18n.t("prefs.bt.pick")
    }

    FactRows {
        id: facts
        visible: !!root.device
        y: ring.height + Space.m
        width: root.width
        facts: root.device ? [[I18n.t("prefs.bt.battery"), root.hasBattery ? Math.round(root.device.battery) + " %" : ""], [I18n.t("prefs.bt.trusted"), root.device.paired ? I18n.t(root.device.trusted ? "prefs.net.on" : "prefs.net.off") : ""], [I18n.t("prefs.bt.address"), root.device.address]] : []
    }

    Row {
        visible: !!root.device
        spacing: Space.l

        Ring {
            id: ring
            width: Space.controlL + Space.l
            height: width
            value: root.hasBattery ? Number(root.device.battery) / 100 : 0
            trackColor: root.hasBattery ? Type.track : "transparent"
            Icon {
                icon: root.device ? Icons[ConnectModel.deviceGlyph(root.device.icon)] : ""
                role: "display"
                tone: root.device && root.device.connected ? "accent" : "secondary"
            }
        }

        Column {
            anchors.verticalCenter: ring.verticalCenter
            spacing: Space.xs
            KitText {
                role: "title"
                text: root.device ? root.device.name : ""
            }
            KitText {
                role: "secondary"
                text: ConnectModel.deviceLine(root.device, k => I18n.t(k))
            }
        }
    }

    Row {
        id: actions
        visible: !!root.device
        y: Math.max(root.height - height, facts.y + facts.height + Space.m)
        spacing: Space.s
        PillButton {
            objectName: "btAction"
            kind: root.device && root.device.connected ? "ghost" : "filled"
            icon: root.device && root.device.connected ? "xCircle" : "link"
            text: I18n.t(!root.device ? "prefs.bt.connect" : root.device.connected ? "prefs.bt.disconnect" : root.device.paired ? "prefs.bt.connect" : "prefs.bt.pair")
            onClicked: {
                const d = root.device;
                if (d.connected)
                    BluetoothService.disconnectDevice(d.address);
                else if (d.paired)
                    BluetoothService.connectDevice(d.address);
                else
                    BluetoothService.pairDevice(d.address);
            }
        }
        PillButton {
            objectName: "btForget"
            visible: !!root.device && root.device.paired
            kind: "ghost"
            icon: "trash"
            text: I18n.t("prefs.bt.forget")
            onClicked: BluetoothService.removeDevice(root.device.address)
        }
    }
}
