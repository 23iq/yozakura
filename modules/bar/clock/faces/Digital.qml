import QtQuick

// "21:05" / "9:05 PM" on one line, tabular digits so the width never jitters.
// The face reserves the width of the widest reading ("00:00", + suffix) so a
// 9 -> 10 rollover or a ticking minute never resizes the bar island.
Item {
    id: root

    required property var clock

    implicitWidth: Math.max(label.implicitWidth, Math.ceil(widest.advanceWidth))
    implicitHeight: label.implicitHeight

    TextMetrics {
        id: widest
        font: label.font
        text: "00:00" + (root.clock.parts.suffix !== "" ? " " + root.clock.parts.suffix : "")
    }

    Text {
        id: label
        objectName: "faceDigital"
        anchors.centerIn: parent
        text: root.clock.parts.hours + ":" + root.clock.parts.minutes + (root.clock.parts.suffix !== "" ? " " + root.clock.parts.suffix : "")
        color: root.clock.textColor
        font.family: root.clock.fontFamily
        font.pixelSize: root.clock.fontSize
        font.weight: root.clock.fontWeight
        font.features: {
            "tnum": 1
        }
    }
}
