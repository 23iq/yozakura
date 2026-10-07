pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.config
import qs.modules.services
import "../shell/osd/OsdStyles.js" as OsdStyles
import "../shell/osd/MicrophoneVolume.js" as MicrophoneVolume

// Single source of OSD events. Listens to Audio and Brightness, normalises
// them to (kind, value, muted, device) and routes them by the chosen style:
//   level        -> every OSD host (window styles, bar-inline)
//   toIsland     -> the notch, when style == island
//   inlineRequest-> the bar widget, when style == bar-inline
// `device` is non-empty only when it should be shown (an output switch).
Singleton {
    id: root

    // volume | mic | brightness
    signal level(string kind, real value, bool muted, string device)
    signal toIsland(string kind, real value, bool muted, string device)
    signal inlineRequest(string kind)
    // Click on any OSD: open the bar's controls popup.
    signal controlsRequested(string screenName)

    readonly property string style: OsdStyles.normalize(Config.layout && Config.layout.osd ? Config.layout.osd.style : "pill")
    readonly property int timeout: Config.layout && Config.layout.osd && Config.layout.osd.timeout > 0 ? Config.layout.osd.timeout : 2500

    // Hosts register here: the bar widget (bar-inline) and the notch (island).
    // inlineScreens (screen name -> hosts) is the one record; inlineHosts is
    // its total.
    property var inlineScreens: ({})
    readonly property int inlineHosts: {
        let n = 0;
        for (const name in root.inlineScreens)
            n += root.inlineScreens[name];
        return n;
    }
    property bool islandHandled: false
    // Event routing (is any inline host out there?). Each window decides for
    // its own screen with routeForScreen: a monitor without a host keeps its
    // pill while the others show the level inline.
    readonly property var route: OsdStyles.resolve(root.style, {
        "inlineAvailable": root.inlineHosts > 0,
        "islandHandled": root.islandHandled
    })

    // Last event, for hosts that mount after it fired.
    property string lastKind: "volume"
    property real lastValue: 0
    property bool lastMuted: false
    property string lastDevice: ""
    property string lastScreen: ""

    property string _sinkName: ""
    property var _micBaseline: null

    function registerInline(on: bool, screenName: string): void {
        const name = screenName || "";
        const next = Object.assign({}, root.inlineScreens);
        next[name] = Math.max(0, (next[name] || 0) + (on ? 1 : -1));
        root.inlineScreens = next;
    }

    // A host on another monitor must not suppress this screen's window.
    function routeForScreen(screenName: string): var {
        return OsdStyles.resolve(root.style, {
            "inlineAvailable": (root.inlineScreens[screenName || ""] || 0) > 0 || (root.inlineScreens[""] || 0) > 0,
            "islandHandled": root.islandHandled
        });
    }

    function report(kind: string, value: real, muted: bool, device: string, screenName: string): void {
        root.lastKind = kind;
        root.lastValue = OsdStyles.clamp01(value);
        root.lastMuted = muted;
        root.lastDevice = device || "";
        root.lastScreen = screenName || "";
        root.level(kind, root.lastValue, muted, root.lastDevice);
        if (root.style === "island")
            root.toIsland(kind, root.lastValue, muted, root.lastDevice);
        else if (root.route.style === "bar-inline")
            root.inlineRequest(kind);
    }

    // The device a level belongs to (the muted OSD names it); "" for brightness.
    function currentDevice(kind: string): string {
        if (kind === "mic")
            return OsdStyles.deviceName(Audio.source);
        return kind === "volume" ? root._sinkName : "";
    }

    function openControls(screenName: string): void {
        root.controlsRequested(screenName || "");
    }

    // Scroll over an OSD: change the level of `kind` by `delta` (0..1 scale).
    function adjust(kind: string, delta: real, screen: var): void {
        if (kind === "volume")
            Audio.setVolume(OsdStyles.clamp01((Audio.sink?.audio?.volume ?? 0) + delta));
        else if (kind === "mic")
            Audio.setMicVolume(OsdStyles.clamp01((Audio.source?.audio?.volume ?? 0) + delta));
        else if (kind === "brightness") {
            const mon = screen ? Brightness.getMonitorForScreen(screen) : null;
            if (mon && mon.ready)
                mon.setBrightness(Math.max(0.01, Math.min(1, mon.brightness + delta)));
        }
    }

    function _resetMic(): void {
        const ready = !!Audio.source?.ready && !!Audio.source?.audio;
        root._micBaseline = MicrophoneVolume.observe(null, Audio.source, Audio.source?.audio?.volume, ready);
    }

    Component.onCompleted: {
        root._sinkName = OsdStyles.deviceName(Audio.sink);
        root._resetMic();
    }

    Connections {
        target: Audio

        function onSourceChanged() {
            root._resetMic();
        }

        function onSinkChanged() {
            const name = OsdStyles.deviceName(Audio.sink);
            const switched = OsdStyles.deviceSwitched(root._sinkName, name);
            root._sinkName = name;
            if (switched && Audio.sink?.audio)
                root.report("volume", Audio.sink.audio.volume, Audio.sink.audio.muted, name, "");
        }

        function onVolumeChanged(volume, muted, node) {
            root.report("volume", volume, muted, "", "");
        }

        function onMicVolumeChanged(volume, muted, node) {
            if (node !== Audio.source)
                return;
            const ready = !!Audio.source?.ready && !!Audio.source?.audio;
            root._micBaseline = MicrophoneVolume.observe(root._micBaseline, node, volume, ready);
            if (root._micBaseline.show)
                root.report("mic", volume, muted, "", "");
        }
    }

    Connections {
        target: Brightness

        function onBrightnessChanged(value, screen) {
            root.report("brightness", value, false, "", screen ? screen.name : "");
        }
    }
}
