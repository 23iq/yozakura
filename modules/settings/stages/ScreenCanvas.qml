pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store
import qs.modules.settings

// The Screen destination's canvas (SettingsPage, two panes): the whole
// screen as it is laid out (every bar, the island, the dock, the frame, on
// your wallpaper), the part this tab edits ringed in the accent, every other
// part a click away (a bar picks that bar on the Bar tab, the island and the
// dock open their tabs); under it a loupe: the tab's own stage (the bar
// strip, the island in its states, the dock) at a readable scale. The rows
// of the page are the inspector of the ringed part.
Item {
    id: canvas
    objectName: "screenCanvas"

    // "bar" | "island" | "dock": the part this tab edits
    property string part: "bar"
    // the tab's own stage (the loupe), by URL
    property string loupeUrl: ""

    readonly property var loupe: loupeLoader.item
    // a vertical bar's strip only repeats the canvas: no loupe then
    // a part that is off has nothing to magnify (the canvas shows it gone)
    readonly property bool partOn: canvas.part === "dock" ? SettingsStore.get("dock.enabled") !== false : canvas.part === "island" ? SettingsStore.get("notch.enabled") !== false : true
    readonly property bool loupeShown: canvas.partOn && loupeLoader.status === Loader.Ready && !(canvas.part === "bar" && canvas.loupe && canvas.loupe.vertical === true)
    readonly property real screenH: Math.round(canvas.width * 9 / 16)
    readonly property real loupeH: canvas.loupeShown ? Math.min(Space.px(260), Math.max(Space.px(96), canvas.loupe.preferredHeight || Space.px(120))) : 0
    // a part that is off: a note with its switch instead of the loupe
    readonly property bool offNote: !canvas.partOn && canvas.part !== "bar"
    // asked of the page: the canvas, the gap and the loupe (or the note)
    readonly property real preferredHeight: canvas.screenH + (canvas.loupeShown ? Space.m + canvas.loupeH : 0) + (canvas.offNote ? Space.m + offRow.height : 0)
    readonly property bool pageWide: false
    property bool calm: false

    implicitHeight: canvas.preferredHeight

    Stage {
        id: frame
        width: parent.width
        height: canvas.screenH
        stageHeight: canvas.screenH

        ScreenMini {
            id: mini
            objectName: "screenCanvasMini"
            anchors.fill: parent
            showWindows: true
            windowsOpacity: 0.55
            barOpacity: frame.barOpacity
            cornerRadius: 0
            emphasis: canvas.part === "bar" ? "" : canvas.part
            partsClickable: true
            onPartPicked: part => SettingsStore.navigate(part === "island" ? "notch" : "dock")
            // the bar's modules are buttons: each scrolls to its card
            modulesClickable: canvas.part === "bar"
            onModulePicked: id => SettingsStore.navigate("bar", id === "clock" ? "clock" : (id === "workspaces" ? "workspaces" : "layout"), "")
            // every bar can be picked; on the Bar tab the picked one is ringed
            selectable: true
            selectedPanel: canvas.part === "bar" ? SettingsStore.selectedPanel : -1
            onPanelPicked: index => {
                SettingsStore.selectedPanel = index;
                if (canvas.part !== "bar")
                    SettingsStore.navigate("bar");
            }
        }
    }

    // the part is off: say so, with the switch that brings it back
    Row {
        id: offRow
        objectName: "screenCanvasOff"
        visible: canvas.offNote
        y: frame.height + Space.m
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Space.m
        KitText {
            anchors.verticalCenter: parent.verticalCenter
            role: "secondary"
            text: I18n.t(canvas.part === "dock" ? "prefs.dock.off_stage" : "prefs.notch.off_stage")
        }
        PillButton {
            anchors.verticalCenter: parent.verticalCenter
            kind: "tonal"
            text: I18n.t("prefs.disabled.turn_on")
            onClicked: SettingsStore.set(canvas.part === "dock" ? "dock.enabled" : "notch.enabled", true)
        }
    }

    // the loupe: the tab's stage on its own plain ground
    Loader {
        id: loupeLoader
        objectName: "screenCanvasLoupe"
        y: frame.height + Space.m
        width: parent.width
        height: canvas.loupeH
        visible: canvas.loupeShown
        active: canvas.loupeUrl !== ""
        source: canvas.loupeUrl
        onLoaded: {
            if (item && "calm" in item)
                item.calm = true;
        }
    }
}
