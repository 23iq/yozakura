import QtQuick
import qs.modules.widgets.menus
import qs.modules.widgets.powermenu

// layout.powermenu.style "notch": the power actions as an ActionStrip in
// the notch. Left/Right move between them; destructive ones are held to
// confirm (the caption says "Hold to shut down").
FocusScope {
    id: root

    // Style contract (MenuStyles.js); unused in the notch.
    property point cursor
    property var area: null
    property bool shown: true

    signal closeRequested

    implicitWidth: strip.implicitWidth
    implicitHeight: strip.implicitHeight

    PowerMenuModel {
        id: power
        objectName: "powerModel"
        onDone: root.closeRequested()
    }

    ActionStrip {
        id: strip
        objectName: "powerStrip"
        anchors.fill: parent
        focus: true
        items: power.items
        onTriggered: index => power.run(index)
        onDismissed: root.closeRequested()
    }
}
