pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.widgets.powermenu

// layout.powermenu.style "notch": a row of power tiles inside the notch.
// Left/Right move between them; destructive ones are held to confirm.
FocusScope {
    id: root

    // Style contract (PowerMenuStyles.js); unused in the notch.
    property point cursor
    property var area: null
    property bool shown: true

    signal closeRequested

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    function focusFirst() {
        const first = tiles.itemAt(0);
        if (first)
            first.forceActiveFocus();
    }

    function move(delta) {
        for (let i = 0; i < tiles.count; i++) {
            if (tiles.itemAt(i).activeFocus) {
                tiles.itemAt((i + delta + tiles.count) % tiles.count).forceActiveFocus();
                return;
            }
        }
        root.focusFirst();
    }

    onActiveFocusChanged: {
        if (activeFocus)
            Qt.callLater(root.focusFirst);
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab)
            root.move(1);
        else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab)
            root.move(-1);
        else if (event.key === Qt.Key_Escape)
            root.closeRequested();
        else
            return;
        event.accepted = true;
    }

    PowerMenuModel {
        id: power
        onDone: root.closeRequested()
    }

    Row {
        id: row
        spacing: Metrics.spacing

        Repeater {
            id: tiles
            model: power.items

            delegate: PowerTile {
                required property var modelData
                required property int index
                action: modelData
                onActivated: power.run(index)
                onHovered: forceActiveFocus()
            }
        }
    }
}
