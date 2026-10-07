pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components
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

    implicitHeight: card.implicitHeight + root.depth * root.peek

    function dismiss(): void {
        if (root.notifications.length > 0)
            Notifications.discardNotifications(root.notifications.map(n => n.id));
    }

    HoverHandler {
        id: hover
        onHoveredChanged: {
            if (!root.held)
                return;
            if (hovered)
                Notifications.pauseGroupTimers(root.held.appName);
            else
                Notifications.resumeGroupTimers(root.held.appName);
        }
    }

    // The stack: sheets behind the card, each a little narrower and quieter,
    // with a hairline so their edges read over any wallpaper.
    Repeater {
        model: root.depth

        Surface {
            required property int index
            readonly property int step: index + 1
            z: -step
            x: Space.m * step
            y: root.stackUp ? root.depth * root.peek - root.peek * step : root.peek * step
            width: root.width - 2 * Space.m * step
            height: card.height
            glassSurface: "popups"
            opacity: ToastModel.sheetOpacity(step)
            padding: 0

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: "transparent"
                border.width: Space.hairline
                border.color: Type.track
            }
        }
    }

    Surface {
        id: card
        y: root.stackUp ? root.depth * root.peek : 0
        width: root.width
        implicitHeight: box.implicitHeight + 2 * padding
        glassSurface: "popups"
        layer.enabled: true
        layer.effect: Shadow {}

        MouseArea {
            width: box.width
            height: box.height
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
                if (mouse.button === Qt.MiddleButton)
                    root.dismiss();
                else if (root.latest)
                    Notifications.activateNotification(root.latest.id);
            }
        }

        // The language's group box (ink: none, glass: a frosted card, tiles: a tile).
        Group {
            id: box
            width: card.width - 2 * card.padding

            ToastCard {
                id: content
                width: parent.width
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
}
