import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.config

// Tiny count pill ("2") for activities a segment does not show.
StyledRect {
    id: badge

    property int count: 0

    variant: "common"
    enableBorder: false
    visible: count > 0
    readonly property real diameter: Math.round(Styling.fontSize(-4) + 6)
    implicitHeight: diameter
    implicitWidth: Math.max(diameter, countText.implicitWidth + 8)
    radius: diameter / 2

    Text {
        id: countText
        anchors.centerIn: parent
        text: badge.count
        color: Colors.overBackground
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-4)
        font.weight: Font.Bold
        font.features: ({
                "tnum": 1
            })
    }
}
