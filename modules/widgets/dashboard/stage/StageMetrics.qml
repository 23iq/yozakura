pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "StageModel.js" as StageModel

// The metrics strip at the bottom of the stage home: CPU, RAM and GPU load
// as small rings with their value, the network down / up rates, a caret at
// the end. One thin line; clicking it opens the metrics tab (`open()`).
// Keeps SystemResources polling while it is shown.
Item {
    id: root

    readonly property string consumerKey: "stage-metrics-" + Math.random().toString(36).slice(2)
    readonly property var loads: {
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
        return out;
    }

    signal open

    implicitHeight: Space.controlS
    implicitWidth: row.implicitWidth

    onVisibleChanged: SystemResources.setConsumer(root.consumerKey, root.visible)
    Component.onCompleted: SystemResources.setConsumer(root.consumerKey, root.visible)
    Component.onDestruction: SystemResources.setConsumer(root.consumerKey, false)

    MouseArea {
        id: area
        objectName: "metricsArea"
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.open()
    }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: Space.xl

        Repeater {
            model: root.loads

            Row {
                id: load
                required property var modelData
                spacing: Space.s

                Ring {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Space.l
                    height: width
                    thickness: Space.stroke - 1
                    value: (Number(load.modelData.value) || 0) / 100
                }

                KitText {
                    anchors.verticalCenter: parent.verticalCenter
                    role: "caption"
                    text: load.modelData.label
                }

                KitText {
                    anchors.verticalCenter: parent.verticalCenter
                    role: "secondary"
                    tabular: true
                    text: Math.round(Number(load.modelData.value) || 0) + "%"
                }
            }
        }

        Row {
            objectName: "netRates"
            spacing: Space.s

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Icons.arrowDown
                font.family: Icons.font
                font.pixelSize: Type.iconSize("caption")
                color: Type.muted
            }

            KitText {
                anchors.verticalCenter: parent.verticalCenter
                role: "secondary"
                tabular: true
                text: StageModel.rate(SystemResources.netRxRate)
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Icons.arrowUp
                font.family: Icons.font
                font.pixelSize: Type.iconSize("caption")
                color: Type.muted
            }

            KitText {
                anchors.verticalCenter: parent.verticalCenter
                role: "secondary"
                tabular: true
                text: StageModel.rate(SystemResources.netTxRate)
            }
        }
    }

    Text {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: Icons.caretRight
        font.family: Icons.font
        font.pixelSize: Type.iconSize("caption")
        color: area.containsMouse ? Type.text : Type.muted
    }
}
