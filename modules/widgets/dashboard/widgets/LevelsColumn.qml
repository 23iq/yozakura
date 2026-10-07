pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit

// Bento widget "levels": brightness, volume and mic as three vertical
// LineSliders side by side (value on top), each over an IconButton: the sun
// toggles syncing every monitor (active while on), the speaker and the mic
// mute (their glyph shows it). Brightness follows the focused monitor.
HostWidget {
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

    function setBrightness(v) {
        if (Brightness.syncBrightness) {
            for (let i = 0; i < Brightness.monitors.length; i++) {
                const mon = Brightness.monitors[i];
                if (mon && mon.ready)
                    mon.setBrightness(v);
            }
        } else if (root.monitor && root.monitor.ready) {
            root.monitor.setBrightness(v);
        }
    }

    function volumeIcon(audio) {
        if (!audio || audio.muted)
            return Icons.speakerSlash;
        if (audio.volume < 0.01)
            return Icons.speakerX;
        if (audio.volume < 0.19)
            return Icons.speakerNone;
        if (audio.volume < 0.49)
            return Icons.speakerLow;
        return Icons.speakerHigh;
    }

    Group {
        id: group
        anchors.fill: parent
        fill: true
        bare: !root.framed
        label: I18n.t("bento.label.levels")

        Row {
            width: parent.width
            height: group.bodyHeight

            Level {
                objectName: "lightLevel"
                value: root.monitor?.brightness ?? 0
                available: root.monitor !== null && root.monitor.ready
                icon: Icons.sun
                active: Brightness.syncBrightness
                onMoved: v => root.setBrightness(v)
                onToggled: Brightness.syncBrightness = !Brightness.syncBrightness
            }
            Level {
                objectName: "volumeLevel"
                value: root.sinkAudio?.volume ?? 0
                available: root.sinkAudio !== null
                icon: root.volumeIcon(root.sinkAudio)
                onMoved: v => {
                    if (root.sinkAudio)
                        root.sinkAudio.volume = v;
                }
                onToggled: {
                    if (root.sinkAudio)
                        root.sinkAudio.muted = !root.sinkAudio.muted;
                }
            }
            Level {
                objectName: "micLevel"
                value: root.sourceAudio?.volume ?? 0
                available: root.sourceAudio !== null
                icon: root.sourceAudio?.muted ? Icons.micSlash : Icons.mic
                onMoved: v => {
                    if (root.sourceAudio)
                        root.sourceAudio.volume = v;
                }
                onToggled: {
                    if (root.sourceAudio)
                        root.sourceAudio.muted = !root.sourceAudio.muted;
                }
            }
        }
    }

    component Level: Column {
        id: level
        property real value: 0
        property bool available: true
        property string icon: ""
        property bool active: false
        signal moved(real value)
        signal toggled

        width: parent.width / 3
        height: parent.height
        spacing: Space.s
        enabled: level.available

        LineSlider {
            id: slider
            anchors.horizontalCenter: parent.horizontalCenter
            height: parent.height - button.height - parent.spacing
            vertical: true
            showValue: true
            onMoved: v => level.moved(v)
        }
        // The slider sets its own value while dragged; the service value
        // comes back through this binding.
        Binding {
            target: slider
            property: "value"
            value: level.value
            when: !slider.pressed
        }
        IconButton {
            id: button
            anchors.horizontalCenter: parent.horizontalCenter
            size: "s"
            icon: level.icon
            active: level.active
            onClicked: level.toggled()
        }
    }
}
