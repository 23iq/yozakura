import QtQuick
import Quickshell.Services.Pipewire
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "HomeModel.js" as HomeModel

// Levels on the composed dashboard: output volume, microphone and
// brightness as LineSliders without numbers. The speaker and mic icons
// mute; the microphone track carries its live input level (a Pipewire peak
// monitor, running only while shown and unmuted). The chevrons open the
// output / input device lists (`details("output" | "input")`). Same
// services as widgets/LevelsColumn.qml.
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
    readonly property real sliderW: root.width - Space.controlS - Space.xs

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

    spacing: Space.xs

    PwNodePeakMonitor {
        id: micPeak
        node: Audio.source
        enabled: root.visible && root.sourceAudio !== null && !root.sourceAudio.muted
    }

    Row {
        spacing: Space.xs

        LineSlider {
            id: volume
            objectName: "volumeSlider"
            width: root.sliderW
            icon: root.sinkAudio?.muted ?? true ? Icons.speakerX : (volume.value < 0.33 ? Icons.speakerLow : Icons.speakerHigh)
            iconClickable: true
            enabled: root.sinkAudio !== null
            onMoved: v => root.setLevel(root.sinkAudio, v)
            onIconClicked: root.toggleMuted(root.sinkAudio)
        }

        IconButton {
            objectName: "outputDevices"
            size: "s"
            icon: Icons.caretRight
            onClicked: root.details("output")
        }
    }

    Row {
        spacing: Space.xs

        LineSlider {
            id: mic
            objectName: "micSlider"
            width: root.sliderW
            icon: root.sourceAudio?.muted ?? true ? Icons.micSlash : Icons.mic
            iconClickable: true
            enabled: root.sourceAudio !== null
            level: micPeak.enabled ? HomeModel.meterLevel(micPeak.peak) : -1
            onMoved: v => root.setLevel(root.sourceAudio, v)
            onIconClicked: root.toggleMuted(root.sourceAudio)
        }

        IconButton {
            objectName: "inputDevices"
            size: "s"
            icon: Icons.caretRight
            onClicked: root.details("input")
        }
    }

    LineSlider {
        id: light
        objectName: "lightSlider"
        width: root.sliderW
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
