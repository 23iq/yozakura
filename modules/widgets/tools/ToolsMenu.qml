import QtQuick
import qs.modules.components
import qs.modules.widgets.tools

// layout.tools.style "notch": the tools as an ActionGrid row in the notch.
// Actions live in ToolsModel (shared with the radial style).
ActionGrid {
    id: root

    signal itemSelected

    layout: "row"
    buttonSize: 48
    iconSize: 20
    spacing: 8
    actions: tools.items

    onActionTriggered: action => tools.run(action.id)

    ToolsModel {
        id: tools
        onDone: root.itemSelected()
    }
}
