import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.modules.components.kit

// Tiny count pill ("2") for activities a segment does not show.
StyledRect {
    id: badge

    property int count: 0

    variant: "common"
    enableBorder: false
    visible: count > 0
    readonly property real diameter: Type.size("caption") + Space.s
    implicitHeight: diameter
    implicitWidth: Math.max(diameter, countText.implicitWidth + Space.s)
    radius: diameter / 2

    KitText {
        id: countText
        anchors.centerIn: parent
        role: "caption"
        tabular: true
        color: Type.text
        text: badge.count
    }
}
