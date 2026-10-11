import QtQuick
import qs.modules.theme
import qs.modules.components.kit

// One capsule of the stage metrics strip: the name as a label over the
// value large (it rolls to new values), a sparkline of the recent history
// on the right in the load's color (Type.load: progress, warning, error).
// `value` 0..1 (-1 = none: `valueText` alone, e.g. network rates) and
// `subText` at the end in place of the sparkline.
Item {
    id: root

    property string label: ""
    property real value: -1
    property var history: []
    property string valueText: ""
    property string subText: ""
    property bool hovered: false
    property real shown: Math.max(0, root.value)
    readonly property color tone: Type.load(root.value)

    implicitHeight: Space.controlL - Space.s
    implicitWidth: Space.controlL * 2

    Behavior on shown {
        enabled: Motion.morph.duration > 0
        NumberAnimation {
            duration: Motion.morph.duration
            easing.type: Motion.morph.easing
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Look.bigRadius(height)
        color: Look.raisedFill(root.hovered)
        border.width: Look.controlEdge.a > 0 ? Space.hairline : 0
        border.color: Look.controlEdge
    }

    Sparkline {
        objectName: "metricSpark"
        anchors.right: parent.right
        anchors.rightMargin: Space.m
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Space.s
        width: parent.width * 0.42
        height: parent.height * 0.5
        visible: root.value >= 0
        values: root.history
        color: root.tone
    }

    Column {
        x: Space.m
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        KitText {
            role: "label"
            text: root.label
        }

        KitText {
            objectName: "metricValue"
            role: "title"
            tabular: true
            font.weight: Font.Bold
            color: root.value >= 0 ? (root.value >= 0.7 ? root.tone : Type.text) : Type.text
            text: root.value >= 0 ? Math.round(root.shown * 100) + "%" : root.valueText
        }
    }

    KitText {
        anchors.right: parent.right
        anchors.rightMargin: Space.m
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Space.s
        visible: root.subText !== ""
        role: "secondary"
        tabular: true
        text: root.subText
    }
}
