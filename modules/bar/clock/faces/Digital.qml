import QtQuick

// "21:05" / "9:05 PM" on one line, tabular digits so the width never jitters.
Text {
    required property var clock

    objectName: "faceDigital"
    text: clock.parts.hours + ":" + clock.parts.minutes + (clock.parts.suffix !== "" ? " " + clock.parts.suffix : "")
    color: clock.textColor
    font.family: clock.fontFamily
    font.pixelSize: clock.fontSize
    font.bold: true
    font.features: {
        "tnum": 1
    }
}
