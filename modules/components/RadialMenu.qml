pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.config
import "../shell/EdgeLayout.js" as EdgeLayout

// A ring of round actions around a hub, opened at `cursor` and kept inside
// `area` (the work area, EdgeService.workArea) by EdgeLayout.radialCenter.
// Fill the overlay with it. items: [{icon, label, confirm}]; a confirm item
// (shutdown, reboot, logout) fires only after a full HoldToConfirm hold, by
// mouse or by holding Enter. Arrows/Tab move the selection, Escape or a
// click on the hub or outside the ring dismisses.
Item {
    id: root

    property var items: []
    property point cursor: Qt.point(width / 2, height / 2)
    property var area: ({
            "x": 0,
            "y": 0,
            "w": root.width,
            "h": root.height
        })
    property bool shown: false
    property int currentIndex: 0

    readonly property int count: items ? items.length : 0
    readonly property int itemSize: Metrics.rowHeight + Metrics.spacing
    readonly property real ringRadius: Math.max(itemSize * 1.4, count * itemSize * 1.3 / (2 * Math.PI))
    readonly property int outerRadius: Math.ceil(ringRadius + itemSize / 2 + Metrics.padding)
    readonly property var center: EdgeLayout.radialCenter(cursor, outerRadius, area)
    readonly property var current: count > 0 ? items[Math.min(currentIndex, count - 1)] : null

    property real progress: shown ? 1 : 0
    Behavior on progress {
        enabled: Motion.enter.duration > 0
        NumberAnimation {
            duration: root.shown ? Motion.enter.duration : Motion.exit.duration
            easing.type: root.shown ? Motion.enter.easing : Motion.exit.easing
            easing.overshoot: Motion.enter.overshoot
        }
    }

    signal triggered(int index)
    signal dismissed

    function step(delta) {
        if (root.count > 0)
            root.currentIndex = (root.currentIndex + delta + root.count) % root.count;
    }

    function itemAt(index) {
        return ring.itemAt(index);
    }

    function holderAt(index) {
        const it = root.itemAt(index);
        return it ? it.holder : null;
    }

    // Plain items fire at once; confirm items start the hold.
    function activate(index, pressed) {
        const item = root.items[index];
        if (!item)
            return;
        if (!item.confirm) {
            if (pressed)
                root.triggered(index);
            return;
        }
        const holder = root.holderAt(index);
        if (holder)
            pressed ? holder.press() : holder.release();
    }

    Keys.onPressed: event => {
        const k = event.key;
        if (k === Qt.Key_Escape) {
            root.dismissed();
        } else if (k === Qt.Key_Right || k === Qt.Key_Down || k === Qt.Key_Tab) {
            root.step(1);
        } else if (k === Qt.Key_Left || k === Qt.Key_Up || k === Qt.Key_Backtab) {
            root.step(-1);
        } else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) {
            if (!event.isAutoRepeat)
                root.activate(root.currentIndex, true);
        } else {
            return;
        }
        event.accepted = true;
    }
    Keys.onReleased: event => {
        if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space)
            return;
        event.accepted = true;
        if (!event.isAutoRepeat)
            root.activate(root.currentIndex, false);
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.dismissed()
    }

    StyledRect {
        id: disc
        variant: "popup"
        enableShadow: true
        width: root.outerRadius * 2 - Metrics.padding
        height: width
        radius: width / 2
        x: root.center.x - width / 2
        y: root.center.y - height / 2
        opacity: root.progress
        scale: 0.6 + 0.4 * root.progress

        MouseArea {
            anchors.fill: parent
            onClicked: root.dismissed()
        }

        Text {
            anchors.centerIn: parent
            width: root.ringRadius * 2 - root.itemSize - Metrics.spacing * 2
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: root.current ? (root.current.label || "") : ""
            color: Colors.overBackground
            font.family: Config.defaultFont
            font.pixelSize: Styling.fontSize(0)
            font.weight: Font.Medium
        }
    }

    Repeater {
        id: ring
        model: root.items

        delegate: StyledRect {
            id: slot

            required property var modelData
            required property int index
            readonly property real angle: (-90 + (root.count > 0 ? index * 360 / root.count : 0)) * Math.PI / 180
            readonly property bool selected: root.currentIndex === index
            property alias holder: hold

            variant: selected ? "primary" : "common"
            width: root.itemSize
            height: root.itemSize
            radius: width / 2
            x: root.center.x + Math.cos(angle) * root.ringRadius * root.progress - width / 2
            y: root.center.y + Math.sin(angle) * root.ringRadius * root.progress - height / 2
            opacity: root.progress
            scale: selected ? 1.08 : 1

            Behavior on scale {
                enabled: Motion.enter.duration > 0
                NumberAnimation {
                    duration: Motion.enter.duration
                    easing.type: Motion.enter.easing
                }
            }

            Text {
                anchors.centerIn: parent
                text: slot.modelData.icon || ""
                color: slot.selected ? Styling.srItem("primary") : (slot.modelData.confirm ? Colors.error : Colors.overBackground)
                font.family: Icons.font
                font.pixelSize: Math.round(Metrics.iconSize * 0.65)
            }

            HoldToConfirm {
                id: hold
                anchors.fill: parent
                anchors.margins: -4
                color: Colors.error
                onConfirmed: root.triggered(slot.index)
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: root.currentIndex = slot.index
                onPressed: root.activate(slot.index, true)
                onReleased: root.activate(slot.index, false)
                onCanceled: root.activate(slot.index, false)
            }
        }
    }
}
