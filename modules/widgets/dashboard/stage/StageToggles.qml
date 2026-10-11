import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "../home/HomeModel.js" as HomeModel

// Quick toggles of the stage home: one row of seven square kit Tiles (icon
// over the name): Wi-Fi, Bluetooth, microphone, silence, night light, stay
// awake and game mode. Solid accent while on; the state (network, device)
// is in the tooltip. Wi-Fi, Bluetooth and the microphone have a detail
// (corner caret, right-click, hold, Menu / Shift+Enter): `details("wifi" |
// "bluetooth" | "input")`. `compact` (low screens): shorter, icon-only
// tiles, the names as tooltips. Same service calls as home/HomeToggles.
Row {
    id: root

    readonly property string btDevice: HomeModel.connectedDevice(BluetoothService.friendlyDeviceList)
    readonly property var micAudio: Audio.source?.audio ?? null
    readonly property bool micOn: root.micAudio !== null && !root.micAudio.muted
    readonly property string onText: I18n.t("dashboard.home.on")
    readonly property string offText: I18n.t("dashboard.home.off")
    property bool compact: false
    // The detail open in the home.
    property string detail: ""
    readonly property real tileW: Space.controlL - Space.xs
    readonly property real tileH: root.compact ? Space.controlM : root.tileW
    // The row at its natural size (the left column takes this width).
    readonly property real rowWidth: root.tileW * 7 + Space.s * 6
    readonly property real fullHeight: root.tileW
    readonly property Item firstTile: wifi

    signal details(string kind)

    function stateText(on: bool, extra: string): string {
        return on ? (extra !== "" ? extra : root.onText) : root.offText;
    }

    function tip(on: bool, name: string, extra: string): string {
        return name + " · " + root.stateText(on, extra);
    }

    spacing: Math.max(Space.xs, Math.floor((root.width - root.tileW * 7) / 6))

    Component.onCompleted: BluetoothService.initialize()

    Tile {
        id: wifi
        objectName: "wifiToggle"
        highlighted: root.detail === "wifi"
        width: root.tileW
        height: root.tileH
        vertical: true
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
        highlighted: root.detail === "bluetooth"
        width: root.tileW
        height: root.tileH
        vertical: true
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
        highlighted: root.detail === "input"
        width: root.tileW
        height: root.tileH
        vertical: true
        showLabel: !root.compact
        icon: root.micOn ? Icons.mic : Icons.micSlash
        text: I18n.t("dashboard.home.short.mic")
        active: root.micOn
        enabled: root.micAudio !== null
        hasMore: true
        tooltipText: root.tip(root.micOn, I18n.t("dashboard.home.microphone"), "")
        onClicked: {
            if (root.micAudio)
                root.micAudio.muted = !root.micAudio.muted;
        }
        onMore: root.details("input")
    }

    Tile {
        objectName: "silenceToggle"
        width: root.tileW
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
        width: root.tileW
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
        width: root.tileW
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
        width: root.tileW
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
