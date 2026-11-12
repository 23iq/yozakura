import QtQuick
import qs.modules.components.kit

// Stage of the island tab: your whole screen (ScreenMini) with the island
// ringed in the accent where it sits; rows light up their part.
Stage {
    id: stage

    stageHeight: Space.px(270)

    ScreenMini {
        anchors.fill: parent
        barOpacity: stage.barOpacity
        cornerRadius: stage.radius
        emphasis: "island"
    }
}
