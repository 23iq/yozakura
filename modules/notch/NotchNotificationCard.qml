import QtQuick
import qs.modules.services
import qs.modules.notifications

// notifications.notchStyle "card": the notification in the island, laid
// out like a corner toast (ToastCard: the art, the summary, the body, the
// app · time caption, with "2/3" while there are more popups). The geometry holds
// between rest and hover: hovering only shows the dismiss button in its
// reserved place, lets the body run to more lines and adds the actions
// under the caption (the first one primary). Click activates.
// CompactNotification is the one-line alternative (NotchNotificationStyles.js).
Item {
    id: card

    property var notification
    property bool hovered: false
    property int timestampUpdateCounter: 0
    // Place among the popups ("2/3", scroll to move), "" when alone
    property string position: ""

    implicitHeight: content.implicitHeight

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (card.notification)
                Notifications.activateNotification(card.notification.id);
        }
    }

    ToastCard {
        id: content
        objectName: "notchCardContent"
        width: parent.width
        notification: card.notification
        position: card.position
        hovered: card.hovered
        tick: card.timestampUpdateCounter
        showActions: card.hovered
        primaryAction: true
        // The StackView clips: keep the dismiss button inside the card
        dismissOutset: 0
        bodyLines: card.hovered ? 4 : 2
        onDismissRequested: {
            if (card.notification)
                Notifications.discardNotification(card.notification.id);
        }
        onActionInvoked: identifier => {
            if (card.notification)
                Notifications.attemptInvokeAction(card.notification.id, identifier);
        }
    }
}
