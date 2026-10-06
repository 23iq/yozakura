pragma Singleton
import QtQuick
import qs.modules.services
import "IslandSources.js" as Sources

// A Bluetooth device connected or disconnected: its name and, when known,
// its battery as a ring.
EphemeralProvider {
    id: root

    source: "bluetooth"

    readonly property var connectedDevices: BluetoothService.friendlyDeviceList.filter(d => d && d.connected).map(d => ({
                address: d.address,
                name: d.name,
                battery: d.battery
            }))
    property var _last: null

    onLiveChanged: if (live)
        BluetoothService.initialize()
    onConnectedDevicesChanged: {
        const prev = root._last;
        root._last = root.connectedDevices;
        if (prev === null)
            return;
        const events = Sources.bluetoothEvents(prev, root.connectedDevices);
        if (events.length > 0)
            root.flash(Sources.bluetoothActivity(events[0], {
                connected: I18n.t("activities.bluetooth.connected"),
                disconnected: I18n.t("activities.bluetooth.disconnected")
            }));
    }
    Component.onCompleted: {
        if (live)
            BluetoothService.initialize();
        root._last = root.connectedDevices;
    }
}
