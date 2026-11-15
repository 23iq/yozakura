pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.modules.components.kit
import qs.modules.settings.store
import qs.modules.settings.live
import "../PanelsModel.js" as PanelsModel
import "../SchemaUtil.js" as SchemaUtil
import "../../notifications/NotificationPolicy.js" as Policy

// Stage of the Notifications page: a notification as the shell shows it
// now (NotificationPolicy, the shell's rules), the shell's own component
// with a sample message (live/): a corner toast (LiveToast: its art, text,
// actions, and the app's other notifications stacked behind it when
// grouped by app), the island grown with it (LiveIsland, its card or
// compact style) hanging from the stage's top edge, or strips on their
// threads (LiveStrips). With corner toasts a small screen beside it shows
// the corner, and every other corner is a target: a click moves them
// there.
Stage {
    id: stage
    objectName: "notifStage"

    readonly property var panels: PanelsModel.panelsOf({
        "position": SchemaUtil.plain(SettingsStore.get("bar.position")) || "top",
        "layout": SchemaUtil.plain(SettingsStore.get("bar.layout")) || {},
        "panels": SchemaUtil.plain(SettingsStore.get("bar.panels")) || []
    })
    readonly property var ctx: ({
            "barStyle": stage.panels.length > 0 ? stage.panels[0].style : "",
            "barPosition": stage.panels.length > 0 ? stage.panels[0].edge : "top",
            "notchPosition": SettingsStore.get("notch.position") === "bottom" ? "bottom" : "top",
            "notchEnabled": SettingsStore.get("notch.enabled") !== false
        })
    readonly property string presentation: Policy.resolvePresentation(String(SettingsStore.get("notifications.presentation") || "auto"), stage.ctx)
    readonly property string position: Policy.resolvePosition(String(SettingsStore.get("notifications.position") || "auto"), stage.ctx)
    readonly property bool corners: stage.presentation === "corner"
    readonly property bool island: stage.presentation === "notch"
    readonly property bool strips: stage.presentation === "strips"
    readonly property bool grouped: SettingsStore.get("notifications.groupByApp") === true
    readonly property bool cornerBottom: Policy.anchorsOf(stage.position).vertical === "bottom"
    readonly property var places: Policy.POSITIONS.filter(p => p !== "auto")

    // a strip as wide as the page (SettingsPage)
    readonly property bool pageWide: true
    // a narrow stage (a pane beside the cards): the small screen above the
    // toast instead of beside it
    readonly property bool narrow: stage.width > 0 && stage.width < Space.px(720)
    // (unless the page gives it less than stacking needs, a short window:
    // then side by side, the small screen as tall as the stage allows)
    readonly property real stackedHeight: Math.round(Space.px(176) * 9 / 16 + cornerName.height + stage.toastHeight + Space.xs + Space.m * 4)
    readonly property bool short: stage.height > 0 && stage.height + 1 < stage.stackedHeight
    readonly property bool stacked: stage.narrow && stage.corners && !stage.short
    // the toast's room: beside the small screen, or the whole stage
    readonly property real room: stage.corners && !stage.stacked ? stage.width - screen.x - screen.width - Space.xl * 2 : stage.width - Space.l * 2
    // its height as large as life (a narrow pane still has the room for
    // its width; never from the stage's width: the page sizes the stage
    // from its height)
    readonly property real toastHeight: toast.part.partHeight > 0 ? toast.part.partHeight : Space.px(120)
    readonly property real preferredHeight: stage.narrow && stage.corners ? stage.stackedHeight : Space.px(200)

    stageHeight: stage.preferredHeight

    // ---- the notification itself --------------------------------------------
    // a corner toast: centred in its room
    LiveToast {
        id: toast
        objectName: "notifToast"
        active: stage.corners
        visible: stage.corners
        grouped: stage.grouped
        stackUp: stage.cornerBottom
        x: stage.corners && !stage.stacked ? screen.x + screen.width + Space.xl : Space.l
        y: stage.stacked ? Math.round(cornerName.y + cornerName.height + Space.m) : Space.m
        width: stage.room
        height: stage.stacked ? stage.toastHeight : stage.height - Space.m * 2
    }
    // the island grown with it, hanging from the stage's top edge
    LiveIsland {
        id: islandToast
        objectName: "notifIsland"
        active: stage.island
        visible: stage.island
        state: "notification"
        // as large as life where it fits
        zoom: Math.min(1, (stage.width - Space.l * 2) / Math.max(560, islandToast.targetRect.width), (stage.height - Space.m) / Math.max(1, islandToast.targetRect.height + Space.m))
        overrides: ({
                "notch.position": "top",
                "notch.align": "center"
            })
        width: stage.width
        height: stage.height
    }
    // strips on their threads, from the stage's top edge
    LiveStrips {
        id: stripsToast
        objectName: "notifStrips"
        active: stage.strips
        visible: stage.strips
        grouped: stage.grouped
        x: Space.l
        width: stage.width - Space.l * 2
        height: stage.height - Space.m
    }
    // what lights for the notification rows
    Item {
        readonly property rect r: stage.corners ? Qt.rect(toast.x + toast.toastRect.x, toast.y + toast.toastRect.y, toast.toastRect.width, toast.toastRect.height) : (stage.island ? Qt.rect(islandToast.islandRect.x, islandToast.islandRect.y, islandToast.islandRect.width, islandToast.islandRect.height) : Qt.rect(stripsToast.x + stripsToast.stripsRect.x, stripsToast.y + stripsToast.stripsRect.y, stripsToast.stripsRect.width, stripsToast.stripsRect.height))
        objectName: "notifShown"
        x: r.x
        y: r.y
        width: r.width
        height: r.height
        StageSpot {
            keys: ["notifications"]
            cornerRadius: Look.radius("box", Space.px(80))
        }
    }

    // ---- with corner toasts: the corner, on a small screen ------------------
    Mark {
        id: screen
        objectName: "notifScreen"
        visible: stage.corners
        y: stage.stacked ? Space.m : Math.round((parent.height - height - cornerName.height - Space.xs) / 2)
        x: stage.stacked ? Math.round((parent.width - width) / 2) : Space.xl
        width: Math.round(Math.max(Space.px(80), Math.min(Space.px(176), (stage.height - cornerName.height - Space.xs - Space.m * 2) * 16 / 9)))
        height: Math.round(width * 9 / 16)
        radius: Look.radius("box", height)
        color: Look.raisedFill(false)
        border.width: Space.hairline
        border.color: Type.hairline

        Repeater {
            model: stage.corners ? stage.places : []
            delegate: Mark {
                id: place
                required property string modelData
                readonly property var a: Policy.anchorsOf(modelData)
                readonly property bool current: modelData === stage.position
                objectName: "notifPlace:" + modelData
                width: Space.px(40)
                height: Space.px(14)
                radius: Look.radius("small", height)
                x: a.horizontal === "left" ? Space.s : (a.horizontal === "right" ? screen.width - width - Space.s : (screen.width - width) / 2)
                y: a.vertical === "top" ? Space.s : screen.height - height - Space.s
                color: place.current ? Type.accent : (placeArea.containsMouse ? Qt.alpha(Type.accent, 0.4) : Qt.alpha(Type.text, 0.16))
                MouseArea {
                    id: placeArea
                    objectName: "notifPlaceArea:" + place.modelData
                    anchors.fill: parent
                    anchors.margins: -Space.xs
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    Accessible.role: Accessible.RadioButton
                    Accessible.name: I18n.t("prefs.notif.position." + place.modelData)
                    Accessible.checked: place.current
                    onClicked: SettingsStore.transaction("prefs.undo.notif_moved", () => SettingsStore.set("notifications.position", place.modelData))
                }
            }
        }
    }
    KitText {
        id: cornerName
        visible: stage.corners
        anchors.top: screen.bottom
        anchors.topMargin: Space.xs
        anchors.horizontalCenter: screen.horizontalCenter
        role: "caption"
        text: I18n.t("prefs.notif.position." + stage.position)
    }
}
