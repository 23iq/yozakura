import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "../home/HomeModel.js" as HomeModel

// Quick toggles of the stage home as kit Tiles in two rows: Wi-Fi and
// Bluetooth as wide tiles (name + state, a caret zone that opens the
// detail: `details("wifi" | "bluetooth")`), then the microphone, silence,
// night light, stay awake and game mode as square tiles (icon over the
// name; right-click or hold the microphone for `details("input")`). Solid
// accent while on. `compact` (low screens): one row of seven icon-only
// tiles, the names as tooltips. Same service calls as home/HomeToggles.
Flow {
    id: root

    readonly property string btDevice: HomeModel.connectedDevice(BluetoothService.friendlyDeviceList)
    readonly property var micAudio: Audio.source?.audio ?? null
    readonly property bool micOn: root.micAudio !== null && !root.micAudio.muted
    readonly property string onText: I18n.t("dashboard.home.on")
    readonly property string offText: I18n.t("dashboard.home.off")
    property bool compact: false
    readonly property real tileH: root.compact ? Space.controlM : Space.controlM + Space.l
    readonly property real squareW: Math.floor(root.compact ? (root.width - root.spacing * 6) / 7 : (root.width - root.spacing * 4) / 5)
    readonly property real wideW: root.compact ? root.squareW : Math.floor((root.width - root.spacing) / 2)
    // The two-row height, whatever the mode (the host sizes itself by it).
    readonly property real fullHeight: (Space.controlM + Space.l) * 2 + Space.s

    signal details(string kind)

    function stateText(on: bool, extra: string): string {
        return on ? (extra !== "" ? extra : root.onText) : root.offText;
    }

    function tip(on: bool, name: string, extra: string): string {
        return name + " · " + root.stateText(on, extra);
    }

    spacing: Space.s

    Component.onCompleted: BluetoothService.initialize()

    Tile {
        objectName: "wifiToggle"
        width: root.wideW
        height: root.tileH
        vertical: root.compact
        showLabel: !root.compact
        icon: NetworkService.wifiEnabled ? Icons.wifiHigh : Icons.wifiOff
        text: I18n.t("dashboard.home.wifi")
        subtext: root.stateText(NetworkService.wifiEnabled, NetworkService.networkName ?? "")
        active: NetworkService.wifiEnabled
        hasMore: true
        tooltipText: root.tip(NetworkService.wifiEnabled, text, NetworkService.networkName ?? "")
        onClicked: NetworkService.toggleWifi()
        onMore: root.details("wifi")
    }

    Tile {
        objectName: "bluetoothToggle"
        width: root.wideW
        height: root.tileH
        vertical: root.compact
        showLabel: !root.compact
        icon: !BluetoothService.enabled ? Icons.bluetoothOff : (BluetoothService.connected ? Icons.bluetoothConnected : Icons.bluetooth)
        text: I18n.t("dashboard.home.bluetooth")
        subtext: root.stateText(BluetoothService.enabled, root.btDevice)
        active: BluetoothService.enabled
        hasMore: true
        tooltipText: root.tip(BluetoothService.enabled, text, root.btDevice)
        onClicked: BluetoothService.toggle()
        onMore: root.details("bluetooth")
    }

    Tile {
        objectName: "micToggle"
        width: root.squareW
        height: root.tileH
        vertical: true
        showLabel: !root.compact
        icon: root.micOn ? Icons.mic : Icons.micSlash
        text: I18n.t("dashboard.home.short.mic")
        active: root.micOn
        enabled: root.micAudio !== null
        tooltipText: root.tip(root.micOn, I18n.t("dashboard.home.microphone"), "")
        onClicked: {
            if (root.micAudio)
                root.micAudio.muted = !root.micAudio.muted;
        }
        onMore: root.details("input")
    }

    Tile {
        objectName: "silenceToggle"
        width: root.squareW
        height: root.tileH
        vertical: true
        showLabel: !root.compact
        icon: Notifications.silent ? Icons.bellZ : Icons.bell
        text: I18n.t("dashboard.home.silence")
        active: Notifications.silent
        tooltipText: root.tip(Notifications.silent, text, "")
        onClicked: Notifications.toggleDnd()
    }

    Tile {
        objectName: "nightToggle"
        width: root.squareW
        height: root.tileH
        vertical: true
        showLabel: !root.compact
        icon: Icons.nightLight
        text: I18n.t("dashboard.home.short.night")
        active: NightLightClient.active
        tooltipText: root.tip(NightLightClient.active, I18n.t("dashboard.home.night_light"), "")
        onClicked: NightLightClient.toggle()
    }

    Tile {
        objectName: "awakeToggle"
        width: root.squareW
        height: root.tileH
        vertical: true
        showLabel: !root.compact
        icon: Icons.caffeine
        text: I18n.t("dashboard.home.awake")
        active: CaffeineClient.inhibit
        tooltipText: root.tip(CaffeineClient.inhibit, text, "")
        onClicked: CaffeineClient.toggle()
    }

    Tile {
        objectName: "gameToggle"
        width: root.squareW
        height: root.tileH
        vertical: true
        showLabel: !root.compact
        icon: Icons.gameMode
        text: I18n.t("dashboard.home.game")
        active: GameModeClient.toggled
        tooltipText: root.tip(GameModeClient.toggled, text, "")
        onClicked: GameModeClient.toggle()
    }
}
