pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store
import "../../notifications/NotificationPolicy.js" as Policy

// Stage of the Notifications page: your whole screen (ScreenMini) with a
// notification where it appears now (NotificationPolicy, the same rules as
// the shell): grown from the island, or a toast in its corner, ringed in
// the accent. With corner toasts the windows fade back and every other
// place is a dashed "move here" zone with an arrow; a click moves
// notifications there (notifications.position).
Stage {
    id: stage

    readonly property var ctx: ({
            "barStyle": mini.panels.length > 0 ? mini.panels[0].style : "",
            "barPosition": mini.panels.length > 0 ? mini.panels[0].edge : "top",
            "notchPosition": mini.islandEdge,
            "notchEnabled": mini.island
        })
    readonly property string presentation: Policy.resolvePresentation(String(SettingsStore.get("notifications.presentation") || "auto"), stage.ctx)
    readonly property string position: Policy.resolvePosition(String(SettingsStore.get("notifications.position") || "auto"), stage.ctx)
    readonly property bool corners: stage.presentation === "corner"
    readonly property var places: Policy.POSITIONS.filter(p => p !== "auto")
    property string hovered: ""

    stageHeight: Space.px(270)

    ScreenMini {
        id: mini
        anchors.fill: parent
        barOpacity: stage.barOpacity
        cornerRadius: stage.radius
        showDock: true
        emphasis: stage.presentation === "notch" ? "island" : ""
        windowsOpacity: stage.corners ? 0.3 : 1

        // Where a toast sits for a position, in the space the bars leave.
        function placeOf(pos, w, h) {
            const a = Policy.anchorsOf(pos);
            const r = mini.freeRect;
            const m = Math.round(mini.unit * 0.5);
            return {
                "x": a.horizontal === "left" ? r.x + m : a.horizontal === "right" ? r.x + r.w - w - m : r.x + (r.w - w) / 2,
                "y": a.vertical === "top" ? r.y + m : r.y + r.h - h - m
            };
        }

        // The other places (corner toasts only): faint targets.
        Repeater {
            model: stage.corners ? stage.places : []
            delegate: Toast {
                id: target
                required property string modelData
                readonly property var at: mini.placeOf(modelData, width, height)
                objectName: "notifPlace:" + modelData
                visible: modelData !== stage.position
                solid: false
                ghost: false
                border.width: 0
                x: at.x
                y: at.y

                DashedFrame {
                    anchors.fill: parent
                    radius: target.radius
                    fill: Qt.alpha(Type.accent, stage.hovered === target.modelData ? 0.28 : 0.08)
                }
                Row {
                    anchors.centerIn: parent
                    spacing: Space.xs
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: target.at.y > mini.height / 2 ? Icons.arrowDown : Icons.arrowUp
                        role: "caption"
                        tone: "accent"
                    }
                    KitText {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: target.width > Space.px(90)
                        role: "caption"
                        color: Type.text
                        text: I18n.t("prefs.home.move_here")
                    }
                }

                MouseArea {
                    objectName: "notifPlaceArea:" + target.modelData
                    anchors.fill: parent
                    anchors.margins: -Space.xs
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onContainsMouseChanged: {
                        if (containsMouse)
                            stage.hovered = target.modelData;
                        else if (stage.hovered === target.modelData)
                            stage.hovered = "";
                    }
                    onClicked: {
                        stage.hovered = "";
                        SettingsStore.transaction("prefs.undo.notif_moved", () => SettingsStore.set("notifications.position", target.modelData));
                    }
                }
            }
        }

        // The notification where it shows now; it glides to a new place.
        Toast {
            id: now
            objectName: "notifNow"
            readonly property var at: stage.corners ? mini.placeOf(stage.position, width, height) : {
                "x": mini.islandRect.x + (mini.islandRect.w - width) / 2,
                "y": mini.islandEdge === "bottom" ? mini.islandRect.y - height - Space.xs : mini.islandRect.y + mini.islandRect.h + Space.xs
            }
            visible: stage.presentation !== "strips"
            x: now.at.x
            y: now.at.y
            Behavior on x {
                NumberAnimation {
                    duration: Motion.glide.duration
                    easing.type: Motion.glide.easing
                }
            }
            Behavior on y {
                NumberAnimation {
                    duration: Motion.glide.duration
                    easing.type: Motion.glide.easing
                }
            }
            Mark {
                anchors.fill: parent
                anchors.margins: -Space.xs
                visible: stage.corners
                radius: now.radius + Space.xs
                color: "transparent"
                border.width: Space.stroke - 1
                border.color: Type.accent
            }
            StageSpot {
                keys: ["notifications.presentation", "notifications.position"]
                cornerRadius: now.radius
            }
        }
    }

    // One toast: an icon and two lines.
    component Toast: Mark {
        id: toast
        property bool solid: true
        property bool ghost: false
        width: Math.round(mini.width * 0.2)
        height: Math.round(mini.unit * 1.9)
        radius: Look.radius("box", height)
        color: toast.solid ? Look.raisedFill(false) : Qt.alpha(Type.accent, toast.ghost ? 0.22 : 0)
        border.width: Space.hairline
        border.color: toast.solid ? Qt.alpha(Colors.outlineVariant, 0.8) : Qt.alpha(Type.accent, toast.ghost ? 1 : 0.4)

        Row {
            visible: toast.solid || toast.ghost
            anchors.verticalCenter: parent.verticalCenter
            x: Math.round(mini.unit * 0.45)
            spacing: Math.round(mini.unit * 0.35)
            opacity: toast.solid ? 1 : 0.7
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                icon: Icons.bell
                size: Math.round(mini.unit * 0.8)
                tone: "accent"
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(mini.unit * 0.22)
                Mark {
                    width: toast.width * 0.42
                    height: Math.max(2, Math.round(mini.unit * 0.2))
                    color: Qt.alpha(Type.text, 0.7)
                }
                Mark {
                    width: toast.width * 0.6
                    height: Math.max(2, Math.round(mini.unit * 0.16))
                    color: Qt.alpha(Type.text, 0.3)
                }
            }
        }
    }
}
