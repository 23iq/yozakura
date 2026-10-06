pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme

// Tiny per-day bar chart (tokens per day); the last bar is today.
Row {
    id: root

    property var values: []
    property int barWidth: 4
    property int chartHeight: 18

    readonly property real peak: Math.max.apply(null, [1].concat(values || []))

    spacing: 2
    height: chartHeight

    Repeater {
        model: root.values || []
        delegate: Item {
            id: bar
            required property var modelData
            required property int index
            width: root.barWidth
            height: root.chartHeight
            // One day's bar.
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: Math.max(2, parent.height * (bar.modelData || 0) / root.peak)
                radius: width / 2
                color: bar.modelData > 0 ? Colors.primary : Colors.outlineVariant
                opacity: bar.index === (root.values || []).length - 1 ? 1 : 0.6
            }
        }
    }
}
