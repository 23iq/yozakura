pragma Singleton

import QtQuick

// What the list cards of the connect pages (Network, Bluetooth) have
// picked, so the details card beside them shows it: the Wi-Fi network by
// SSID, the Bluetooth device by address ("" = the connected one, if any).
// Window-local, never saved.
QtObject {
    property string ssid: ""
    property string device: ""
}
