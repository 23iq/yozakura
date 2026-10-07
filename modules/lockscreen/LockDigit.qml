import QtQuick
import qs.config
import qs.modules.theme

// One clock glyph in a fixed-width cell. When the value changes the old glyph
// rolls up and fades out while the new one rises in from below.
Item {
    id: root

    property string value: ""
    property font font
    property color color: "white"
    // Width of the cell; the clock passes the widest digit so time changes
    // never shift the layout.
    property real cellWidth: metrics.advanceWidth
    readonly property real travel: Math.round(height * 0.32)

    implicitWidth: cellWidth
    implicitHeight: metrics.height

    TextMetrics {
        id: metrics
        font: root.font
        text: root.value
    }

    Text {
        id: outgoing
        anchors.horizontalCenter: parent.horizontalCenter
        font: root.font
        color: root.color
        opacity: 0
        renderType: Text.QtRendering
    }

    Text {
        id: incoming
        anchors.horizontalCenter: parent.horizontalCenter
        font: root.font
        color: root.color
        text: root.value
        renderType: Text.QtRendering
    }

    property string _shown: ""
    Component.onCompleted: _shown = value

    onValueChanged: {
        if (_shown === value)
            return;
        if (_shown === "" || Config.animDuration <= 0) {
            _shown = value;
            return;
        }
        outgoing.text = _shown;
        _shown = value;
        roll.restart();
    }

    ParallelAnimation {
        id: roll
        readonly property int duration: Math.max(1, Math.round(Config.animDuration * 1.6))

        NumberAnimation {
            target: incoming
            property: "y"
            from: root.travel
            to: 0
            duration: roll.duration
            easing.type: Motion.emphasis.easing
        }
        NumberAnimation {
            target: incoming
            property: "opacity"
            from: 0
            to: 1
            duration: roll.duration
            easing.type: Motion.emphasis.easing
        }
        NumberAnimation {
            target: outgoing
            property: "y"
            from: 0
            to: -root.travel
            duration: roll.duration
            easing.type: Motion.emphasis.easing
        }
        NumberAnimation {
            target: outgoing
            property: "opacity"
            from: 1
            to: 0
            duration: Math.round(roll.duration * 0.7)
            easing.type: Motion.emphasis.easing
        }
    }
}
