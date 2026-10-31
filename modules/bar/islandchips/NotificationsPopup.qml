import QtQuick
import qs.modules.services
import qs.modules.components
import qs.modules.components.kit
import qs.modules.widgets.dashboard.widgets

// Popup of the notifications chip: the notification history, the same
// widget as the dashboard's (NotificationHistory: one row per app, Clear,
// the Silent chip), sized to its rows up to a scrolling list.
BarPopup {
    id: popup

    readonly property int rows: Math.min(6, Math.max(2, Notifications.appNameList ? Notifications.appNameList.length : 0))

    objectName: "notificationsPopup"
    popupPadding: Look.surfacePadding
    contentWidth: Space.controlXL * 4 + popupPadding * 2
    // The label row, the rows, then the Silent chip under the list
    contentHeight: Space.xl + popup.rows * (Space.rowHeight + Space.xs) + Space.m + Space.chip + popupPadding * 2

    NotificationHistory {
        anchors.fill: parent
        framed: false
        active: popup.isOpen
    }
}
