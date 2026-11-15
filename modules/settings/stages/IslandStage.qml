pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store
import qs.modules.settings
import qs.modules.settings.live
import "../live/LiveSamples.js" as LiveSamples

// Stage of the Island page: the island itself, the shell's own (live/
// LiveIsland: the real Notch and resting view), big, hanging from the
// stage's edge as from the screen's (its edge: notch.position; on a side
// edge it stands upright), showing one of its states with sample content,
// picked with the chips beside or under it: at rest (user@host, the
// compositor or your text), a song (with the visualizer), a notification,
// a running timer. Every look follows the config (shape, theme, fonts,
// activities, the media and notification styles); a state change is the
// island's own morph. Where it sits on the screen is the canvas' job. A
// click on the island scrolls to the card of what it shows and flashes it;
// rows light up their part. It stands in its card wherever it is (the loupe
// under the Screen canvas too): the island in the middle of the card's
// edge, its chips beside or under it.
Stage {
    id: stage
    objectName: "islandStage"

    readonly property bool islandOn: SettingsStore.get("notch.enabled") !== false
    readonly property string position: String(SettingsStore.get("notch.position") || "top")
    readonly property bool atBottom: stage.position === "bottom"
    // on a side edge the island stands upright
    readonly property bool side: stage.position === "left" || stage.position === "right"
    // the state shown: "rest" | "media" | "notification" | "timer"
    property string showing: "rest"
    readonly property var stateList: LiveSamples.STATES

    // a strip as wide as the page (SettingsPage)
    readonly property bool pageWide: true
    // a narrow stage (the loupe of the Screen canvas): the state chips go
    // under the island instead of beside it
    readonly property bool narrow: stage.width > 0 && stage.width < Space.px(720)
    // the room along the edge the island gets (the chips beside it take
    // theirs on a wide stage; an upright island: as tall as it is, no
    // empty card around a small one)
    readonly property real lane: stage.side ? Math.max(Space.px(160), live.targetRect.height * stage.zoom + Space.l * 2) : (stage.narrow ? stage.width : stage.width - chips.width - Space.xl * 2)
    // native px -> stage px: the island a little larger than life, a wide
    // state (a notification) still fitting the lane
    readonly property real zoom: Math.max(0.4, Math.min(1.25, stage.side ? (Space.px(320) - Space.l * 2) / Math.max(live.targetRect.height, 200) : (stage.lane - Space.l * 2) / Math.max(1, Math.max(live.targetRect.width, 560))))
    // how far the island reaches from its edge (its target: a state
    // change sizes the stage once, the island morphs into it)
    readonly property real reach: {
        const t = live.targetRect;
        if (t.width <= 0)
            return Space.px(48);
        switch (stage.position) {
        case "bottom":
            return (LiveTarget.height - t.y) * stage.zoom;
        case "left":
            return (t.x + t.width) * stage.zoom;
        case "right":
            return (LiveTarget.width - t.x) * stage.zoom;
        default:
            return (t.y + t.height) * stage.zoom;
        }
    }
    property real reachShown: stage.reach
    Behavior on reachShown {
        enabled: Motion.morph.duration > 0
        NumberAnimation {
            duration: Motion.morph.duration
            easing.type: Motion.morph.easing
        }
    }
    // the island's room (the reach and a margin past it)
    readonly property real depth: Math.round(stage.reachShown + Space.m)
    readonly property real preferredHeight: Math.round(stage.side ? stage.lane : (stage.narrow ? stage.depth + Space.m + chips.implicitHeight : Math.max(stage.depth + Space.m, chips.implicitHeight + Space.m * 2)))

    stageHeight: stage.preferredHeight
    calm: true

    LiveIsland {
        id: live
        objectName: "islandLive"
        visible: stage.islandOn
        active: stage.islandOn
        state: stage.showing
        zoom: stage.zoom
        // against its edge: a band along it, or a column on a side edge
        x: stage.position === "right" ? stage.width - width : 0
        y: stage.atBottom ? stage.height - height : 0
        width: stage.side ? stage.depth : stage.lane
        height: stage.side ? stage.height : stage.depth
    }

    // the island's place: its spot and a click to its card
    Item {
        id: part
        objectName: "islandPart"
        visible: stage.islandOn
        x: live.x + live.islandRect.x
        y: live.y + live.islandRect.y
        width: live.islandRect.width
        height: live.islandRect.height

        StageSpot {
            keys: ["notch"]
            cornerRadius: Math.min(part.width, part.height) / 2
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            Accessible.role: Accessible.Button
            Accessible.name: I18n.t("prefs.notch.state." + stage.showing)
            onClicked: {
                const st = stage.stateList.find(s => s.id === stage.showing);
                SettingsStore.navigate("notch", st ? st.section : "notch", "");
            }
        }
    }

    KitText {
        visible: !stage.islandOn
        anchors.centerIn: parent
        role: "secondary"
        text: I18n.t("prefs.notch.off_stage")
    }

    // the state shown
    Segmented {
        id: chips
        objectName: "islandStates"
        // beside the island, on the right; under it on a narrow stage
        // (a side edge: centred in the room the upright island leaves)
        x: stage.side ? (stage.position === "left" ? live.width + Math.round((parent.width - live.width - width) / 2) : Math.round((parent.width - live.width - width) / 2)) : (stage.narrow ? Math.round((parent.width - width) / 2) : parent.width - width - Space.xl)
        y: stage.side ? Math.round((parent.height - height) / 2) : (stage.narrow ? (stage.atBottom ? 0 : stage.depth + Space.xs) : Math.round((parent.height - height) / 2))
        visible: stage.islandOn
        model: stage.stateList.map(s => ({
                    "name": "islandState:" + s.id,
                    "icon": "",
                    "text": I18n.t(s.label)
                }))
        currentIndex: stage.stateList.findIndex(s => s.id === stage.showing)
        onActivated: i => stage.showing = stage.stateList[i].id
    }
}
