pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.config
import "./NotificationDelegate.qml"

// One corner toast: the latest notification of a popup group (one app, or
// one notification when notifications.groupByApp is off) on a glass popup
// card, with a "+N" badge for the rest of the group. Hover pauses the
// group's timers; the delegate handles click (activate), actions and dismiss.
Item {
    id: root

    property var group: null
    // Last non-empty group: keeps the content while the remove transition runs
    property var held: null
    onGroupChanged: if (group)
        held = group
    readonly property var notifications: held ? held.notifications.filter(n => n && (n.summary || n.body)) : []
    readonly property var latest: notifications.length > 0 ? notifications.reduce((a, b) => (b.time > a.time ? b : a)) : null
    readonly property int extra: Math.max(0, notifications.length - 1)

    implicitHeight: card.implicitHeight

    HoverHandler {
        onHoveredChanged: {
            if (!root.held)
                return;
            if (hovered)
                Notifications.pauseGroupTimers(root.held.appName);
            else
                Notifications.resumeGroupTimers(root.held.appName);
        }
    }

    StyledRect {
        id: card
        variant: "popup"
        glassSurface: "popups"
        width: parent.width
        implicitHeight: delegate.implicitHeight + 24
        radius: Styling.radius(4)
        layer.enabled: true
        layer.effect: Shadow {}

        NotificationDelegate {
            id: delegate
            x: 12
            y: 12
            width: card.width - 24
            notificationObject: root.latest
            notifications: root.latest ? [root.latest] : []
            expanded: true
            onlyNotification: true
            onDestroyRequested: {
                if (root.notifications.length > 0)
                    Notifications.discardNotifications(root.notifications.map(n => n.id));
            }
        }

        // "+N" more from the same app
        StyledRect {
            visible: root.extra > 0
            variant: "primary"
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 10
            width: badge.implicitWidth + 14
            height: badge.implicitHeight + 6
            radius: height / 2
            Text {
                id: badge
                anchors.centerIn: parent
                text: "+" + root.extra
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
                font.weight: Font.DemiBold
                color: parent.item
            }
        }
    }
}
