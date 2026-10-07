import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components.kit

// A 3px line slider: track, accent fill, a knob that shows while hovered or
// dragged. Drag or click to set, the wheel adjusts by `step`. Optional
// leading `icon` and value text (`showValue`, `valueText`). `vertical: true`
// stacks value / track / icon top to bottom. `moved(value)` on user changes;
// `iconClickable` makes the icon a button (`iconClicked()`, e.g. mute).
// `level` (0..1, -1 = none) draws a live meter over the track (an input's
// signal level); the icon sits in a fixed cell so stacked sliders align.
Item {
    id: root

    property real from: 0
    property real to: 1
    property real value: 0
    property real step: (to - from) / 20
    property bool vertical: false
    property string icon: ""
    property bool showValue: false
    property string valueText: Math.round(root.fraction * 100) + "%"
    property bool highlighted: false
    property bool iconClickable: false
    property real level: -1
    readonly property real fraction: root.to === root.from ? 0 : Math.max(0, Math.min(1, (root.value - root.from) / (root.to - root.from)))
    readonly property bool hovered: mouse.containsMouse || root.highlighted
    readonly property bool pressed: mouse.pressed

    signal moved(real value)
    signal iconClicked

    function setFraction(f: real) {
        const v = root.from + Math.max(0, Math.min(1, f)) * (root.to - root.from);
        if (v === root.value)
            return;
        root.value = v;
        root.moved(v);
    }

    implicitWidth: root.vertical ? Space.controlM : 240
    implicitHeight: root.vertical ? 160 : Space.controlS
    opacity: root.enabled ? 1 : 0.38

    GridLayout {
        anchors.fill: parent
        flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rowSpacing: Space.s
        columnSpacing: Space.m

        Text {
            visible: root.icon !== ""
            text: root.icon
            font.family: Icons.font
            font.pixelSize: Type.iconSize("body")
            color: Type.secondary
            horizontalAlignment: Text.AlignHCenter
            Layout.preferredWidth: root.vertical ? implicitWidth : Math.round(Type.iconSize("body") * 1.25)
            Layout.row: root.vertical ? 2 : 0
            Layout.column: 0
            Layout.alignment: Qt.AlignCenter

            MouseArea {
                anchors.fill: parent
                anchors.margins: -Space.xs
                visible: root.iconClickable
                cursorShape: Qt.PointingHandCursor
                onClicked: root.iconClicked()
            }
        }

        Item {
            id: area
            Layout.row: root.vertical ? 1 : 0
            Layout.column: root.vertical ? 0 : 1
            Layout.fillWidth: true
            Layout.fillHeight: true
            implicitWidth: knob.width
            implicitHeight: knob.height

            Rectangle {
                id: track
                anchors.centerIn: parent
                width: root.vertical ? Space.stroke : parent.width
                height: root.vertical ? parent.height : Space.stroke
                radius: Space.stroke / 2
                color: Type.track

                Rectangle {
                    x: 0
                    y: root.vertical ? parent.height - height : 0
                    width: root.vertical ? parent.width : parent.width * root.fraction
                    height: root.vertical ? parent.height * root.fraction : parent.height
                    radius: parent.radius
                    color: Type.progress
                }

                // Live level, quieter than the value it rides on.
                Rectangle {
                    objectName: "levelMeter"
                    visible: root.level >= 0
                    readonly property real f: Math.max(0, Math.min(1, root.level))
                    x: 0
                    y: root.vertical ? parent.height - height : 0
                    width: root.vertical ? parent.width : parent.width * f
                    height: root.vertical ? parent.height * f : parent.height
                    radius: parent.radius
                    color: Type.text
                    opacity: 0.35
                }
            }

            Rectangle {
                id: knob
                width: Space.m
                height: width
                radius: width / 2
                color: Type.progress
                x: root.vertical ? (area.width - width) / 2 : root.fraction * area.width - width / 2
                y: root.vertical ? (1 - root.fraction) * area.height - height / 2 : (area.height - height) / 2
                scale: root.hovered || root.pressed ? 1 : 0
                Behavior on scale {
                    enabled: Motion.enter.duration > 0
                    NumberAnimation {
                        duration: Motion.enter.duration / 2
                        easing.type: Motion.morph.easing
                    }
                }
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                anchors.margins: -Space.xs
                hoverEnabled: true
                enabled: root.enabled
                function track(m: var) {
                    root.setFraction(root.vertical ? 1 - (m.y - Space.xs) / area.height : (m.x - Space.xs) / area.width);
                }
                onPressed: m => mouse.track(m)
                onPositionChanged: m => {
                    if (mouse.pressed)
                        mouse.track(m);
                }
                onWheel: w => {
                    const d = (w.angleDelta.y !== 0 ? w.angleDelta.y : w.angleDelta.x) > 0 ? 1 : -1;
                    root.setFraction(root.fraction + d * root.step / (root.to - root.from));
                }
            }
        }

        KitText {
            visible: root.showValue
            role: "secondary"
            tabular: true
            text: root.valueText
            horizontalAlignment: root.vertical ? Text.AlignHCenter : Text.AlignRight
            Layout.row: 0
            Layout.column: root.vertical ? 0 : 2
            Layout.alignment: Qt.AlignCenter
            Layout.minimumWidth: root.vertical ? 0 : Type.size("secondary") * 2.4
        }
    }
}
