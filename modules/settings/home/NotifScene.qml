pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store
import "../../notifications/NotificationPolicy.js" as Policy

// Home tile scene of Notifications: a little stack of toasts in the corner
// where they show (NotificationPolicy, the shell's own rules).
Item {
    id: scene

    required property Card tile
    readonly property string position: Policy.resolvePosition(String(SettingsStore.get("notifications.position") || "auto"), {
        "barPosition": String(SettingsStore.get("bar.position") || "top")
    })
    readonly property var corner: Policy.anchorsOf(scene.position)
    readonly property bool atBottom: scene.corner.vertical === "bottom"
    readonly property real toastW: scene.width * 0.8
    readonly property real toastH: Space.controlM
    readonly property real stackX: scene.corner.horizontal === "left" ? 0 : scene.corner.horizontal === "right" ? scene.width - scene.toastW : (scene.width - scene.toastW) / 2

    // the older toast, behind
    Mark {
        x: scene.stackX + scene.toastW * 0.04
        y: scene.atBottom ? scene.height - scene.toastH - Space.xs - height : scene.toastH + Space.xs
        width: scene.toastW * 0.92
        height: scene.toastH * 0.7
        radius: Look.radius("box", height)
        color: Look.raisedFill(false)
        opacity: 0.6
    }
    // the newest
    Mark {
        x: scene.stackX
        y: scene.atBottom ? scene.height - scene.toastH : 0
        width: scene.toastW
        height: scene.toastH
        radius: Look.radius("box", height)
        color: Look.raisedFill(true)

        KitText {
            x: Space.m
            y: Space.s
            role: "caption"
            color: Type.text
            font.weight: Font.DemiBold
            text: "Yuki"
        }
        Mark {
            x: Space.m
            y: parent.height - Space.s - height
            width: scene.toastW * 0.5
            height: Space.xs
            color: Qt.alpha(Type.text, 0.35)
        }
    }
}
