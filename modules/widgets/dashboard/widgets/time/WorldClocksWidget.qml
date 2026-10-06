pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.config
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import "../../../../bar/modules/WorldClock.js" as WorldClock

// World clocks bento widget: the zones of the bar world clocks module
// (bar.moduleOptions.worldClocks.zones, [{label, zone}]), each with its time
// and a +1/-1 badge when its calendar day differs from the local one. A
// wide tile lays them side by side, a narrow one stacks them. UTC offsets
// come from `date` (tz database, DST aware), refreshed hourly.
StyledRect {
    id: root

    property real cellW: Metrics.bentoCell
    property real cellH: Metrics.bentoCell
    property bool compact: false

    readonly property var zones: WorldClock.zonesOf(Config.bar.moduleOptions?.worldClocks?.zones)
    readonly property bool use12h: Config.bar.use12hFormat ?? false
    readonly property bool wide: root.width > root.height * 1.5
    property var offsets: ({})
    property real now: Date.now()

    variant: "pane"
    enableShadow: false
    radius: Styling.radius(4)

    function at(zone) {
        const off = root.offsets[zone];
        if (off === undefined || off === null)
            return null;
        return WorldClock.timeAt(root.now, off, -new Date(root.now).getTimezoneOffset());
    }

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
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.now = Date.now();
            interval = 60000;
        }
    }
    Timer {
        interval: 3600000
        running: root.visible
        repeat: true
        onTriggered: root.refresh()
    }

    Text {
        anchors.centerIn: parent
        visible: root.zones.length === 0
        text: I18n.t("bento.worldClocks.empty")
        color: Colors.outline
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-1)
    }

    GridLayout {
        anchors.fill: parent
        anchors.margins: Metrics.spacing
        columns: root.wide ? Math.max(1, root.zones.length) : 1
        rowSpacing: 0
        columnSpacing: Metrics.spacing

        Repeater {
            model: root.zones

            ColumnLayout {
                id: zoneItem
                required property var modelData
                readonly property var time: root.at(modelData.zone)
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Metrics.spacing / 2
                    Text {
                        Layout.fillWidth: true
                        text: zoneItem.modelData.label
                        elide: Text.ElideRight
                        color: Colors.outline
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-2)
                    }
                    Text {
                        visible: zoneItem.time !== null && zoneItem.time.dayDelta !== 0
                        text: zoneItem.time && zoneItem.time.dayDelta > 0 ? "+1" : "−1"
                        color: Colors.primary
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-3)
                        font.bold: true
                    }
                }
                Text {
                    objectName: "worldClockTime"
                    text: zoneItem.time ? WorldClock.format(zoneItem.time, root.use12h) : "--:--"
                    color: Colors.overBackground
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(root.wide || root.zones.length < 3 ? 4 : 1)
                    font.bold: true
                    font.features: {
                        "tnum": 1
                    }
                }
            }
        }
    }
}
