import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.modules.components.kit
import qs.modules.notifications
import qs.config
import "../notifications/notification_utils.js" as NotificationUtils
import "NotificationBody.js" as NotificationBody

// notifications.notchStyle "card": the full notification in the notch.
// Resting: app icon, summary and body on one line. Hovered: a larger icon,
// summary · app and the time, the body on up to three lines, the dismiss
// button and the actions. Text in kit Type roles; a critical one keeps its
// stripes and critical ink. CompactNotification is the one-line
// alternative (NotchNotificationStyles.js).
Item {
    id: card

    property var notification
    property bool hovered: false
    property int timestampUpdateCounter: 0

    readonly property bool critical: !!card.notification && card.notification.urgency == NotificationUrgency.Critical
    readonly property color ink: card.critical ? Colors.criticalText : Type.text
    readonly property color quiet: card.critical ? Colors.criticalText : Type.secondary
    readonly property string bodyText: card.notification ? NotificationBody.clean(card.notification.body, card.notification.appName) : ""

    implicitHeight: content.implicitHeight

    Column {
        id: content
        width: parent.width
        spacing: card.hovered ? Space.s : 0

        Item {
            id: main
            width: parent.width
            readonly property int criticalMargins: card.hovered && card.critical ? Space.l : 0
            implicitHeight: row.implicitHeight + main.criticalMargins * 2

            DiagonalStripePattern {
                anchors.fill: parent
                visible: card.critical
                radius: Space.controlRadius
                animationRunning: visible
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (card.notification)
                        Notifications.activateNotification(card.notification.id);
                }
            }

            RowLayout {
                id: row
                anchors.fill: parent
                anchors.margins: main.criticalMargins
                anchors.leftMargin: main.criticalMargins > 0 ? Space.s : 0
                anchors.rightMargin: main.criticalMargins > 0 ? Space.s : 0
                spacing: Space.m

                NotificationAppIcon {
                    readonly property int iconSize: card.hovered ? Space.controlM + Space.s : Space.controlS
                    Layout.preferredWidth: iconSize
                    Layout.preferredHeight: iconSize
                    Layout.alignment: Qt.AlignTop
                    size: iconSize
                    radius: Space.controlRadius
                    appName: card.notification ? card.notification.appName : ""
                    appIcon: card.notification ? (card.notification.cachedAppIcon || card.notification.appIcon) : ""
                    image: card.notification ? (card.notification.cachedImage || card.notification.image) : ""
                    summary: card.notification ? card.notification.summary : ""
                    urgency: card.notification ? card.notification.urgency : NotificationUrgency.Normal
                }

                Column {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 1

                    // Hovered: summary · app, the time on the right
                    Item {
                        width: parent.width
                        height: summaryText.implicitHeight
                        visible: card.hovered

                        Row {
                            anchors.left: parent.left
                            anchors.right: timeText.left
                            anchors.rightMargin: Space.s
                            spacing: Space.s

                            KitText {
                                id: summaryText
                                width: Math.min(implicitWidth, parent.width - (appText.visible ? Math.min(appText.implicitWidth, parent.width * 0.4) + parent.spacing : 0))
                                role: "body"
                                font.weight: Look.activeLabelWeight
                                font.underline: card.critical
                                color: card.ink
                                text: card.notification ? card.notification.summary : ""
                            }
                            KitText {
                                id: appText
                                anchors.baseline: summaryText.baseline
                                width: Math.min(implicitWidth, parent.width - summaryText.width - parent.spacing)
                                visible: text !== ""
                                role: "caption"
                                color: card.critical ? Colors.criticalText : Type.muted
                                text: card.notification ? card.notification.appName : ""
                            }
                        }
                        KitText {
                            id: timeText
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            role: "caption"
                            tabular: true
                            color: card.critical ? Colors.criticalText : Type.muted
                            text: card.notification && card.timestampUpdateCounter >= 0 ? NotificationUtils.getFriendlyNotifTimeString(card.notification.time) : ""
                        }
                    }
                    KitText {
                        width: parent.width
                        visible: card.hovered && text !== ""
                        role: "secondary"
                        color: card.quiet
                        text: card.bodyText
                        textFormat: Text.StyledText
                        wrapMode: Text.Wrap
                        maximumLineCount: 3
                    }

                    // Resting: summary, then the body on the same line
                    Row {
                        width: parent.width
                        visible: !card.hovered
                        spacing: Space.s

                        KitText {
                            id: summaryLine
                            width: Math.min(implicitWidth, bodyLine.text !== "" ? parent.width * 0.6 : parent.width)
                            role: "body"
                            font.weight: Look.activeLabelWeight
                            color: card.ink
                            text: card.notification ? card.notification.summary : ""
                        }
                        KitText {
                            id: bodyLine
                            anchors.baseline: summaryLine.baseline
                            width: parent.width - summaryLine.width - parent.spacing
                            visible: text !== ""
                            role: "secondary"
                            color: card.quiet
                            text: card.bodyText.replace(/\n/g, " ")
                        }
                    }
                }

                NotchNotificationDismiss {
                    Layout.preferredWidth: implicitWidth
                    Layout.preferredHeight: implicitHeight
                    Layout.alignment: Qt.AlignTop
                    notification: card.notification
                    hovered: card.hovered
                }
            }
        }

        NotchNotificationActions {
            width: parent.width
            notification: card.notification
            hovered: card.hovered
        }
    }
}
