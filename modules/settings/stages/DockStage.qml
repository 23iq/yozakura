pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store

// Stage of the dock tab: your whole screen (ScreenMini) with the dock
// ringed in the accent where it sits. A click on another edge of the tiny
// screen moves it there (EdgePicker shows a ghost first); rows light up
// their part.
Stage {
    id: stage

    readonly property string edge: String(SettingsStore.get("dock.position") || "bottom")

    stageHeight: Space.px(270)

    ScreenMini {
        id: mini
        anchors.fill: parent
        barOpacity: stage.barOpacity
        cornerRadius: stage.radius
        partsClickable: true
        onPartPicked: part => SettingsStore.navigate(part === "island" ? "notch" : "dock")
        emphasis: "dock"
        EdgePicker {
            objectName: "dockEdgePicker"
            visible: SettingsStore.get("dock.enabled") !== false && SettingsStore.get("dock.theme") !== "integrated"
            edges: ["bottom", "left", "right"]
            current: stage.edge
            reach: Math.max(mini.unit * 1.6, Space.px(24))
            ghostThickness: mini.unit
            ghostSpan: 0.4
            onPicked: e => SettingsStore.transaction("prefs.undo.dock_moved", () => SettingsStore.set("dock.position", e))
        }
    }
}
