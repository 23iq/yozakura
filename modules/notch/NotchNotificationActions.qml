pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.services
import qs.modules.components.kit

// A notification's action buttons as kit Chips, shown while the notch is
// hovered (NotchNotificationCard, CompactNotification).
Item {
    id: actions

    property var notification
    property bool hovered: false

    implicitHeight: (actions.hovered && actions.notification && actions.notification.actions.length > 0 && !actions.notification.isCached) ? Space.chip : 0
    height: implicitHeight
    visible: implicitHeight > 0
    clip: true
    z: 200

    RowLayout {
        anchors.fill: parent
        spacing: Space.s

        Repeater {
            model: actions.notification ? actions.notification.actions : []

            Chip {
                required property var modelData
                Layout.fillWidth: true
                text: modelData.text
                onClicked: Notifications.attemptInvokeAction(actions.notification.id, modelData.identifier)
            }
        }
    }
}
