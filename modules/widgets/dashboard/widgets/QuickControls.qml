pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit

// Bento widget "quickControls": Wi-Fi, Bluetooth, night light, caffeine and
// game mode as kit toggles (active while on), spread over the tile. Right-
// click or hold Wi-Fi / Bluetooth to open its device panel in the tile
// (the section label then names it, its "Done" action closes it).
HostWidget {
    id: root

    property int expandedPanel: -1 // -1: none, 0: wifi, 1: bluetooth
    readonly property var panels: ["../controls/WifiPanel.qml", "../controls/BluetoothPanel.qml"]

    function togglePanel(index) {
        root.expandedPanel = root.expandedPanel === index ? -1 : index;
    }

    onVisibleChanged: {
        if (!visible)
            root.expandedPanel = -1;
        else
            BluetoothService.initialize();
    }

    Group {
        id: group
        anchors.fill: parent
        fill: true
        bare: !root.framed
        label: root.expandedPanel === 0 ? I18n.t("bento.controls.wifi") : (root.expandedPanel === 1 ? I18n.t("bento.controls.bluetooth") : I18n.t("bento.label.controls"))
        actionText: root.expandedPanel !== -1 ? I18n.t("bento.done") : ""
        onActionTriggered: root.expandedPanel = -1

        Item {
            visible: root.expandedPanel === -1
            width: parent.width
            height: visible ? Math.min(group.bodyHeight, Space.controlM * 2) : 0

            Row {
                anchors.centerIn: parent
                spacing: Math.max(0, Math.min(Space.l, (parent.width - Space.controlM * 5) / 4))

                ControlToggle {
                    icon: {
                        if (!NetworkService.wifiEnabled)
                            return Icons.wifiOff;
                        const s = NetworkService.networkStrength;
                        if (s === 0 || s >= 75)
                            return Icons.wifiHigh;
                        if (s < 25)
                            return Icons.wifiNone;
                        return s < 50 ? Icons.wifiLow : Icons.wifiMedium;
                    }
                    active: NetworkService.wifiEnabled
                    tooltipText: NetworkService.wifiEnabled ? I18n.t("wifi.tooltip_on") : I18n.t("wifi.tooltip_off")
                    onClicked: NetworkService.toggleWifi()
                    onMore: root.togglePanel(0)
                }
                ControlToggle {
                    icon: !BluetoothService.enabled ? Icons.bluetoothOff : (BluetoothService.connected ? Icons.bluetoothConnected : Icons.bluetooth)
                    active: BluetoothService.enabled
                    tooltipText: !BluetoothService.enabled ? I18n.t("controls.bluetooth_off") : (BluetoothService.connected ? I18n.t("controls.bluetooth_connected") : I18n.t("controls.bluetooth_on"))
                    onClicked: BluetoothService.toggle()
                    onMore: root.togglePanel(1)
                }
                ControlToggle {
                    icon: Icons.nightLight
                    active: NightLightClient.active
                    tooltipText: NightLightClient.active ? I18n.t("controls.night_light_on") : I18n.t("controls.night_light_off")
                    onClicked: NightLightClient.toggle()
                }
                ControlToggle {
                    icon: Icons.caffeine
                    active: CaffeineClient.inhibit
                    tooltipText: CaffeineClient.inhibit ? I18n.t("controls.caffeine_on") : I18n.t("controls.caffeine_off")
                    onClicked: CaffeineClient.toggle()
                }
                ControlToggle {
                    icon: Icons.gameMode
                    active: GameModeClient.toggled
                    tooltipText: GameModeClient.toggled ? I18n.t("controls.game_mode_on") : I18n.t("controls.game_mode_off")
                    onClicked: GameModeClient.toggle()
                }
            }
        }

        // The device panel of Wi-Fi / Bluetooth, in place of the toggles.
        Loader {
            width: parent.width
            height: active ? group.bodyHeight : 0
            active: root.expandedPanel !== -1
            asynchronous: true
            clip: true
            source: root.expandedPanel === -1 ? "" : root.panels[root.expandedPanel]
            onLoaded: item.maxContentWidth = width
        }
    }
}
