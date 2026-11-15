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
    // the band got less than it asked for (a short window): the heading
    // steps down from display size so it never runs over the band's top
    readonly property bool roomy: band.height >= band.stageHeight - Space.s

    // a narrow window: the tile takes its own width, not the big one
    readonly property bool compact: band.width < Space.px(760)

    Column {
        id: what
        x: Space.xxl
        width: tile.x - x - Space.xl
        anchors.verticalCenter: parent.verticalCenter
        spacing: band.roomy ? Space.m : Space.s

        // the state and, beside it, "Look for devices"
        Flow {
            id: head
            width: parent.width
            spacing: Space.m
            KitText {
                objectName: "bluetoothState"
                width: Math.min(implicitWidth, what.width)
                wrapMode: Text.WordWrap
                role: band.roomy ? "display" : "title"
                text: !band.on ? I18n.t("prefs.bt.off") : band.connected.length > 0 ? I18n.t("prefs.bt.n_connected").replace("%1", band.connected.length) : I18n.t("prefs.bt.none_connected")
            }
            Chip {
                id: scan
                objectName: "btScan"
                visible: band.on
                icon: BluetoothService.discovering ? Icons.spinnerGap : Icons.magnifyingGlass
                quiet: true
                text: I18n.t(BluetoothService.discovering ? "prefs.bt.searching" : "prefs.bt.search")
                onClicked: BluetoothService.discovering ? BluetoothService.stopDiscovery() : BluetoothService.startDiscovery()
            }
        }
        // the devices connected now, as many whole lines of chips as the
        // band holds (the list under it names them all)
        Flow {
            id: chips
            readonly property real line: scan.height + chips.spacing
            readonly property real room: band.height - Space.m * 2 - (head.height + what.spacing)
            width: parent.width
            height: Math.min(implicitHeight, Math.max(0, Math.floor((room + chips.spacing) / line)) * line - chips.spacing)
            clip: true
            spacing: Space.s
            visible: band.on && band.connected.length > 0 && height > 0
            Repeater {
                model: band.connected
                delegate: Chip {
                    required property var modelData
                    icon: Icons[ConnectModel.deviceGlyph(modelData.icon)]
                    active: true
                    text: modelData.name + (modelData.battery >= 0 ? "  " + Math.round(modelData.battery) + " %" : "")
                }
            }
        }
    }

    Tile {
        id: tile
        objectName: "bluetoothTile"
        anchors.right: parent.right
        anchors.rightMargin: Space.xxl
        anchors.verticalCenter: parent.verticalCenter
        width: band.compact ? implicitWidth : Space.controlXL * 2
        icon: band.on ? Icons.bluetooth : Icons.bluetoothOff
        text: I18n.t("prefs.bt.bluetooth")
        subtext: I18n.t(band.on ? "prefs.net.on" : "prefs.net.off")
        active: band.on
        onClicked: BluetoothService.setEnabled(!band.on)
    }
}
