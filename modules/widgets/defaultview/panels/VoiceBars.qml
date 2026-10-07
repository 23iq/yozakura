pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.modules.components.kit
import "../../../services/voice/VoiceModel.js" as VoiceModel

// Live microphone spectrum in the cava/visualizer style: rounded bars
// growing from the centre in the kit accent (an active state).
// "live" follows the backend bands; "busy" (transcribing) is a travelling
// wave; "idle" settles to dots.
Item {
    id: root

    property var bands: []
    property string mode: "live"
    property bool speech: false
    property int barCount: 32
    property real spacing: 3

    readonly property real barWidth: Math.max(2, (width - spacing * (barCount - 1)) / barCount)
    property var levels: []
    property real phase: 0

    function busyLevel(index) {
        return 0.18 + 0.32 * (0.5 + 0.5 * Math.sin(phase - index * 0.45));
    }

    onBandsChanged: {
        if (mode !== "live")
            return;
        const next = VoiceModel.resampleBands(bands, barCount, 0.04);
        levels = VoiceModel.smoothBands(levels, next, 0.65, 0.22);
    }
    onModeChanged: {
        if (mode === "idle")
            levels = [];
    }

    NumberAnimation on phase {
        running: root.mode === "busy" && root.visible
        from: 0
        to: Math.PI * 2
        duration: 1100
        loops: Animation.Infinite
    }

    Repeater {
        model: root.barCount

        Rectangle {
            id: bar
            required property int index
            readonly property real level: root.mode === "busy" ? root.busyLevel(bar.index) : (root.levels[bar.index] ?? 0)

            x: bar.index * (root.barWidth + root.spacing)
            y: (root.height - bar.height) / 2
            width: root.barWidth
            // Never thinner than wide, so silent bars are round dots.
            height: Math.max(bar.width, Math.min(root.height, bar.level * root.height))
            radius: bar.width / 2
            color: Type.accent
            opacity: root.mode === "idle" ? 0.35 : (root.speech || root.mode === "busy" ? 0.95 : 0.7)
            antialiasing: true

            Behavior on height {
                enabled: Config.animDuration > 0 && root.mode !== "busy"
                NumberAnimation {
                    duration: 60
                    easing.type: Easing.OutQuad
                }
            }
            Behavior on opacity {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Math.min(Config.animDuration, 200)
                }
            }
        }
    }
}
