import QtQuick
import qs.modules.widgets.menus
import qs.modules.widgets.tools

// layout.tools.style "notch": the tools as an ActionStrip in the notch,
// grouped (capture, recording, utilities); the caption names the focused
// tool (and the recording time while recording). Actions live in ToolsModel
// (shared with the radial style).
FocusScope {
    id: root

    signal itemSelected

    implicitWidth: strip.implicitWidth
    implicitHeight: strip.implicitHeight

    ToolsModel {
        id: tools
        objectName: "toolsModel"
        onDone: root.itemSelected()
    }

    ActionStrip {
        id: strip
        objectName: "toolsStrip"
        anchors.fill: parent
        focus: true
        items: tools.items
        onTriggered: index => tools.run(tools.items[index].id)
        onDismissed: root.itemSelected()
    }
}
