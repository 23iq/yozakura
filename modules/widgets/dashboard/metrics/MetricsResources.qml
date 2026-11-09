pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "MetricsModel.js" as MetricsModel

// The live resource meters, scrolling: CPU, RAM, one per detected GPU and
// one per disk, each in its series colour (MetricsModel.seriesColor).
Flickable {
    id: root

    contentHeight: column.height
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Column {
        id: column
        width: root.width
        spacing: Space.s

        MetricsResource {
            width: parent.width
            icon: Icons.cpu
            value: SystemResources.cpuUsage / 100
            seriesColor: Colors[MetricsModel.seriesColor("cpu")]
            name: SystemResources.cpuModel || "CPU"
            valueText: `${Math.round(SystemResources.cpuUsage)}%`
            temperature: SystemResources.cpuTemp
        }

        MetricsResource {
            width: parent.width
            icon: Icons.ram
            value: SystemResources.ramUsage / 100
            seriesColor: Colors[MetricsModel.seriesColor("ram")]
            name: MetricsModel.memoryText(SystemResources.ramUsed, SystemResources.ramTotal)
            valueText: `${Math.round(SystemResources.ramUsage)}%`
        }

        Repeater {
            model: SystemResources.gpuDetected ? SystemResources.gpuCount : 0

            MetricsResource {
                required property int index
                width: column.width
                icon: Icons.gpu
                value: (SystemResources.gpuUsages[index] || 0) / 100
                seriesColor: Colors[MetricsModel.seriesColor("gpu", SystemResources.gpuVendors[index])]
                name: SystemResources.gpuNames[index] || "GPU"
                valueText: `${Math.round(SystemResources.gpuUsages[index] || 0)}%`
                temperature: SystemResources.gpuTemps[index] ?? -1
            }
        }

        Repeater {
            model: SystemResources.validDisks

            MetricsResource {
                required property string modelData
                width: column.width
                icon: Icons[MetricsModel.diskGlyph(SystemResources.diskTypes[modelData])]
                value: (SystemResources.diskUsage[modelData] || 0) / 100
                seriesColor: Colors[MetricsModel.seriesColor("disk")]
                name: modelData
                valueText: `${Math.round(SystemResources.diskUsage[modelData] || 0)}%`
            }
        }
    }
}
