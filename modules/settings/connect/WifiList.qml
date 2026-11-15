import QtQuick
import qs.modules.services
import qs.modules.settings.connect
import "ConnectModel.js" as ConnectModel

// Network > the Wi-Fi networks around you, the connected one first, then
// by signal; a click picks one for the details card. Rescans when the
// page opens.
DeviceList {
    id: root

    property var entry
    readonly property var networks: NetworkService.friendlyWifiNetworks || []

    objectName: "wifiList"
    current: ConnectModel.pick(root.networks, "ssid", ConnectState.ssid, "active")?.ssid ?? ""
    empty: I18n.t(NetworkService.wifiEnabled ? "prefs.net.none" : "prefs.net.wifi_off")
    rows: root.networks.map(ap => ({
                "key": ap.ssid,
                "icon": ["wifiNone", "wifiLow", "wifiMedium", "wifiHigh", "wifiHigh"][ConnectModel.bars(ap.strength)],
                "title": ap.ssid,
                "line": ap.active ? I18n.t("prefs.net.connected") : ConnectModel.wifiLine(ap, k => I18n.t(k)),
                "on": ap.active === true,
                "trailing": ap.isSecure ? "lock" : ""
            }))
    onPicked: key => ConnectState.ssid = key
    Component.onCompleted: {
        if (NetworkService.wifiEnabled && NetworkService.rescanWifi)
            NetworkService.rescanWifi();
    }
}
