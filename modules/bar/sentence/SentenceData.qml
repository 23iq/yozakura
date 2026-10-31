import QtQuick
import Quickshell
import qs.config
import qs.modules.services
import "Sentence.js" as Sentence
import "../modules/AppNames.js" as AppNames

// The live values of the sentence bar, one plain object per fragment
// (null = nothing to say: no battery, nothing playing, no notifications).
// `fragments` is the built sentence (Sentence.build) in the current
// language. Media and notifications yield to the island while it shows
// them (ShellLayout.homeOf "notch"); nothing is said twice there.
QtObject {
    id: root

    property var order: Sentence.DEFAULT_ORDER
    property string verbosity: "full"
    property bool active: true
    property date now: new Date()

    readonly property string lang: I18n.resolvedLanguage || "en"
    readonly property bool use12h: Config.bar && Config.bar.use12hFormat === true

    readonly property var client: root.wants("window") ? YozdService.focusedClient : null
    readonly property string appId: root.client ? (root.client["class"] || "") : ""
    readonly property var entry: root.appId !== "" ? DesktopEntries.heuristicLookup(root.appId) : null
    readonly property var workspace: !root.wants("workspace") ? null : YozdService.focusedWorkspace || (YozdService.focusedMonitor ? YozdService.focusedMonitor.activeWorkspace : null)
    readonly property var player: root.wants("media") ? MprisController.activePlayer : null
    readonly property var sinkAudio: root.wants("volume") && Audio.sink && Audio.sink.audio ? Audio.sink.audio : null

    function wants(id: string): bool {
        return root.order.indexOf(id) !== -1;
    }

    readonly property var values: ({
            "clock": {
                "time": Qt.formatDateTime(root.now, root.use12h ? "h:mm ap" : "hh:mm"),
                "day": Qt.locale(root.lang).dayName(root.now.getDay(), Locale.LongFormat)
            },
            "window": root.appId === "" ? null : {
                "app": Sentence.trimWords(root.entry && root.entry.name ? root.entry.name : AppNames.pretty(root.appId), Sentence.MAX_CHARS)
            },
            "workspace": root.workspace ? {
                "ws": String(root.workspace.name || root.workspace.id || "")
            } : null,
            "battery": root.wants("battery") && Battery.available ? {
                "pct": Math.round(Battery.percentage),
                "charging": Battery.isCharging === true
            } : null,
            "network": root.wants("network") ? root.network() : null,
            "volume": root.sinkAudio ? {
                "pct": Math.round((root.sinkAudio.volume || 0) * 100),
                "muted": root.sinkAudio.muted === true
            } : null,
            "media": root.player && ShellLayout.homeOf("media") !== "notch" ? {
                "playing": root.player.isPlaying === true,
                "title": Sentence.trimWords(root.player.trackTitle || "", Sentence.MAX_CHARS),
                "artist": Sentence.trimWords(root.player.trackArtist || "", Sentence.MAX_CHARS)
            } : null,
            "notifications": root.wants("notifications") && ShellLayout.homeOf("notifications") !== "notch" ? {
                "n": Notifications.list ? Notifications.list.length : 0
            } : null,
            "weather": root.wants("weather") && WeatherService.dataAvailable ? {
                "temp": Math.round(WeatherService.currentTemp) + "°",
                "desc": String(WeatherService.weatherDescription || "").toLowerCase()
            } : null
        })

    readonly property var fragments: Sentence.build(root.values, {
        "order": root.order,
        "verbosity": root.verbosity
    }, key => I18n.has(key) ? I18n.t(key) : "", key => I18n.has(key), root.lang)

    function network(): var {
        if (NetworkService.ethernet)
            return {
                "kind": "wired"
            };
        if (NetworkService.wifiStatus === "connected" || NetworkService.wifiStatus === "limited")
            return {
                "kind": "wifi",
                "name": Sentence.trimWords(NetworkService.networkName || "", Sentence.MAX_CHARS)
            };
        return {
            "kind": "offline"
        };
    }

    // Minute ticks, aligned to the wall clock
    property Timer ticker: Timer {
        interval: 60000 - (Date.now() % 60000) + 20
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.now = new Date();
            interval = 60000 - (Date.now() % 60000) + 20;
        }
    }
}
