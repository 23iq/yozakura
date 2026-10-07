import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "HomeModel.js" as HomeModel

// Quick toggles of the composed dashboard, wrapping Chips. Same service
// calls as widgets/QuickControls.qml; Wi-Fi and Bluetooth show what they are
// connected to, Silence is do-not-disturb, Awake the idle inhibitor.
Flow {
    id: root

    readonly property string btDevice: HomeModel.connectedDevice(BluetoothService.friendlyDeviceList)

    spacing: Space.s

    Component.onCompleted: BluetoothService.initialize()

    Chip {
        objectName: "wifiChip"
        icon: NetworkService.wifiEnabled ? Icons.wifiHigh : Icons.wifiOff
        text: NetworkService.wifiEnabled && NetworkService.networkName !== "" ? NetworkService.networkName : I18n.t("dashboard.home.wifi")
        active: NetworkService.wifiEnabled
        onClicked: NetworkService.toggleWifi()
    }

    Chip {
        objectName: "bluetoothChip"
        icon: !BluetoothService.enabled ? Icons.bluetoothOff : (BluetoothService.connected ? Icons.bluetoothConnected : Icons.bluetooth)
        text: BluetoothService.enabled && root.btDevice !== "" ? root.btDevice : I18n.t("dashboard.home.bluetooth")
        active: BluetoothService.enabled
        onClicked: BluetoothService.toggle()
    }

    Chip {
        objectName: "silenceChip"
        icon: Notifications.silent ? Icons.bellZ : Icons.bell
        text: I18n.t("dashboard.home.silence")
        active: Notifications.silent
        onClicked: Notifications.toggleDnd()
    }

    Chip {
        objectName: "awakeChip"
        icon: Icons.caffeine
        text: I18n.t("dashboard.home.awake")
        active: CaffeineClient.inhibit
        onClicked: CaffeineClient.toggle()
    }

    Chip {
        objectName: "gameChip"
        icon: Icons.gameMode
        text: I18n.t("dashboard.home.game")
        active: GameModeClient.toggled
        onClicked: GameModeClient.toggle()
    }
}
