pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store

// Stage of the island tab: your whole screen (ScreenMini) with the island
// ringed in the accent where it sits. A click on another edge of the tiny
// screen moves it there (EdgePicker shows a ghost first); rows light up
// their part.
Stage {
    id: stage

    readonly property string edge: String(SettingsStore.get("notch.position") || "top")

    stageHeight: Space.px(270)

    ScreenMini {
        id: mini
        anchors.fill: parent
        barOpacity: stage.barOpacity
        cornerRadius: stage.radius
        partsClickable: true
        onPartPicked: part => SettingsStore.navigate(part === "island" ? "notch" : "dock")
        emphasis: "island"
        EdgePicker {
            objectName: "islandEdgePicker"
            visible: SettingsStore.get("notch.enabled") !== false
            edges: ["top", "bottom"]
            current: stage.edge
            reach: Math.max(mini.unit * 1.6, Space.px(24))
            ghostThickness: Math.round(mini.unit * 0.9)
            ghostSpan: 0.22
            onPicked: e => SettingsStore.transaction("prefs.undo.island_moved", () => SettingsStore.set("notch.position", e))
        }
    }
}
