pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.services
import qs.modules.components
import qs.modules.components.kit
import qs.modules.theme

// The levels popup: volume, microphone and brightness as kit LineSliders
// (the glyph toggles mute). Opened by the bar controls module and the
// sentence bar's volume fragment.
BarPopup {
    id: popup

    readonly property var brightnessMonitor: Brightness.getMonitorForScreen(popup.bar ? popup.bar.screen : null)

    function volumeIcon(audio: var): string {
        if (audio?.muted)
            return Icons.speakerSlash;
        const vol = audio?.volume ?? 0;
        if (vol < 0.01)
            return Icons.speakerX;
        if (vol < 0.19)
            return Icons.speakerNone;
        if (vol < 0.49)
            return Icons.speakerLow;
        return Icons.speakerHigh;
    }

    function setBrightness(v: real) {
        if (Brightness.syncBrightness) {
            for (let i = 0; i < Brightness.monitors.length; i++) {
                const mon = Brightness.monitors[i];
                if (mon && mon.ready)
                    mon.setBrightness(v);
            }
        } else if (popup.brightnessMonitor && popup.brightnessMonitor.ready) {
            popup.brightnessMonitor.setBrightness(v);
        }
    }

    objectName: "controlsPopup"
    popupPadding: Look.surfacePadding

    contentWidth: 280 + popupPadding * 2
    contentHeight: levels.implicitHeight + popupPadding * 2

    // The levels as one kit group (a frosted card in glass, a tile in tiles)
    Group {
        id: levels
        width: parent.width

        LevelRow {
            id: volumeRow
            icon: popup.volumeIcon(Audio.sink?.audio)
            muted: Audio.sink?.audio?.muted ?? false
            value: Audio.sink?.audio?.volume ?? 0
            onMoved: v => {
                if (Audio.sink?.audio)
                    Audio.sink.audio.volume = v;
            }
            onIconClicked: {
                if (Audio.sink?.audio)
                    Audio.sink.audio.muted = !Audio.sink.audio.muted;
            }

            Connections {
                target: Audio.sink?.audio ?? null
                ignoreUnknownSignals: true
                function onVolumeChanged() {
                    volumeRow.value = Audio.sink.audio.volume;
                }
            }
        }

        LevelRow {
            id: micRow
            icon: Audio.source?.audio?.muted ? Icons.micSlash : Icons.mic
            muted: Audio.source?.audio?.muted ?? false
            value: Audio.source?.audio?.volume ?? 0
            onMoved: v => {
                if (Audio.source?.audio)
                    Audio.source.audio.volume = v;
            }
            onIconClicked: {
                if (Audio.source?.audio)
                    Audio.source.audio.muted = !Audio.source.audio.muted;
            }

            Connections {
                target: Audio.source?.audio ?? null
                ignoreUnknownSignals: true
                function onVolumeChanged() {
                    micRow.value = Audio.source.audio.volume;
                }
            }
        }

        LevelRow {
            id: brightnessRow
            icon: Icons.sun
            value: popup.brightnessMonitor?.brightness ?? 0.5
            onMoved: v => popup.setBrightness(v)

            Connections {
                target: popup.brightnessMonitor ?? null
                ignoreUnknownSignals: true
                function onBrightnessChanged() {
                    brightnessRow.value = popup.brightnessMonitor.brightness;
                }
                function onReadyChanged() {
                    if (popup.brightnessMonitor?.ready)
                        brightnessRow.value = popup.brightnessMonitor.brightness;
                }
            }
        }
    }

    // One level: the glyph (a quiet button: mute toggle) + a line slider.
    component LevelRow: RowLayout {
        id: row

        property string icon: ""
        property bool muted: false
        property alias value: slider.value
        signal moved(real value)
        signal iconClicked

        width: parent ? parent.width : 0
        spacing: Space.s

        IconButton {
            size: "s"
            icon: row.icon
            onClicked: row.iconClicked()
        }

        LineSlider {
            id: slider
            Layout.fillWidth: true
            showValue: true
            opacity: row.muted ? 0.5 : 1
            onMoved: v => row.moved(v)
        }
    }
}
