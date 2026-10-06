import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import qs.modules.theme
import qs.modules.services
import qs.modules.globals
import qs.modules.components
import qs.modules.notifications
import qs.config
import "../notifications/notification_utils.js" as NotificationUtils
import "NotificationBody.js" as NotificationBody

// notifications.notchStyle "card": the full notification in the notch
// (icon, summary, app, time, body; actions and a larger icon on hover).
// Extracted from NotchNotificationView; CompactNotification is the
// one-line alternative (NotchNotificationStyles.js).
Item {
    id: card

    property var notification
    property bool hovered: false
    property int timestampUpdateCounter: 0

    implicitHeight: notificationContent.implicitHeight

    Column {
        id: notificationContent
        width: parent.width
        spacing: card.hovered ? 8 : 0

        Behavior on spacing {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutBack
                easing.overshoot: 1.2
            }
        }

        // Contenido principal de la notificación
        Item {
            width: parent.width
            property int criticalMargins: card.hovered && card.notification && card.notification.urgency == NotificationUrgency.Critical ? 16 : 0
            implicitHeight: mainContentRow.implicitHeight + (criticalMargins * 2)

            Behavior on criticalMargins {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration
                    easing.type: Easing.OutQuart
                }
            }

            DiagonalStripePattern {
                id: notchStripeContainer
                anchors.fill: parent
                visible: card.notification && card.notification.urgency == NotificationUrgency.Critical
                radius: Styling.radius(4)
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
                id: mainContentRow
                anchors.fill: parent
                anchors.topMargin: parent.criticalMargins
                anchors.bottomMargin: parent.criticalMargins
                anchors.leftMargin: parent.criticalMargins > 0 ? 8 : 0
                anchors.rightMargin: parent.criticalMargins > 0 ? 8 : 0
                implicitHeight: Math.max(card.hovered ? 48 : 32, textContainer.implicitHeight)
                spacing: 8

                // Contenido principal
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    // App icon
                    NotificationAppIcon {
                        id: appIcon
                        property int iconSize: card.hovered ? 48 : 32
                        Layout.preferredWidth: iconSize
                        Layout.preferredHeight: iconSize
                        Layout.alignment: Qt.AlignTop
                        size: iconSize
                        radius: Styling.radius(4)
                        appName: card.notification ? card.notification.appName : ""
                        appIcon: card.notification ? (card.notification.cachedAppIcon || card.notification.appIcon) : ""
                        image: card.notification ? (card.notification.cachedImage || card.notification.image) : ""
                        summary: card.notification ? card.notification.summary : ""
                        urgency: card.notification ? card.notification.urgency : NotificationUrgency.Normal

                        Behavior on iconSize {
                            enabled: Config.animDuration > 0
                            NumberAnimation {
                                duration: Config.animDuration
                                easing.type: Easing.OutQuart
                            }
                        }
                    }

                    // Textos de la notificación
                    Item {
                        id: textContainer
                        Layout.fillWidth: true
                        implicitHeight: card.hovered ? textColumnExpanded.implicitHeight : textRowCollapsed.implicitHeight

                        Column {
                            id: textColumnExpanded
                            width: parent.width
                            spacing: 4
                            visible: card.hovered

                            // Fila del summary, app name y timestamp
                            RowLayout {
                                width: parent.width
                                spacing: 4

                                // Contenedor izquierdo para summary y app name
                                Row {
                                    id: leftTextsContainer
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    spacing: 4

                                    Text {
                                        id: summaryText
                                        property real combinedImplicitWidth: implicitWidth + (appNameText.visible ? appNameText.implicitWidth + parent.spacing : 0)
                                        width: {
                                            if (combinedImplicitWidth <= leftTextsContainer.width) {
                                                return implicitWidth;
                                            }
                                            return leftTextsContainer.width - (appNameText.visible ? appNameText.width + parent.spacing : 0);
                                        }
                                        text: card.notification ? card.notification.summary : ""
                                        font.family: Config.theme.font
                                        font.pixelSize: Config.theme.fontSize
                                        font.weight: Font.Bold
                                        font.underline: card.notification && card.notification.urgency == NotificationUrgency.Critical && card.hovered
                                        color: card.notification && card.notification.urgency == NotificationUrgency.Critical ? Colors.criticalText : Styling.srItem("overprimary")
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                        wrapMode: Text.NoWrap
                                        verticalAlignment: Text.AlignVCenter
                                    }

                                    Text {
                                        id: appNameText
                                        property real availableWidth: leftTextsContainer.width - summaryText.implicitWidth - (visible ? parent.spacing : 0)
                                        width: {
                                            if (summaryText.combinedImplicitWidth <= leftTextsContainer.width) {
                                                return implicitWidth;
                                            }
                                            return Math.min(implicitWidth, Math.max(60, availableWidth, leftTextsContainer.width * 0.3));
                                        }
                                        text: card.notification ? "• " + card.notification.appName : ""
                                        font.family: Config.theme.font
                                        font.pixelSize: Config.theme.fontSize
                                        font.weight: Font.Bold
                                        color: card.notification && card.notification.urgency == NotificationUrgency.Critical ? Colors.criticalText : Colors.outline
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                        wrapMode: Text.NoWrap
                                        verticalAlignment: Text.AlignVCenter
                                        visible: text !== ""
                                    }
                                }

                                // Timestamp a la derecha
                                Text {
                                    id: timestampText
                                    // Usar timestampUpdateCounter para forzar re-evaluación cada minuto
                                    text: card.notification ? (card.timestampUpdateCounter >= 0 ? NotificationUtils.getFriendlyNotifTimeString(card.notification.time) : "") : ""
                                    font.family: Config.theme.font
                                    font.pixelSize: Config.theme.fontSize
                                    font.weight: Font.Bold
                                    color: card.notification && card.notification.urgency == NotificationUrgency.Critical ? Colors.criticalText : Colors.outline
                                    verticalAlignment: Text.AlignVCenter
                                    visible: text !== ""
                                }
                            }

                            Text {
                                width: parent.width
                                text: card.notification ? NotificationBody.clean(card.notification.body, card.notification.appName) : ""
                                font.family: Config.theme.font
                                font.pixelSize: Config.theme.fontSize
                                font.weight: card.notification && card.notification.urgency == NotificationUrgency.Critical ? Font.Bold : Font.Normal
                                color: card.notification && card.notification.urgency == NotificationUrgency.Critical ? Colors.criticalText : Colors.overBackground
                                wrapMode: Text.Wrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                                visible: text !== ""
                            }
                        }

                        Row {
                            id: textRowCollapsed
                            width: parent.width
                            spacing: 4
                            visible: !card.hovered

                            Text {
                                id: summaryCollapsed
                                property real combinedImplicitWidth: implicitWidth + (bodyCollapsed.visible ? bodyCollapsed.implicitWidth + bulletCollapsed.implicitWidth + parent.spacing * 2 : 0)
                                width: {
                                    if (combinedImplicitWidth <= parent.width) {
                                        return implicitWidth;
                                    }
                                    return parent.width - (bodyCollapsed.visible ? bodyCollapsed.width + bulletCollapsed.width + parent.spacing * 2 : 0);
                                }
                                text: card.notification ? card.notification.summary : ""
                                font.family: Config.theme.font
                                font.pixelSize: Config.theme.fontSize
                                font.weight: Font.Bold
                                color: card.notification && card.notification.urgency == NotificationUrgency.Critical ? Colors.criticalText : Styling.srItem("overprimary")
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                wrapMode: Text.NoWrap
                                verticalAlignment: Text.AlignVCenter
                            }

                            Text {
                                id: bulletCollapsed
                                text: "•"
                                font.family: Config.theme.font
                                font.pixelSize: Config.theme.fontSize
                                font.weight: Font.Bold
                                color: card.notification && card.notification.urgency == NotificationUrgency.Critical ? Colors.criticalText : Colors.outline
                                verticalAlignment: Text.AlignVCenter
                                visible: card.notification && card.notification.body && card.notification.body.length > 0
                            }

                            Text {
                                id: bodyCollapsed
                                property real availableWidth: parent.width - summaryCollapsed.implicitWidth - (visible ? bulletCollapsed.implicitWidth + parent.spacing * 2 : 0)
                                width: {
                                    if (summaryCollapsed.combinedImplicitWidth <= parent.width) {
                                        return implicitWidth;
                                    }
                                    return Math.min(implicitWidth, Math.max(60, availableWidth, parent.width * 0.3));
                                }
                                text: card.notification ? NotificationBody.clean(card.notification.body || "").replace(/\n/g, ' ') : ""
                                font.family: Config.theme.font
                                font.pixelSize: Config.theme.fontSize
                                font.weight: card.notification && card.notification.urgency == NotificationUrgency.Critical ? Font.Bold : Font.Normal
                                color: card.notification && card.notification.urgency == NotificationUrgency.Critical ? Colors.criticalText : Colors.overBackground
                                wrapMode: Text.NoWrap
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                verticalAlignment: Text.AlignVCenter
                                visible: text.length > 0
                            }
                        }
                    }
                }

                // Dismiss button
                NotchNotificationDismiss {
                    Layout.preferredWidth: implicitWidth
                    Layout.preferredHeight: implicitHeight
                    Layout.alignment: Qt.AlignTop
                    notification: card.notification
                    hovered: card.hovered
                }
            }
        }

        // Action buttons (hover only)
        NotchNotificationActions {
            width: parent.width
            notification: card.notification
            hovered: card.hovered
        }
    }
}
