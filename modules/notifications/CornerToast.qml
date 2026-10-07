pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "ToastModel.js" as ToastModel

// One corner toast: the latest notification of a popup group (one app, or
// one notification when notifications.groupByApp is off) on a kit Surface.
// The rest of the group is a compact stack: up to two sheets peek out from
// under the card, away from the screen edge (`stackUp` for bottom corners),
// and the caption counts them. Hover pauses the group's timers and shows
// the dismiss button; click activates, middle click dismisses the group.
Item {
    id: root

    property var group: null
    property bool stackUp: false
    // Last non-empty group: keeps the content while the remove transition runs
    property var held: null
    onGroupChanged: if (group)
        held = group
    readonly property var notifications: root.held ? ToastModel.visible(root.held.notifications) : []
    readonly property var latest: ToastModel.latest(root.notifications)
    readonly property int extra: Math.max(0, root.notifications.length - 1)
    readonly property int depth: ToastModel.stackDepth(root.notifications.length)
    readonly property int peek: Space.m

    implicitHeight: card.height + root.depth * root.peek

    function dismiss(): void {
        if (root.notifications.length > 0)
            Notifications.discardNotifications(root.notifications.map(n => n.id));
    }

    // The app group this toast paused; resumed on leave, or when the toast
    // goes away under the pointer (no leave event then)
    property string pausedApp: ""
    function hold(on: bool): void {
        if (root.pausedApp !== "")
            Notifications.resumeGroupTimers(root.pausedApp);
        root.pausedApp = on && root.held ? root.held.appName : "";
        if (root.pausedApp !== "")
            Notifications.pauseGroupTimers(root.pausedApp);
    }
    Component.onDestruction: hold(false)

    HoverHandler {
        id: hover
        onHoveredChanged: root.hold(hovered)
    }

    // The stack: sheets behind the card, each a little narrower and quieter.
    // Each sheet shows only its own `peek` strip past the one in front of it
    // (a clip), so translucent boxes never show through each other.
    Repeater {
        model: root.depth

        Item {
            id: strip
            objectName: "toastSheet"
            required property int index
            readonly property int step: index + 1
            z: -step
            x: Space.m * step
            y: root.stackUp ? card.y - root.peek * step : card.y + card.height + root.peek * (step - 1)
            width: root.width - 2 * Space.m * step
            height: root.peek
            clip: true

            Surface {
                y: root.stackUp ? 0 : root.peek - card.height
                width: strip.width
                height: card.height
                floating: true
                glassSurface: "popups"
                opacity: ToastModel.sheetOpacity(strip.step)
                padding: 0
            }
        }
    }

    // The card: one floating kit Surface sized to its content. Its own box
    // (StyledRect) draws the fill, edge and shadow; no extra layer on top.
    Surface {
        id: card
        objectName: "toastCard"
        y: root.stackUp ? root.depth * root.peek : 0
        width: root.width
        height: content.implicitHeight + 2 * card.padding
        floating: true
        glassSurface: "popups"
        enableShadow: true

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
                if (mouse.button === Qt.MiddleButton)
                    root.dismiss();
                else if (root.latest)
                    Notifications.activateNotification(root.latest.id);
            }
        }

        ToastCard {
            id: content
            objectName: "toastContent"
            width: card.width - 2 * card.padding
            notification: root.latest
            extra: root.extra
            hovered: hover.hovered
            onDismissRequested: root.dismiss()
            onActionInvoked: identifier => {
                if (!root.latest)
                    return;
                Notifications.attemptInvokeAction(root.latest.id, identifier, false);
                root.dismiss();
            }
        }
    }
}
