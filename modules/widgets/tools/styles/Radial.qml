import QtQuick
import qs.modules.components
import qs.modules.widgets.tools

// layout.tools.style "radial": the tools on a RadialMenu at the cursor,
// kept inside the work area.
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

    ToolsModel {
        id: tools
        onDone: root.closeRequested()
    }

    RadialMenu {
        id: menu
        anchors.fill: parent
        focus: true
        items: tools.actions
        cursor: root.cursor
        area: root.area || ({
                "x": 0,
                "y": 0,
                "w": root.width,
                "h": root.height
            })
        shown: root.shown
        onTriggered: index => tools.run(tools.actions[index].id)
        onDismissed: root.closeRequested()
    }
}
