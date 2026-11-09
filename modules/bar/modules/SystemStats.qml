pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.bar.look
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

    contentLength: vertical ? column.implicitHeight + Space.m : row.implicitWidth + (flat ? Space.m : Space.xl)

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
    // Load colours (Type.load): progress, warning, then error.
    function colorOf(kind) {
        const l = StatsFormat.level(kind, valueOf(kind));
        return l === 2 ? Colors.error : (l === 1 ? Colors.warning : Type.progress);
    }

    BarModuleSurface {
        id: surface
        module: root
    }

    Row {
        id: row
        visible: !root.vertical
        anchors.centerIn: parent
        spacing: Space.m
        Repeater {
            model: root.items
            delegate: Row {
                id: stat
                required property string modelData
                spacing: Space.xs
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: root.iconOf(stat.modelData)
                    size: root.iconSize - Space.hairline * 2
                    color: root.colorOf(stat.modelData)
                }
                KitText {
                    anchors.verticalCenter: parent.verticalCenter
                    role: BarLook.textRole(root.moduleSize)
                    tabular: true
                    text: root.textOf(stat.modelData)
                    font.weight: root.textWeight
                    color: surface.foreground
                }
            }
        }
    }

    Column {
        id: column
        visible: root.vertical
        anchors.centerIn: parent
        spacing: Space.s
        Repeater {
            model: root.items.filter(k => k !== "net")
            delegate: Column {
                id: vstat
                required property string modelData
                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    icon: root.iconOf(vstat.modelData)
                    size: root.iconSize - Space.hairline * 2
                    color: root.colorOf(vstat.modelData)
                }
                KitText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    role: "label"
                    tabular: true
                    text: root.textOf(vstat.modelData)
                    font.capitalization: Font.MixedCase
                    font.letterSpacing: 0
                    color: surface.foreground
                }
            }
        }
    }
}
