pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "../../shell/EdgeLayout.js" as EdgeLayout

// A ring of kit ActionButtons around a round surface, opened at `cursor`
// and kept inside `area` (the work area, EdgeService.workArea) by
// EdgeLayout.radialCenter. Fill the overlay with it. items: [{icon, label,
// hold, confirm, active}]; the center names the selected item and, for a
// confirm item (shutdown, reboot, logout), asks to hold: it fires only after
// a full HoldToConfirm hold, by mouse or by holding Enter. Arrows/Tab move
// the selection, Escape or a click on the hub or outside the ring dismisses.
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
    // A button plus its hold ring.
    readonly property int itemSize: Space.controlM + Space.s * 2
    readonly property real ringRadius: Math.max(itemSize * 2, count * itemSize * 1.3 / (2 * Math.PI))
    readonly property int outerRadius: Math.ceil(ringRadius + itemSize / 2 + Space.l)
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
        return it ? it.hold : null;
    }

    // Plain items fire on press; confirm items start / stop the hold.
    function activate(index, pressed) {
        const it = root.itemAt(index);
        if (it)
            pressed ? it.press() : it.release();
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

    Surface {
        id: disc
        objectName: "radialDisc"
        enableShadow: true
        width: root.outerRadius * 2
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
    }

    Column {
        objectName: "radialCenter"
        width: root.ringRadius * 2 - root.itemSize - Space.l
        x: root.center.x - width / 2
        y: root.center.y - height / 2
        spacing: Space.xs
        opacity: root.progress

        KitText {
            objectName: "radialLabel"
            width: parent.width
            role: "title"
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            text: root.current ? (root.current.label || "") : ""
        }

        KitText {
            objectName: "radialHint"
            width: parent.width
            visible: text !== ""
            role: "caption"
            horizontalAlignment: Text.AlignHCenter
            text: !root.current ? "" : (root.current.hold || (root.current.confirm ? I18n.t("powermenu.hold_confirm") : (root.current.text || "")))
        }
    }

    Repeater {
        id: ring
        // By count, so a rebuilt list (a recording's time) keeps the slots.
        model: root.count

        delegate: ActionButton {
            id: slot

            required property int index
            readonly property var modelData: root.items[slot.index] || ({})
            readonly property real angle: (-90 + (root.count > 0 ? index * 360 / root.count : 0)) * Math.PI / 180

            icon: modelData.icon || ""
            text: modelData.label || ""
            confirm: !!modelData.confirm
            active: !!modelData.active
            highlighted: root.currentIndex === index
            x: root.center.x + Math.cos(angle) * root.ringRadius * root.progress - width / 2
            y: root.center.y + Math.sin(angle) * root.ringRadius * root.progress - height / 2
            opacity: root.progress
            onEntered: root.currentIndex = slot.index
            onActivated: root.triggered(slot.index)
        }
    }
}
