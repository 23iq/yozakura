import QtQuick
import Quickshell.Services.Pipewire
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "../home/HomeModel.js" as HomeModel

// Levels of the stage home as kit LevelSliders: output volume, microphone
// and brightness, the value at the end. The speaker / mic icons mute (the
// fill then goes quiet); the microphone shows its live input level (a
// Pipewire peak monitor, only while shown and unmuted). The caret zones of
// volume and mic open the device lists (`details("output" | "input")`).
// Fills are tonal (the accent is kept for play and the on tiles).
// `compact` (low screens) slims the tracks. Same services as
// home/HomeLevels.qml (the composed home).
Column {
    id: root

    readonly property var sinkAudio: Audio.sink?.audio ?? null
    readonly property var sourceAudio: Audio.source?.audio ?? null
    readonly property var monitor: {
        const mons = Brightness.monitors;
        if (mons.length === 0)
            return null;
        const focused = YozdService.focusedMonitor?.name ?? "";
        for (let i = 0; i < mons.length; i++) {
            if (mons[i] && mons[i].screen && mons[i].screen.name === focused)
                return mons[i];
        }
        return mons[0];
    }
    readonly property bool lightReady: root.monitor !== null && root.monitor.ready

    // The detail open in the home (its caret shows active).
    property string detail: ""
    // Low screens: slimmer tracks, closer together.
    property bool compact: false
    readonly property real trackH: root.compact ? Space.controlS - Space.xs : Space.controlS
    // The full height, whatever the mode (the host sizes itself by it).
    readonly property real fullHeight: Space.controlS * 3 + Space.s * 2

    signal details(string kind)

    function setLevel(audio: var, v: real) {
        if (audio && Math.abs(audio.volume - v) > 0.001)
            audio.volume = v;
    }

    function toggleMuted(audio: var) {
        if (audio)
            audio.muted = !audio.muted;
    }

    function setBrightness(v: real) {
        if (Brightness.syncBrightness) {
            for (let i = 0; i < Brightness.monitors.length; i++) {
                const mon = Brightness.monitors[i];
                if (mon && mon.ready)
                    mon.setBrightness(v);
            }
        } else if (root.lightReady && Math.abs(root.monitor.brightness - v) > 0.001) {
            root.monitor.setBrightness(v);
        }
    }

    spacing: root.compact ? Space.xs : Space.s

    PwNodePeakMonitor {
        id: micPeak
        node: Audio.source
        enabled: root.visible && root.sourceAudio !== null && !root.sourceAudio.muted
    }

    LevelSlider {
        id: volume
        objectName: "volumeSlider"
        width: root.width
        height: root.trackH
        readonly property bool muted: root.sinkAudio?.muted ?? true
        icon: volume.muted ? Icons.speakerX : (volume.value < 0.33 ? Icons.speakerLow : Icons.speakerHigh)
        iconClickable: true
        dimmed: volume.muted
        enabled: root.sinkAudio !== null
        hasMore: true
        moreActive: root.detail === "output"
        onMoved: v => root.setLevel(root.sinkAudio, v)
        onIconClicked: root.toggleMuted(root.sinkAudio)
        onMore: root.details("output")
    }

    LevelSlider {
        id: mic
        objectName: "micSlider"
        width: root.width
        height: root.trackH
        readonly property bool muted: root.sourceAudio?.muted ?? true
        icon: mic.muted ? Icons.micSlash : Icons.mic
        iconClickable: true
        dimmed: mic.muted
        enabled: root.sourceAudio !== null
        level: micPeak.enabled ? HomeModel.meterLevel(micPeak.peak) : -1
        hasMore: true
        moreActive: root.detail === "input"
        onMoved: v => root.setLevel(root.sourceAudio, v)
        onIconClicked: root.toggleMuted(root.sourceAudio)
        onMore: root.details("input")
    }

    LevelSlider {
        id: light
        objectName: "lightSlider"
        width: root.width
        height: root.trackH
        icon: Icons.sun
        enabled: root.lightReady
        onMoved: v => root.setBrightness(v)
    }

    // The sliders set their own value while dragged; the service value
    // comes back through these bindings.
    Binding {
        target: volume
        property: "value"
        value: root.sinkAudio?.volume ?? 0
        when: !volume.pressed
    }

    Binding {
        target: mic
        property: "value"
        value: root.sourceAudio?.volume ?? 0
        when: !mic.pressed
    }

    Binding {
        target: light
        property: "value"
        value: root.monitor?.brightness ?? 0
        when: !light.pressed
    }
}
