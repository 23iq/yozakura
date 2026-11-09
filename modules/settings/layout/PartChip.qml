import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.config
import "../Ui.js" as Ui
import qs.modules.components.kit

// One part (bar, notch, dock) of the layout builder's screen mock: a chip
// at `rect` that can be selected and dragged. While dragging it follows the
// pointer and reports where the pointer is (in its parent's coordinates);
// on release it glides back to `rect`, which the new config then moves.
Item {
    id: chip

    property string partId: ""
    property var rect: ({
            "x": 0,
            "y": 0,
            "w": 0,
            "h": 0
        })
    property bool vertical: false
    property bool selected: false
    property bool dimmed: false
    property string icon: ""
    property string label: ""
    // Icons of the re-homed content it shows (clock, tray, activities)
    property var badges: []
    readonly property bool dragging: mouse.drag.active

    signal picked(string partId)
    signal moved(string partId, real cx, real cy)
    signal released(string partId, real cx, real cy)

    objectName: "partChip_" + partId
    x: rect.x
    y: rect.y
    width: rect.w
    height: rect.h
    z: dragging ? 10 : (selected ? 2 : 1)

    readonly property color tint: chip.partId === "notch" ? Colors.secondary : chip.partId === "dock" ? Colors.tertiary : Colors.primary

    Behavior on x {
        enabled: !chip.dragging
        NumberAnimation {
            duration: Motion.morph.duration
            easing.type: Motion.morph.easing
        }
    }
    Behavior on y {
        enabled: !chip.dragging
        NumberAnimation {
            duration: Motion.morph.duration
            easing.type: Motion.morph.easing
        }
    }
    Behavior on width {
        NumberAnimation {
            duration: Motion.morph.duration
            easing.type: Motion.morph.easing
        }
    }
    Behavior on height {
        NumberAnimation {
            duration: Motion.morph.duration
            easing.type: Motion.morph.easing
        }
    }

    Rectangle {
        id: body
        anchors.fill: parent
        radius: Math.min(width, height) / 2
        color: Ui.mix(Colors.surfaceContainerHighest, chip.tint, chip.selected || chip.dragging ? 0.42 : (mouse.containsMouse ? 0.3 : 0.2))
        border.width: chip.selected ? 2 : 1
        border.color: chip.selected ? chip.tint : Ui.alpha(chip.tint, 0.55)
        opacity: chip.dimmed ? 0.45 : 1
        scale: chip.dragging ? 1.06 : 1

        Behavior on color {
            ColorAnimation {
                duration: Motion.enter.duration
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Motion.enter.duration
                easing.type: Motion.enter.easing
                easing.overshoot: Motion.enter.overshoot
            }
        }

        Flow {
            id: face
            anchors.centerIn: parent
            flow: chip.vertical ? Flow.TopToBottom : Flow.LeftToRight
            spacing: Metrics.spacing
            readonly property bool roomy: chip.vertical ? chip.height > 90 : chip.width > 110

            Icon {
                icon: Icons[chip.icon] || ""
                tone: "text"
                // Shrinks with a thin chip
                size: Math.max(1, Math.min(Type.iconSize("caption"), (chip.vertical ? chip.width : chip.height) - Space.s))
            }
            KitText {
                role: "caption"
                visible: face.roomy && !chip.vertical
                text: chip.label
                font.family: Styling.defaultFont
                font.weight: Font.DemiBold
                color: Colors.overBackground
            }
            Repeater {
                model: face.roomy ? chip.badges : []
                Icon {
                    role: "caption"
                    required property string modelData
                    icon: Icons[modelData] || ""
                    color: Ui.alpha(Colors.overBackground, 0.7)
                }
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: chip.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        drag.target: chip
        drag.threshold: 4
        onPressed: chip.picked(chip.partId)
        // The pointer decides where the part lands (the chip lags it by
        // the drag threshold)
        onPositionChanged: event => {
            if (!chip.dragging)
                return;
            const p = mouse.mapToItem(chip.parent, event.x, event.y);
            chip.moved(chip.partId, p.x, p.y);
        }
        onReleased: event => {
            const wasDragging = chip.dragging;
            const p = mouse.mapToItem(chip.parent, event.x, event.y);
            const cx = p.x;
            const cy = p.y;
            // Back to the config's rect (the drop may move it there)
            chip.x = Qt.binding(() => chip.rect.x);
            chip.y = Qt.binding(() => chip.rect.y);
            if (wasDragging)
                chip.released(chip.partId, cx, cy);
        }
    }
}
