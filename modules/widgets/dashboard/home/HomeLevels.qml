import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit

// "Levels" on the composed dashboard: volume (click the speaker to mute)
// and brightness as LineSliders with their values. Same services as
// widgets/LevelsColumn.qml (Audio sink, Brightness monitors with the sync
// option).
Group {
    id: root

    readonly property var sinkAudio: Audio.sink?.audio ?? null
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

    function setVolume(v: real) {
        if (root.sinkAudio && Math.abs(root.sinkAudio.volume - v) > 0.001)
            root.sinkAudio.volume = v;
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

    label: I18n.t("dashboard.home.levels")

    LineSlider {
        id: volume
        objectName: "volumeSlider"
        width: parent.width
        icon: root.sinkAudio?.muted ? Icons.speakerX : Icons.speakerHigh
        iconClickable: true
        showValue: true
        enabled: root.sinkAudio !== null
        valueText: enabled ? Math.round(volume.fraction * 100) + "%" : "–"
        onMoved: v => root.setVolume(v)
        onIconClicked: {
            if (root.sinkAudio)
                root.sinkAudio.muted = !root.sinkAudio.muted;
        }
    }

    // The slider sets its own value while dragged; the service value comes
    // back through these bindings.
    Binding {
        target: volume
        property: "value"
        value: root.sinkAudio?.volume ?? 0
        when: !volume.pressed
    }

    LineSlider {
        id: light
        objectName: "lightSlider"
        width: parent.width
        icon: Icons.sun
        showValue: true
        enabled: root.lightReady
        valueText: enabled ? Math.round(light.fraction * 100) + "%" : "–"
        onMoved: v => root.setBrightness(v)
    }

    Binding {
        target: light
        property: "value"
        value: root.monitor?.brightness ?? 0
        when: !light.pressed
    }
}
