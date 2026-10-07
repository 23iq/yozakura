pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.services
import qs.modules.components.kit

// Bento widget "metricsSummary": CPU, RAM and GPU load, each a label with
// its value over a ProgressLine; side by side on a wide tile, stacked
// otherwise (a small tile keeps the rows that fit).
// Keeps SystemResources polling while it is shown.
HostWidget {
    id: root

    readonly property string consumerKey: "bento-metrics-" + Math.random().toString(36).slice(2)
    readonly property real rowH: Type.size("secondary") * 1.4 + Space.xs + Space.stroke
    readonly property bool wide: root.width >= root.height * 1.8
    readonly property int capacity: root.wide ? 3 : Math.max(1, Math.floor((group.bodyHeight + Space.m) / (root.rowH + Space.m)))
    readonly property var rows: {
        const out = [
            {
                "label": "CPU",
                "value": SystemResources.cpuUsage
            },
            {
                "label": "RAM",
                "value": SystemResources.ramUsage
            }
        ];
        if (SystemResources.gpuDetected)
            out.push({
                "label": "GPU",
                "value": SystemResources.gpuUsage
            });
        return out.slice(0, root.capacity);
    }

    onVisibleChanged: SystemResources.setConsumer(consumerKey, visible)
    Component.onCompleted: SystemResources.setConsumer(consumerKey, visible)
    Component.onDestruction: SystemResources.setConsumer(consumerKey, false)

    Group {
        id: group
        anchors.fill: parent
        fill: true
        bare: !root.framed
        label: I18n.t("bento.label.system")

        Grid {
            width: parent.width
            columns: root.wide ? root.rows.length : 1
            columnSpacing: Space.l
            rowSpacing: Space.m

            Repeater {
                model: root.rows

                Column {
                    id: row
                    required property var modelData
                    width: root.wide ? (parent.width - Space.l * (root.rows.length - 1)) / root.rows.length : parent.width
                    spacing: Space.xs

                    Item {
                        width: parent.width
                        height: name.implicitHeight

                        KitText {
                            id: name
                            role: "secondary"
                            text: row.modelData.label
                        }
                        KitText {
                            anchors.right: parent.right
                            role: "caption"
                            tabular: true
                            text: Math.round(row.modelData.value) + "%"
                        }
                    }
                    ProgressLine {
                        width: parent.width
                        value: row.modelData.value / 100
                    }
                }
            }
        }
    }
}
