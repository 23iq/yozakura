pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "../connect/ConnectModel.js" as ConnectModel

// The Bluetooth page's band (list form): the devices connected now as
// chips with their glyph and battery, a "Look for devices" chip while the
// adapter is on, and Bluetooth itself as one big tile.
Stage {
    id: band
    objectName: "bluetoothBand"

    readonly property bool on: BluetoothService.enabled === true
    readonly property var connected: (BluetoothService.friendlyDeviceList || []).filter(d => d && d.connected)

    stageHeight: Space.px(150)

    Column {
        x: Space.xxl
        width: parent.width - x - tile.width - Space.xxl * 2
        anchors.verticalCenter: parent.verticalCenter
        spacing: Space.m

        KitText {
            objectName: "bluetoothState"
            role: "display"
            text: !band.on ? I18n.t("prefs.bt.off") : band.connected.length > 0 ? I18n.t("prefs.bt.n_connected").replace("%1", band.connected.length) : I18n.t("prefs.bt.none_connected")
        }
        Flow {
            width: parent.width
            spacing: Space.s
            visible: band.on
            Repeater {
                model: band.connected
                delegate: Chip {
                    required property var modelData
                    icon: Icons[ConnectModel.deviceGlyph(modelData.icon)]
                    active: true
                    text: modelData.name + (modelData.battery >= 0 ? "  " + Math.round(modelData.battery) + " %" : "")
                }
            }
            Chip {
                objectName: "btScan"
                icon: BluetoothService.discovering ? Icons.spinnerGap : Icons.magnifyingGlass
                quiet: true
                text: I18n.t(BluetoothService.discovering ? "prefs.bt.searching" : "prefs.bt.search")
                onClicked: BluetoothService.discovering ? BluetoothService.stopDiscovery() : BluetoothService.startDiscovery()
            }
        }
    }

    Tile {
        id: tile
        objectName: "bluetoothTile"
        anchors.right: parent.right
        anchors.rightMargin: Space.xxl
        anchors.verticalCenter: parent.verticalCenter
        width: Space.controlXL * 2
        icon: band.on ? Icons.bluetooth : Icons.bluetoothOff
        text: I18n.t("prefs.bt.bluetooth")
        subtext: I18n.t(band.on ? "prefs.net.on" : "prefs.net.off")
        active: band.on
        onClicked: BluetoothService.setEnabled(!band.on)
    }
}
