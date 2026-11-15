pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.modules.components.kit
import qs.modules.components.preview
import qs.modules.settings.store
import qs.modules.settings.live
import "OsdPlace.js" as OsdPlace
import "../live/LivePatch.js" as LivePatch
import "../live/LiveSamples.js" as LiveSamples
import "../../shell/osd/OsdStyles.js" as OsdStyles

// Stage of Menus & OSD: the things themselves on a plain ground. The real
// on-screen display (its style component, by URL: live/LivePart) at its
// real size, showing the volume, or your bar's controls button holding the
// level ("in the bar": live/LivePanel); beside it a small screen with the
// edge it shows on (the shell's rules, OsdPlace.js), every other edge a
// target: a click puts it there (layout.osd.position). On the right a bar
// menu: the shell's popup surface (PopupSurface: the popup style, its
// entry motion, replayed when it changes, and its tail toward the bar)
// holding the shell's menu rows (bar/modules/MenuRow.qml, by URL).
Stage {
    id: stage
    objectName: "osdStage"

    readonly property string style: OsdStyles.normalize(SettingsStore.get("layout.osd.style"))
    readonly property bool inline: stage.style === "bar-inline"
    readonly property string pref: String(SettingsStore.get("layout.osd.position") || "auto")
    readonly property string edge: OsdPlace.edge(stage.style, stage.pref, {
        "notchPosition": SettingsStore.get("notch.position") === "bottom" ? "bottom" : "top",
        "notchEnabled": SettingsStore.get("notch.enabled") !== false,
        "barEdge": String(SettingsStore.get("bar.position") || "top"),
        "occupied": [String(SettingsStore.get("bar.position") || "top")]
    })
    readonly property bool vertical: stage.edge === "left" || stage.edge === "right"
    readonly property var size: OsdStyles.sizeFor(stage.style, stage.vertical, Metrics.osdW)
    readonly property bool tail: SettingsStore.get("theme.popup.tail") === true
    // the menu replays its entry when the popup animation changes
    readonly property string entry: String(SettingsStore.get("theme.popup.entry") || "")

    // a strip as wide as the page (SettingsPage)
    readonly property bool pageWide: true
    // a narrow stage (a pane beside the cards): the small screen and the OSD
    // on one line, the menu under them
    readonly property bool narrow: stage.width > 0 && stage.width < Space.px(720)
    readonly property real topRow: Math.max(screen.visible ? screen.height : 0, osd.height)
    readonly property real preferredHeight: stage.narrow ? Math.round(Space.m * 3 + stage.topRow + menu.height) : Space.px(188)
    // the OSD's room: beside the small screen, before the menu
    readonly property real osdRoom: stage.narrow ? stage.width - (screen.visible ? screen.x + screen.width + Space.l : 0) - Space.l : stage.width - (screen.visible ? screen.x + screen.width + Space.xl * 2 : Space.xl) - menu.width - Space.xl * 2

    stageHeight: stage.preferredHeight

    // ---- where it shows: a small screen, its edges targets ------------------
    Mark {
        id: screen
        objectName: "osdScreen"
        y: stage.narrow ? Math.round(Space.m + (stage.topRow - height) / 2) : Math.round((parent.height - height) / 2)
        x: stage.narrow ? Space.l : Space.xl
        width: Space.px(176)
        height: Math.round(width * 9 / 16)
        radius: Look.radius("box", height)
        color: Look.raisedFill(false)
        border.width: Space.hairline
        border.color: Type.hairline
        visible: !stage.inline

        Repeater {
            model: ["top", "bottom", "left", "right"]
            delegate: Mark {
                id: edgeMark
                required property string modelData
                readonly property bool side: modelData === "left" || modelData === "right"
                readonly property bool current: modelData === stage.edge
                objectName: "osdEdge:" + modelData
                width: side ? Space.px(8) : Space.px(56)
                height: side ? Space.px(40) : Space.px(8)
                x: modelData === "left" ? Space.s : (modelData === "right" ? screen.width - width - Space.s : (screen.width - width) / 2)
                y: modelData === "top" ? Space.s : (modelData === "bottom" ? screen.height - height - Space.s : (screen.height - height) / 2)
                color: edgeMark.current ? Type.accent : (edgeArea.containsMouse ? Qt.alpha(Type.accent, 0.4) : Qt.alpha(Type.text, 0.16))
                MouseArea {
                    id: edgeArea
                    anchors.fill: parent
                    anchors.margins: -Space.s
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    Accessible.role: Accessible.RadioButton
                    Accessible.name: I18n.t("common." + edgeMark.modelData)
                    Accessible.checked: edgeMark.current
                    onClicked: SettingsStore.transaction("prefs.undo.osd_moved", () => SettingsStore.set("layout.osd.position", OsdPlace.positionFor(edgeMark.modelData)))
                }
            }
        }
    }

    // ---- the OSD itself, at its real size -----------------------------------
    Item {
        id: osd
        objectName: "osdOnStage"
        // the real size, or as large as its room allows
        readonly property real k: Math.max(0.1, Math.min(1, stage.osdRoom / Math.max(1, stage.size.w), (stage.narrow ? Space.px(120) : stage.height - Space.m * 2) / Math.max(1, stage.size.h)))
        x: screen.visible ? screen.x + screen.width + (stage.narrow ? Space.l : Space.xl * 2) : (stage.narrow ? Math.round((stage.width - width) / 2) : Space.xl)
        y: stage.narrow ? Math.round(Space.m + (stage.topRow - height) / 2) : Math.round((parent.height - height) / 2)
        width: stage.inline ? Math.min(stage.osdRoom, Space.px(300)) : Math.round(stage.size.w * osd.k)
        height: stage.inline ? Space.px(64) : Math.round(stage.size.h * osd.k)

        LivePart {
            anchors.fill: parent
            active: !stage.inline
            visible: active
            source: Qt.resolvedUrl("../../shell/osd/" + OsdStyles.fileFor(stage.style))
            nativeWidth: stage.size.w
            nativeHeight: stage.size.h
            properties: Object.assign(LiveSamples.osd(), {
                "vertical": stage.vertical
            })
            // built again for the other orientation
            refreshKey: stage.vertical
        }
        // in the bar: your bar's controls button holding the level
        LivePanel {
            anchors.fill: parent
            active: stage.inline
            visible: active
            nativeWidth: 640
            frame: "modules"
            patch: LivePatch.only(["controls"])
            samples: ({
                    "osd": LiveSamples.osd()
                })
        }
        StageSpot {
            keys: ["layout.osd"]
            cornerRadius: Look.radius("chip", osd.height)
        }
    }

    // ---- a bar menu in the popup style ---------------------------------------
    Item {
        id: menu
        objectName: "menuOnStage"
        x: stage.narrow ? Math.round((parent.width - width) / 2) : parent.width - width - Space.xl
        y: stage.narrow ? Math.round(Space.m * 2 + stage.topRow) : Math.round((parent.height - height) / 2)
        width: Space.px(220)
        height: anchorChip.height + gap + rows.implicitHeight + Metrics.spacing * 2
        // as BarPopup leaves it between the bar and the popup
        readonly property real gap: Space.s + (stage.tail ? Metrics.spacing : 0)

        // the bar item it opens from
        Chip {
            id: anchorChip
            anchors.horizontalCenter: parent.horizontalCenter
            dense: true
            icon: Icons.power
            text: I18n.t("prefs.menus.powermenu_style")
            active: true
        }
        PopupSurface {
            id: surface
            y: anchorChip.height + menu.gap
            width: parent.width
            height: rows.implicitHeight + Metrics.spacing * 2
            dir: "down"
            tail: stage.tail
            tailSize: Metrics.spacing
            padding: Metrics.spacing
            Column {
                id: rows
                width: parent.width
                Repeater {
                    model: [["moon", "powermenu.suspend"], ["arrowsClockwise", "powermenu.reboot"], ["power", "powermenu.power_off"]]
                    delegate: Loader {
                        id: row
                        required property var modelData
                        width: rows.width
                        Component.onCompleted: row.setSource(Qt.resolvedUrl("../../bar/modules/MenuRow.qml"), {
                            "icon": row.modelData[0],
                            "label": I18n.t(row.modelData[1]),
                            "danger": row.modelData[0] === "power"
                        })
                    }
                }
            }
        }
        StageSpot {
            keys: ["theme.popup", "layout.powermenu", "layout.tools"]
            cornerRadius: Styling.radius(0)
        }
    }
    // the menu opens with the page, and again for another popup animation
    Component.onCompleted: surface.shown = true
    onEntryChanged: {
        surface.shown = false;
        replay.restart();
    }
    Timer {
        id: replay
        interval: Math.max(1, Motion.exit.duration)
        onTriggered: surface.shown = true
    }
}
