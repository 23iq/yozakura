pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.components.kit
import qs.modules.settings.store

// Stage of the Bar page: your whole screen arrangement (ScreenMini: every
// bar panel on its edge, rails, the dock, the island, the frame and the
// space they reserve) on your wallpaper. A click on a panel picks it for
// the bars editor (SettingsStore.selectedPanel); rows light up their part.
Stage {
    id: stage

    stageHeight: Space.px(270)

    ScreenMini {
        anchors.fill: parent
        barOpacity: stage.barOpacity
        cornerRadius: stage.radius
        selectable: true
        selectedPanel: SettingsStore.selectedPanel
        onPanelPicked: index => SettingsStore.selectedPanel = index
    }
}
