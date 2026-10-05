import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.config
import "../Ui.js" as Ui

// Horizontal slider with a value readout. `moved(value)` fires while
// dragging (values are applied live and previewed by the shell).
Item {
    id: root

    property real value: 0
    property real from: 0
    property real to: 100
    property real stepSize: 1
    property string unit: ""
    property var specialValues: []

    signal moved(real value)

    readonly property real ratio: to > from ? Ui.clamp((value - from) / (to - from), 0, 1) : 0
    property bool dragging: false

    implicitWidth: 280
    implicitHeight: 32
    activeFocusOnTab: true

    Accessible.role: Accessible.Slider

    function emitValue(v) {
        const snapped = Ui.snap(v, from, to, stepSize);
        if (Math.abs(snapped - value) > 1e-9)
            moved(snapped);
    }

    function valueAt(x) {
        return from + Ui.clamp((x - track.x) / track.width, 0, 1) * (to - from);
    }

    Keys.onLeftPressed: emitValue(value - stepSize)
    Keys.onRightPressed: emitValue(value + stepSize)
    Keys.onDownPressed: emitValue(value - stepSize)
    Keys.onUpPressed: emitValue(value + stepSize)
    Keys.onPressed: event => {
        if (event.key === Qt.Key_PageUp) {
            emitValue(value + stepSize * 10);
            event.accepted = true;
        } else if (event.key === Qt.Key_PageDown) {
            emitValue(value - stepSize * 10);
            event.accepted = true;
        } else if (event.key === Qt.Key_Home) {
            emitValue(from);
            event.accepted = true;
        } else if (event.key === Qt.Key_End) {
            emitValue(to);
            event.accepted = true;
        }
    }

    Text {
        id: readout
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 64
        horizontalAlignment: Text.AlignRight
        text: Ui.formatValue(root.value, root.unit, root.specialValues, I18n.t)
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-1)
        font.weight: Font.DemiBold
        font.features: {
            "tnum": 1
        }
        color: root.dragging || root.activeFocus ? Colors.primary : Colors.overSurfaceVariant
    }

    Item {
        id: track
        anchors.left: parent.left
        anchors.right: readout.left
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        height: 22

        Rectangle {
            id: rail
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 6
            radius: 3
            color: Ui.alpha(Colors.overBackground, 0.14)
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(height, handle.x + handle.width / 2)
            height: 6
            radius: 3
            color: Colors.primary
            opacity: root.enabled ? 1 : 0.4
        }

        Rectangle {
            id: handle
            width: root.dragging ? 22 : 18
            height: width
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            x: root.ratio * (track.width - width)
            color: Colors.primary
            border.width: 4
            border.color: Colors.overPrimary

            Behavior on width {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on x {
                enabled: Config.animDuration > 0 && !root.dragging
                NumberAnimation {
                    duration: 140
                    easing.type: Easing.OutCubic
                }
            }

            Rectangle {
                anchors.centerIn: parent
                width: parent.width + 10
                height: width
                radius: width / 2
                color: "transparent"
                border.width: 2
                border.color: Ui.alpha(Colors.primary, 0.6)
                visible: root.activeFocus
            }
        }

        MouseArea {
            anchors.fill: parent
            anchors.topMargin: -6
            anchors.bottomMargin: -6
            cursorShape: Qt.PointingHandCursor
            preventStealing: true
            onPressed: mouse => {
                root.forceActiveFocus();
                root.dragging = true;
                root.emitValue(root.valueAt(mouse.x));
            }
            onPositionChanged: mouse => {
                if (pressed)
                    root.emitValue(root.valueAt(mouse.x));
            }
            onReleased: root.dragging = false
            onCanceled: root.dragging = false
            onWheel: wheel => {
                root.emitValue(root.value + (wheel.angleDelta.y > 0 ? root.stepSize : -root.stepSize));
            }
        }
    }
}
