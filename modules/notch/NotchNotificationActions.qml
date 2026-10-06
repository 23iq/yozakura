pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.Notifications
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.config

// A notification's action buttons, shown while the notch is hovered
// (NotchNotificationCard, CompactNotification).
Item {
    id: actions

    property var notification
    property bool hovered: false

    implicitHeight: (actions.hovered && actions.notification && actions.notification.actions.length > 0 && !actions.notification.isCached) ? 32 : 0
    height: implicitHeight
    visible: implicitHeight > 0
    clip: true
    z: 200

    RowLayout {
        anchors.fill: parent
        spacing: 4

        Repeater {
            model: actions.notification ? actions.notification.actions : []

            Button {
                id: actionButton
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                z: 200

                text: actionButton.modelData.text
                font.family: Config.theme.font
                font.pixelSize: Config.theme.fontSize
                font.weight: Font.Bold
                hoverEnabled: true

                background: Item {
                    id: notchActionBg
                    property color textColor: actions.notification && actions.notification.urgency == NotificationUrgency.Critical ? Colors.shadow : notchActionStyled.item

                    Rectangle {
                        anchors.fill: parent
                        visible: actions.notification && actions.notification.urgency == NotificationUrgency.Critical
                        color: actionButton.hovered ? Qt.lighter(Colors.criticalRed, 1.3) : Colors.criticalRed
                        radius: Styling.radius(4)

                        Behavior on color {
                            enabled: Config.animDuration > 0
                            ColorAnimation {
                                duration: Config.animDuration
                            }
                        }
                    }

                    StyledRect {
                        id: notchActionStyled
                        anchors.fill: parent
                        visible: !(actions.notification && actions.notification.urgency == NotificationUrgency.Critical)
                        variant: actionButton.pressed ? "primary" : (actionButton.hovered ? "focus" : "common")
                        radius: Styling.radius(4)
                    }
                }

                contentItem: Text {
                    text: actionButton.text
                    font: actionButton.font
                    color: notchActionBg.textColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }

                onClicked: {
                    Notifications.attemptInvokeAction(actions.notification.id, actionButton.modelData.identifier);
                }
            }
        }
    }
}
