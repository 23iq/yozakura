pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "StageModel.js" as StageModel

// The metrics strip at the bottom of the stage home: CPU, RAM and GPU
// load and the network rates as StageMetric capsules of equal width (the
// value large, a sparkline of the history in the load's color), a caret
// at the end. Clicking it opens the metrics tab (`open()`). Keeps
// SystemResources polling while it is shown. The capsules stay alive
// across updates (the Repeater counts, it does not rebuild), so values
// roll and sparklines slide. Keyboard: focusable, Enter opens metrics.
Item {
    id: root

    readonly property string consumerKey: "stage-metrics-" + Math.random().toString(36).slice(2)
    readonly property var loads: {
        const out = [
            {
                "label": "CPU",
                "value": SystemResources.cpuUsage,
                "history": SystemResources.cpuHistory ?? []
            },
            {
                "label": "RAM",
                "value": SystemResources.ramUsage,
                "history": SystemResources.ramHistory ?? []
            }
        ];
        if (SystemResources.gpuDetected)
            out.push({
                "label": "GPU",
                "value": SystemResources.gpuUsage,
                "history": (SystemResources.gpuHistories ?? [])[0] ?? []
            });
        return out;
    }
    readonly property real cellW: (row.width - row.spacing * root.loads.length) / (root.loads.length + 1)

    signal open

    implicitHeight: Space.controlM + Space.xs
    activeFocusOnTab: true
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.open();
            event.accepted = true;
        }
    }
    implicitWidth: Space.controlL * 8

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
        anchors.left: parent.left
        anchors.right: caret.left
        anchors.rightMargin: Space.s
        height: parent.height
        spacing: Space.s

        Repeater {
            model: root.loads.length

            StageMetric {
                required property int index
                readonly property var load: root.loads[index] ?? ({})
                width: root.cellW
                height: row.height
                hovered: area.containsMouse || root.activeFocus
                label: load.label ?? ""
                value: (Number(load.value) || 0) / 100
                history: load.history ?? []
            }
        }

        StageMetric {
            objectName: "netRates"
            width: root.cellW
            height: row.height
            hovered: area.containsMouse || root.activeFocus
            label: "NET"
            valueText: "↓ " + StageModel.rate(SystemResources.netRxRate)
            subText: "↑ " + StageModel.rate(SystemResources.netTxRate)
        }
    }

    Text {
        id: caret
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: Icons.caretRight
        font.family: Icons.font
        font.pixelSize: Type.iconSize("body")
        color: area.containsMouse ? Type.text : Type.muted
    }

    FocusRing {
        radius: Look.chipRadius(root.height) + Space.stroke
        shown: root.activeFocus
    }
}
