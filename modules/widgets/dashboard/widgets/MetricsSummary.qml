pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config

// Bento widget "metricsSummary": CPU, RAM and GPU load as labelled bars.
// Keeps SystemResources polling while it is shown.
StyledRect {
    id: root

    property real cellW: 0
    property real cellH: 0
    property bool compact: false

    readonly property string consumerKey: "bento-metrics-" + Math.random().toString(36).slice(2)
    readonly property var rows: {
        const out = [
            {
                "icon": Icons.cpu,
                "label": "CPU",
                "value": SystemResources.cpuUsage
            },
            {
                "icon": Icons.ram,
                "label": "RAM",
                "value": SystemResources.ramUsage
            }
        ];
        if (SystemResources.gpuDetected)
            out.push({
                "icon": Icons.gpu,
                "label": "GPU",
                "value": SystemResources.gpuUsage
            });
        return out;
    }

    variant: "pane"
    radius: Styling.radius(4)

    onVisibleChanged: SystemResources.setConsumer(consumerKey, visible)
    Component.onCompleted: SystemResources.setConsumer(consumerKey, visible)
    Component.onDestruction: SystemResources.setConsumer(consumerKey, false)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Metrics.padding * 0.75
        spacing: Metrics.spacing / 2

        Repeater {
            model: root.rows

            delegate: RowLayout {
                id: row

                required property var modelData

                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Metrics.spacing

                Text {
                    text: row.modelData.icon
                    font.family: Icons.font
                    font.pixelSize: Styling.fontSize(2)
                    color: Colors.primary
                }

                Text {
                    visible: !root.compact || root.width > Metrics.bentoCell * 1.5
                    text: row.modelData.label
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-1)
                    font.weight: Font.DemiBold
                    color: Colors.overBackground
                }

                StyledRect {
                    Layout.fillWidth: true
                    implicitHeight: Metrics.spacing
                    variant: "internalbg"
                    radius: height / 2

                    StyledRect {
                        variant: "primary"
                        radius: height / 2
                        height: parent.height
                        width: parent.width * Math.max(0, Math.min(1, row.modelData.value / 100))

                        Behavior on width {
                            enabled: Motion.morph.duration > 0
                            NumberAnimation {
                                duration: Motion.morph.duration
                                easing.type: Motion.morph.easing
                            }
                        }
                    }
                }

                Text {
                    Layout.minimumWidth: Metrics.iconSize + Metrics.spacing
                    horizontalAlignment: Text.AlignRight
                    text: Math.round(row.modelData.value) + "%"
                    font.family: Config.theme.monoFont || Config.theme.font
                    font.pixelSize: Styling.fontSize(-1)
                    color: Colors.overBackground
                }
            }
        }
    }
}
