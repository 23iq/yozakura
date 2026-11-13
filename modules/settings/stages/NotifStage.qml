pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.modules.components.kit
import qs.modules.settings.store
import "../PanelsModel.js" as PanelsModel
import "../SchemaUtil.js" as SchemaUtil
import "../../notifications/NotificationPolicy.js" as Policy

// Stage of the Notifications page: a notification itself, at its real
// size, as it shows now (NotificationPolicy, the shell's rules): a toast
// with its app icon, title, body, time and actions, stacked behind two
// more from the same app when "group by app" is on; grown from the island
// (card or compact) when the island shows them; a strip on its thread for
// the strips style. With corner toasts a small screen beside it shows the
// corner, and every other corner is a target: a click moves them there.
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
    readonly property bool grouped: SettingsStore.get("notifications.groupByApp") === true
    readonly property bool compactIsland: SettingsStore.get("notifications.notchStyle") === "compact"
    readonly property var places: Policy.POSITIONS.filter(p => p !== "auto")

    // a strip as wide as the page (SettingsPage)
    readonly property bool pageWide: true
    readonly property real preferredHeight: Space.px(176)

    stageHeight: stage.preferredHeight

    // ---- the notification itself --------------------------------------------
    Item {
        id: shown
        objectName: "notifShown"
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: stage.corners ? Space.px(90) : 0
        width: toast.width
        height: toast.height

        // the same app's other notifications, stacked behind
        Repeater {
            model: stage.grouped && stage.presentation !== "notch" ? 2 : 0
            delegate: StyledRect {
                required property int index
                x: Space.s * (index + 1)
                y: Space.s * (index + 1)
                z: -1 - index
                width: toast.width - Space.s * 2 * (index + 1)
                height: toast.height
                variant: "popup"
                enableShadow: false
                opacity: 0.6 - index * 0.2
                radius: toast.radius
            }
        }

        StyledRect {
            id: toast
            objectName: "notifToast"
            readonly property bool island: stage.presentation === "notch"
            readonly property bool strip: stage.presentation === "strips"
            width: toast.island && stage.compactIsland ? Space.px(300) : (toast.strip ? Space.px(120) : Space.px(380))
            height: toast.strip ? stage.height - Space.m * 2 : (toast.island && stage.compactIsland ? Space.px(44) : body.implicitHeight + Space.m * 2)
            variant: toast.island ? "bg" : "popup"
            enableShadow: true
            radius: toast.island ? (stage.compactIsland ? height / 2 : Look.radius("surface", height)) : Look.radius("box", height)

            // compact island: icon, title, a line
            Row {
                visible: toast.island && stage.compactIsland
                anchors.centerIn: parent
                spacing: Space.s
                AppIcon {}
                KitText {
                    anchors.verticalCenter: parent.verticalCenter
                    role: "secondary"
                    color: Type.text
                    font.weight: Font.DemiBold
                    text: "Yuki · Dinner at eight?"
                }
            }

            // a strip: vertical text on its thread
            Column {
                visible: toast.strip
                anchors.centerIn: parent
                spacing: Space.s
                AppIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                KitText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    role: "secondary"
                    color: Type.text
                    font.weight: Font.DemiBold
                    text: "Yuki"
                }
                KitText {
                    width: toast.width - Space.m * 2
                    horizontalAlignment: Text.AlignHCenter
                    role: "caption"
                    wrapMode: Text.WordWrap
                    text: "Dinner at eight?"
                }
            }

            // the card: icon, app and time, title, body, actions
            Column {
                id: body
                visible: !toast.strip && !(toast.island && stage.compactIsland)
                x: Space.m
                y: Space.m
                width: toast.width - Space.m * 2
                spacing: Space.xs
                Row {
                    spacing: Space.s
                    AppIcon {}
                    KitText {
                        anchors.verticalCenter: parent.verticalCenter
                        role: "caption"
                        text: "Messages · now"
                    }
                }
                KitText {
                    role: "body"
                    font.weight: Font.DemiBold
                    text: "Yuki"
                }
                KitText {
                    width: parent.width
                    role: "secondary"
                    wrapMode: Text.WordWrap
                    text: "Dinner at eight? I booked the place by the river."
                }
                Row {
                    spacing: Space.s
                    topPadding: Space.xs
                    Chip {
                        dense: true
                        text: "Reply"
                    }
                    Chip {
                        dense: true
                        quiet: true
                        text: "Mark as read"
                    }
                }
            }
            // grouped: how many from the app
            Chip {
                visible: stage.grouped && !toast.strip && !(toast.island && stage.compactIsland)
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Space.s
                dense: true
                text: "3"
            }
            StageSpot {
                keys: ["notifications"]
                cornerRadius: toast.radius
            }
        }
    }

    // ---- with corner toasts: the corner, on a small screen ------------------
    Mark {
        id: screen
        objectName: "notifScreen"
        visible: stage.corners
        anchors.verticalCenter: parent.verticalCenter
        x: Space.xl
        width: Space.px(176)
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
                    onClicked: SettingsStore.transaction("prefs.undo.notif_moved", () => SettingsStore.set("notifications.position", place.modelData))
                }
            }
        }
    }
    KitText {
        visible: stage.corners
        anchors.top: screen.bottom
        anchors.topMargin: Space.xs
        anchors.horizontalCenter: screen.horizontalCenter
        role: "caption"
        text: I18n.t("prefs.notif.position." + stage.position)
    }

    // the app's icon (a letter on the accent)
    component AppIcon: Mark {
        width: Space.px(24)
        height: width
        radius: Look.radius("small", height)
        color: Qt.alpha(Type.accent, 0.3)
        KitText {
            anchors.centerIn: parent
            role: "caption"
            font.weight: Font.DemiBold
            color: Type.text
            text: "M"
        }
    }
}
