import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "HomeModel.js" as HomeModel

// Quick toggles of the composed dashboard, wrapping Chips. Same service
// calls as widgets/QuickControls.qml; Wi-Fi and Bluetooth show what they are
// connected to, Silence is do-not-disturb, Awake the idle inhibitor. When
// the five don't fit one row, inactive chips show only their icon
// (HomeModel.chipLabels), so the row never wraps a lone chip.
Flow {
    id: root

    readonly property string btDevice: HomeModel.connectedDevice(BluetoothService.friendlyDeviceList)
    readonly property var chips: [wifiChip, bluetoothChip, silenceChip, awakeChip, gameChip]
    readonly property var labels: HomeModel.chipLabels(root.chips.map(c => c.fullWidth), root.chips.map(c => c.compactWidth), root.chips.map(c => c.active), root.width, root.spacing)

    spacing: Space.s

    Component.onCompleted: BluetoothService.initialize()

    Chip {
        id: wifiChip
        objectName: "wifiChip"
        showLabel: root.labels[0] !== false
        icon: NetworkService.wifiEnabled ? Icons.wifiHigh : Icons.wifiOff
        text: NetworkService.wifiEnabled && NetworkService.networkName !== "" ? NetworkService.networkName : I18n.t("dashboard.home.wifi")
        active: NetworkService.wifiEnabled
        onClicked: NetworkService.toggleWifi()
    }

    Chip {
        id: bluetoothChip
        objectName: "bluetoothChip"
        showLabel: root.labels[1] !== false
        icon: !BluetoothService.enabled ? Icons.bluetoothOff : (BluetoothService.connected ? Icons.bluetoothConnected : Icons.bluetooth)
        text: BluetoothService.enabled && root.btDevice !== "" ? root.btDevice : I18n.t("dashboard.home.bluetooth")
        active: BluetoothService.enabled
        onClicked: BluetoothService.toggle()
    }

    Chip {
        id: silenceChip
        objectName: "silenceChip"
        showLabel: root.labels[2] !== false
        icon: Notifications.silent ? Icons.bellZ : Icons.bell
        text: I18n.t("dashboard.home.silence")
        active: Notifications.silent
        onClicked: Notifications.toggleDnd()
    }

    Chip {
        id: awakeChip
        objectName: "awakeChip"
        showLabel: root.labels[3] !== false
        icon: Icons.caffeine
        text: I18n.t("dashboard.home.awake")
        active: CaffeineClient.inhibit
        onClicked: CaffeineClient.toggle()
    }

    Chip {
        id: gameChip
        objectName: "gameChip"
        showLabel: root.labels[4] !== false
        icon: Icons.gameMode
        text: I18n.t("dashboard.home.game")
        active: GameModeClient.toggled
        onClicked: GameModeClient.toggle()
    }
}
