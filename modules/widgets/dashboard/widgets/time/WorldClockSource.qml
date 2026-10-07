import QtQuick
import Quickshell.Io
import qs.config
import "../../../../bar/modules/WorldClock.js" as WorldClock
import "../WidgetFormat.js" as WidgetFormat

// The world clocks of the bar module (bar.moduleOptions.worldClocks.zones,
// [{label, zone}]) for the views (the bento widget, the clock popup):
// `rows` = [{label, zone, time: "04:25" | "--:--", offset: "+6h",
// dayDelta}]. UTC offsets come from `date` (tz database, DST aware),
// refreshed hourly; the minute ticks only while `running`.
Item {
    id: root

    property bool running: true
    readonly property var zones: WorldClock.zonesOf(Config.bar.moduleOptions?.worldClocks?.zones)
    readonly property bool use12h: Config.bar.use12hFormat ?? false
    property var offsets: ({})
    property real now: Date.now()
    readonly property int localOffset: -new Date(root.now).getTimezoneOffset()
    readonly property var rows: root.zones.map(z => {
        const off = root.offsets[z.zone];
        const known = off !== undefined && off !== null;
        const t = known ? WorldClock.timeAt(root.now, off, root.localOffset) : null;
        return {
            "label": z.label,
            "zone": z.zone,
            "time": t ? WorldClock.format(t, root.use12h) : "--:--",
            "offset": known ? WidgetFormat.offsetLabel(off, root.localOffset) : "",
            "dayDelta": t ? t.dayDelta : 0
        };
    })

    function refresh() {
        if (root.zones.length === 0)
            return;
        offsetProc.command = ["sh", "-c", "for z in \"$@\"; do TZ=\"$z\" date +%z; done", "sh"].concat(root.zones.map(z => z.zone));
        offsetProc.running = true;
    }

    onZonesChanged: root.refresh()
    Component.onCompleted: root.refresh()

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
        running: root.running
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.now = Date.now();
            interval = 60000;
        }
    }

    Timer {
        interval: 3600000
        running: root.running
        repeat: true
        onTriggered: root.refresh()
    }
}
