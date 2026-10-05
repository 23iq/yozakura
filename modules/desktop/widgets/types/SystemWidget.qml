pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io
import qs.modules.services
import qs.modules.theme
import qs.modules.desktop.widgets
import "../NetRate.js" as NetRate

// CPU, RAM, GPU temperature and network throughput, each with a
// sparkline. Registers with SystemResources only while on screen, so the
// backend monitor stops when no one looks.
DesktopWidget {
    id: root

    readonly property bool wantsNet: options.net ?? true
    readonly property int capacity: 30
    property var netPrev: null
    property real netPrevAt: 0
    property var netNow: ({
            rx: 0,
            tx: 0
        })
    property var netHistory: []
    property string consumerKey: ""

    readonly property var rows: {
        const out = [];
        if (options.cpu ?? true)
            out.push({
                icon: "cpu",
                label: I18n.t("desktop.widgets.system.cpu"),
                value: Math.round(SystemResources.cpuUsage) + "%",
                values: SystemResources.cpuHistory,
                color: Colors.primary
            });
        if (options.ram ?? true)
            out.push({
                icon: "ram",
                label: I18n.t("desktop.widgets.system.ram"),
                value: Math.round(SystemResources.ramUsage) + "%",
                values: SystemResources.ramHistory,
                color: Colors.secondary
            });
        if ((options.gpuTemp ?? true) && SystemResources.gpuTemp >= 0)
            out.push({
                icon: "temperature",
                label: I18n.t("desktop.widgets.system.gpu_temp"),
                value: SystemResources.gpuTemp + "°",
                values: (SystemResources.gpuTempHistories[0] ?? []).map(t => Math.max(0, t) / 100),
                color: Colors.tertiary
            });
        if (wantsNet)
            out.push({
                icon: "globe",
                label: "↓ " + NetRate.format(netNow.rx) + "  ↑ " + NetRate.format(netNow.tx),
                value: "",
                values: NetRate.normalized(netHistory, 64 * 1024),
                color: Colors.primary
            });
        return out;
    }

    onActiveChanged: SystemResources.setConsumer(consumerKey, active)
    Component.onCompleted: {
        consumerKey = "desktop-widget-" + Date.now().toString(36) + Math.random().toString(36).slice(2);
        SystemResources.setConsumer(consumerKey, active);
    }
    Component.onDestruction: SystemResources.setConsumer(consumerKey, false)

    FileView {
        id: netDev
        path: root.wantsNet ? "/proc/net/dev" : ""
        blockLoading: true
    }

    Timer {
        interval: 2000
        repeat: true
        triggeredOnStart: true
        running: root.active && root.wantsNet
        onTriggered: {
            netDev.reload();
            const cur = NetRate.totals(netDev.text());
            const at = Date.now();
            const r = NetRate.rate(root.netPrev, cur, at - root.netPrevAt);
            root.netPrev = cur;
            root.netPrevAt = at;
            root.netNow = r;
            root.netHistory = NetRate.push(root.netHistory, r.rx + r.tx, root.capacity);
        }
    }

    Column {
        id: list
        x: root.pad
        y: root.pad
        width: root.width - 2 * root.pad
        height: root.height - 2 * root.pad
        spacing: Math.round(8 * root.k)

        Repeater {
            model: root.rows
            Item {
                id: row
                required property var modelData
                width: list.width
                height: Math.max(Math.round(22 * root.k), (list.height - (root.rows.length - 1) * list.spacing) / Math.max(1, root.rows.length))

                Text {
                    id: glyph
                    anchors.verticalCenter: parent.verticalCenter
                    text: Icons[row.modelData.icon] ?? ""
                    font.family: Icons.font
                    font.pixelSize: root.px(1)
                    color: row.modelData.color
                }
                Text {
                    id: label
                    anchors.left: glyph.right
                    anchors.leftMargin: Math.round(8 * root.k)
                    anchors.verticalCenter: parent.verticalCenter
                    width: row.modelData.value === "" ? parent.width * 0.62 - glyph.width : Math.round(parent.width * 0.22)
                    text: row.modelData.label
                    elide: Text.ElideRight
                    font.family: root.font
                    font.pixelSize: root.px(-2)
                    color: root.inkSoft
                }
                Text {
                    id: value
                    anchors.left: label.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: row.modelData.value !== ""
                    width: visible ? Math.round(parent.width * 0.16) : 0
                    text: row.modelData.value
                    font.family: root.font
                    font.pixelSize: root.px(0)
                    font.weight: Font.DemiBold
                    font.features: {
                        "tnum": 1
                    }
                    color: root.ink
                }
                Sparkline {
                    anchors.left: value.right
                    anchors.leftMargin: Math.round(8 * root.k)
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: Math.min(parent.height, Math.round(30 * root.k))
                    values: (row.modelData.values ?? []).slice(-root.capacity)
                    capacity: root.capacity
                    color: row.modelData.color
                    lineWidth: Math.max(1.5, 2 * root.k)
                }
            }
        }
    }
}
