pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.modules.theme
import qs.modules.services
import "StatsFormat.js" as StatsFormat

// Live CPU / RAM / GPU usage, temperatures and network throughput
// (moduleOptions.systemStats.items). Keeps SystemResources sampling only
// while shown.
BarModuleBase {
    id: root

    moduleKey: "systemStats"

    readonly property var items: StatsFormat.itemsOf(options.items)

    // Keeps SystemResources sampling while this module is alive
    readonly property string consumerKey: "bar.systemStats:" + root
    Component.onCompleted: SystemResources.setConsumer(consumerKey, true)
    Component.onDestruction: SystemResources.setConsumer(consumerKey, false)

    contentLength: vertical ? column.implicitHeight + 14 : row.implicitWidth + (flat ? 12 : 24)

    function valueOf(kind) {
        switch (kind) {
        case "cpu":
            return SystemResources.cpuUsage;
        case "ram":
            return SystemResources.ramUsage;
        case "gpu":
            return SystemResources.gpuUsage;
        case "cpuTemp":
            return SystemResources.cpuTemp;
        case "gpuTemp":
            return SystemResources.gpuTemp;
        }
        return 0;
    }
    function textOf(kind) {
        switch (kind) {
        case "cpuTemp":
        case "gpuTemp":
            return StatsFormat.temp(valueOf(kind));
        case "net":
            return "↓" + StatsFormat.rate(SystemResources.netRxRate) + " ↑" + StatsFormat.rate(SystemResources.netTxRate);
        }
        return StatsFormat.percent(valueOf(kind));
    }
    function iconOf(kind) {
        switch (kind) {
        case "cpu":
            return Icons.cpu;
        case "ram":
            return Icons.ram;
        case "gpu":
            return Icons.gpu;
        case "net":
            return Icons.ethernet;
        }
        return Icons.temperature;
    }
    function colorOf(kind) {
        const l = StatsFormat.level(kind, valueOf(kind));
        return l === 2 ? Colors.error : (l === 1 ? Colors.tertiary : Colors.primary);
    }

    BarModuleSurface {
        id: surface
        module: root
    }

    Row {
        id: row
        visible: !root.vertical
        anchors.centerIn: parent
        spacing: 14
        Repeater {
            model: root.items
            delegate: Row {
                id: stat
                required property string modelData
                spacing: 5
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.iconOf(stat.modelData)
                    font.family: Icons.font
                    font.pixelSize: root.iconSize - 2
                    color: root.colorOf(stat.modelData)
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.textOf(stat.modelData)
                    font.family: Config.theme.font
                    font.pixelSize: root.textSize
                    font.weight: Font.Medium
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
        spacing: 8
        Repeater {
            model: root.items.filter(k => k !== "net")
            delegate: Column {
                id: vstat
                required property string modelData
                spacing: 1
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.iconOf(vstat.modelData)
                    font.family: Icons.font
                    font.pixelSize: root.iconSize - 2
                    color: root.colorOf(vstat.modelData)
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.textOf(vstat.modelData)
                    font.family: Config.theme.font
                    font.pixelSize: root.smallTextSize - 1
                    color: surface.foreground
                }
            }
        }
    }
}
