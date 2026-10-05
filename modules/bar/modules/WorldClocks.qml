pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import qs.config
import qs.modules.theme
import "WorldClock.js" as WorldClock

// Clocks for other time zones (moduleOptions.worldClocks.zones:
// [{label, zone}]). UTC offsets come from `date` (tz database, DST aware),
// refreshed hourly; the time ticks locally every minute.
BarModuleBase {
    id: root

    moduleKey: "worldClocks"

    readonly property var zones: WorldClock.zonesOf(options.zones)
    readonly property bool use12h: Config.bar && Config.bar.use12hFormat === true
    property var offsets: ({})
    property real now: Date.now()

    contentLength: vertical ? column.implicitHeight + 12 : row.implicitWidth + (flat ? 12 : 24)
    visible: zones.length > 0

    function timeFor(zone) {
        const off = offsets[zone];
        if (off === undefined || off === null)
            return "--:--";
        const localOff = -new Date(now).getTimezoneOffset();
        return WorldClock.format(WorldClock.timeAt(now, off, localOff), use12h);
    }

    function refreshOffsets() {
        if (zones.length === 0)
            return;
        offsetProc.command = ["sh", "-c", "for z in \"$@\"; do TZ=\"$z\" date +%z; done", "sh"].concat(zones.map(z => z.zone));
        offsetProc.running = true;
    }

    onZonesChanged: refreshOffsets()
    Component.onCompleted: refreshOffsets()

    Process {
        id: offsetProc
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                const out = {};
                for (let i = 0; i < root.zones.length && i < lines.length; i++)
                    out[root.zones[i].zone] = WorldClock.parseOffset(lines[i]);
                root.offsets = out;
            }
        }
    }

    Timer {
        interval: 60000 - (Date.now() % 60000) + 50
        running: true
        repeat: true
        onTriggered: {
            root.now = Date.now();
            interval = 60000;
        }
    }
    Timer {
        interval: 3600000
        running: true
        repeat: true
        onTriggered: root.refreshOffsets()
    }

    BarModuleSurface {
        id: surface
        module: root
    }

    Row {
        id: row
        visible: !root.vertical
        anchors.centerIn: parent
        spacing: 16
        Repeater {
            model: root.zones
            delegate: Row {
                id: entry
                required property var modelData
                spacing: 6
                anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                Text {
                    anchors.baseline: time.baseline
                    text: entry.modelData.label
                    font.family: Config.theme.font
                    font.pixelSize: root.smallTextSize
                    color: surface.foreground
                    opacity: 0.65
                }
                Text {
                    id: time
                    text: root.timeFor(entry.modelData.zone)
                    font.family: Config.theme.font
                    font.pixelSize: root.textSize
                    font.weight: Font.Bold
                    font.features: {
                        "tnum": 1
                    }
                    color: surface.foreground
                }
            }
        }
    }

    Column {
        id: column
        visible: root.vertical
        anchors.centerIn: parent
        spacing: 6
        Repeater {
            model: root.zones
            delegate: Column {
                id: vEntry
                required property var modelData
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: vEntry.modelData.label.slice(0, 3).toUpperCase()
                    font.family: Config.theme.font
                    font.pixelSize: root.smallTextSize - 1
                    color: surface.foreground
                    opacity: 0.65
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.timeFor(vEntry.modelData.zone)
                    font.family: Config.theme.font
                    font.pixelSize: root.smallTextSize
                    font.weight: Font.Bold
                    color: surface.foreground
                }
            }
        }
    }
}
