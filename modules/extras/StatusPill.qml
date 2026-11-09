import QtQuick
import qs.modules.theme
import qs.modules.components.kit
import "ExtrasUi.js" as Ui

// Small tinted state pill of a catalog card: icon (an Icons key) + label
// in `accent`, the state's semantic colour (success, error, ...). Not a
// control: a dense chip-shaped tag, no hover.
Rectangle {
    id: root

    property string icon: ""
    property string text: ""
    property color accent: Type.accent

    implicitWidth: row.implicitWidth + Space.m * 2
    implicitHeight: Space.chip - Space.s
    radius: Look.radius("chip", height)
    color: Ui.alpha(root.accent, 0.14)
    border.width: Space.hairline
    border.color: Ui.alpha(root.accent, 0.38)

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Space.xs

        Icon {
            visible: root.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            icon: Icons[root.icon] ?? ""
            role: "caption"
            color: root.accent
        }
        KitText {
            anchors.verticalCenter: parent.verticalCenter
            role: "caption"
            text: root.text
            font.weight: Look.activeLabelWeight
            color: root.accent
        }
    }
}
