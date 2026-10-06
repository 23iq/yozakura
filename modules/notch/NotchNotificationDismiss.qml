pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell.Services.Notifications
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.config

// Dismiss button of a notification in the notch; grows in on hover.
Item {
    id: dismiss

    property var notification
    property bool hovered: false

    property int buttonSize: dismiss.hovered ? 24 : 0
    implicitWidth: buttonSize
    implicitHeight: buttonSize
    z: 200

    Behavior on buttonSize {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutQuart
        }
    }

    Loader {
        anchors.fill: parent
        active: dismiss.hovered

        sourceComponent: Button {
            id: dismissButton
            anchors.fill: parent
            hoverEnabled: true
            z: 200

            background: Item {
                id: notchDismissBg
                property color iconColor: dismiss.notification && dismiss.notification.urgency == NotificationUrgency.Critical ? Colors.shadow : (dismissButton.pressed ? Colors.overError : Colors.error)

                Rectangle {
                    anchors.fill: parent
                    visible: dismiss.notification && dismiss.notification.urgency == NotificationUrgency.Critical
                    color: dismissButton.hovered ? Qt.lighter(Colors.criticalRed, 1.3) : Colors.criticalRed
                    radius: Styling.radius(4)

                    Behavior on color {
                        enabled: Config.animDuration > 0
                        ColorAnimation {
                            duration: Config.animDuration
                        }
                    }
                }

                StyledRect {
                    id: notchDismissStyled
                    anchors.fill: parent
                    visible: !(dismiss.notification && dismiss.notification.urgency == NotificationUrgency.Critical)
                    variant: dismissButton.pressed ? "error" : (dismissButton.hovered ? "focus" : "common")
                    radius: Styling.radius(4)
                }
            }

            contentItem: Text {
                text: Icons.cancel
                textFormat: Text.RichText
                font.family: Icons.font
                font.pixelSize: 16
                color: notchDismissBg.iconColor
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            onClicked: {
                if (dismiss.notification) {
                    Notifications.discardNotification(dismiss.notification.id);
                }
            }
        }
    }
}
