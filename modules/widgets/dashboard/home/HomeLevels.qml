pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config

// Volume and brightness on the composed dashboard: two quiet StyledSliders
// with an icon (click the speaker to mute) and the value. Same services as
// LevelsColumn.qml (Audio sink, Brightness monitors with the sync option).
ColumnLayout {
    id: root

    spacing: Metrics.spacing / 2

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

    function setVolume(v) {
        if (root.sinkAudio && Math.abs(root.sinkAudio.volume - v) > 0.001)
            root.sinkAudio.volume = v;
    }

    function setBrightness(v) {
        if (Brightness.syncBrightness) {
            for (let i = 0; i < Brightness.monitors.length; i++) {
                const mon = Brightness.monitors[i];
                if (mon && mon.ready)
                    mon.setBrightness(v);
            }
        } else if (root.monitor && root.monitor.ready && Math.abs(root.monitor.brightness - v) > 0.001) {
            root.monitor.setBrightness(v);
        }
    }

    component LevelRow: RowLayout {
        id: row

        property string icon
        property real level: 0
        property bool available: true
        property bool muted: false

        signal moved(real value)
        signal iconClicked

        Layout.fillWidth: true
        spacing: Metrics.spacing
        opacity: row.available ? 1 : 0.5

        HomeIconButton {
            icon: row.icon
            iconSize: Styling.fontSize(1)
            implicitWidth: Metrics.iconSize
            onClicked: row.iconClicked()
        }

        StyledSlider {
            id: slider
            Layout.fillWidth: true
            Layout.preferredHeight: Metrics.badgeHeight
            enabled: row.available
            resizeParent: false
            tooltip: false
            progressColor: row.muted ? Colors.outline : Colors.overSurfaceVariant
            onValueChanged: {
                if (Math.abs(slider.value - row.level) > 0.001)
                    row.moved(slider.value);
            }
        }

        // The slider assigns its own value while dragged or scrolled; the
        // service value comes back through this binding.
        Binding {
            target: slider
            property: "value"
            value: row.level
            when: !slider.isDragging
        }

        Text {
            Layout.preferredWidth: Metrics.iconSize
            horizontalAlignment: Text.AlignRight
            text: row.available ? Math.round(row.level * 100) : "–"
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            font.features: {
                "tnum": 1
            }
            color: Colors.outline
        }
    }

    LevelRow {
        objectName: "volumeRow"
        icon: root.sinkAudio?.muted ? Icons.speakerX : Icons.speakerHigh
        available: root.sinkAudio !== null
        level: root.sinkAudio?.volume ?? 0
        muted: root.sinkAudio?.muted ?? false
        onMoved: v => root.setVolume(v)
        onIconClicked: {
            if (root.sinkAudio)
                root.sinkAudio.muted = !root.sinkAudio.muted;
        }
    }

    LevelRow {
        objectName: "lightRow"
        icon: Icons.sun
        available: root.monitor !== null && root.monitor.ready
        level: root.monitor?.brightness ?? 0
        onMoved: v => root.setBrightness(v)
    }
}
