pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.modules.components.kit
import qs.modules.settings.store
import qs.modules.settings

// Stage of the Island page: the island itself, big, as configured: its
// shape (attached to the edge, floating, a small pill), its place along the
// edge, on the bar's surface; showing one of its states, picked with the
// chips under it (at rest: user@host, the compositor or your text; a song
// in the row or artwork look, with the visualizer; a notification; a
// running timer as the Timers page draws it). Not a desktop: where it sits
// is the Edge row's job. A click on the island scrolls to the card of what
// it shows and flashes it; rows light up their part.
Stage {
    id: stage
    objectName: "islandStage"

    readonly property bool islandOn: SettingsStore.get("notch.enabled") !== false
    readonly property string shape: String(SettingsStore.get("notch.style") || "attached")
    readonly property string align: String(SettingsStore.get("notch.align") || "center")
    readonly property string rest: String(SettingsStore.get("notch.noMediaDisplay") || "userHost")
    readonly property string custom: String(SettingsStore.get("notch.customText") || "")
    readonly property string mediaStyle: String(SettingsStore.get("notch.mediaStyle") || "row")
    readonly property bool visualizer: SettingsStore.get("notch.visualizer") !== false
    readonly property string timerStyle: String(SettingsStore.get("system.timers.notchStyle") || "ring")
    readonly property string position: String(SettingsStore.get("notch.position") || "top")
    readonly property bool atBottom: stage.position === "bottom"
    // on a side edge the island stands upright (the picture turns)
    readonly property bool side: stage.position === "left" || stage.position === "right"
    // the length of the edge drawn (a side edge: the stage's height)
    readonly property real lane: stage.side ? Math.round(stage.u * 4 + Space.l * 2) : stage.width
    // the state shown: "rest" | "media" | "notification" | "timer"
    property string showing: "rest"
    readonly property var stateList: [
        {
            "id": "rest",
            "label": "prefs.notch.state.rest",
            "section": "idle"
        },
        {
            "id": "media",
            "label": "prefs.notch.state.media",
            "section": "media"
        },
        {
            "id": "notification",
            "label": "prefs.notch.state.notification",
            "section": "activities"
        },
        {
            "id": "timer",
            "label": "prefs.notch.state.timer",
            "section": "activities"
        }
    ]

    // the island's height at this stage's scale (a real one is ~36 px)
    readonly property real u: Math.round(Space.px(56) * (stage.shape === "pill" ? 0.86 : 1))
    // a strip as wide as the page (SettingsPage)
    readonly property bool pageWide: true
    // a narrow stage (the loupe of the Screen canvas): the state chips go
    // under the island instead of beside it
    readonly property bool narrow: stage.width > 0 && stage.width < Space.px(720)
    // as tall as the island and its room (and the chips under it), no more
    // (narrow: the island, then the chips right under it, nothing more)
    readonly property real preferredHeight: Math.round(stage.side ? stage.lane + Space.m * 2 : (stage.narrow ? stage.u + Space.m * 2 + chips.implicitHeight : stage.u * 1.6 + Space.m * 2))

    stageHeight: stage.preferredHeight
    calm: true
    // the loupe under the Screen canvas is no second card: the island and
    // its state chips stand on the page under the canvas
    backdrop: !stage.narrow
    framed: !stage.narrow

    // the bar's surface along the edge, faint: the island sits on it
    // The bar's edge and the island hanging from it, drawn along the top
    // (or bottom) edge; on a side edge (notch.position left / right) the
    // same picture stands upright on that side, as the island does there.
    Item {
        id: edge
        width: stage.lane
        height: Math.round(stage.u * 1.6 + Space.m)
        transformOrigin: Item.TopLeft
        rotation: stage.position === "right" ? 90 : (stage.position === "left" ? -90 : 0)
        x: stage.position === "right" ? stage.width : 0
        y: stage.position === "left" ? Space.m + stage.lane : (stage.side ? Space.m : (stage.atBottom ? stage.height - height : 0))

        StyledRect {
            id: band
            x: 0
            width: edge.width
            height: Math.round(stage.u * 0.9)
            y: stage.atBottom ? edge.height - height : 0
            variant: "barbg"
            enableShadow: false
            radius: Look.radius("small", height)
            opacity: 0.55
        }

        StyledRect {
            id: island
            objectName: "islandShape"
            visible: stage.islandOn
            readonly property real r: stage.shape === "pill" ? height / 2 : Math.round(stage.u * 0.45)
            readonly property bool attached: stage.shape === "attached"
            height: stage.u + (attached ? r : 0)
            y: island.attached ? (stage.atBottom ? band.y + band.height - height + r : band.y - r) : (stage.atBottom ? band.y + band.height - height - Space.s : band.y + Space.s)
            variant: "bg"
            enableShadow: true
            radius: r
            // a new state or alignment glides; a resize of the stage lands
            // at once (never rubber-bands)
            readonly property real wantW: Math.round(Math.max(content.implicitWidth + stage.u * 1.2, stage.u * (stage.side ? 3.5 : 5)))
            // centred in the room the chips leave (or at its start / end)
            readonly property real room: stage.side || stage.narrow ? edge.width - Space.xl * 2 : edge.width - chips.width - Space.xl * 3
            RectGlide {
                target: island
                frame: edge
                rect: ({
                        "x": stage.align === "start" ? Space.xl : (stage.align === "end" ? island.room - island.wantW + Space.xl : (island.room - island.wantW) / 2 + Space.xl),
                        "w": island.wantW
                    })
            }

            Row {
                id: content
                anchors.horizontalCenter: parent.horizontalCenter
                y: (island.attached && !stage.atBottom ? island.r : 0) + (stage.u - height) / 2
                height: Math.round(stage.u * 0.6)
                spacing: Space.m

                // at rest
                KitText {
                    visible: stage.showing === "rest"
                    anchors.verticalCenter: parent.verticalCenter
                    role: "body"
                    font.weight: Font.DemiBold
                    text: stage.rest === "custom" ? (stage.custom || "Yozakura") : (stage.rest === "compositor" ? "Hyprland" : "you@sakura")
                }
                // a song
                Mark {
                    visible: stage.showing === "media"
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(stage.u * (stage.mediaStyle === "artwork" ? 0.72 : 0.56))
                    height: width
                    radius: Look.radius("small", height)
                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: Colors.primary
                        }
                        GradientStop {
                            position: 1
                            color: Colors.tertiary
                        }
                    }
                }
                Column {
                    visible: stage.showing === "media"
                    anchors.verticalCenter: parent.verticalCenter
                    KitText {
                        role: "secondary"
                        color: Type.text
                        font.weight: Font.DemiBold
                        text: "Hanami Night"
                    }
                    KitText {
                        visible: stage.mediaStyle === "artwork"
                        role: "caption"
                        text: "Sakura Trio"
                    }
                }
                Row {
                    visible: stage.showing === "media" && stage.visualizer
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Space.hairline * 2
                    Repeater {
                        model: [0.4, 0.8, 0.55, 1, 0.6]
                        delegate: Mark {
                            required property real modelData
                            anchors.verticalCenter: parent.verticalCenter
                            width: Space.xs
                            height: Math.round(stage.u * 0.45 * modelData)
                            color: Type.accent
                        }
                    }
                }
                // a notification
                Mark {
                    visible: stage.showing === "notification"
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(stage.u * 0.56)
                    height: width
                    color: Qt.alpha(Type.accent, 0.3)
                    Icon {
                        anchors.centerIn: parent
                        icon: Icons.bell
                        role: "secondary"
                        tone: "accent"
                    }
                }
                KitText {
                    visible: stage.showing === "notification"
                    anchors.verticalCenter: parent.verticalCenter
                    role: "secondary"
                    color: Type.text
                    text: "Yuki · Dinner at eight?"
                }
                // a timer
                Ring {
                    visible: stage.showing === "timer" && stage.timerStyle !== "text"
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(stage.u * 0.5)
                    height: width
                    thickness: Space.xs
                    value: 0.65
                }
                KitText {
                    visible: stage.showing === "timer"
                    anchors.verticalCenter: parent.verticalCenter
                    role: "body"
                    font.weight: Font.DemiBold
                    tabular: true
                    text: "16:20"
                }
            }

            StageSpot {
                keys: ["notch"]
                cornerRadius: island.radius
            }
            MouseArea {
                objectName: "islandPart"
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    const st = stage.stateList.find(s => s.id === stage.showing);
                    SettingsStore.navigate("notch", st ? st.section : "notch", "");
                }
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
        x: stage.side ? (stage.position === "left" ? edge.height + Math.round((parent.width - edge.height - width) / 2) : Math.round((parent.width - edge.height - width) / 2)) : (stage.narrow ? Math.round((parent.width - width) / 2) : parent.width - width - Space.xl)
        y: stage.side ? Math.round((parent.height - height) / 2) : (stage.narrow ? (stage.atBottom ? 0 : island.y + island.height + Space.m) : Math.round((parent.height - height) / 2))
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
