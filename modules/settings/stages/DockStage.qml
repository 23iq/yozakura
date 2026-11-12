import QtQuick
import qs.modules.components.kit

// Stage of the dock tab: your whole screen (ScreenMini) with the dock
// ringed in the accent where it sits; rows light up their part.
Stage {
    id: stage

    stageHeight: Space.px(270)

    ScreenMini {
        anchors.fill: parent
        barOpacity: stage.barOpacity
        cornerRadius: stage.radius
        emphasis: "dock"
    }
}
