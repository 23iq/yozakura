pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store
import "../PanelsModel.js" as PanelsModel
import "../SchemaUtil.js" as SchemaUtil

// Stage of the Bar page: the bar itself, as wide as the page and at a
// readable scale (ScreenMini drawn page-wide and cropped to the edge of the
// bar picked for editing: its shape, size, the real clock face and
// workspace indicator, every module's glyph, the island under it). Not a
// shrunk desktop: where the bar sits is the Edge row's job. A click on a
// module scrolls to its card and flashes it (the clock to Clock, the
// workspaces to Workspaces, any other to On the bar); a click on a bar
// picks it for the bars editor; rows light up their part.
Stage {
    id: stage

    readonly property var barConfig: ({
            "position": SchemaUtil.plain(SettingsStore.get("bar.position")) || "top",
            "layout": SchemaUtil.plain(SettingsStore.get("bar.layout")) || {},
            "panels": SchemaUtil.plain(SettingsStore.get("bar.panels")) || []
        })
    readonly property var panels: PanelsModel.panelsOf(stage.barConfig)
    readonly property int current: Math.max(0, Math.min(SettingsStore.selectedPanel, stage.panels.length - 1))
    readonly property string currentEdge: stage.panels[stage.current] ? stage.panels[stage.current].edge : "top"
    readonly property bool vertical: stage.currentEdge === "left" || stage.currentEdge === "right"
    // the band of the bar and the island hanging from it, never taller than
    // a vertical bar's top part needs
    // a strip as wide as the page (SettingsPage)
    readonly property bool strip: true
    readonly property real preferredHeight: stage.vertical ? Space.px(240) : Math.round(mini.edgeDepth(stage.currentEdge) + mini.unit * 2)

    // the card a module is edited in
    function sectionOf(id) {
        return id === "clock" ? "clock" : (id === "workspaces" ? "workspaces" : "layout");
    }

    stageHeight: stage.preferredHeight

    Item {
        id: crop
        anchors.fill: parent
        clip: true

        ScreenMini {
            id: mini
            objectName: "barStageScreen"
            width: crop.width
            height: Math.round(crop.width * 9 / 16)
            x: 0
            y: stage.currentEdge === "bottom" ? crop.height - height : 0
            showWindows: false
            showDock: false
            corners: false
            barOpacity: stage.barOpacity
            cornerRadius: 0
            partsClickable: true
            onPartPicked: part => SettingsStore.navigate(part === "island" ? "notch" : "dock")
            modulesClickable: true
            onModulePicked: id => SettingsStore.navigate("bar", stage.sectionOf(id), "")
            selectable: stage.panels.length > 1
            selectedPanel: SettingsStore.selectedPanel
            onPanelPicked: index => SettingsStore.selectedPanel = index
        }
    }
}
