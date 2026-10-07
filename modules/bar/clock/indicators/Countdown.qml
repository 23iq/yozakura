import QtQuick
import qs.modules.theme

// The phase time left ("12:34") next to the clock, tabular digits in a box
// sized for "00:00" so the bar never jitters while it ticks. A vertical bar
// stacks minutes over seconds.
Item {
    id: root

    required property var indicator

    objectName: "pomodoroCountdown"
    readonly property string label: indicator.view.label

    implicitWidth: Math.max(metrics.width, digits.implicitWidth)
    implicitHeight: digits.implicitHeight
    opacity: indicator.view.running || indicator.view.ringing ? 1 : 0.6

    TextMetrics {
        id: metrics
        font: digits.font
        text: root.indicator.vertical ? "00" : (root.label.length > 5 ? "0:00:00" : "00:00")
    }

    Text {
        id: digits
        objectName: "pomodoroCountdownText"
        anchors.centerIn: parent
        horizontalAlignment: Text.AlignHCenter
        text: root.indicator.vertical ? root.label.split(":").join("\n") : root.label
        color: root.indicator.phaseColor
        font.family: root.indicator.fontFamily
        font.pixelSize: root.indicator.fontSize
        font.weight: root.indicator.fontWeight
        font.features: {
            "tnum": 1
        }
        lineHeight: 0.9
    }

    SequentialAnimation on opacity {
        running: root.indicator.view.ringing && Motion.emphasis.duration > 0
        loops: Animation.Infinite
        NumberAnimation {
            to: 0.35
            duration: Motion.emphasis.duration
        }
        NumberAnimation {
            to: 1
            duration: Motion.emphasis.duration
        }
    }
}
