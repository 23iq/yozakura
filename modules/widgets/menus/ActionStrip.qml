pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.services
import qs.modules.components.kit

// A menu as a compact strip (the notch styles of the power and tools
// menus): a row of kit ActionButtons, {type: "separator"} items as quiet
// vertical dividers between groups, and one caption line under the row
// naming the selected / hovered item (a confirm item says "Hold to ...",
// an item's `text` follows its label). items: [{icon, label, hold, confirm,
// active, text}]. The strip keeps the keyboard focus and the selection
// (`currentIndex`), so a model rebuild (a recording's ticking time) keeps
// both: Left/Right/Tab move, Enter fires (held for confirm items), Escape
// dismisses.
FocusScope {
    id: root

    property var items: []
    property int currentIndex: -1
    readonly property var current: root.isAction(root.currentIndex) ? root.items[root.currentIndex] : null
    readonly property string hint: !root.current ? "" : (root.current.hold || (root.current.confirm ? I18n.t("powermenu.hold_confirm") : root.current.label + (root.current.text ? " · " + root.current.text : "")))

    signal triggered(int index)
    signal dismissed

    implicitWidth: Math.max(row.implicitWidth, caption.implicitWidth)
    implicitHeight: row.implicitHeight + Space.s + caption.implicitHeight

    function isAction(i) {
        const it = root.items ? root.items[i] : null;
        return !!it && it.type !== "separator";
    }

    function select(i) {
        if (root.isAction(i))
            root.currentIndex = i;
    }

    function itemAt(i) {
        return buttons.itemAt(i);
    }

    // Plain items fire on press; confirm items start / stop the hold.
    function activate(i, pressed) {
        const d = root.itemAt(i);
        if (d && root.isAction(i))
            pressed ? d.press() : d.release();
    }

    function move(delta) {
        const n = root.items.length;
        let i = root.currentIndex < 0 ? (delta > 0 ? -1 : 0) : root.currentIndex;
        for (let k = 0; k < n; k++) {
            i = (i + delta + n) % n;
            if (root.isAction(i)) {
                root.currentIndex = i;
                return;
            }
        }
    }

    onActiveFocusChanged: {
        if (activeFocus && !root.isAction(root.currentIndex))
            root.move(1);
    }

    Keys.onPressed: event => {
        const k = event.key;
        if (k === Qt.Key_Right || k === Qt.Key_Tab)
            root.move(1);
        else if (k === Qt.Key_Left || k === Qt.Key_Backtab)
            root.move(-1);
        else if (k === Qt.Key_Escape)
            root.dismissed();
        else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) {
            if (!event.isAutoRepeat)
                root.activate(root.currentIndex, true);
        } else
            return;
        event.accepted = true;
    }
    Keys.onReleased: event => {
        if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space)
            return;
        event.accepted = true;
        if (!event.isAutoRepeat)
            root.activate(root.currentIndex, false);
    }

    Row {
        id: row
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Space.s

        Repeater {
            id: buttons
            // By count: a rebuilt list of the same length (a recording's
            // ticking time) updates the delegates instead of recreating them.
            model: root.items ? root.items.length : 0

            delegate: Item {
                id: slot

                required property int index
                readonly property var modelData: root.items[slot.index] || ({})
                readonly property bool separator: modelData.type === "separator"
                readonly property alias hold: action.hold

                width: slot.separator ? rule.width : action.width
                height: action.height

                function press() {
                    action.press();
                }

                function release() {
                    action.release();
                }

                Divider {
                    id: rule
                    vertical: true
                    visible: slot.separator && Look.dividers
                    width: Look.dividers ? Space.hairline : Space.xs
                    height: Math.round(action.height * 0.5)
                    anchors.centerIn: parent
                }

                ActionButton {
                    id: action
                    visible: !slot.separator
                    icon: slot.modelData.icon || ""
                    text: slot.modelData.label || ""
                    confirm: !!slot.modelData.confirm
                    active: !!slot.modelData.active
                    highlighted: root.currentIndex === slot.index
                    onEntered: root.select(slot.index)
                    onActivated: root.triggered(slot.index)
                }
            }
        }
    }

    KitText {
        id: caption
        objectName: "stripCaption"
        anchors.top: row.bottom
        anchors.topMargin: Space.s
        anchors.horizontalCenter: parent.horizontalCenter
        role: "caption"
        // Keeps its line while empty so the strip does not jump.
        text: root.hint !== "" ? root.hint : " "
    }
}
