pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store
import "OsdPlace.js" as OsdPlace
import "../Ui.js" as Ui
import "../../shell/osd/OsdStyles.js" as OsdStyles

// Stage of On-screen display: your screen with the real OSD (its style
// component, loaded by URL) where it shows now (OsdPlace.js, the shell's
// rules), ringed in the accent. Hovering an edge shows a ghost and "Move
// here"; a click puts it on that edge (layout.osd.position). The bar-inline
// style lives in the bar: the bar is ringed instead.
Stage {
    id: stage

    readonly property string style: OsdStyles.normalize(SettingsStore.get("layout.osd.style"))
    readonly property string pref: String(SettingsStore.get("layout.osd.position") || "auto")
    readonly property string edge: OsdPlace.edge(stage.style, stage.pref, {
        "notchPosition": mini.islandEdge,
        "notchEnabled": mini.island,
        "barEdge": mini.panels.length > 0 ? mini.panels[0].edge : "",
        "occupied": ["top", "bottom", "left", "right"].filter(e => mini.edgeDepth(e) > 0)
    })
    readonly property bool vertical: stage.edge === "left" || stage.edge === "right"
    // the shell's OSD size (OsdStyles.sizeFor) at the miniature's scale
    readonly property var size: OsdStyles.sizeFor(stage.style, stage.vertical, Metrics.osdW)
    readonly property real k: mini.width / 1920

    stageHeight: Space.px(270)

    ScreenMini {
        id: mini
        anchors.fill: parent
        barOpacity: stage.barOpacity
        cornerRadius: stage.radius
        windowsOpacity: 0.45

        Item {
            id: osd
            objectName: "osdOnStage"
            visible: stage.edge !== ""
            readonly property real m: Math.round(mini.unit * 0.6)
            width: Math.round(stage.size.w * stage.k * 1.6)
            height: Math.round(stage.size.h * stage.k * 1.6)
            x: stage.vertical ? (stage.edge === "left" ? mini.freeRect.x + m : mini.freeRect.x + mini.freeRect.w - width - m) : mini.freeRect.x + (mini.freeRect.w - width) / 2
            y: stage.vertical ? mini.freeRect.y + (mini.freeRect.h - height) / 2 : (stage.edge === "top" ? mini.freeRect.y + m : mini.freeRect.y + mini.freeRect.h - height - m)
            Behavior on x {
                enabled: Motion.glide.duration > 0
                NumberAnimation {
                    duration: Motion.glide.duration
                    easing.type: Motion.glide.easing
                }
            }
            Behavior on y {
                enabled: Motion.glide.duration > 0
                NumberAnimation {
                    duration: Motion.glide.duration
                    easing.type: Motion.glide.easing
                }
            }

            // the real style, drawn at the shell's size and scaled in
            Loader {
                id: real
                anchors.centerIn: parent
                width: stage.size.w
                height: stage.size.h
                scale: Math.min(osd.width / Math.max(1, stage.size.w), osd.height / Math.max(1, stage.size.h))
                source: "../../shell/osd/" + OsdStyles.fileFor(stage.style)
                onLoaded: {
                    Ui.setIfPresent(item, "vertical", Qt.binding(() => stage.vertical));
                    item.kind = "volume";
                    item.value = 0.62;
                    item.shown = true;
                }
            }
            StageSpot {
                keys: ["layout.osd"]
                cornerRadius: Look.radius("chip", osd.height)
            }
        }

        EdgePicker {
            objectName: "osdEdgePicker"
            anchors.fill: parent
            visible: stage.style !== "bar-inline"
            current: stage.pref === "auto" ? "" : stage.edge
            // as thick as the OSD across its edge
            ghostThickness: Math.round(OsdStyles.sizeFor(stage.style, false, Metrics.osdW).h * stage.k * 1.6)
            ghostSpan: 0.3
            onPicked: e => SettingsStore.transaction("prefs.undo.osd_moved", () => SettingsStore.set("layout.osd.position", OsdPlace.positionFor(e)))
        }
    }
}
