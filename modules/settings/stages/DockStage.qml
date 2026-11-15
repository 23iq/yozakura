pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.modules.components.kit
import qs.modules.settings.store
import qs.modules.settings
import qs.modules.settings.live

// Stage of the dock tab: the dock itself, a strip at a readable scale (a
// little over its real size). It is the shell's own dock (live/LiveDock:
// your pinned and running apps, their real running indicators, the pin
// and overview buttons, its height, icon size, spacing and style), so
// what the rows change is what the dock does. Not a desktop: where it sits
// is the Edge row's job. A click on it scrolls to the dock's size card.
Stage {
    id: stage
    objectName: "dockStage"

    readonly property bool dockOn: SettingsStore.get("dock.enabled") !== false
    // off: a ghost of the dock as it would be, outlined, with its switch
    // (the canvas shows this loupe then, instead of a bare note)
    readonly property bool ghost: !stage.dockOn
    readonly property string theme: String(SettingsStore.get("dock.theme") || "default")
    readonly property real zoom: 1.2
    readonly property real dockHeight: Math.max(Number(SettingsStore.get("dock.height") || 48), Number(SettingsStore.get("dock.iconSize") || 24) + 12)
    // a strip as wide as the page (SettingsPage)
    readonly property bool pageWide: true
    readonly property real preferredHeight: Math.round((stage.dockHeight + dock.margin * 2) * stage.zoom + Space.xl * 2)

    stageHeight: stage.preferredHeight

    LiveDock {
        id: dock
        objectName: "dockShape"
        anchors.fill: parent
        anchors.margins: Space.l
        visible: stage.theme !== "integrated"
        active: stage.theme !== "integrated"
        maxZoom: stage.zoom
        // off: only its place is drawn (the outline below)
        opacity: stage.ghost ? 0 : 1
    }

    // the dock's own part of the stage: its spot, and a click to its card
    Item {
        id: surface
        visible: dock.visible && dock.part.ready
        x: dock.x + dock.surfaceRect.x + dock.margin * dock.part.shownScale
        y: dock.y + dock.surfaceRect.y + dock.margin * dock.part.shownScale
        width: Math.max(0, dock.surfaceRect.width - dock.margin * 2 * dock.part.shownScale)
        height: Math.max(0, dock.surfaceRect.height - dock.margin * 2 * dock.part.shownScale)

        StageSpot {
            keys: ["dock"]
        }
        MouseArea {
            objectName: "dockPart"
            anchors.fill: parent
            enabled: !stage.ghost
            cursorShape: Qt.PointingHandCursor
            onClicked: SettingsStore.navigate("dock", "size", "")
        }
    }

    // the ghost's outline: where the dock would be
    DashedFrame {
        objectName: "dockGhost"
        visible: stage.ghost && dock.visible
        x: Math.round(surface.x + surface.width / 2 - width / 2)
        y: surface.y - Space.s
        width: Math.max(surface.width + Space.s * 2, offRow.implicitWidth + Space.xl * 2)
        height: surface.height + Space.s * 2
        radius: Look.radius("box", height)
        color: Type.muted
    }

    // off: say so over the ghost, with the switch that brings it back
    Row {
        id: offRow
        objectName: "dockOff"
        visible: stage.ghost
        anchors.centerIn: dock.visible ? surface : parent
        spacing: Space.m
        KitText {
            anchors.verticalCenter: parent.verticalCenter
            role: "body"
            text: I18n.t("prefs.dock.off_stage")
        }
        PillButton {
            objectName: "dockTurnOn"
            anchors.verticalCenter: parent.verticalCenter
            kind: "tonal"
            text: I18n.t("prefs.disabled.turn_on")
            onClicked: SettingsStore.set("dock.enabled", true)
        }
    }

    KitText {
        visible: stage.dockOn && stage.theme === "integrated"
        anchors.centerIn: parent
        role: "secondary"
        text: I18n.t("prefs.dock.in_bar_stage")
    }
}
