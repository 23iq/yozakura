pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit

// Wi-Fi networks (dashboard home details, bento quick controls, the
// settings Connect page), from the kit: the on/off switch with the status
// and actions (captive portal, network settings, rescan), then one
// WifiNetworkItem per network, scrolling.
Item {
    id: root

    property int maxContentWidth: 480
    readonly property int contentWidth: Math.min(width, maxContentWidth)
    readonly property real sideMargin: (width - contentWidth) / 2

    // Defer the scan so opening stays smooth.
    Timer {
        interval: 300
        running: true
        onTriggered: NetworkService.rescanWifi()
    }

    DeviceListHeader {
        id: header
        objectName: "wifiHeader"
        x: root.sideMargin
        width: root.contentWidth
        checked: NetworkService.wifiStatus !== "disabled"
        status: NetworkService.wifiConnecting ? I18n.t("wifi.connecting") : (NetworkService.wifiStatus === "limited" ? I18n.t("wifi.limited") : "")
        actions: [
            {
                icon: Icons.globe,
                tooltip: I18n.t("wifi.open_portal"),
                enabled: NetworkService.wifiStatus === "limited",
                onClicked: () => NetworkService.openPublicWifiPortal()
            },
            {
                icon: Icons.popOpen,
                tooltip: I18n.t("wifi.network_settings"),
                onClicked: () => Quickshell.execDetached(["nm-connection-editor"])
            },
            {
                icon: Icons.sync,
                tooltip: I18n.t("wifi.rescan"),
                enabled: NetworkService.wifiEnabled,
                loading: NetworkService.wifiScanning || NetworkService.isUpdating,
                onClicked: () => NetworkService.rescanWifi()
            }
        ]
        onToggled: value => {
            NetworkService.enableWifi(value);
            if (value)
                NetworkService.rescanWifi();
        }
    }

    ListView {
        id: list
        objectName: "networkList"
        anchors.fill: parent
        anchors.topMargin: header.height + Space.s
        clip: true
        spacing: Space.xs / 2
        boundsBehavior: Flickable.StopAtBounds
        model: NetworkService.friendlyWifiNetworks

        delegate: WifiNetworkItem {
            required property var modelData
            x: root.sideMargin
            width: root.contentWidth
            network: modelData
        }

        KitText {
            anchors.centerIn: parent
            visible: list.count === 0 && !NetworkService.wifiScanning
            role: "caption"
            text: NetworkService.wifiEnabled ? I18n.t("wifi.no_networks") : I18n.t("wifi.disabled")
        }
    }
}
