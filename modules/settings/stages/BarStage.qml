pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store
import "../PanelsModel.js" as PanelsModel
import "../SchemaUtil.js" as SchemaUtil

// Stage of the Bar page: your whole screen arrangement (ScreenMini: every
// bar panel on its edge, rails, the dock, the island, the frame and the
// space they reserve) on your wallpaper, and the place to move the bar:
// a click on an empty edge of the tiny screen moves the bar there (the
// bar picked for editing when there are several; EdgePicker shows a ghost
// first); a click on a bar picks it for the bars editor
// (SettingsStore.selectedPanel); a click on the island or the dock opens
// its tab. Rows light up their part.
Stage {
    id: stage

    readonly property var panels: PanelsModel.panelsOf({
        "position": SchemaUtil.plain(SettingsStore.get("bar.position")) || "top",
        "layout": SchemaUtil.plain(SettingsStore.get("bar.layout")) || {},
        "panels": SchemaUtil.plain(SettingsStore.get("bar.panels")) || []
    })
    readonly property bool several: stage.panels.length > 1
    readonly property int current: Math.max(0, Math.min(SettingsStore.selectedPanel, stage.panels.length - 1))
    readonly property string currentEdge: stage.panels[stage.current] ? stage.panels[stage.current].edge : "top"

    // Move the bar (the picked one) to `edge`; a bar already there is
    // picked instead.
    function moveTo(edge) {
        if (stage.several) {
            const there = stage.panels.findIndex(p => p.edge === edge);
            if (there >= 0) {
                SettingsStore.selectedPanel = there;
                return;
            }
            SettingsStore.transaction("prefs.undo.bar_moved", () => SettingsStore.set("bar.panels", PanelsModel.setField(stage.panels, stage.current, "edge", edge)));
        } else {
            SettingsStore.transaction("prefs.undo.bar_moved", () => SettingsStore.set("bar.position", edge));
        }
    }

    stageHeight: Space.px(270)

    ScreenMini {
        id: mini
        objectName: "barStageScreen"
        anchors.fill: parent
        barOpacity: stage.barOpacity
        cornerRadius: stage.radius
        partsClickable: true
        onPartPicked: part => SettingsStore.navigate(part === "island" ? "notch" : "dock")
        selectable: true
        selectedPanel: SettingsStore.selectedPanel
        onPanelPicked: index => SettingsStore.selectedPanel = index
        EdgePicker {
            objectName: "barEdgePicker"
            current: stage.currentEdge
            busy: stage.several ? stage.panels.map(p => p.edge).filter(e => e !== stage.currentEdge) : []
            reach: Math.max(mini.unit * 1.6, Space.px(24))
            ghostThickness: mini.unit
            onPicked: edge => stage.moveTo(edge)
        }
    }
}
