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
    // Stage home: the toggles share the width as wide buttons (a larger hit area).
    property bool stretch: false
    readonly property real gap: root.stretch ? Space.s : Math.max(0, (root.width - Space.controlM * root.count) / Math.max(1, root.count - 1))
    readonly property real cellW: root.stretch ? Math.max(Space.controlM, (root.width - root.gap * (root.count - 1)) / Math.max(1, root.count)) : Space.controlM

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
            width: root.cellW
            objectName: "wifiToggle"
            icon: NetworkService.wifiEnabled ? Icons.wifiHigh : Icons.wifiOff
            active: NetworkService.wifiEnabled
            tooltipText: root.tip(NetworkService.wifiEnabled, I18n.t("dashboard.home.wifi"), NetworkService.networkName)
            onClicked: NetworkService.toggleWifi()
            onMore: root.details("wifi")
        }

        ControlToggle {
            width: root.cellW
            objectName: "bluetoothToggle"
            icon: !BluetoothService.enabled ? Icons.bluetoothOff : (BluetoothService.connected ? Icons.bluetoothConnected : Icons.bluetooth)
            active: BluetoothService.enabled
            tooltipText: root.tip(BluetoothService.enabled, I18n.t("dashboard.home.bluetooth"), root.btDevice)
            onClicked: BluetoothService.toggle()
            onMore: root.details("bluetooth")
        }

        ControlToggle {
            width: root.cellW
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
            width: root.cellW
            objectName: "silenceToggle"
            icon: Notifications.silent ? Icons.bellZ : Icons.bell
            active: Notifications.silent
            tooltipText: root.tip(Notifications.silent, I18n.t("dashboard.home.silence"), "")
            onClicked: Notifications.toggleDnd()
        }

        ControlToggle {
            width: root.cellW
            objectName: "nightToggle"
            icon: Icons.nightLight
            active: NightLightClient.active
            tooltipText: root.tip(NightLightClient.active, I18n.t("dashboard.home.night_light"), "")
            onClicked: NightLightClient.toggle()
        }

        ControlToggle {
            width: root.cellW
            objectName: "awakeToggle"
            icon: Icons.caffeine
            active: CaffeineClient.inhibit
            tooltipText: root.tip(CaffeineClient.inhibit, I18n.t("dashboard.home.awake"), "")
            onClicked: CaffeineClient.toggle()
        }

        ControlToggle {
            width: root.cellW
            objectName: "gameToggle"
            icon: Icons.gameMode
            active: GameModeClient.toggled
            tooltipText: root.tip(GameModeClient.toggled, I18n.t("dashboard.home.game"), "")
            onClicked: GameModeClient.toggle()
        }
    }
}
