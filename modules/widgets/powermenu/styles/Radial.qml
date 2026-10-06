import QtQuick
import qs.modules.components
import qs.modules.widgets.powermenu

// layout.powermenu.style "radial": the power actions on a RadialMenu at the
// cursor, kept inside the work area.
FocusScope {
    id: root

    property point cursor
    property var area: null
    property bool shown: false

    signal closeRequested

    onActiveFocusChanged: {
        if (activeFocus)
            menu.forceActiveFocus();
    }

    PowerMenuModel {
        id: power
        onDone: root.closeRequested()
    }

    RadialMenu {
        id: menu
        anchors.fill: parent
        focus: true
        items: power.items
        cursor: root.cursor
        area: root.area || ({
                "x": 0,
                "y": 0,
                "w": root.width,
                "h": root.height
            })
        shown: root.shown
        onTriggered: index => power.run(index)
        onDismissed: root.closeRequested()
    }
}
