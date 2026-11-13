pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.modules.components.kit
import qs.modules.settings.store
import "OsdPlace.js" as OsdPlace
import "../Ui.js" as Ui
import "../../shell/osd/OsdStyles.js" as OsdStyles

// Stage of Menus & OSD: the things themselves on a plain ground. The real
// on-screen display (its style component, by URL) at its real size, showing
// the volume; beside it a small screen with the edge it shows on (the
// shell's rules, OsdPlace.js), every other edge a target: a click puts it
// there (layout.osd.position). On the right a bar menu as the popup style
// draws it, with its tail toward the bar when that is on.
Stage {
    id: stage
    objectName: "osdStage"

    readonly property string style: OsdStyles.normalize(SettingsStore.get("layout.osd.style"))
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

    // a strip as wide as the page (SettingsPage)
    readonly property bool pageWide: true
    // a narrow stage (a pane beside the cards): the small screen and the OSD
    // on one line, the menu under them
    readonly property bool narrow: stage.width > 0 && stage.width < Space.px(720)
    readonly property real topRow: Math.max(screen.visible ? screen.height : 0, osd.height)
    readonly property real preferredHeight: stage.narrow ? Math.round(Space.m * 3 + stage.topRow + menu.height) : Space.px(188)

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
        visible: stage.style !== "bar-inline"

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
        y: stage.narrow ? Math.round(Space.m + (stage.topRow - height) / 2) : Math.round((parent.height - height) / 2)
        x: screen.visible ? screen.x + screen.width + (stage.narrow ? Space.l : Space.xl * 2) : (stage.narrow ? Math.round((stage.width - width) / 2) : Space.xl)
        width: real.width * real.scale
        height: real.height * real.scale
        Loader {
            id: real
            anchors.centerIn: parent
            width: stage.size.w
            height: stage.size.h
            // the real size, or as large as the band allows
            // (the room beside the small screen, not osd.x: that follows the width)
            scale: stage.narrow ? Math.min(1, Space.px(120) / Math.max(1, stage.size.h), (stage.width - (screen.visible ? screen.x + screen.width + Space.l : 0) - Space.l) / Math.max(1, stage.size.w)) : Math.min(1, (stage.height - Space.m * 2) / Math.max(1, stage.size.h))
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

    // ---- a bar menu in the popup style ---------------------------------------
    Item {
        id: menu
        objectName: "menuOnStage"
        x: stage.narrow ? Math.round((parent.width - width) / 2) : parent.width - width - Space.xl
        y: stage.narrow ? Math.round(Space.m * 2 + stage.topRow) : Math.round((parent.height - height) / 2)
        width: Space.px(220)
        height: anchorChip.height + Space.s + popup.height

        // the bar item it opens from
        Chip {
            id: anchorChip
            anchors.horizontalCenter: parent.horizontalCenter
            dense: true
            icon: Icons.wifiHigh ?? ""
            text: "Sakura 5G"
            active: true
        }
        // its tail, toward the item
        Mark {
            visible: stage.tail
            width: Space.px(14)
            height: width
            rotation: 45
            radius: 0
            anchors.horizontalCenter: parent.horizontalCenter
            y: popup.y - height / 2 + Space.hairline
            color: Colors.surfaceContainer
        }
        StyledRect {
            id: popup
            y: anchorChip.height + Space.s
            width: parent.width
            height: rows.implicitHeight + Space.s * 2
            variant: "popup"
            enableShadow: true
            radius: Look.radius("box", height)
            Column {
                id: rows
                x: Space.s
                y: Space.s
                width: popup.width - Space.s * 2
                Repeater {
                    model: [["wifiHigh", "Sakura 5G", true], ["wifiMedium", "Neighbour", false], ["gear", "Network settings", false]]
                    delegate: Mark {
                        id: rowMark
                        required property var modelData
                        width: rows.width
                        height: Space.px(30)
                        radius: Look.radius("small", height)
                        color: rowMark.modelData[2] ? Qt.alpha(Type.accent, 0.16) : "transparent"
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            x: Space.s
                            spacing: Space.s
                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                icon: Icons[rowMark.modelData[0]] ?? ""
                                role: "secondary"
                                tone: rowMark.modelData[2] ? "accent" : "secondary"
                            }
                            KitText {
                                anchors.verticalCenter: parent.verticalCenter
                                role: "secondary"
                                color: Type.text
                                text: rowMark.modelData[1]
                            }
                        }
                    }
                }
            }
            StageSpot {
                keys: ["theme.popup", "layout.powermenu", "layout.tools"]
                cornerRadius: popup.radius
            }
        }
    }
}
