import QtQuick
import qs.modules.theme
import qs.modules.components.kit

// Text button of the settings pages: a kit Chip. `kind`: "filled" is the
// page's primary action (the filled accent); every other kind ("tonal",
// "ghost", "solid") is the language's quiet control box. `icon` is an Icons
// name.
Item {
    id: root

    property string text: ""
    property string icon: ""
    property string kind: "tonal"

    signal clicked

    implicitWidth: chip.implicitWidth
    implicitHeight: chip.implicitHeight
    activeFocusOnTab: true

    Accessible.role: Accessible.Button
    Accessible.name: root.text

    Keys.onReturnPressed: root.clicked()
    Keys.onSpacePressed: root.clicked()

    Chip {
        id: chip
        anchors.fill: parent
        icon: root.icon !== "" ? (Icons[root.icon] ?? "") : ""
        text: root.text
        primary: root.kind === "filled"
        highlighted: root.activeFocus
        onClicked: root.clicked()
    }
}
