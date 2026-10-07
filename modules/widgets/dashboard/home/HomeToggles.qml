import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.widgets.dashboard.widgets
import "HomeModel.js" as HomeModel

// Quick toggles of the composed dashboard: one row of icon-only
// ControlToggles spread over the width (active while the feature is on;
// the name and state are the tooltip). Same service calls as the bento
// QuickControls. Right-click or hold Wi-Fi, Bluetooth or the microphone to
// open its details (`details(kind)`: "wifi", "bluetooth", "input").
Item {
    id: root

    readonly property string btDevice: HomeModel.connectedDevice(BluetoothService.friendlyDeviceList)
    readonly property var micAudio: Audio.source?.audio ?? null
    readonly property bool micOn: root.micAudio !== null && !root.micAudio.muted
    readonly property int count: row.children.length
    readonly property real gap: Math.max(0, (root.width - Space.controlM * root.count) / Math.max(1, root.count - 1))

    signal details(string kind)

    function tip(on: bool, name: string, extra: string): string {
        return name + " · " + I18n.t(on ? "dashboard.home.on" : "dashboard.home.off") + (on && extra !== "" ? " · " + extra : "");
    }

    implicitWidth: Space.controlM * root.count
    implicitHeight: Space.controlM

    Component.onCompleted: BluetoothService.initialize()

    Row {
        id: row
        spacing: root.gap

        ControlToggle {
            objectName: "wifiToggle"
            icon: NetworkService.wifiEnabled ? Icons.wifiHigh : Icons.wifiOff
            active: NetworkService.wifiEnabled
            tooltipText: root.tip(NetworkService.wifiEnabled, I18n.t("dashboard.home.wifi"), NetworkService.networkName)
            onClicked: NetworkService.toggleWifi()
            onMore: root.details("wifi")
        }

        ControlToggle {
            objectName: "bluetoothToggle"
            icon: !BluetoothService.enabled ? Icons.bluetoothOff : (BluetoothService.connected ? Icons.bluetoothConnected : Icons.bluetooth)
            active: BluetoothService.enabled
            tooltipText: root.tip(BluetoothService.enabled, I18n.t("dashboard.home.bluetooth"), root.btDevice)
            onClicked: BluetoothService.toggle()
            onMore: root.details("bluetooth")
        }

        ControlToggle {
            objectName: "micToggle"
            icon: root.micOn ? Icons.mic : Icons.micSlash
            active: root.micOn
            enabled: root.micAudio !== null
            tooltipText: root.tip(root.micOn, I18n.t("dashboard.home.microphone"), "")
            onClicked: {
                if (root.micAudio)
                    root.micAudio.muted = !root.micAudio.muted;
            }
            onMore: root.details("input")
        }

        ControlToggle {
            objectName: "silenceToggle"
            icon: Notifications.silent ? Icons.bellZ : Icons.bell
            active: Notifications.silent
            tooltipText: root.tip(Notifications.silent, I18n.t("dashboard.home.silence"), "")
            onClicked: Notifications.toggleDnd()
        }

        ControlToggle {
            objectName: "nightToggle"
            icon: Icons.nightLight
            active: NightLightClient.active
            tooltipText: root.tip(NightLightClient.active, I18n.t("dashboard.home.night_light"), "")
            onClicked: NightLightClient.toggle()
        }

        ControlToggle {
            objectName: "awakeToggle"
            icon: Icons.caffeine
            active: CaffeineClient.inhibit
            tooltipText: root.tip(CaffeineClient.inhibit, I18n.t("dashboard.home.awake"), "")
            onClicked: CaffeineClient.toggle()
        }

        ControlToggle {
            objectName: "gameToggle"
            icon: Icons.gameMode
            active: GameModeClient.toggled
            tooltipText: root.tip(GameModeClient.toggled, I18n.t("dashboard.home.game"), "")
            onClicked: GameModeClient.toggle()
        }
    }
}
