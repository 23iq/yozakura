import QtQuick
import qs.modules.services
import qs.modules.settings.connect
import "ConnectModel.js" as ConnectModel

// Bluetooth > your devices (connected, then paired, then found nearby),
// each with its glyph and state; a click picks one for the details card.
DeviceList {
    id: root

    property var entry
    readonly property var devices: BluetoothService.friendlyDeviceList || []

    objectName: "bluetoothList"
    current: ConnectModel.pick(root.devices, "address", ConnectState.device, "connected")?.address ?? ""
    empty: I18n.t(BluetoothService.enabled ? "prefs.bt.empty" : "prefs.bt.off")
    rows: root.devices.map(d => ({
                "key": d.address,
                "icon": ConnectModel.deviceGlyph(d.icon),
                "title": d.name,
                "line": ConnectModel.deviceLine(d, k => I18n.t(k)),
                "on": d.connected === true,
                "trailing": ""
            }))
    onPicked: key => ConnectState.device = key
}
