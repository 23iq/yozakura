import QtQuick

// One clock glyph in a fixed-width cell that rolls on change
// (modules/lockscreen/LockDigit.qml).
Item {
    id: digit

    property string value: ""
    property font font
    property color color: "white"
    property real cellWidth: digitMetrics.advanceWidth
    property int duration: 480
    readonly property real travel: Math.round(height * 0.32)

    implicitWidth: cellWidth
    implicitHeight: digitMetrics.height
    width: implicitWidth
    height: implicitHeight

    TextMetrics {
        id: digitMetrics
        font: digit.font
        text: digit.value
    }
    Text {
        id: outgoing
        anchors.horizontalCenter: parent.horizontalCenter
        font: digit.font
        color: digit.color
        opacity: 0
        renderType: Text.QtRendering
    }
    Text {
        id: incoming
        anchors.horizontalCenter: parent.horizontalCenter
        font: digit.font
        color: digit.color
        text: digit.value
        renderType: Text.QtRendering
    }

    property string shown: ""
    Component.onCompleted: shown = value
    onValueChanged: {
        if (shown === value)
            return;
        if (shown === "") {
            shown = value;
            return;
        }
        outgoing.text = shown;
        shown = value;
        roll.restart();
    }

    ParallelAnimation {
        id: roll
        NumberAnimation {
            target: incoming
            property: "y"
            from: digit.travel
            to: 0
            duration: digit.duration
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: incoming
            property: "opacity"
            from: 0
            to: 1
            duration: digit.duration
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: outgoing
            property: "y"
            from: 0
            to: -digit.travel
            duration: digit.duration
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: outgoing
            property: "opacity"
            from: 1
            to: 0
            duration: Math.round(digit.duration * 0.7)
            easing.type: Easing.OutCubic
        }
    }
}
