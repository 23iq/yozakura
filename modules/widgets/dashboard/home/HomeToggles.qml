import QtQuick
import qs.modules.theme
import qs.modules.services

// Quick toggles of the composed dashboard. Same service calls as
// widgets/QuickControls.qml; Wi-Fi and Bluetooth show what they are
// connected to, Silence is do-not-disturb, Awake the idle inhibitor.
Flow {
    id: root

    spacing: Metrics.spacing / 2

    readonly property string btDevice: {
        const list = BluetoothService.friendlyDeviceList;
        for (let i = 0; i < list.length; i++) {
            if (list[i] && list[i].connected)
                return list[i].name || "";
        }
        return "";
    }

    Component.onCompleted: BluetoothService.initialize()

    ToggleChip {
        objectName: "wifiChip"
        icon: NetworkService.wifiEnabled ? Icons.wifiHigh : Icons.wifiOff
        label: NetworkService.wifiEnabled && NetworkService.networkName !== "" ? NetworkService.networkName : I18n.t("dashboard.home.wifi")
        active: NetworkService.wifiEnabled
        onClicked: NetworkService.toggleWifi()
    }

    ToggleChip {
        objectName: "bluetoothChip"
        icon: !BluetoothService.enabled ? Icons.bluetoothOff : (BluetoothService.connected ? Icons.bluetoothConnected : Icons.bluetooth)
        label: BluetoothService.enabled && root.btDevice !== "" ? root.btDevice : I18n.t("dashboard.home.bluetooth")
        active: BluetoothService.enabled
        onClicked: BluetoothService.toggle()
    }

    ToggleChip {
        objectName: "silenceChip"
        icon: Notifications.silent ? Icons.bellZ : Icons.bell
        label: I18n.t("dashboard.home.silence")
        active: Notifications.silent
        onClicked: Notifications.toggleDnd()
    }

    ToggleChip {
        objectName: "awakeChip"
        icon: Icons.caffeine
        label: I18n.t("dashboard.home.awake")
        active: CaffeineClient.inhibit
        onClicked: CaffeineClient.toggle()
    }

    ToggleChip {
        objectName: "gameChip"
        icon: Icons.gameMode
        label: I18n.t("dashboard.home.game")
        active: GameModeClient.toggled
        onClicked: GameModeClient.toggle()
    }
}
